/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
@testable import SharedTestUtils

final class HttpTestServerTests: XCTestCase {
  func testDefaultInitHasUnassignedPort() {
    let server = HttpTestServer()
    XCTAssertEqual(server.serverPort, 0)
  }

  func testInitWithConfigStoresCallbacks() {
    let successCalled = Counter()
    let errorCalled = Counter()
    let config = HttpTestServerConfig(
      successCallback: { successCalled.increment() },
      errorCallback: { errorCalled.increment() }
    )
    let server = HttpTestServer(url: URL(string: "http://localhost:12345"), config: config)
    XCTAssertNotNil(server.config)
    server.config?.successCallback?()
    server.config?.errorCallback?()
    XCTAssertEqual(successCalled.value, 1)
    XCTAssertEqual(errorCalled.value, 1)
  }

  func testStartAssignsPortAndStops() throws {
    let server = HttpTestServer()
    try server.start()
    defer { server.stop() }
    XCTAssertGreaterThan(server.serverPort, 0, "serverPort should be assigned after start()")
    XCTAssertLessThanOrEqual(server.serverPort, 65535)
  }

  func testStartAcceptsSemaphore() throws {
    let server = HttpTestServer()
    let sem = DispatchSemaphore(value: 0)
    try server.start(semaphore: sem)
    defer { server.stop() }
    let waitResult = sem.wait(timeout: .now() + 1)
    XCTAssertEqual(waitResult, .success, "start(semaphore:) should signal the passed semaphore")
  }

  func testServerAcceptsHttpGetRequest() throws {
    let server = HttpTestServer()
    try server.start()
    defer { server.stop() }
    let port = server.serverPort
    XCTAssertGreaterThan(port, 0)

    let url = URL(string: "http://127.0.0.1:\(port)/")!
    let expectation = expectation(description: "response received")
    let receivedResponseBox = ResponseBox()
    let task = URLSession.shared.dataTask(with: url) { _, response, _ in
      receivedResponseBox.set(response as? HTTPURLResponse)
      expectation.fulfill()
    }
    task.resume()
    wait(for: [expectation], timeout: 5)
    XCTAssertNotNil(receivedResponseBox.get(), "server should respond to HTTP GET on assigned port")
  }

  func testStopIsIdempotent() throws {
    let server = HttpTestServer()
    try server.start()
    server.stop()
    server.stop()
  }

  func testShutdownStopsServer() throws {
    let server = HttpTestServer()
    try server.start()
    server.shutdown()
    // Hitting stop() via shutdown should leave subsequent stop() a no-op.
    server.stop()
  }

  func testPostRequestCapturesBody() throws {
    let server = HttpTestServer()
    try server.start()
    defer { server.stop() }
    let port = server.serverPort

    var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/otel")!)
    request.httpMethod = "POST"
    request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
    request.setValue("trace=abc", forHTTPHeaderField: "X-Trace")
    let body = Data([0x01, 0x02, 0x03, 0x04, 0x05])
    request.httpBody = body

    let expectation = expectation(description: "POST response received")
    let responseBox = ResponseBox()
    let task = URLSession.shared.dataTask(with: request) { _, response, _ in
      responseBox.set(response as? HTTPURLResponse)
      expectation.fulfill()
    }
    task.resume()
    wait(for: [expectation], timeout: 5)

    // Give the server a moment to finish recording the request.
    Thread.sleep(forTimeInterval: 0.05)

    let received = server.requests
    XCTAssertGreaterThan(received.count, 0)
    let first = received.first
    XCTAssertEqual(first?.body, body)
    XCTAssertEqual(first?.head.method.rawValue, "POST")
    XCTAssertEqual(first?.head.uri, "/otel")
    XCTAssertEqual(first?.head.headers.first(name: "X-Trace"), "trace=abc")
  }

  func testWaitForRequestReturnsNilWhenNoRequest() throws {
    let server = HttpTestServer()
    try server.start()
    defer { server.stop() }
    let started = Date()
    let req = server.waitForRequest(timeout: 0.2)
    let elapsed = Date().timeIntervalSince(started)
    XCTAssertNil(req)
    XCTAssertGreaterThanOrEqual(elapsed, 0.1)
  }

  func testURLSessionConfigPathDispatchesCallbacks() throws {
    let successCalled = Counter()
    let errorCalled = Counter()
    let config = HttpTestServerConfig(
      successCallback: { successCalled.increment() },
      errorCallback: { errorCalled.increment() })
    let server = HttpTestServer(url: URL(string: "http://127.0.0.1"), config: config)
    try server.start()
    defer { server.stop() }

    // /success → success callback
    let successExpectation = expectation(description: "success response")
    let successTask = URLSession.shared.dataTask(
      with: URL(string: "http://127.0.0.1:\(server.serverPort)/success")!) { _, _, _ in
      successExpectation.fulfill()
    }
    successTask.resume()
    wait(for: [successExpectation], timeout: 5)

    // /forbidden → error callback
    let forbiddenExpectation = expectation(description: "forbidden response")
    let forbiddenTask = URLSession.shared.dataTask(
      with: URL(string: "http://127.0.0.1:\(server.serverPort)/forbidden")!) { _, _, _ in
      forbiddenExpectation.fulfill()
    }
    forbiddenTask.resume()
    wait(for: [forbiddenExpectation], timeout: 5)

    // Unknown path → 404 with no callback
    let notFoundExpectation = expectation(description: "404 response")
    let unknownTask = URLSession.shared.dataTask(
      with: URL(string: "http://127.0.0.1:\(server.serverPort)/unknown")!) { _, _, _ in
      notFoundExpectation.fulfill()
    }
    unknownTask.resume()
    wait(for: [notFoundExpectation], timeout: 5)

    Thread.sleep(forTimeInterval: 0.05)
    XCTAssertGreaterThanOrEqual(successCalled.value, 1)
    XCTAssertGreaterThanOrEqual(errorCalled.value, 1)
  }

  func testClearRequestsDropsReceivedRequests() throws {
    let server = HttpTestServer()
    try server.start()
    defer { server.stop() }

    let expectation = expectation(description: "GET response received")
    let task = URLSession.shared.dataTask(
      with: URL(string: "http://127.0.0.1:\(server.serverPort)/")!) { _, _, _ in
      expectation.fulfill()
    }
    task.resume()
    wait(for: [expectation], timeout: 5)
    Thread.sleep(forTimeInterval: 0.05)

    XCTAssertGreaterThan(server.requests.count, 0)
    server.clearRequests()
    XCTAssertEqual(server.requests.count, 0)
    server.clearReceivedRequests() // should be no-op on empty
    XCTAssertEqual(server.requests.count, 0)
  }
}

/// Test helper for tracking callback invocations in a Sendable-safe way.
private final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var _value = 0
  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }
  func increment() {
    lock.lock()
    defer { lock.unlock() }
    _value += 1
  }
}

private final class ResponseBox: @unchecked Sendable {
  private let lock = NSLock()
  private var response: HTTPURLResponse?
  func set(_ r: HTTPURLResponse?) {
    lock.lock()
    defer { lock.unlock() }
    response = r
  }
  func get() -> HTTPURLResponse? {
    lock.lock()
    defer { lock.unlock() }
    return response
  }
}
