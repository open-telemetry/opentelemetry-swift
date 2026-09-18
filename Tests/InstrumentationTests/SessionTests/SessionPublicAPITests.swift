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

  func testSessionEqualityComparesEveryPersistedField() {
    let equal: (Session, Session) -> Bool = (==)
    func makeSession(id: String = "session",
                     expireTime: Date = Date(timeIntervalSince1970: 1_000),
                     previousId: String? = "previous",
                     startTime: Date = Date(timeIntervalSince1970: 100),
                     sessionTimeout: TimeInterval = 900,
                     maxLifetime: TimeInterval? = 1_800,
                     samplingDecision: SessionSamplingDecision = .sampled) -> Session {
      return Session(id: id, expireTime: expireTime, previousId: previousId,
                     startTime: startTime, sessionTimeout: sessionTimeout,
                     maxLifetime: maxLifetime, samplingDecision: samplingDecision)
    }

    let session = makeSession()
    XCTAssertTrue(equal(session, makeSession()))
    let differentSessions = [
      makeSession(id: "other"),
      makeSession(expireTime: Date(timeIntervalSince1970: 2_000)),
      makeSession(previousId: nil),
      makeSession(startTime: Date(timeIntervalSince1970: 200)),
      makeSession(sessionTimeout: 800),
      makeSession(maxLifetime: nil),
      makeSession(samplingDecision: .notSampled)
    ]
    for different in differentSessions {
      XCTAssertFalse(equal(session, different))
    }
  }

  func testEndSessionIsPublic() {
    let end: (SessionManager) -> () -> Void = SessionManager.endSession
    XCTAssertNotNil(end)
  }
}
