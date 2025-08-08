//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import OpenTelemetryAtomicInt32

public final class OtelAtomicInt32: @unchecked Sendable {
    private var raw = otel_atomic_int32_t()
    
    public init(_ initial: Int32 = 0) {
        withUnsafeMutablePointer(to: &raw) { p in
            otel_atomic_int32_init(p, initial)
        }
    }
    
    @inline(__always)
    public func load() -> Int32 {
        withUnsafePointer(to: raw) { p in
            otel_atomic_int32_load(p)
        }
    }
    
    @inline(__always)
    public func store(_ newValue: Int32) {
        withUnsafeMutablePointer(to: &raw) { p in
            otel_atomic_int32_store(p, newValue)
        }
    }
    
    /// Returns the old value.
    @discardableResult
    @inline(__always)
    public func exchange(_ newValue: Int32) -> Int32 {
        withUnsafeMutablePointer(to: &raw) { p in
            otel_atomic_int32_exchange(p, newValue)
        }
    }
    
    /// Compare-and-exchange. On failure returns (false, currentValue).
    @inline(__always)
    public func compareExchange(expected: Int32, desired: Int32) -> (Bool, Int32) {
        var exp = expected
        let ok = withUnsafeMutablePointer(to: &raw) { p in
            withUnsafeMutablePointer(to: &exp) { e in
                otel_atomic_int32_compare_exchange(p, e, desired)
            }
        }
        return (ok, exp)
    }
    
    /// Add delta and return the **new** value.
    @inline(__always)
    public func add(_ delta: Int32) -> Int32 {
        let old = withUnsafeMutablePointer(to: &raw) { p in
            otel_atomic_int32_fetch_add(p, delta)
        }
        return old &+ delta
    }
    
    /// Subtract delta and return the **new** value.
    @inline(__always)
    public func sub(_ delta: Int32) -> Int32 { add(-delta) }
    
    @inline(__always) public func increment() -> Int32 { add(1) }
    @inline(__always) public func decrement() -> Int32 { sub(1) }
}
