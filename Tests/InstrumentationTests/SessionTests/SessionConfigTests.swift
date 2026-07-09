import XCTest
@testable import Sessions

final class SessionConfigurationTests: XCTestCase {
  
  func testDefaultConfiguration() {
    let config = SessionConfig.default
    XCTAssertEqual(config.sessionTimeout, 30 * 60) // should be 30 minutes
    XCTAssertNil(config.maxLifetime)
    XCTAssertTrue(config.restorePersistedSession)
  }
  
  func testCustomConfiguration() {
    let config = SessionConfig(sessionTimeout: 3600, maxLifetime: 4 * 60 * 60, restorePersistedSession: false)
    XCTAssertEqual(config.sessionTimeout, 3600)
    XCTAssertEqual(config.maxLifetime, 4 * 60 * 60)
    XCTAssertFalse(config.restorePersistedSession)
  }
  
  func testBuilderPattern() {
    let config = SessionConfig.builder()
      .with(sessionTimeout: 45 * 60)
      .with(maxLifetime: 4 * 60 * 60)
      .with(restorePersistedSession: false)
      .build()
    
    XCTAssertEqual(config.sessionTimeout, 45 * 60)
    XCTAssertEqual(config.maxLifetime, 4 * 60 * 60)
    XCTAssertFalse(config.restorePersistedSession)
  }
  
  func testBuilderDefaultValues() {
    let config = SessionConfig.builder().build()
    XCTAssertEqual(config.sessionTimeout, 30 * 60) // should be 30 minutes
    XCTAssertNil(config.maxLifetime)
    XCTAssertTrue(config.restorePersistedSession)
  }
  
  func testBuilderMethodChaining() {
    let builder = SessionConfig.builder()
    let sameBuilder = builder.with(sessionTimeout: 60 * 60)
    XCTAssertTrue(builder === sameBuilder)
    XCTAssertTrue(builder === builder.with(maxLifetime: 4 * 60 * 60))
    XCTAssertTrue(builder === builder.with(restorePersistedSession: false))
  }
  
  func testBuilderEqualsNormalConfig() {
    let normalConfig = SessionConfig(sessionTimeout: 45 * 60, maxLifetime: 4 * 60 * 60, restorePersistedSession: false)
    let builderConfig = SessionConfig.builder()
      .with(sessionTimeout: 45 * 60)
      .with(maxLifetime: 4 * 60 * 60)
      .with(restorePersistedSession: false)
      .build()
    
    XCTAssertEqual(normalConfig.sessionTimeout, builderConfig.sessionTimeout)
    XCTAssertEqual(normalConfig.maxLifetime, builderConfig.maxLifetime)
    XCTAssertEqual(normalConfig.restorePersistedSession, builderConfig.restorePersistedSession)
  }
}
