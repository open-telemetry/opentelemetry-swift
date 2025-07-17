/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

// ===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Metrics API open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Metrics API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Metrics API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#else
  #error("Unsupported platform")
#endif

/// A threading lock based on `libpthread` instead of `libdispatch`.
///
/// This object provides a lock on top of a single `pthread_mutex_t`. This kind
/// of lock is safe to use with `libpthread`-based threading models, such as the
/// one used by NIO.
final class Lock {
  private let mutex: UnsafeMutablePointer<pthread_mutex_t> = UnsafeMutablePointer.allocate(capacity: 1)

  /// Create a new lock.
  public init() {
    let err = pthread_mutex_init(mutex, nil)
    precondition(err == 0, "pthread_mutex_init failed with error \(err)")
  }

  deinit {
    let err = pthread_mutex_destroy(self.mutex)
    precondition(err == 0, "pthread_mutex_destroy failed with error \(err)")
    self.mutex.deallocate()
  }

  /// Acquire the lock.
  ///
  /// Whenever possible, consider using `withLock` instead of this method and
  /// `unlock`, to simplify lock handling.
  public func lock() {
    let err = pthread_mutex_lock(mutex)
    precondition(err == 0, "pthread_mutex_lock failed with error \(err)")
  }

  /// Release the lock.
  ///
  /// Whenever possible, consider using `withLock` instead of this method and
  /// `lock`, to simplify lock handling.
  public func unlock() {
    let err = pthread_mutex_unlock(mutex)
    precondition(err == 0, "pthread_mutex_unlock failed with error \(err)")
  }
}

extension Lock {
  /// Acquire the lock for the duration of the given block.
  ///
  /// This convenience method should be preferred to `lock` and `unlock` in
  /// most situations, as it ensures that the lock will be released regardless
  /// of how `body` exits.
  ///
  /// - Parameter body: The block to execute while holding the lock.
  /// - Returns: The value returned by the block.
  @inlinable
  func withLock<T>(_ body: () throws -> T) rethrows -> T {
    lock()
    defer {
      self.unlock()
    }
    return try body()
  }

  // specialise Void return (for performance)
  @inlinable
  func withLockVoid(_ body: () throws -> Void) rethrows {
    try withLock(body)
  }
}

/// A threading lock based on `libpthread` instead of `libdispatch`.
///
/// This object provides a lock on top of a single `pthread_mutex_t`. This kind
/// of lock is safe to use with `libpthread`-based threading models, such as the
/// one used by NIO.
final class ReadWriteLock {
  private let rwlock: UnsafeMutablePointer<pthread_rwlock_t> = UnsafeMutablePointer.allocate(capacity: 1)

  /// Create a new lock.
  public init() {
    let err = pthread_rwlock_init(rwlock, nil)
    precondition(err == 0, "pthread_rwlock_init failed with error \(err)")
  }

  deinit {
    let err = pthread_rwlock_destroy(self.rwlock)
    precondition(err == 0, "pthread_rwlock_destroy failed with error \(err)")
    self.rwlock.deallocate()
  }

  /// Acquire a reader lock.
  ///
  /// Whenever possible, consider using `withLock` instead of this method and
  /// `unlock`, to simplify lock handling.
  public func lockRead() {
    let err = pthread_rwlock_rdlock(rwlock)
    precondition(err == 0, "pthread_rwlock_rdlock failed with error \(err)")
  }

  /// Acquire a writer lock.
  ///
  /// Whenever possible, consider using `withLock` instead of this method and
  /// `unlock`, to simplify lock handling.
  public func lockWrite() {
    let err = pthread_rwlock_wrlock(rwlock)
    precondition(err == 0, "pthread_rwlock_wrlock failed with error \(err)")
  }

  /// Release the lock.
  ///
  /// Whenever possible, consider using `withLock` instead of this method and
  /// `lock`, to simplify lock handling.
  public func unlock() {
    let err = pthread_rwlock_unlock(rwlock)
    precondition(err == 0, "pthread_rwlock_unlock failed with error \(err)")
  }
}

extension ReadWriteLock {
  /// Acquire the reader lock for the duration of the given block.
  ///
  /// This convenience method should be preferred to `lock` and `unlock` in
  /// most situations, as it ensures that the lock will be released regardless
  /// of how `body` exits.
  ///
  /// - Parameter body: The block to execute while holding the lock.
  /// - Returns: The value returned by the block.
  @inlinable
  public func withReaderLock<T>(_ body: () throws -> T) rethrows -> T {
    lockRead()
    defer {
      self.unlock()
    }
    return try body()
  }

  /// Acquire the writer lock for the duration of the given block.
  ///
  /// This convenience method should be preferred to `lock` and `unlock` in
  /// most situations, as it ensures that the lock will be released regardless
  /// of how `body` exits.
  ///
  /// - Parameter body: The block to execute while holding the lock.
  /// - Returns: The value returned by the block.
  @inlinable
  public func withWriterLock<T>(_ body: () throws -> T) rethrows -> T {
    lockWrite()
    defer {
      self.unlock()
    }
    return try body()
  }

  // specialise Void return (for performance)
  @inlinable
  func withReaderLockVoid(_ body: () throws -> Void) rethrows {
    try withReaderLock(body)
  }

  // specialise Void return (for performance)
  @inlinable
  func withWriterLockVoid(_ body: () throws -> Void) rethrows {
    try withWriterLock(body)
  }
}

public final class Locked<Value> : @unchecked Sendable {
    
    private var internalValue: Value
    
    private let lock = Lock()
    
    public var protectedValue: Value {
        get {
            lock.withLock { internalValue }
        }
        _modify {
            lock.lock()
            defer { lock.unlock() }
            yield &internalValue
        }
    }
    
    public init(initialValue: Value) {
        self.internalValue = initialValue
    }
    
    public func locking<T>(_ block: (inout Value) throws -> T) rethrows -> T {
        try lock.withLock { try block(&internalValue) }
    }
}

public final class ReadWriteLocked<Value> : @unchecked Sendable {
    
    private var internalValue: Value
    
    private let rwlock = ReadWriteLock()
    
    public var protectedValue: Value {
        get {
            rwlock.withReaderLock { internalValue }
        }
        _modify {
            rwlock.lockWrite()
            defer { rwlock.unlock() }
            yield &internalValue
        }
    }
    
    public init(initialValue: Value) {
        self.internalValue = initialValue
    }
    
    public func readLocking<T>(_ block: (Value) throws -> T) rethrows -> T {
        try rwlock.withReaderLock{ try block(internalValue) }
    }
    
    public func writeLocking<T>(_ block: (inout Value) throws -> T) rethrows -> T {
        try rwlock.withWriterLock{ try block(&internalValue) }
    }
    
    
}
