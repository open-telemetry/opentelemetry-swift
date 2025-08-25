import XCTest
@testable import Sessions

final class SessionConfigurationTests: XCTestCase {
  
  func testDefaultConfiguration() {
    let config = SessionConfig.default
    XCTAssertEqual(config.sessionTimeout, 30 * 60) // should be 30 minutes
  }
  
  func testCustomConfiguration() {
    let config = SessionConfig(sessionTimeout: 3600)
    XCTAssertEqual(config.sessionTimeout, 3600)
  }
  
  func testBuilderPattern() {
    let config = SessionConfig.builder()
      .with(sessionTimeout: 45 * 60)
      .build()
    
    XCTAssertEqual(config.sessionTimeout, 45 * 60)
  }
  
  func testBuilderDefaultValues() {
    let config = SessionConfig.builder().build()
    XCTAssertEqual(config.sessionTimeout, 30 * 60) // should be 30 minutes
  }
  
  func testBuilderMethodChaining() {
    let builder = SessionConfig.builder()
    let sameBuilder = builder.with(sessionTimeout: 60 * 60)
    XCTAssertTrue(builder === sameBuilder)
  }
  
  func testBuilderEqualsNormalConfig() {
    let normalConfig = SessionConfig(sessionTimeout: 45 * 60)
    let builderConfig = SessionConfig.builder()
      .with(sessionTimeout: 45 * 60)
      .build()
    
    XCTAssertEqual(normalConfig.sessionTimeout, builderConfig.sessionTimeout)
  }
}