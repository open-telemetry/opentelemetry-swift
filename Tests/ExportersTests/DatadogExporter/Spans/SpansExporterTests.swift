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

class SpansExporterTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testWhenExportSpanIsCalled_thenTraceIsUploaded() throws {
        var tracesSent = false
        let expec = expectation(description: "traces received")
        let server = HttpTestServer(url: URL(string: "http://localhost:33333"),
                                    config: HttpTestServerConfig(tracesReceivedCallback: {
                                        tracesSent = true
                                        expec.fulfill()
                                    },
                                                                 logsReceivedCallback: nil))

        DispatchQueue.global(qos: .default).async {
            do {
                try server.start()
            } catch {
                XCTFail()
                return
            }
        }

        let configuration = ExporterConfiguration(serviceName: "serviceName",
                                                  resource: "resource",
                                                  applicationName: "applicationName",
                                                  applicationVersion: "applicationVersion",
                                                  environment: "environment",
                                                  clientToken: "clientToken",
                                                  endpoint: Endpoint.custom(
                                                      tracesURL: URL(string: "http://localhost:33333/traces")!,
                                                      logsURL: URL(string: "http://localhost:33333/logs")!),
                                                  uploadCondition: { true })

        let spansExporter = try SpansExporter(config: configuration)

        let spanData = createBasicSpan()
        spansExporter.exportSpan(span: spanData)

        waitForExpectations(timeout: 30) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                XCTFail()
            }
        }
        XCTAssertTrue(tracesSent)

        server.stop()
    }

    private func createBasicSpan() -> SpanData {
        return SpanData(traceId: TraceId(),
                        spanId: SpanId(),
                        traceFlags: TraceFlags(),
                        traceState: TraceState(),
                        resource: Resource(),
                        instrumentationLibraryInfo: InstrumentationLibraryInfo(),
                        name: "spanName",
                        kind: .server,
                        startTime: Date(timeIntervalSinceReferenceDate: 3000),
                        endTime: Date(timeIntervalSinceReferenceDate: 3001),
                        hasRemoteParent: false)
    }
}
