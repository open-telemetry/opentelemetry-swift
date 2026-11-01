#!/usr/bin/env python3
# Copyright The OpenTelemetry Authors
# SPDX-License-Identifier: Apache-2.0
"""Compares MincoreLaunchInstrumentation's app.start span with Instruments on a real device.

Each launch is recorded by both: xctrace's App Launch template, and an OTLP receiver in this script
that the demo app exports to. The script then checks the span's launch type, sampled pages and
phase durations against what the trace saw for the same launch.

Modes, which say how the launch's pages got into their state:

  warm           Launches once first, so the recorded launch finds its code in memory.
  fresh-install  Installs over the app before each launch.
  reboot         Reboots the device before each launch, the only way to empty its page cache.
                 You have to unlock the device after each reboot.

Usage:
  Scripts/compare-app-launch-accuracy.py --mode warm --launches 3
  Scripts/compare-app-launch-accuracy.py --mode reboot --launches 1 --device <udid>
  Scripts/compare-app-launch-accuracy.py --reanalyze .build/app-launch-accuracy/<run>
  Scripts/compare-app-launch-accuracy.py --reanalyze .build/app-launch-accuracy/<run> --dump-periods

The demo app is built for the device, and a copy is patched so it can reach this Mac over plain
HTTP. The device must be unlocked, on the same network as this Mac, and allow the app local network
access the first time it asks. Traces, spans and a report.json are kept in the run's directory.

xctrace hangs when launching on the iOS simulator, so this only supports devices.
"""

import argparse
import collections
import gzip
import http.server
import json
import os
import plistlib
import re
import statistics
import struct
import subprocess
import sys
import threading
import time
import xml.etree.ElementTree as ET

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(REPO_ROOT, "Examples/HackerNewsDemo/HackerNewsDemo.xcodeproj")
SCHEME = "HackerNewsDemo"
BUNDLE_ID = "io.opentelemetry.HackerNewsDemo"
LAUNCH_SPAN = "app.start"
MAX_SAMPLED_PAGES = 256  # MAX_SAMPLED_PAGES in LaunchPageSampling.c.
COLD_RATIO = 0.5  # The default AppLaunchInstrumentationConfiguration.coldPageInRatio.

DISK_READ = "File Backed Page In"
CACHE_HIT = "Page Cache Hit"
STATIC_INIT_PERIOD = "Initializing - Static Runtime Initialization"
FRAME_PERIOD = "Launching - Initial Frame Rendering"
ACTIVE_PERIOD = "Foreground - Active"
# Apple documents UIKit initialization and UIKit initial scene rendering as separate launch phases, and
# app.start.scene_setup would line up with the second. Nobody has confirmed on a device which
# life-cycle-period labels exist for them, so this one is only a guess that --dump-periods marks and
# no comparison uses. To finish the mapping, run with --dump-periods on a real trace (or --reanalyze
# an existing run with it), find the period whose start and end match the scene connecting until the
# first frame, and compare that period's start to the span's. Check it on several launches and iOS
# versions before trusting it.
FIRST_SCENE_PERIOD = "Launching - UIKit Initialization"
# The durations the script knows about. compare() warns about any other app.start.*.duration attribute,
# which is what a renamed attribute looks like from here.
KNOWN_DURATIONS = ("pre_init", "pre_activation", "app_init", "render")


def log(message):
    print("==> " + message, flush=True)


def run(command, timeout=None, check=True):
    return subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          universal_newlines=True, timeout=timeout, check=check).stdout


# OTLP receiver. Only the fields this script reads are decoded, so it needs no protobuf library.


def varint(data, offset):
    value, shift = 0, 0
    while True:
        byte = data[offset]
        offset += 1
        value |= (byte & 0x7F) << shift
        shift += 7
        if not byte & 0x80:
            return value, offset


def fields(data):
    offset = 0
    while offset < len(data):
        key, offset = varint(data, offset)
        number, wire = key >> 3, key & 7
        if wire == 0:
            value, offset = varint(data, offset)
        elif wire == 1:
            value, offset = data[offset:offset + 8], offset + 8
        elif wire == 2:
            length, offset = varint(data, offset)
            value, offset = data[offset:offset + length], offset + length
        elif wire == 5:
            value, offset = data[offset:offset + 4], offset + 4
        else:
            raise ValueError("unsupported protobuf wire type %d" % wire)
        yield number, value


def any_value(data):
    for number, value in fields(data):
        if number == 1:
            return value.decode("utf-8", "replace")
        if number == 2:
            return bool(value)
        if number == 3:
            return value
        if number == 4:
            return struct.unpack("<d", value)[0]
    return None


def key_value(data):
    key, value = None, None
    for number, field in fields(data):
        if number == 1:
            key = field.decode("utf-8", "replace")
        elif number == 2:
            value = any_value(field)
    return key, value


def decode_span(data):
    span = {"attributes": {}}
    for number, value in fields(data):
        if number == 1:
            span["trace_id"] = value.hex()
        elif number == 2:
            span["span_id"] = value.hex()
        elif number == 4:
            span["parent_span_id"] = value.hex()
        elif number == 5:
            span["name"] = value.decode("utf-8", "replace")
        elif number == 7:
            span["start"] = struct.unpack("<Q", value)[0]
        elif number == 8:
            span["end"] = struct.unpack("<Q", value)[0]
        elif number == 9:
            key, attribute = key_value(value)
            span["attributes"][key] = attribute
    return span


def decode_trace_request(body):
    spans = []
    for number, resource_spans in fields(body):
        if number != 1:
            continue
        for inner, scope_spans in fields(resource_spans):
            if inner != 2:
                continue
            spans.extend(decode_span(value) for field, value in fields(scope_spans) if field == 2)
    return spans


class Receiver(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if self.headers.get("Content-Encoding") == "gzip":
            body = gzip.decompress(body)
        if self.path.endswith("/v1/traces"):
            spans = decode_trace_request(body)
            with self.server.lock:
                self.server.spans.extend(spans)
        self.send_response(200)
        self.send_header("Content-Type", "application/x-protobuf")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, *args):
        pass


def start_receiver(host, port):
    server = http.server.ThreadingHTTPServer((host, port), Receiver)
    server.lock = threading.Lock()
    server.spans = []
    thread = threading.Thread(target=server.serve_forever)
    thread.daemon = True
    thread.start()
    return server


def wait_for_span(server, deadline):
    while time.time() < deadline:
        with server.lock:
            launches = [span for span in server.spans if span.get("name") == LAUNCH_SPAN]
            if launches:
                return launches[0], list(server.spans)
        time.sleep(0.5)
    return None, []


# Device and app setup.


def find_device():
    output = run(["xcrun", "xctrace", "list", "devices"])
    section = output.split("== Simulators ==")[0]
    devices = re.findall(r"^(.+) \([\d.]+\) \(([0-9A-Fa-f-]+)\)$", section, re.MULTILINE)
    devices = [device for device in devices if "Mac" not in device[0]]
    if not devices:
        sys.exit("No connected device. Unlock it and check `xcrun xctrace list devices`.")
    if len(devices) > 1:
        sys.exit("Several devices are connected, so choose one with --device: %s" % devices)
    log("Using %s" % devices[0][0])
    return devices[0][1]


def lan_address():
    for interface in ("en0", "en1"):
        address = run(["ipconfig", "getifaddr", interface], check=False).strip()
        if re.match(r"^\d+\.\d+\.\d+\.\d+$", address):
            return address
    sys.exit("Couldn't find this Mac's LAN address, so pass it with --host.")


def build_app(args, directory):
    log("Building %s for the device" % SCHEME)
    derived_data = os.path.join(args.work_dir, "DerivedData")
    command = ["xcodebuild", "-project", PROJECT, "-scheme", SCHEME, "-configuration", args.configuration,
               "-destination", "id=" + args.device, "-derivedDataPath", derived_data,
               "-allowProvisioningUpdates", "build"]
    if args.team:
        command.append("DEVELOPMENT_TEAM=" + args.team)
    log_path = os.path.join(directory, "xcodebuild.log")
    with open(log_path, "w") as output:
        if subprocess.call(command, stdout=output, stderr=subprocess.STDOUT) != 0:
            sys.exit("The build failed. See %s" % log_path)
    return os.path.join(derived_data, "Build/Products/%s-iphoneos/%s.app" % (args.configuration, SCHEME))


def patched_copy(source, directory):
    app = os.path.join(directory, SCHEME + ".app")
    run(["ditto", source, app])
    identity = re.search(r"^Authority=(.+)$", run(["codesign", "-dvv", app]), re.MULTILINE).group(1)
    entitlements = os.path.join(directory, "entitlements.plist")
    with open(entitlements, "w") as output:
        subprocess.check_call(["codesign", "-d", "--entitlements", "-", "--xml", app],
                              stdout=output, stderr=subprocess.DEVNULL)
    info_path = os.path.join(app, "Info.plist")
    with open(info_path, "rb") as info_file:
        info = plistlib.load(info_file)
    info["NSAppTransportSecurity"] = {"NSAllowsArbitraryLoads": True}
    info["NSLocalNetworkUsageDescription"] = "Send telemetry to a local collector"
    with open(info_path, "wb") as info_file:
        plistlib.dump(info, info_file)
    run(["codesign", "-f", "-s", identity, "--entitlements", entitlements, app])
    return app


def devicectl(args, *command):
    return run(["xcrun", "devicectl"] + list(command) + ["--device", args.device], timeout=180, check=False)


def install(args, app):
    output = devicectl(args, "device", "install", "app", app)
    if "installed" not in output.lower() and "databaseUUID" not in output:
        sys.exit("Installing the app failed:\n" + output)


def wait_until_unlocked(args):
    deadline = time.time() + 900
    while time.time() < deadline:
        output = devicectl(args, "device", "info", "lockState")
        if "passcodeRequired: false" in output and "unlockedSinceBoot: true" in output:
            return
        time.sleep(5)
    sys.exit("The device wasn't unlocked within 15 minutes.")


def prepare_launch(args, app):
    if args.mode == "warm":
        # `--device` goes first, because what follows the bundle ID is passed to the app.
        output = run(["xcrun", "devicectl", "device", "process", "launch", "--device", args.device,
                      "--terminate-existing", BUNDLE_ID], timeout=60, check=False)
        if "Launched application" not in output:
            sys.exit("Launching the app to warm it up failed:\n" + output)
        time.sleep(4)
    elif args.mode == "fresh-install":
        # Installing over the app, because uninstalling resets its local network access.
        install(args, app)
    elif args.mode == "reboot":
        log("Rebooting the device. Unlock it when it comes back")
        devicectl(args, "device", "reboot")
        time.sleep(30)
        wait_until_unlocked(args)
        # Let the system finish its post-boot work, which competes with the launch.
        time.sleep(args.settle)


def record(args, trace, endpoint, log_path):
    command = ["xcrun", "xctrace", "record", "--no-prompt", "--template", "App Launch",
               "--device", args.device, "--time-limit", "%ds" % args.record_seconds, "--output", trace,
               "--env", "OTEL_EXPORTER_OTLP_ENDPOINT=" + endpoint, "--launch", "--", BUNDLE_ID]
    with open(log_path, "w") as output:
        process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
        try:
            process.wait(timeout=args.record_seconds + 180)
        except subprocess.TimeoutExpired:
            process.kill()
            return False
    return process.returncode == 0 and os.path.isdir(trace)


# Trace analysis.


def export_toc(trace):
    return run(["xcrun", "xctrace", "export", "--input", trace, "--toc"], timeout=300)


def export_table(trace, schema, path):
    xpath = '/trace-toc/run[@number="1"]/data/table[@schema="%s"]' % schema
    with open(path, "w") as output:
        status = subprocess.call(["xcrun", "xctrace", "export", "--input", trace, "--xpath", xpath],
                                 stdout=output, stderr=subprocess.DEVNULL, timeout=600)
    if status != 0:
        log("Warning: exporting the %s table failed with status %d, so it reads as empty" % (schema, status))
    return path


def table_rows(path):
    """Returns a table's rows as dictionaries of elements, with `ref` attributes followed."""
    if os.path.getsize(path) == 0:
        return []
    rows = []
    for node in ET.parse(path).getroot().findall("node"):
        schema = node.find("schema")
        if schema is None:
            continue
        columns = [column.find("mnemonic").text for column in schema.findall("col")]
        elements = {element.attrib["id"]: element for element in node.iter() if "id" in element.attrib}
        for row in node.findall("row"):
            rows.append({column: elements.get(cell.attrib.get("ref"), cell)
                         for column, cell in zip(columns, list(row))})
    return rows


def label(element):
    return element.attrib.get("fmt") or element.text or ""


def text_segments(path, app):
    """Returns the __TEXT address range of each image in the app bundle that the trace saw."""
    with open(path, errors="replace") as table:
        contents = table.read()
    pattern = r'<binary [^>]*load-addr="(0x[0-9a-f]+)"[^>]*path="([^"]*\.app/[^"]*)"'
    segments = []
    for load_address, image in sorted(set(re.findall(pattern, contents))):
        name = image.split(".app/", 1)[1]
        match = re.search(r"segname __TEXT\n\s+vmaddr \S+\n\s+vmsize (\S+)",
                          run(["otool", "-l", os.path.join(app, name)]))
        if match:
            segments.append((int(load_address, 16), int(match.group(1), 16), name))
    return segments


def sampled_pages(segments, page_size):
    """Mirrors the constructor in LaunchPageSampling.c. dyld's image order isn't in the trace, so
    this is only exact for an app with one image."""
    images = [(start, max(size // page_size - 1, 0)) for start, size, _ in segments]
    candidates = sum(pages for _, pages in images)
    count = min(candidates, MAX_SAMPLED_PAGES)
    sampled, image_offset, index = set(), 0, 0
    for start, pages in images:
        while index < count:
            candidate = index * candidates // count
            if candidate >= image_offset + pages:
                break
            sampled.add(start + (1 + candidate - image_offset) * page_size)
            index += 1
        image_offset += pages
    return sampled


def analyze_trace(trace, app, directory):
    toc = export_toc(trace)
    pid = re.search(r'<process type="launched"[^>]*pid="(\d+)"', toc).group(1)
    owner = "(%s)" % pid

    periods = []
    for row in table_rows(export_table(trace, "life-cycle-period", os.path.join(directory, "life-cycle.xml"))):
        if owner in label(row["process"]):
            periods.append((label(row["period"]), int(row["start"].text) / 1e6, int(row["duration"].text) / 1e6))
    if not periods:
        raise ValueError("the trace has no life cycle periods")

    def period(name):
        return next((entry for entry in periods if entry[0] == name), None)

    static_init, frame, active = period(STATIC_INIT_PERIOD), period(FRAME_PERIOD), period(ACTIVE_PERIOD)
    did_finish = next((entry for entry in periods if "didFinishLaunching" in entry[0]), None)
    for name, entry in ((STATIC_INIT_PERIOD, static_init), (FRAME_PERIOD, frame), (ACTIVE_PERIOD, active),
                        ("a period containing didFinishLaunching", did_finish)):
        if entry is None:
            raise ValueError("the trace has no %r period. It has: %s" % (name, ", ".join(entry[0] for entry in periods)))
    # This is the end of all static runtime initialization. The span's pre_init instead ends at this
    # library's own constructor, which runs somewhere inside that period, so pre_init and app_init
    # compare differently defined boundaries. The trace can't say where the constructor ran, so the
    # difference is reported but isn't a pure measurement error.
    initializer_end = static_init[1] + static_init[2]
    frame_end = frame[1] + frame[2]
    did_finish_end = did_finish[1] + did_finish[2]

    memory_path = export_table(trace, "virtual-memory", os.path.join(directory, "virtual-memory.xml"))
    segments = text_segments(memory_path, app)
    if not segments:
        # A launch with no faults in app code has no backtrace there, but it still takes samples.
        segments = text_segments(export_table(trace, "time-profile", os.path.join(directory, "time-profile.xml")), app)
    if not segments:
        raise ValueError("the trace doesn't say where the app's images loaded")
    events = []
    for row in table_rows(memory_path):
        if owner in label(row["process"]) and row["address"].text is not None:
            events.append((int(row["start"].text) / 1e6, label(row["operation"]),
                           int(row["address"].text), int(row["size"].text or 0)))
    events.sort()
    if not events:
        log("Warning: the trace has no virtual memory events for the app, so every page count is zero")
    page_size = next((size for _, _, _, size in events if size), 16384)

    def in_text(address):
        return any(start <= address < start + size for start, size, _ in segments)

    def page(address):
        return address - address % page_size

    def is_header(address):
        return any(page(address) == start for start, _, _ in segments)

    launch = [event for event in events if event[0] < active[1]]
    text = [event for event in launch if in_text(event[2]) and not is_header(event[2])]
    reads = [event for event in text if event[1] == DISK_READ]
    hits = [event for event in text if event[1] == CACHE_HIT]
    first_read = reads[0][0] if reads else float("inf")
    touched = {page(event[2]) for event in text}
    # Hits after a read might be that read's read-ahead, so only earlier hits are surely pre-cached.
    pre_cached = {page(event[2]) for event in hits if event[0] < first_read}
    sampled = sampled_pages(segments, page_size)
    sampled_reads = {page(event[2]) for event in reads if event[0] >= initializer_end} & sampled
    all_reads = [event for event in events if event[1] == DISK_READ]

    return {
        "periods": periods,
        "images": [name for _, _, name in segments],
        "page_size": page_size,
        "text_pages": sum(size // page_size for _, size, _ in segments),
        "sampled_pages": len(sampled),
        "touched_pages": len(touched),
        "touched_sampled_pages": len(touched & sampled),
        "pre_cached_pages": len(pre_cached),
        "text_disk_reads": len(reads),
        "text_cache_hits": len(hits),
        "sampled_disk_reads_after_initializer": len(sampled_reads),
        "disk_reads_before_initializer": sum(1 for event in all_reads if event[0] < initializer_end),
        "disk_reads_after_initializer": sum(1 for event in all_reads if initializer_end <= event[0] < active[1]),
        "launch_type": "warm" if len(pre_cached) >= COLD_RATIO * max(len(touched), 1) else "cold",
        "pre_init_seconds": initializer_end / 1e3,
        "app_init_seconds": (did_finish_end - initializer_end) / 1e3,
        "render_seconds": (frame_end - did_finish_end) / 1e3,
        "total_seconds": frame_end / 1e3,
    }


def compare(span, trace):
    attributes = span["attributes"]

    def integer(name):
        value = attributes.get("app.start." + name)
        return int(value) if value is not None else None

    def seconds(name):
        return attributes.get("app.start.%s.duration" % name)

    # A phase can be legitimately absent, such as pre_init on a prewarmed launch, so only an
    # attribute this script doesn't know is surprising. That is what a rename looks like.
    unknown = sorted(key for key in attributes if re.match(r"^app\.start\.[a-z_]+\.duration$", key)
                     and key.split(".")[2] not in KNOWN_DURATIONS)
    if unknown:
        log("Warning: the span has duration attributes this script doesn't compare: %s. "
            "If one was renamed, update seconds() calls in compare()." % ", ".join(unknown))

    sampled_total = integer("sampled_pages.total") or trace["sampled_pages"]
    touched_estimate = trace["touched_sampled_pages"] * max(trace["text_pages"] - len(trace["images"]), 1) / max(sampled_total, 1)
    total = (span["end"] - span["start"]) / 1e9
    return {
        "span_type": attributes.get("app.start.type"),
        "trace_type": trace["launch_type"],
        "types_agree": attributes.get("app.start.type") == trace["launch_type"],
        "determined_by": attributes.get("app.start.determined_by"),
        "sampled_total": integer("sampled_pages.total"),
        "resident_at_end": integer("sampled_pages.resident_at_end"),
        "paged_in": integer("sampled_pages.paged_in"),
        "paged_in_error": None if integer("sampled_pages.paged_in") is None
        else integer("sampled_pages.paged_in") - trace["sampled_disk_reads_after_initializer"],
        "touched_estimate_error": touched_estimate - trace["touched_pages"],
        "page_ins_pre_initializer_error": None if integer("page_ins.pre_initializer") is None
        else integer("page_ins.pre_initializer") - trace["disk_reads_before_initializer"],
        "page_ins_post_initializer_error": None if integer("page_ins.post_initializer") is None
        else integer("page_ins.post_initializer") - trace["disk_reads_after_initializer"],
        "total_error_seconds": total - trace["total_seconds"],
        "pre_init_error_seconds": None if seconds("pre_init") is None else seconds("pre_init") - trace["pre_init_seconds"],
        "app_init_error_seconds": None if seconds("app_init") is None else seconds("app_init") - trace["app_init_seconds"],
        "render_error_seconds": None if seconds("render") is None else seconds("render") - trace["render_seconds"],
    }


# Reporting.


def print_periods(trace):
    """Lists every life cycle period the trace has, to find the labels a comparison could use."""
    print("  Life cycle periods (start, duration):")
    for name, start, duration in sorted(trace["periods"], key=lambda entry: entry[1]):
        note = "  <- unverified candidate for app.start.scene_setup" if name == FIRST_SCENE_PERIOD else ""
        print("    %-52s %9.1f ms %9.1f ms%s" % (name, start, duration, note))
    if not any(name == FIRST_SCENE_PERIOD for name, _, _ in trace["periods"]):
        print("    (no period is labelled %r on this OS version)" % FIRST_SCENE_PERIOD)


def print_launch(index, trace, comparison, dump_periods=False):
    print("\nLaunch %d" % index)
    print("  %-34s %-12s %s" % ("", "span", "xctrace"))
    rows = [
        ("type", comparison["span_type"], comparison["trace_type"]),
        ("sampled pages", comparison["sampled_total"], trace["sampled_pages"]),
        ("paged in (sampled)", comparison["paged_in"], trace["sampled_disk_reads_after_initializer"]),
        ("resident at end / touched", comparison["resident_at_end"], trace["touched_sampled_pages"]),
        ("__TEXT disk reads / cache hits", "-", "%d / %d" % (trace["text_disk_reads"], trace["text_cache_hits"])),
        ("__TEXT touched / total pages", "-", "%d / %d" % (trace["touched_pages"], trace["text_pages"])),
        ("touched pages known pre-cached", "-", trace["pre_cached_pages"]),
    ]
    for name, span_value, trace_value in rows:
        print("  %-34s %-12s %s" % (name, span_value, trace_value))
    print("  total %+.1f ms, pre_init %s, app_init %s, render %s" % (
        comparison["total_error_seconds"] * 1e3, milliseconds(comparison["pre_init_error_seconds"]),
        milliseconds(comparison["app_init_error_seconds"]), milliseconds(comparison["render_error_seconds"])))
    print("  pre_init and app_init compare against the end of static runtime initialization, not the span's own boundary.")
    if dump_periods:
        print_periods(trace)


def milliseconds(value):
    return "n/a" if value is None else "%+.1f ms" % (value * 1e3)


def print_summary(mode, comparisons):
    print("\nSummary: %d %s launches compared" % (len(comparisons), mode))
    if not comparisons:
        return
    agreed = sum(1 for comparison in comparisons if comparison["types_agree"])
    print("  Launch type agreed: %d/%d" % (agreed, len(comparisons)))
    for key, name, scale, unit in (
            ("paged_in_error", "paged_in minus sampled disk reads", 1, "pages"),
            ("touched_estimate_error", "estimated minus touched pages", 1, "pages"),
            ("page_ins_pre_initializer_error", "page_ins.pre_initializer minus reads", 1, "reads"),
            ("page_ins_post_initializer_error", "page_ins.post_initializer minus reads", 1, "reads"),
            ("total_error_seconds", "app.start minus Instruments", 1e3, "ms")):
        values = [comparison[key] * scale for comparison in comparisons if comparison[key] is not None]
        if values:
            print("  %-40s median %+.1f %s, range %+.1f to %+.1f" % (
                name, statistics.median(values), unit, min(values), max(values)))
    print("  pre_init and app_init split the launch at the library's constructor in the span, but at the end of")
    print("  static runtime initialization in xctrace, so their errors aren't pure measurement error. Their sum is.")
    print("  paged_in includes read-ahead the launch didn't fault on, so it can exceed the disk reads.")
    print("  xctrace's type is `warm` if most touched __TEXT pages were cached before any was read.")


def load_launches(directory):
    pattern = re.compile(r"^launch-(\d+)$")
    names = sorted((name for name in os.listdir(directory) if pattern.match(name)),
                   key=lambda name: int(pattern.match(name).group(1)))
    return [os.path.join(directory, name) for name in names]


def score_launch(index, launch_directory, app, dump_periods=False):
    trace = analyze_trace(os.path.join(launch_directory, "launch.trace"), app, launch_directory)
    with open(os.path.join(launch_directory, "span.json")) as span_file:
        comparison = compare(json.load(span_file), trace)
    print_launch(index, trace, comparison, dump_periods)
    return {"launch": index, "trace": trace, "comparison": comparison}


def write_report(directory, mode, results):
    with open(os.path.join(directory, "report.json"), "w") as report:
        json.dump({"mode": mode, "launches": results}, report, indent=2)
    print_summary(mode, [result["comparison"] for result in results])
    print("\nReport: %s" % os.path.join(directory, "report.json"))


def reanalyze(directory, dump_periods):
    with open(os.path.join(directory, "run.json")) as run_file:
        mode = json.load(run_file)["mode"]
    app = os.path.join(directory, SCHEME + ".app")
    results = [score_launch(index, path, app, dump_periods) for index, path in enumerate(load_launches(directory), 1)
               if os.path.exists(os.path.join(path, "span.json"))]
    write_report(directory, mode, results)


def main():
    parser = argparse.ArgumentParser(description="Compare the app.start span with Instruments on a real device.")
    parser.add_argument("--mode", choices=["warm", "fresh-install", "reboot"], default="warm")
    parser.add_argument("--launches", type=int, default=3)
    parser.add_argument("--device", help="the device's UDID, if several are connected")
    parser.add_argument("--host", help="the address the device reaches this Mac at")
    parser.add_argument("--port", type=int, default=14318)
    parser.add_argument("--team", help="the development team, if the project doesn't set one")
    parser.add_argument("--configuration", default="Release")
    parser.add_argument("--app", help="a device build to use instead of building")
    parser.add_argument("--record-seconds", type=int, default=20)
    parser.add_argument("--settle", type=int, default=60, help="seconds to wait after unlocking in reboot mode")
    parser.add_argument("--work-dir", default=os.path.join(REPO_ROOT, ".build/app-launch-accuracy"))
    parser.add_argument("--dump-periods", action="store_true", help="print every life cycle period in each trace")
    parser.add_argument("--reanalyze", metavar="RUN_DIRECTORY", help="score a previous run again without a device")
    args = parser.parse_args()

    if args.reanalyze:
        reanalyze(args.reanalyze, args.dump_periods)
        return

    args.device = args.device or find_device()
    host = args.host or lan_address()
    directory = os.path.join(args.work_dir, time.strftime("%Y%m%d-%H%M%S") + "-" + args.mode)
    os.makedirs(directory)
    with open(os.path.join(directory, "run.json"), "w") as run_file:
        json.dump({"mode": args.mode, "device": args.device}, run_file)

    app = patched_copy(args.app or build_app(args, directory), directory)
    install(args, app)
    server = start_receiver(host, args.port)
    endpoint = "http://%s:%d" % (host, args.port)
    log("Receiving OTLP on %s" % endpoint)

    results, failures = [], collections.Counter()
    for index in range(1, args.launches + 1):
        log("Launch %d of %d (%s)" % (index, args.launches, args.mode))
        prepare_launch(args, app)
        with server.lock:
            del server.spans[:]
        launch_directory = os.path.join(directory, "launch-%d" % index)
        os.makedirs(launch_directory)
        trace = os.path.join(launch_directory, "launch.trace")
        if not record(args, trace, endpoint, os.path.join(launch_directory, "xctrace.log")):
            failures["xctrace didn't finish"] += 1
            continue
        span, spans = wait_for_span(server, time.time() + 15)
        if span is None:
            failures["no span arrived, so check the app has local network access"] += 1
            continue
        with open(os.path.join(launch_directory, "span.json"), "w") as span_file:
            json.dump(span, span_file, indent=2)
        with open(os.path.join(launch_directory, "spans.json"), "w") as spans_file:
            json.dump(spans, spans_file, indent=2)
        try:
            results.append(score_launch(index, launch_directory, app, args.dump_periods))
        except (ValueError, KeyError, AttributeError, StopIteration, TypeError, ET.ParseError) as error:
            failures["couldn't read the trace: %s" % error] += 1

    server.shutdown()
    write_report(directory, args.mode, results)
    for reason, count in failures.items():
        print("Failed %d time(s): %s" % (count, reason))
    if failures or not results:
        sys.exit(1)


if __name__ == "__main__":
    main()
