import XCTest
@testable import Sessions

final class SessionManagerProviderTests: XCTestCase {
  
  override func tearDown() {
    // Reset singleton state for clean tests
    SessionManagerProvider.register(sessionManager: SessionManager())
    super.tearDown()
  }
  
  func testGetInstanceReturnsDefaultManager() {
    let manager = SessionManagerProvider.getInstance()
    XCTAssertNotNil(manager)
  }
  
  func testRegisterAndGetInstance() {
    let customManager = SessionManager(configuration: SessionConfig(sessionTimeout: 3600))
    SessionManagerProvider.register(sessionManager: customManager)
    
    let retrievedManager = SessionManagerProvider.getInstance()
    XCTAssertTrue(retrievedManager === customManager)
  }
  
  func testSingletonBehavior() {
    let manager1 = SessionManagerProvider.getInstance()
    let manager2 = SessionManagerProvider.getInstance()
    XCTAssertTrue(manager1 === manager2)
  }
  
  func testThreadSafety() {
    let expectation = XCTestExpectation(description: "Thread safety test")
    expectation.expectedFulfillmentCount = 10
    
    var managers: [SessionManager] = []
    let queue = DispatchQueue.global(qos: .default)
    let syncQueue = DispatchQueue(label: "test.sync")
    
    for _ in 0..<10 {
      queue.async {
        let manager = SessionManagerProvider.getInstance()
        syncQueue.async {
          managers.append(manager)
          expectation.fulfill()
        }
      }
    }
    
    wait(for: [expectation], timeout: 1.0)
    
    let firstManager = managers.first!
    for manager in managers {
      XCTAssertTrue(manager === firstManager)
    }
  }
  
  func testConcurrentGetInstanceCreatesOnlyOneInstance() {
    let group = DispatchGroup()
    var instances: [SessionManager] = []
    let syncQueue = DispatchQueue(label: "test.instances")
    
    for _ in 0..<100 {
      group.enter()
      DispatchQueue.global().async {
        let instance = SessionManagerProvider.getInstance()
        syncQueue.async {
          instances.append(instance)
          group.leave()
        }
      }
    }
    
    group.wait()
    
    XCTAssertEqual(instances.count, 100)
    let firstInstance = instances[0]
    for instance in instances {
      XCTAssertTrue(instance === firstInstance, "All instances should be the same object")
    }
  }
}