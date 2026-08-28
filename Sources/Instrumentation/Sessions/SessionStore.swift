/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct PersistedSessionRecord: Codable, Equatable {
  static let currentVersion = 1

  let version: Int
  let session: PersistedSession

  init(version: Int, session: PersistedSession) {
    self.version = version
    self.session = session
  }

  init(session: Session) {
    self.init(version: Self.currentVersion, session: PersistedSession(session: session))
  }
}

private struct PersistedSessionRecordVersion: Codable {
  let version: Int
}

struct PersistedSession: Codable, Equatable {
  let id: String
  let expireTime: Date
  let previousId: String?
  let startTime: Date
  let sessionTimeout: TimeInterval
  let maxLifetime: TimeInterval?

  init(session: Session) {
    id = session.id
    expireTime = session.expireTime
    previousId = session.previousId
    startTime = session.startTime
    sessionTimeout = session.sessionTimeout
    maxLifetime = session.maxLifetime
  }

  var value: Session {
    return Session(
      id: id,
      expireTime: expireTime,
      previousId: previousId,
      startTime: startTime,
      sessionTimeout: sessionTimeout,
      maxLifetime: maxLifetime
    )
  }
}

/// Encodes and schedules complete session-record writes through an injected backend.
final class SessionStore: @unchecked Sendable {
  private static let defaultPersistence = UserDefaultsSessionPersistence()
  static let shared = SessionStore(persistence: defaultPersistence)

  /// Legacy aliases remain internal so migration behavior can be tested directly.
  static var idKey: String {
    defaultPersistence.idKey
  }

  static var previousIdKey: String {
    defaultPersistence.previousIdKey
  }

  static var expireTimeKey: String {
    defaultPersistence.expireTimeKey
  }

  static var startTimeKey: String {
    defaultPersistence.startTimeKey
  }

  static var sessionTimeoutKey: String {
    defaultPersistence.sessionTimeoutKey
  }

  static var maxLifetimeKey: String {
    defaultPersistence.maxLifetimeKey
  }

  static var recordKey: String {
    defaultPersistence.recordKey
  }

  private let persistence: any SessionPersistence
  private let lock = NSLock()
  private var pendingSession: Session?
  private var previousSavedSession: Session?
  private var persistenceWritable = true
  private let saveInterval: TimeInterval
  private var saveTimer: Timer?

  init(persistence: any SessionPersistence, saveInterval: TimeInterval = 30) {
    self.persistence = persistence
    self.saveInterval = saveInterval
  }

  deinit {
    lock.withLock {
      saveTimer?.invalidate()
      saveTimer = nil
    }
  }

  static func scheduleSave(session: Session) {
    shared.scheduleSave(session: session)
  }

  static func saveImmediately(session: Session) {
    shared.saveImmediately(session: session)
  }

  static func load() -> Session? {
    return shared.load()
  }

  static func teardown() {
    shared.teardown()
  }

  func scheduleSave(session: Session) {
    let timerToSchedule: Timer? = lock.withLock {
      pendingSession = session
      guard saveTimer == nil else { return nil }

      let timer = Timer(timeInterval: saveInterval, repeats: true) { [weak self] _ in
        self?.savePendingSession()
      }
      locked_save(session: session)
      saveTimer = timer
      return timer
    }

    if let timerToSchedule {
      if Thread.isMainThread {
        RunLoop.main.add(timerToSchedule, forMode: .common)
      } else {
        nonisolated(unsafe) let timerRef = timerToSchedule
        weak let weakSelf = self
        DispatchQueue.main.async {
          guard weakSelf != nil else {
            timerRef.invalidate()
            return
          }
          RunLoop.main.add(timerRef, forMode: .common)
        }
      }
    }
  }

  func saveImmediately(session: Session) {
    lock.withLock { locked_save(session: session) }
  }

  func load() -> Session? {
    return lock.withLock {
      if let data = persistence.read() {
        if let storedVersion = try? PropertyListDecoder().decode(PersistedSessionRecordVersion.self, from: data),
           storedVersion.version != PersistedSessionRecord.currentVersion {
          persistenceWritable = false
          return nil
        }
        guard let record = try? PropertyListDecoder().decode(PersistedSessionRecord.self, from: data) else {
          return nil
        }
        let session = record.session.value
        pendingSession = nil
        previousSavedSession = session
        return session
      }

      guard let userDefaultsPersistence = persistence as? UserDefaultsSessionPersistence,
            let legacySession = userDefaultsPersistence.loadLegacySession()
      else {
        return nil
      }

      locked_save(session: legacySession)
      userDefaultsPersistence.clearLegacySession()
      return legacySession
    }
  }

  func teardown() {
    let timer = lock.withLock {
      let timer = saveTimer
      saveTimer = nil
      pendingSession = nil
      previousSavedSession = nil
      persistenceWritable = true
      persistence.clear()
      if let userDefaultsPersistence = persistence as? UserDefaultsSessionPersistence {
        userDefaultsPersistence.clearLegacySession()
      }
      return timer
    }
    timer?.invalidate()
  }

  private func savePendingSession() {
    lock.withLock {
      if let pendingSession,
         previousSavedSession != pendingSession {
        locked_save(session: pendingSession)
      }
    }
  }

  /// Persists a complete record while `lock` is held.
  private func locked_save(session: Session) {
    guard persistenceWritable else { return }
    guard let data = try? PropertyListEncoder().encode(PersistedSessionRecord(session: session)) else {
      return
    }
    persistence.write(data)
    previousSavedSession = session
    pendingSession = nil
  }
}
