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

import Foundation
import GRPC
import NIO
import OpenTelemetryApi
@testable import OpenTelemetryProtocolExporter
@testable import OpenTelemetrySdk
import XCTest

class OtlpTraceExporterTests: XCTestCase {
    let traceId = "00000000000000000000000000abc123"
    let spanId = "0000000000def456"

    var fakeCollector: FakeCollector!
    var server: EventLoopFuture<Server>!
    var channel: ClientConnection!

    let channelGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let serverGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    override func setUp() {
        fakeCollector = FakeCollector()
        server = startServer()
        channel = startChannel()
    }

    override func tearDown() {
        try! serverGroup.syncShutdownGracefully()
        try! channelGroup.syncShutdownGracefully()
    }

    func testExport() {
        let span = generateFakeSpan()
        let exporter = OtlpTraceExporter(channel: channel)
        let result = exporter.export(spans: [span])
        XCTAssertEqual(result, SpanExporterResultCode.success)
        XCTAssertEqual(fakeCollector.receivedSpans, SpanAdapter.toProtoResourceSpans(spanDataList: [span]))
        exporter.shutdown()
    }

    func testExportMultipleSpans() {
        var spans = [SpanData]()
        for _ in 0 ..< 10 {
            spans.append(generateFakeSpan())
        }
        let exporter = OtlpTraceExporter(channel: channel)
        let result = exporter.export(spans: spans)
        XCTAssertEqual(result, SpanExporterResultCode.success)
        XCTAssertEqual(fakeCollector.receivedSpans, SpanAdapter.toProtoResourceSpans(spanDataList: spans))
        exporter.shutdown()
    }

    func testExportAfterShutdown() {
        let span = generateFakeSpan()
        let exporter = OtlpTraceExporter(channel: channel)
        exporter.shutdown()
        let result = exporter.export(spans: [span])
        XCTAssertEqual(result, SpanExporterResultCode.failure)
    }

    func testExportCancelled() {
        fakeCollector.returnedStatus = GRPCStatus(code: .cancelled, message: nil)
        let exporter = OtlpTraceExporter(channel: channel)
        let span = generateFakeSpan()
        let result = exporter.export(spans: [span])
        XCTAssertEqual(result, SpanExporterResultCode.failure)
        exporter.shutdown()
    }

    private func generateFakeSpan() -> SpanData {
        let duration = 0.9
        let start = Date()
        let end = start.addingTimeInterval(duration)

        var testData = SpanData(traceId: TraceId(fromHexString: traceId),
                                spanId: SpanId(fromHexString: spanId),
                                name: "GET /api/endpoint",
                                kind: SpanKind.server,
                                startTime: start,
                                endTime: end)
        testData.settingHasEnded(true)
        testData.settingTotalRecordedEvents(0)
        testData.settingLinks([SpanData.Link]())
        testData.settingTotalRecordedLinks(0)
        testData.settingStatus(.ok)

        return testData
    }

    func startServer() -> EventLoopFuture<Server> {
        // Start the server and print its address once it has started.
        let server = Server.insecure(group: serverGroup)
            .withServiceProviders([fakeCollector])
            .bind(host: "localhost", port: 55680)

        server.map {
            $0.channel.localAddress
        }.whenSuccess { address in
            print("server started on port \(address!.port!)")
        }
        return server
    }

    func startChannel() -> ClientConnection {
        let channel = ClientConnection.insecure(group: channelGroup)
            .connect(host: "localhost", port: 55680)
        return channel
    }
}

class FakeCollector: Opentelemetry_Proto_Collector_Trace_V1_TraceServiceProvider {
    var receivedSpans = [Opentelemetry_Proto_Trace_V1_ResourceSpans]()
    var returnedStatus = GRPCStatus.ok
    var interceptors: Opentelemetry_Proto_Collector_Trace_V1_TraceServiceServerInterceptorFactoryProtocol? = nil

    func export(request: Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse> {
        receivedSpans.append(contentsOf: request.resourceSpans)
        if returnedStatus != GRPCStatus.ok {
            return context.eventLoop.makeFailedFuture(returnedStatus)
        }
        return context.eventLoop.makeSucceededFuture(Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse())
    }
}
