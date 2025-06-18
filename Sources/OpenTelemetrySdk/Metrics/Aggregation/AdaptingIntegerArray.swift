//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

class AdaptingIntegerArray: NSCopying, Codable {
  func copy(with zone: NSZone? = nil) -> Any {
    let copy = AdaptingIntegerArray(size: size)
    copy.cellSize = cellSize
    switch cellSize {
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

  var byteBacking: [Int8]?
  var shortBacking: [Int16]?
  var intBacking: [Int32]?
  var longBacking: [Int64]?
  var size: Int

  enum ArrayCellSize: Codable {
    case byte
    case short
    case int
    case long
  }

  var cellSize: ArrayCellSize

  init(size: Int) {
    self.size = size
    cellSize = ArrayCellSize.byte
    byteBacking = [Int8](repeating: Int8(0), count: size)
  }

  func increment(index: Int, count: Int64) {
    if cellSize == .byte, var byteBacking {
      let result = Int64(byteBacking[index]) + count
      if result > Int8.max {
        resizeToShort()
        increment(index: index, count: count)
      } else {
        byteBacking[index] = Int8(result)
        self.byteBacking = byteBacking
      }
    } else if cellSize == .short, var shortBacking {
      let result = Int64(shortBacking[index]) + count
      if result > Int16.max {
        resizeToInt()
        increment(index: index, count: count)
      } else {
        shortBacking[index] = Int16(result)
        self.shortBacking = shortBacking
      }
    } else if cellSize == .int, var intBacking {
      let result = Int64(intBacking[index]) + count
      if result > Int32.max {
        resizeToLong()
        increment(index: index, count: count)
      } else {
        intBacking[index] = Int32(result)
        self.intBacking = intBacking
      }
    } else if cellSize == .long, var longBacking {
      let result = longBacking[index] + count
      longBacking[index] = result
      self.longBacking = longBacking
    }
  }

  func get(index: Int) -> Int64 {
    if cellSize == .byte, let byteBacking, index < byteBacking.count {
      return Int64(byteBacking[index])
    } else if cellSize == .short, let shortBacking, index < shortBacking.count {
      return Int64(shortBacking[index])
    } else if cellSize == .int, let intBacking, index < intBacking.count {
      return Int64(intBacking[index])
    } else if cellSize == .long, let longBacking, index < longBacking.count {
      return longBacking[index]
    }

    return Int64(0)
  }

  func length() -> Int {
    var length = 0

    if cellSize == .byte, let byteBacking {
      length = byteBacking.count
    } else if cellSize == .short, let shortBacking {
      length = shortBacking.count
    } else if cellSize == .int, let intBacking {
      length = intBacking.count
    } else if cellSize == .long, let longBacking {
      length = longBacking.count
    }

    return length
  }

  func clear() {
    switch cellSize {
    case .byte:
      byteBacking = Array(repeating: Int8(0), count: byteBacking?.count ?? 0)
    case .short:
      shortBacking = Array(repeating: Int16(0), count: shortBacking?.count ?? 0)
    case .int:
      intBacking = Array(repeating: Int32(0), count: intBacking?.count ?? 0)
    case .long:
      longBacking = Array(repeating: Int64(0), count: longBacking?.count ?? 0)
    }
  }

  private func resizeToShort() {
    guard let byteBacking else { return }
    var tmpShortBacking = [Int16](repeating: Int16(0), count: byteBacking.count)

    for (index, value) in byteBacking.enumerated() {
      tmpShortBacking[index] = Int16(value)
    }
    cellSize = ArrayCellSize.short
    shortBacking = tmpShortBacking
    self.byteBacking = nil
  }

  private func resizeToInt() {
    guard let shortBacking else { return }
    var tmpIntBacking = [Int32](repeating: Int32(0), count: shortBacking.count)

    for (index, value) in shortBacking.enumerated() {
      tmpIntBacking[index] = Int32(value)
    }
    cellSize = ArrayCellSize.int
    intBacking = tmpIntBacking
    self.shortBacking = nil
  }

  private func resizeToLong() {
    guard let intBacking else { return }
    var tmpLongBacking = [Int64](repeating: Int64(0), count: intBacking.count)

    for (index, value) in intBacking.enumerated() {
      tmpLongBacking[index] = Int64(value)
    }
    cellSize = ArrayCellSize.long
    longBacking = tmpLongBacking
    self.intBacking = nil
  }
}
