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

final class InspectingSessionPersistence: SessionPersistence, @unchecked Sendable {
  private let lock = NSLock()
  private var data: Data?
  private var writes = 0
  var onWrite: (() -> Void)?

  var writeCount: Int {
    return lock.withLock { writes }
  }

  var persistedSessionId: String? {
    return lock.withLock {
      guard let data,
            let record = try? PropertyListDecoder().decode(PersistedSessionRecord.self, from: data)
      else {
        return nil
      }
      return record.session.id
    }
  }

  func read() -> Data? {
    return lock.withLock { data }
  }

  func write(_ data: Data) {
    onWrite?()
    lock.withLock {
      self.data = data
      writes += 1
    }
  }

  func clear() {
    lock.withLock { data = nil }
  }
}
