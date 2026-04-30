/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import XCTest
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
