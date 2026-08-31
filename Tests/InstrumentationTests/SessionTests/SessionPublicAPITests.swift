import XCTest
import Sessions

final class SessionPublicAPITests: XCTestCase {
  func testAttributionAccessorIsPublic() {
    let accessor: (SessionManager) -> () -> Session? = SessionManager.getSessionForAttribution
    XCTAssertNotNil(accessor)
  }

  func testSamplingDecisionAccessorIsPublic() {
    let accessor: (SessionManager) -> () -> SessionSamplingDecision? = SessionManager.samplingDecision
    XCTAssertNotNil(accessor)
  }
}
