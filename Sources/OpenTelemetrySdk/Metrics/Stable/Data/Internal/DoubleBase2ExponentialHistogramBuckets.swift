//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoubleBase2ExponentialHistogramBuckets:
  ExponentialHistogramBuckets, NSCopying {
  public func copy(with zone: NSZone? = nil) -> Any {
    let copy = DoubleBase2ExponentialHistogramBuckets(scale: scale, maxBuckets: 0)
    copy.counts = counts.copy() as! AdaptingCircularBufferCounter
    copy.base2ExponentialHistogramIndexer = base2ExponentialHistogramIndexer
    copy.totalCount = totalCount
    return copy
  }

  public var totalCount: Int
  public var scale: Int

  public var offset: Int {
    if counts.isEmpty() {
      return 0
    } else {
      return counts.startIndex
    }
  }

  public var bucketCounts: [Int64] {
    if counts.isEmpty() {
      return []
    }

    let length = counts.endIndex - counts.startIndex + 1
    var countsArr: [Int64] = Array(repeating: Int64(0), count: length)

    for i in 0 ..< length {
      countsArr[i] = counts.get(index: i + counts.startIndex)
    }

    return countsArr
  }

  var counts: AdaptingCircularBufferCounter
  var base2ExponentialHistogramIndexer: Base2ExponentialHistogramIndexer

  init(scale: Int, maxBuckets: Int) {
    counts = AdaptingCircularBufferCounter(maxSize: maxBuckets)
    self.scale = scale
    base2ExponentialHistogramIndexer = Base2ExponentialHistogramIndexer(
      scale: scale)
    totalCount = 0
  }

  func clear(scale: Int) {
    totalCount = 0
    self.scale = scale
    base2ExponentialHistogramIndexer = Base2ExponentialHistogramIndexer(
      scale: scale)
    counts.clear()
  }

  @discardableResult func record(value: Double) -> Bool {
    guard value != 0.0 else { return false }

    let index = base2ExponentialHistogramIndexer.computeIndex(value)
    let recordingSuccessful = counts.increment(index: index, delta: 1)
    if recordingSuccessful {
      totalCount += 1
    }
    return recordingSuccessful
  }

  func downscale(by: Int) {
    if by == 0 {
      return
    } else if by < 0 {
      return
    }

    if !counts.isEmpty() {
      let newCounts = counts.copy() as! AdaptingCircularBufferCounter
      newCounts.clear()

      for i in counts.startIndex ... counts.endIndex {
        let count = counts.get(index: i)
        if count > 0 {
          if !newCounts.increment(index: i >> by, delta: count) {
            return
          }
        }
      }

      counts = newCounts
    }

    scale -= by
    base2ExponentialHistogramIndexer = Base2ExponentialHistogramIndexer(
      scale: scale)
  }

  func getScaleReduction(_ value: Double) -> Int {
    let index = base2ExponentialHistogramIndexer.computeIndex(value)
    let newStart = Swift.min(index, counts.startIndex)
    let newEnd = Swift.max(index, counts.endIndex)
    return getScaleReduction(newStart: newStart, newEnd: newEnd)
  }

  func getScaleReduction(newStart: Int, newEnd: Int) -> Int {
    var scaleReduction = 0
    var newStart = newStart
    var newEnd = newEnd

    while newEnd - newStart + 1 > counts.getMaxSize() {
      newStart >>= 1
      newEnd >>= 1
      scaleReduction += 1
    }

    return scaleReduction
  }
}
