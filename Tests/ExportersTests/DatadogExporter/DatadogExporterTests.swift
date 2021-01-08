// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

@testable import DatadogExporter
import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

class DatadogExporterTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testWhenExportSpanIsCalled_thenTraceAndLogsAreUploaded() throws {
        var logsSent = false
        var tracesSent = false
        let expecTrace = expectation(description: "trace received")
        expecTrace.assertForOverFulfill = false
        let expecLog = expectation(description: "logs received")
        expecLog.assertForOverFulfill = false

        let server = HttpTestServer(url: URL(string: "http://localhost:33333"),
                                    config: HttpTestServerConfig(tracesReceivedCallback: {
                                        tracesSent = true
                                        expecTrace.fulfill()
                                    },
                                                                 logsReceivedCallback: {
                                        logsSent = true
                                        expecLog.fulfill()
        }))
        DispatchQueue.global(qos: .default).async {
            do {
                try server.start()
            } catch {
                XCTFail()
                return
            }
        }
        let instrumentationLibraryName = "SimpleExporter"
        let instrumentationLibraryVersion = "semver:0.1.0"

        let tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: instrumentationLibraryName, instrumentationVersion: instrumentationLibraryVersion) as! TracerSdk

        let exporterConfiguration = ExporterConfiguration(serviceName: "serviceName",
                                                          resource: "resource",
                                                          applicationName: "applicationName",
                                                          applicationVersion: "applicationVersion",
                                                          environment: "environment",
                                                          clientToken: "clientToken",
                                                          endpoint: Endpoint.custom(
                                                              tracesURL: URL(string: "http://localhost:33333/traces")!,
                                                              logsURL: URL(string: "http://localhost:33333/logs")!),
                                                          uploadCondition: { true })

        let datadogExporter = try! DatadogExporter(config: exporterConfiguration)

        let spanProcessor = SimpleSpanProcessor(spanExporter: datadogExporter)
        OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(spanProcessor)

        simpleSpan(tracer: tracer)
        spanProcessor.shutdown()

        let result = XCTWaiter().wait(for: [expecTrace, expecLog], timeout: 20, enforceOrder: false)

        if result == .completed {
            XCTAssertTrue(logsSent)
            XCTAssertTrue(tracesSent)
        } else {
            XCTFail()
        }

        server.stop()
    }

    private func simpleSpan(tracer: TracerSdk) {
        let span = tracer.spanBuilder(spanName: "SimpleSpan").setSpanKind(spanKind: .client).startSpan()
        span.addEvent(name: "My event", timestamp: Date())
        span.end()
    }
}
