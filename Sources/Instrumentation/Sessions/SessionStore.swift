/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct PersistedSessionRecord: Codable, Equatable {
  static let currentVersion = 2

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
  /// Raw values are part of the record schema; new decision semantics require a version bump.
  let samplingDecision: SessionSamplingDecision

  init(session: Session) {
    id = session.id
    expireTime = session.expireTime
    previousId = session.previousId
    startTime = session.startTime
    sessionTimeout = session.sessionTimeout
    maxLifetime = session.maxLifetime
    samplingDecision = session.samplingDecision
  }

  var value: Session {
    return Session(
      id: id,
      expireTime: expireTime,
      previousId: previousId,
      startTime: startTime,
      sessionTimeout: sessionTimeout,
      maxLifetime: maxLifetime,
      samplingDecision: samplingDecision
    )
  }
}

private struct PersistedSessionRecordV1: Codable {
  let version: Int
  let session: PersistedSessionV1
}

private struct PersistedSessionV1: Codable {
  let id: String
  let expireTime: Date
  let previousId: String?
  let startTime: Date
  let sessionTimeout: TimeInterval
  let maxLifetime: TimeInterval?

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

struct LoadedSession {
  enum Source: Equatable {
    case current
    case version1
    case legacyKeys
  }

  let session: Session
  let source: Source

  var requiresMigration: Bool {
    return source != .current
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
  /// Prevents an older SDK from replacing a record written with a newer schema.
  private var isWriteBlockedByFutureRecord = false
  private var shouldClearLegacyAfterNextSave = false
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

  static func load() -> LoadedSession? {
    return shared.load()
  }

  static func teardown() {
    shared.teardown()
  }

  func scheduleSave(session: Session) {
    let timerToSchedule: Timer? = lock.withLock {
      guard !isWriteBlockedByFutureRecord else { return nil }
      pendingSession = session
      guard let timer = locked_makeSaveTimerIfNeeded() else { return nil }
      _ = locked_save(session: session)
      return timer
    }

    scheduleTimerOnMainIfNeeded(timerToSchedule)
  }

  func saveImmediately(session: Session) {
    let timerToSchedule: Timer? = lock.withLock {
      guard !isWriteBlockedByFutureRecord else { return nil }
      pendingSession = session
      guard !locked_save(session: session) else { return nil }
      return locked_makeSaveTimerIfNeeded()
    }

    scheduleTimerOnMainIfNeeded(timerToSchedule)
  }

  func load() -> LoadedSession? {
    return lock.withLock {
      if let data = persistence.read() {
        if let storedVersion = try? PropertyListDecoder().decode(PersistedSessionRecordVersion.self, from: data) {
          if storedVersion.version > PersistedSessionRecord.currentVersion {
            pendingSession = nil
            previousSavedSession = nil
            isWriteBlockedByFutureRecord = true
            shouldClearLegacyAfterNextSave = false
            return nil
          }

          let loadedSession: LoadedSession? = switch storedVersion.version {
          case PersistedSessionRecord.currentVersion:
            if let record = try? PropertyListDecoder().decode(PersistedSessionRecord.self, from: data) {
              LoadedSession(session: record.session.value, source: .current)
            } else {
              nil
            }
          case 1:
            if let record = try? PropertyListDecoder().decode(PersistedSessionRecordV1.self, from: data) {
              LoadedSession(session: record.session.value, source: .version1)
            } else {
              nil
            }
          default:
            nil
          }

          if let loadedSession {
            pendingSession = nil
            previousSavedSession = loadedSession.session
            isWriteBlockedByFutureRecord = false
            shouldClearLegacyAfterNextSave = false
            return loadedSession
          }
        }

        // Session persistence is a cache. Drop unreadable records so later writes can recover.
        isWriteBlockedByFutureRecord = false
        shouldClearLegacyAfterNextSave = false
        _ = persistence.clear()
      } else {
        isWriteBlockedByFutureRecord = false
      }

      guard let userDefaultsPersistence = persistence as? UserDefaultsSessionPersistence,
            let legacySession = userDefaultsPersistence.loadLegacySession()
      else {
        return nil
      }

      pendingSession = nil
      previousSavedSession = legacySession
      return LoadedSession(session: legacySession, source: .legacyKeys)
    }
  }

  /// Replaces a legacy record after its missing fields have been supplied.
  func migrate(_ loadedSession: LoadedSession, to session: Session) {
    guard loadedSession.requiresMigration else { return }
    let timerToSchedule: Timer? = lock.withLock {
      pendingSession = session
      shouldClearLegacyAfterNextSave = loadedSession.source == .legacyKeys
      guard !locked_save(session: session) else { return nil }
      // The decoded v1 session can equal the v2 value when the new decision is `.sampled`.
      // Clear the deduplication baseline so the timer still writes the newer schema.
      previousSavedSession = nil
      return locked_makeSaveTimerIfNeeded()
    }

    scheduleTimerOnMainIfNeeded(timerToSchedule)
  }

  func teardown() {
    let timer = lock.withLock {
      let timer = saveTimer
      saveTimer = nil
      pendingSession = nil
      previousSavedSession = nil
      isWriteBlockedByFutureRecord = false
      shouldClearLegacyAfterNextSave = false
      _ = persistence.clear()
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
        _ = locked_save(session: pendingSession)
      }
    }
  }

  /// Creates the retry timer while `lock` is held, if this store does not already own one.
  private func locked_makeSaveTimerIfNeeded() -> Timer? {
    guard saveTimer == nil else { return nil }
    let timer = Timer(timeInterval: saveInterval, repeats: true) { [weak self] _ in
      self?.savePendingSession()
    }
    saveTimer = timer
    return timer
  }

  private func scheduleTimerOnMainIfNeeded(_ timer: Timer?) {
    guard let timer else { return }
    if Thread.isMainThread {
      scheduleTimerIfCurrent(timer)
    } else {
      nonisolated(unsafe) let timerRef = timer
      weak let weakSelf = self
      DispatchQueue.main.async {
        guard let weakSelf else {
          timerRef.invalidate()
          return
        }
        weakSelf.scheduleTimerIfCurrent(timerRef)
      }
    }
  }

  /// Adds only the timer that still owns this store's pending-save slot.
  private func scheduleTimerIfCurrent(_ timer: Timer) {
    guard lock.withLock({ saveTimer === timer }) else {
      timer.invalidate()
      return
    }
    RunLoop.main.add(timer, forMode: .common)
  }

  /// Persists a complete record while `lock` is held.
  @discardableResult
  private func locked_save(session: Session) -> Bool {
    guard !isWriteBlockedByFutureRecord else { return false }
    guard let data = try? PropertyListEncoder().encode(PersistedSessionRecord(session: session)) else {
      return false
    }
    guard persistence.write(data) else {
      return false
    }
    if shouldClearLegacyAfterNextSave,
       let userDefaultsPersistence = persistence as? UserDefaultsSessionPersistence {
      userDefaultsPersistence.clearLegacySession()
    }
    shouldClearLegacyAfterNextSave = false
    previousSavedSession = session
    pendingSession = nil
    return true
  }
}
