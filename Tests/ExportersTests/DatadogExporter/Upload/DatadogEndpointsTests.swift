/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import XCTest

class DatadogEndpointsTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testWhenAsksUSLogEndpointsWithClientToken_returnsCorrectly() throws {
        let endpoint = Endpoint.us
        let clientToken = "abcdef123456789"

        let logsURL = try endpoint.logsUrlWithClientToken(clientToken: clientToken)

        XCTAssertEqual(logsURL, endpoint.logsURL.appendingPathComponent(clientToken))
        XCTAssertEqual(logsURL.absoluteString, "https://mobile-http-intake.logs.datadoghq.com/v1/input/abcdef123456789")
    }

    func testWhenAsksUS3LogEndpointsWithClientToken_returnsCorrectly() throws {
        let endpoint = Endpoint.us3
        let clientToken = "abcdef123456789"

        let logsURL = try endpoint.logsUrlWithClientToken(clientToken: clientToken)

        XCTAssertEqual(logsURL, endpoint.logsURL.appendingPathComponent(clientToken))
        XCTAssertEqual(logsURL.absoluteString, "https://logs.browser-intake-us3-datadoghq.com/v1/input/abcdef123456789")
    }


    func testWhenAsksEULogEndpointsWithClientToken_returnsCorrectly() throws {
        let endpoint = Endpoint.eu
        let clientToken = "abcdef123456789"

        let logsURL = try endpoint.logsUrlWithClientToken(clientToken: clientToken)

        XCTAssertEqual(logsURL, endpoint.logsURL.appendingPathComponent(clientToken))
        XCTAssertEqual(logsURL.absoluteString, "https://mobile-http-intake.logs.datadoghq.eu/v1/input/abcdef123456789")
    }

    func testWhenAsksGovLogEndpointsWithClientToken_returnsCorrectly() throws {
        let endpoint = Endpoint.gov
        let clientToken = "abcdef123456789"

        let logsURL = try endpoint.logsUrlWithClientToken(clientToken: clientToken)

        XCTAssertEqual(logsURL, endpoint.logsURL.appendingPathComponent(clientToken))
        XCTAssertEqual(logsURL.absoluteString, "https://logs.browser-intake-ddog-gov.com/v1/input/abcdef123456789")
    }

    func testWhenAsksLogEndpointsWithEmptyToken_raisesAnError() throws {
        let endpoint = Endpoint.eu
        let clientToken = ""

        XCTAssertThrowsError(try endpoint.logsUrlWithClientToken(clientToken: clientToken))
    }

    func testWhenAsksUSTracesEndpointsWithClientToken_returnsCorrectly() throws {
        let endpoint = Endpoint.us
        let clientToken = "abcdef123456789"

        let logsURL = try endpoint.tracesUrlWithClientToken(clientToken: clientToken)

        XCTAssertEqual(logsURL, endpoint.tracesURL.appendingPathComponent(clientToken))
        XCTAssertEqual(logsURL.absoluteString, "https://public-trace-http-intake.logs.datadoghq.com/v1/input/abcdef123456789")
    }

    func testWhenAsksUS3TracesEndpointsWithClientToken_returnsCorrectly() throws {
        let endpoint = Endpoint.us3
        let clientToken = "abcdef123456789"

        let logsURL = try endpoint.tracesUrlWithClientToken(clientToken: clientToken)

        XCTAssertEqual(logsURL, endpoint.tracesURL.appendingPathComponent(clientToken))
        XCTAssertEqual(logsURL.absoluteString, "https://trace.browser-intake-us3-datadoghq.com/v1/input/abcdef123456789")
    }

    func testWhenAsksEUTracesEndpointsWithClientToken_returnsCorrectly() throws {
        let endpoint = Endpoint.eu
        let clientToken = "abcdef123456789"

        let logsURL = try endpoint.tracesUrlWithClientToken(clientToken: clientToken)

        XCTAssertEqual(logsURL, endpoint.tracesURL.appendingPathComponent(clientToken))
        XCTAssertEqual(logsURL.absoluteString, "https://public-trace-http-intake.logs.datadoghq.eu/v1/input/abcdef123456789")
    }

    func testWhenAsksGovTracesEndpointsWithClientToken_returnsCorrectly() throws {
        let endpoint = Endpoint.gov
        let clientToken = "abcdef123456789"

        let logsURL = try endpoint.tracesUrlWithClientToken(clientToken: clientToken)

        XCTAssertEqual(logsURL, endpoint.tracesURL.appendingPathComponent(clientToken))
        XCTAssertEqual(logsURL.absoluteString, "https://trace.browser-intake-ddog-gov.com/v1/input/abcdef123456789")
    }

    func testWhenAsksTracesEndpointsWithEmptyToken_raisesAnError() throws {
        let endpoint = Endpoint.eu
        let clientToken = ""

        XCTAssertThrowsError(try endpoint.tracesUrlWithClientToken(clientToken: clientToken))
    }

    func testWhenAsksCustomLogEndpointsWithClientToken_returnsCorrectly() throws {
        let endpoint = Endpoint.custom(tracesURL: URL(string: "https://traces.test.com/v1/input")!, logsURL: URL(string: "https://logs.test.com/v1/input")!, metricsURL: URL(string: "https://metrics.test.com/v1/input")!)

        let clientToken = "abcdef123456789"

        let logsURL = try endpoint.logsUrlWithClientToken(clientToken: clientToken)

        XCTAssertEqual(logsURL, endpoint.logsURL.appendingPathComponent(clientToken))
        XCTAssertEqual(logsURL.absoluteString, "https://logs.test.com/v1/input/abcdef123456789")
    }

    func testWhenAsksCustomTracesEndpointsWithClientToken_returnsCorrectly() throws {
        let endpoint = Endpoint.custom(tracesURL: URL(string: "https://traces.test.com/v1/input")!, logsURL: URL(string: "https://logs.test.com/v1/input")!, metricsURL: URL(string: "https://metrics.test.com/v1/input")!)
        let clientToken = "abcdef123456789"

        let tracesURL = try endpoint.tracesUrlWithClientToken(clientToken: clientToken)

        XCTAssertEqual(tracesURL, endpoint.tracesURL.appendingPathComponent(clientToken))
        XCTAssertEqual(tracesURL.absoluteString, "https://traces.test.com/v1/input/abcdef123456789")
    }
}
