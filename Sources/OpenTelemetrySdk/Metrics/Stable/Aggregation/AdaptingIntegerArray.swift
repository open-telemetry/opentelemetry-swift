//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

class AdaptingIntegerArray: NSCopying {
    
    func copy(with zone: NSZone? = nil) -> Any {
        let copy = AdaptingIntegerArray(size: size)
        copy.cellSize = cellSize
        switch (cellSize) {
        case .byte:
            copy.byteBacking = byteBacking
        case .short:
            copy.shortBacking = shortBacking
        case .int:
            copy.intBacking = intBacking
        case .long:
            copy.longBacking = longBacking
        }
        return copy
    }
    
    var byteBacking: Array<Int8>?
    var shortBacking: Array<Int16>?
    var intBacking: Array<Int32>?
    var longBacking: Array<Int64>?
    var size: Int
    
    enum ArrayCellSize {
        case byte
        case short
        case int
        case long
    }
    
    var cellSize: ArrayCellSize
    
    init(size: Int) {
        self.size = size
        self.cellSize = ArrayCellSize.byte
        self.byteBacking = Array<Int8>(repeating: Int8(0), count: size)
    }
    
    func increment(index: Int, count: Int64) {
        
        if self.cellSize == .byte, var byteBacking = self.byteBacking {
            let result = Int64(byteBacking[index]) + count
            if result > Int8.max {
                resizeToShort()
                increment(index: index, count: count)
            } else {
                byteBacking[index] = Int8(result)
                self.byteBacking = byteBacking
            }
        } else if self.cellSize == .short, var shortBacking = self.shortBacking {
            let result = Int64(shortBacking[index]) + count
            if result > Int16.max {
                resizeToInt()
                increment(index: index, count: count)
            } else {
                shortBacking[index] = Int16(result)
                self.shortBacking = shortBacking
            }
        } else if self.cellSize == .int, var intBacking = self.intBacking {
            let result = Int64(intBacking[index]) + count
            if result > Int32.max {
                resizeToLong()
                increment(index: index, count: count)
            } else {
                intBacking[index] = Int32(result)
                self.intBacking = intBacking
            }
        } else if self.cellSize == .long, var longBacking = self.longBacking {
            let result = longBacking[index] + count
            longBacking[index] = result
            self.longBacking = longBacking
        }
    }
    
    func get(index: Int) -> Int64 {

        if self.cellSize == .byte, let byteBacking = self.byteBacking, index < byteBacking.count {
            return Int64(byteBacking[index])
        } else if self.cellSize == .short, let shortBacking = self.shortBacking, index < shortBacking.count {
            return Int64(shortBacking[index])
        } else if self.cellSize == .int, let intBacking = self.intBacking, index < intBacking.count {
            return Int64(intBacking[index])
        } else if self.cellSize == .long, let longBacking = self.longBacking, index < longBacking.count {
            return longBacking[index]
        }
        
        return Int64(0)
    }
    
    func length() -> Int {
        var length = 0
        
        if self.cellSize == .byte, let byteBacking = self.byteBacking {
            length = byteBacking.count
        } else if self.cellSize == .short, let shortBacking = self.shortBacking {
            length = shortBacking.count
        } else if self.cellSize == .int, let intBacking = self.intBacking {
            length = intBacking.count
        } else if self.cellSize == .long, let longBacking = self.longBacking {
            length = longBacking.count
        }
        
        return length
    }
    
    func clear() {
        switch (self.cellSize) {
        case .byte:
            self.byteBacking = Array(repeating: Int8(0), count: self.byteBacking?.count ?? 0)
        case .short:
            self.shortBacking = Array(repeating: Int16(0), count: self.shortBacking?.count ?? 0)
        case .int:
            self.intBacking = Array(repeating: Int32(0), count: self.intBacking?.count ?? 0)
        case .long:
            self.longBacking = Array(repeating: Int64(0), count: self.longBacking?.count ?? 0)
        }
    }
    
    private func resizeToShort() {
        guard let byteBacking = self.byteBacking else { return }
        var tmpShortBacking: Array<Int16> = Array<Int16>(repeating: Int16(0), count: byteBacking.count)
        
        for (index, value) in byteBacking.enumerated() {
            tmpShortBacking[index] = Int16(value)
        }
        self.cellSize = ArrayCellSize.short
        self.shortBacking = tmpShortBacking
        self.byteBacking = nil
    }
    
    private func resizeToInt() {
        guard let shortBacking = self.shortBacking else { return }
        var tmpIntBacking: Array<Int32> = Array<Int32>(repeating: Int32(0), count: shortBacking.count)
        
        for (index, value) in shortBacking.enumerated() {
            tmpIntBacking[index] = Int32(value)
        }
        self.cellSize = ArrayCellSize.int
        self.intBacking = tmpIntBacking
        self.shortBacking = nil
    }
    
    private func resizeToLong() {
        guard let intBacking = self.intBacking else { return }
        var tmpLongBacking: Array<Int64> = Array<Int64>(repeating: Int64(0), count: intBacking.count)
        
        for (index, value) in intBacking.enumerated() {
            tmpLongBacking[index] = Int64(value)
        }
        self.cellSize = ArrayCellSize.long
        self.longBacking = tmpLongBacking
        self.intBacking = nil
    }
}

