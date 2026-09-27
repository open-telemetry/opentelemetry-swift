import XCTest
import Sessions

final class SessionPublicAPITests: XCTestCase {
  func testResetSessionIsPublic() {
    let reset: (SessionManager) -> () -> Session = SessionManager.resetSession
    XCTAssertNotNil(reset)
  }

  func testEndSessionIsPublic() {
    let end: (SessionManager) -> () -> Void = SessionManager.endSession
    XCTAssertNotNil(end)
  }
}
