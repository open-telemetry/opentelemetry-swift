import Foundation
@testable import Sessions

enum SessionPersistenceFixtures {
  static let versionOne = Data("""
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0"><dict>
    <key>version</key><integer>1</integer>
    <key>session</key><dict>
      <key>id</key><string>version-one-session</string>
      <key>expireTime</key><date>2099-01-01T00:30:00Z</date>
      <key>previousId</key><string>previous-session</string>
      <key>startTime</key><date>2099-01-01T00:00:00Z</date>
      <key>sessionTimeout</key><real>1800</real>
      <key>maxLifetime</key><real>7200</real>
    </dict>
  </dict></plist>
  """.utf8)
}

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
  var onWrite: ((Bool) -> Void)?

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
    let accepted = lock.withLock {
      guard writesAccepted else { return false }
      self.data = data
      return true
    }
    onWrite?(accepted)
    return accepted
  }

  @discardableResult
  func clear() -> Bool {
    return lock.withLock {
      data = nil
      return true
    }
  }
}
