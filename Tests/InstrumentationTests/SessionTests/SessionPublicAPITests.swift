import XCTest
import Sessions

final class SessionPublicAPITests: XCTestCase {
  func testOriginalConfigurationInitializerIsPublic() {
    let initializer: (TimeInterval, TimeInterval?, Bool) -> SessionConfig = SessionConfig.init
    let config = initializer(60, nil, false)

    XCTAssertEqual(config.sessionTimeout, 60)
    XCTAssertNil(config.maxLifetime)
    XCTAssertFalse(config.restorePersistedSession)
    XCTAssertTrue(config.sampler.samplingDecision(for: "compatibility").isSampled)
  }

  func testSamplingDecisionAccessorIsPublic() {
    let accessor: (SessionManager) -> () -> SessionSamplingDecision? = SessionManager.samplingDecision
    XCTAssertNotNil(accessor)
  }

  func testResetSessionIsPublic() {
    let reset: (SessionManager) -> () -> Session = SessionManager.resetSession
    XCTAssertNotNil(reset)
  }
}
