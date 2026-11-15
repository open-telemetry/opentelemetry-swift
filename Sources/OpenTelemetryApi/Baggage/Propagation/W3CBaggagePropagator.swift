/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct W3CBaggagePropagator: TextMapBaggagePropagator {
  private static let version = "00"
  private static let delimiter: Character = "-"
  private static let versionLength = 2
  private static let delimiterLength = 1
  private static let versionPrefixIdLength = versionLength + delimiterLength
  private static let traceIdLength = 2 * TraceId.size
  private static let versionAndTraceIdLength = versionLength + delimiterLength + traceIdLength + delimiterLength
  private static let spanIdLength = 2 * SpanId.size
  private static let versionAndTraceIdAndSpanIdLength = versionAndTraceIdLength + spanIdLength + delimiterLength
  private static let optionsLength = 2
  private static let traceparentLengthV0 = versionAndTraceIdAndSpanIdLength + optionsLength

  static let headerBaggage = "baggage"

  /// The maximum number of list-members accepted from the header. The value is 64.
  /// https://www.w3.org/TR/baggage/#limits
  static let maxListMembers = 64
  /// The maximum number of bytes read from the header. The value is 8192.
  static let maxHeaderBytes = 8192

  private func isValidKeyValuePair(_ keyValue: String) -> (key: String, value: String)? {
    let parts = keyValue.split(separator: "=", maxSplits: 1)
    guard parts.count == 2 else { return nil }

    return (String(parts[0]), String(parts[1]))
  }

  /// Splits the header into list-members, ignoring everything past maxHeaderBytes.
  /// The cut is made at the last separator before the limit, so no list-member is kept in part.
  private static func listMembers(in header: String) -> [String] {
    let bytes = header.utf8
    guard bytes.count > maxHeaderBytes else {
      return header.components(separatedBy: ",")
    }

    let window = bytes.prefix(maxHeaderBytes + 1)
    guard let lastSeparator = window.lastIndex(of: UInt8(ascii: ",")),
          let head = String(bytes: window[..<lastSeparator], encoding: .utf8) else {
      return []
    }

    return head.components(separatedBy: ",")
  }

  public init() {}

  public let fields: Set<String> = [headerBaggage]

  public func inject(baggage: Baggage, carrier: inout [String: String], setter: some Setter) {
    var headerParts: [String] = []
    var headerBytes = 0

    // Sorted so that the members kept at capacity are the same on every peer and every run.
    for entry in baggage.getEntries().sorted() {
      if headerParts.count == W3CBaggagePropagator.maxListMembers {
        break
      }

      let key = entry.key.name.trimmingCharacters(in: .whitespaces)
      guard !key.isEmpty else { continue }

      // Use UTF-8 percent encoding for the value
      let value = entry.value.string
      let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value

      var part = "\(key)=\(encodedValue)"

      if let metadata = entry.metadata?.metadata, !metadata.isEmpty {
        part += ";\(metadata)"
      }

      // The separator counts towards the header the limit is set on.
      let separator = headerParts.isEmpty ? 0 : 1
      guard headerBytes + separator + part.utf8.count <= W3CBaggagePropagator.maxHeaderBytes else { continue }

      headerParts.append(part)
      headerBytes += separator + part.utf8.count
    }

    let headerContent = headerParts.joined(separator: ",")
    if !headerContent.isEmpty {
      setter.set(carrier: &carrier, key: W3CBaggagePropagator.headerBaggage, value: headerContent)
    }
  }

  public func extract(carrier: [String: String], getter: some Getter) -> Baggage? {
    guard let baggageHeaderCollection = getter.get(carrier: carrier, key: W3CBaggagePropagator.headerBaggage),
          let baggageHeader = baggageHeaderCollection.first else {
      return nil
    }

    let builder = OpenTelemetry.instance.baggageManager.baggageBuilder()

    var accepted = 0
    for listMember in W3CBaggagePropagator.listMembers(in: baggageHeader) {
      if accepted == W3CBaggagePropagator.maxListMembers {
        break
      }

      let parts = listMember.split(separator: ";", maxSplits: 1)
      guard !parts.isEmpty else { continue }

      // Validate and extract key-value pair
      guard let (key, encodedValue) = isValidKeyValuePair(String(parts[0])),
            let decodedValue = encodedValue.removingPercentEncoding,
            let entryKey = EntryKey(name: key),
            let entryValue = EntryValue(string: decodedValue) else {
        continue
      }

      let metadata = parts.count > 1 ? String(parts[1]) : nil
      builder.put(key: entryKey,
                  value: entryValue,
                  metadata: EntryMetadata(metadata: metadata))
      accepted += 1
    }

    return builder.build()
  }
}
