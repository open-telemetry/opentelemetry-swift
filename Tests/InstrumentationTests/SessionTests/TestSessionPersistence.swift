import Foundation
@testable import Sessions

final class TestSessionPersistence: SessionPersistence, @unchecked Sendable {
  private let lock = NSLock()
  private var data: Data?

  func read() -> Data? {
    return lock.withLock { data }
  }

  @discardableResult
  func write(_ data: Data) -> Bool {
    lock.withLock { self.data = data }
    return true
  }

  @discardableResult
  func clear() -> Bool {
    lock.withLock { data = nil }
    return true
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

  @discardableResult
  func write(_ data: Data) -> Bool {
    onWrite?()
    lock.withLock {
      self.data = data
      writes += 1
    }
    return true
  }

  @discardableResult
  func clear() -> Bool {
    lock.withLock { data = nil }
    return true
  }
}

final class ToggleSessionPersistence: SessionPersistence, @unchecked Sendable {
  private let lock = NSLock()
  private var data: Data?
  private var writesAccepted: Bool

  var acceptsWrites: Bool {
    get { lock.withLock { writesAccepted } }
    set { lock.withLock { writesAccepted = newValue } }
  }

  init(acceptsWrites: Bool) {
    writesAccepted = acceptsWrites
  }

  func read() -> Data? {
    return lock.withLock { data }
  }

  @discardableResult
  func write(_ data: Data) -> Bool {
    return lock.withLock {
      guard writesAccepted else { return false }
      self.data = data
      return true
    }
  }

  @discardableResult
  func clear() -> Bool {
    return lock.withLock {
      data = nil
      return true
    }
  }
}
