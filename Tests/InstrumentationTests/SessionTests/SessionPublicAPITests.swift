import XCTest
import Sessions

final class SessionPublicAPITests: XCTestCase {
  func testAttributionAccessorIsPublic() {
    let accessor: (SessionManager) -> () -> Session = SessionManager.getSessionForAttribution
    XCTAssertNotNil(accessor)
  }
}
