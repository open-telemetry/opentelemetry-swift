//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class DoubleBase2ExponentialHistogramBuckets:
  ExponentialHistogramBuckets, NSCopying {
  public func copy(with zone: NSZone? = nil) -> Any {
    let copy = DoubleBase2ExponentialHistogramBuckets(
      scale: scale, maxBuckets: 0)
    copy.counts = counts.copy() as! AdaptingCircularBufferCounter
    copy.base2ExponentialHistogramIndexer = base2ExponentialHistogramIndexer
    copy.totalCount = totalCount
    return copy
  }

  public var totalCount: Int
  public var scale: Int

  public var offset: Int {
    if self.counts.isEmpty() {
      return 0
    } else {
      return self.counts.startIndex
    }
  }

  public var bucketCounts: [Int64] {
    if self.counts.isEmpty() {
      return []
    }

    let length = self.counts.endIndex - self.counts.startIndex + 1
    var countsArr: [Int64] = Array(repeating: Int64(0), count: length)

    for i in 0..<length {
      countsArr[i] = self.counts.get(index: (i + self.counts.startIndex))
    }

    return countsArr
  }

  var counts: AdaptingCircularBufferCounter
  var base2ExponentialHistogramIndexer: Base2ExponentialHistogramIndexer

  init(scale: Int, maxBuckets: Int) {
    self.counts = AdaptingCircularBufferCounter(maxSize: maxBuckets)
    self.scale = scale
    self.base2ExponentialHistogramIndexer = Base2ExponentialHistogramIndexer(
      scale: scale)
    self.totalCount = 0
  }

  func clear(scale: Int) {
    self.totalCount = 0
    self.scale = scale
    self.base2ExponentialHistogramIndexer = Base2ExponentialHistogramIndexer(
      scale: scale)
    self.counts.clear()
  }

  @discardableResult func record(value: Double) -> Bool {
    guard value != 0.0 else { return false }

    let index = self.base2ExponentialHistogramIndexer.computeIndex(value)
    let recordingSuccessful = self.counts.increment(index: index, delta: 1)
    if recordingSuccessful {
      self.totalCount += 1
    }
    return recordingSuccessful
  }

  func downscale(by: Int) {
    if by == 0 {
      return
    } else if by < 0 {
      return
    }

    if !self.counts.isEmpty() {
      let newCounts = self.counts.copy() as! AdaptingCircularBufferCounter
      newCounts.clear()

      for i in self.counts.startIndex...self.counts.endIndex {
        let count = self.counts.get(index: i)
        if count > 0 {
          if !newCounts.increment(index: i >> by, delta: count) {
            return
          }
        }
      }

      self.counts = newCounts
    }

    self.scale -= by
    self.base2ExponentialHistogramIndexer = Base2ExponentialHistogramIndexer(
      scale: self.scale)
  }

  func getScaleReduction(_ value: Double) -> Int {
    let index = self.base2ExponentialHistogramIndexer.computeIndex(value)
    let newStart = Swift.min(index, self.counts.startIndex)
    let newEnd = Swift.max(index, self.counts.endIndex)
    return getScaleReduction(newStart: newStart, newEnd: newEnd)
  }

  func getScaleReduction(newStart: Int, newEnd: Int) -> Int {
    var scaleReduction = 0
    var newStart = newStart
    var newEnd = newEnd

    while newEnd - newStart + 1 > self.counts.getMaxSize() {
      newStart >>= 1
      newEnd >>= 1
      scaleReduction += 1
    }

    return scaleReduction
  }
}
