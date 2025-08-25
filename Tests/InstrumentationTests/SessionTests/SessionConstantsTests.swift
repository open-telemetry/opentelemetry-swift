import XCTest
@testable import Sessions

final class SessionConstantsTests: XCTestCase {
  func testSessionEventConstants() {
    XCTAssertEqual(SessionConstants.sessionStartEvent, "session.start")
    XCTAssertEqual(SessionConstants.sessionEndEvent, "session.end")
    XCTAssertEqual(SessionConstants.id, "session.id")
    XCTAssertEqual(SessionConstants.previousId, "session.previous_id")
    XCTAssertEqual(SessionConstants.startTime, "session.start_time")
    XCTAssertEqual(SessionConstants.endTime, "session.end_time")
    XCTAssertEqual(SessionConstants.duration, "session.duration")
    XCTAssertEqual(SessionConstants.sessionEventNotification, "SessionEventInstrumentation.SessionEvent")
  }
}