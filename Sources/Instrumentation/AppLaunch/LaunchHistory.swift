/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin)
  import Darwin
  import Foundation

  /// The device and app state a launch ran in. A launch in the same state as the previous one is
  /// likely to find the app's code and data still cached in memory, which Apple calls a warm launch.
  struct LaunchContext: Codable, Equatable, Sendable {
    // `kern.boottime` moves when the system clock is set, so allow for small adjustments.
    static let bootTimeTolerance: TimeInterval = 1

    var bootTime: TimeInterval
    var bootSessionID: String?
    var appVersion: String?
    var appBuild: String?

    /// Whether the device hasn't rebooted and the app hasn't been updated since `previous`.
    func isSameState(as previous: LaunchContext) -> Bool {
      appVersion == previous.appVersion && appBuild == previous.appBuild && isSameBoot(as: previous)
    }

    private func isSameBoot(as previous: LaunchContext) -> Bool {
      // The boot session ID identifies the boot exactly and doesn't change with the system clock.
      if let bootSessionID, let previousBootSessionID = previous.bootSessionID {
        return bootSessionID == previousBootSessionID
      }
      return abs(bootTime - previous.bootTime) <= Self.bootTimeTolerance
    }
  }

  private let shortVersionKey = "CFBundleShortVersionString"
  private let buildKey = "CFBundleVersion"

  /// Returns the context of the current launch, or `nil` if the boot time can't be read.
  func readCurrentLaunchContext() -> LaunchContext? {
    guard let bootTime = readBootTime() else { return nil }
    let info = Bundle.main.infoDictionary
    return LaunchContext(
      bootTime: bootTime.timeIntervalSince1970,
      bootSessionID: readBootSessionID(),
      appVersion: info?[shortVersionKey] as? String,
      appBuild: info?[buildKey] as? String
    )
  }

  /// Returns the time the device booted, or `nil` if it can't be read.
  func readBootTime() -> Date? {
    var bootTime = timeval()
    var size = MemoryLayout<timeval>.stride
    var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

    guard sysctl(&mib, u_int(mib.count), &bootTime, &size, nil, 0) == 0 else {
      return nil
    }

    return Date(
      timeIntervalSince1970: TimeInterval(bootTime.tv_sec)
        + TimeInterval(bootTime.tv_usec) / TimeInterval(USEC_PER_SEC)
    )
  }

  private let bootSessionIDName = "kern.bootsessionuuid"

  /// Returns the kernel's identifier for the current boot, or `nil` if it can't be read.
  func readBootSessionID() -> String? {
    var size = 0
    guard sysctlbyname(bootSessionIDName, nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(bootSessionIDName, &buffer, &size, nil, 0) == 0 else { return nil }
    let id = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    return id.isEmpty ? nil : id
  }

  /// Remembers the context of the most recent launch across launches.
  protocol LaunchHistory: Sendable {
    /// Records `current` as the most recent launch and returns the launch it replaces.
    func exchange(_ current: LaunchContext) -> LaunchContext?
  }

  struct UserDefaultsLaunchHistory: LaunchHistory {
    static let key = "io.opentelemetry.lifecycle.lastLaunchContext"

    /// The `UserDefaults` suite to store the history in, or `nil` for `UserDefaults.standard`.
    var suiteName: String?

    func exchange(_ current: LaunchContext) -> LaunchContext? {
      guard let defaults = suiteName == nil ? .standard : UserDefaults(suiteName: suiteName) else {
        return nil
      }
      let previous = defaults.data(forKey: Self.key)
        .flatMap { try? JSONDecoder().decode(LaunchContext.self, from: $0) }
      if let data = try? JSONEncoder().encode(current) {
        defaults.set(data, forKey: Self.key)
      }
      return previous
    }
  }
#endif
