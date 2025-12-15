import XCTest
@testable import Sessions

final class SessionConstantsTests: XCTestCase {
  func testSessionEventConstants() {
    XCTAssertEqual(SessionConstants.sessionStartEvent, "session.start")
    XCTAssertEqual(SessionConstants.sessionEndEvent, "session.end")
    XCTAssertEqual(SessionConstants.sessionEventNotification, "SessionEventInstrumentation.SessionEvent")
  }
}