import Foundation
@testable import Sessions

final class TestSessionPersistence: SessionPersistence, @unchecked Sendable {
  private let lock = NSLock()
  private var data: Data?

  func read() -> Data? {
    return lock.withLock { data }
  }

  func write(_ data: Data) {
    lock.withLock { self.data = data }
  }

  func clear() {
    lock.withLock { data = nil }
  }
}
