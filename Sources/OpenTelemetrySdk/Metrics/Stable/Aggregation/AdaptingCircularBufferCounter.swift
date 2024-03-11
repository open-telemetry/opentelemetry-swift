//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

class AdaptingCircularBufferCounter: NSCopying {
    func copy(with zone: NSZone? = nil) -> Any {
        let copy = AdaptingCircularBufferCounter(maxSize: maxSize)
        copy.startIndex = startIndex
        copy.endIndex = endIndex
        copy.baseIndex = baseIndex
        copy.backing = backing.copy() as! AdaptingIntegerArray
        return copy
    }

    private static let NULL_INDEX: Int = Int.min
    public private(set) var endIndex = NULL_INDEX
    public private(set) var startIndex = NULL_INDEX
    private var baseIndex = NULL_INDEX
    private var backing: AdaptingIntegerArray
    private let maxSize: Int

    init(maxSize: Int) {
        self.backing = AdaptingIntegerArray(size: maxSize)
        self.maxSize = maxSize
    }

    @discardableResult func increment(index: Int, delta: Int64) -> Bool{
        if self.baseIndex == Int.min {
            self.startIndex = index
            self.endIndex = index
            self.baseIndex = index
            self.backing.increment(index: 0, count: delta)
            return true
        }

        if index > self.endIndex {
            if (index - self.startIndex + 1) > self.backing.length() {
                return false
            }
            self.endIndex = index
        } else if index < self.startIndex {
            if (self.endIndex - index + 1) > self.backing.length() {
                return false
            }
            self.startIndex = index
        }

        let realIndex = toBufferIndex(index: index)
        self.backing.increment(index: realIndex, count: delta)
        return true
    }

    func get(index: Int) -> Int64 {
        if (index < self.startIndex || index > self.endIndex) {
            return 0
        } else {
            return backing.get(index: toBufferIndex(index: index))
        }
    }

    func isEmpty() -> Bool {
        return baseIndex == Self.NULL_INDEX
    }

    func getMaxSize() -> Int {
        return backing.length()
    }

    func clear() {
        self.backing.clear()
        self.baseIndex = Self.NULL_INDEX
        self.startIndex = Self.NULL_INDEX
        self.endIndex = Self.NULL_INDEX
    }

    private func toBufferIndex(index: Int) -> Int {
        var result = index - self.baseIndex
        if (result >= backing.length()) {
            result -= backing.length()
        } else if (result < 0) {
            result += backing.length()
        }
        return result
    }
}
