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

	public private(set) var endIndex = Int.nullIndex
    public private(set) var startIndex = Int.nullIndex
    private var baseIndex = Int.nullIndex
    private var backing: AdaptingIntegerArray
    private let maxSize: Int

    init(maxSize: Int) {
        backing = AdaptingIntegerArray(size: maxSize)
        self.maxSize = maxSize
    }

    @discardableResult func increment(index: Int, delta: Int64) -> Bool{
        if baseIndex == Int.min {
            startIndex = index
            endIndex = index
            baseIndex = index
            backing.increment(index: 0, count: delta)
            return true
        }

        if index > endIndex {
            if (index - startIndex + 1) > backing.length() {
                return false
            }
            endIndex = index
        } else if index < startIndex {
            if (endIndex - index + 1) > backing.length() {
                return false
            }
            self.startIndex = index
        }

        let realIndex = toBufferIndex(index: index)
        backing.increment(index: realIndex, count: delta)
        return true
    }

    func get(index: Int) -> Int64 {
        if (index < startIndex || index > endIndex) {
            return 0
        } else {
            return backing.get(index: toBufferIndex(index: index))
        }
    }

    func isEmpty() -> Bool {
        return baseIndex == Int.nullIndex
    }

    func getMaxSize() -> Int {
        return backing.length()
    }

    func clear() {
        backing.clear()
        baseIndex = Int.nullIndex
        startIndex = Int.nullIndex
        endIndex = Int.nullIndex
    }

    private func toBufferIndex(index: Int) -> Int {
        var result = index - baseIndex
        if (result >= backing.length()) {
            result -= backing.length()
        } else if (result < 0) {
            result += backing.length()
        }
        return result
    }
}

extension Int {
	static let nullIndex = Int.min
}
