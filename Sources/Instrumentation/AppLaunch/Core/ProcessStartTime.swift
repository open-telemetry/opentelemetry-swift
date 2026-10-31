/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin)
  import Darwin
  import Foundation

  /// Returns the time the kernel created the current process, or `nil` if it can't be read.
  func readProcessStartTime() -> Date? {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

    guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else {
      return nil
    }

    let startTime = info.kp_proc.p_starttime
    return Date(
      timeIntervalSince1970: TimeInterval(startTime.tv_sec)
        + TimeInterval(startTime.tv_usec) / TimeInterval(USEC_PER_SEC)
    )
  }
#endif
