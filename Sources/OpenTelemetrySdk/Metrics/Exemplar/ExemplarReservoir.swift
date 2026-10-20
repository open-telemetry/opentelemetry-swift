//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class ExemplarReservoir {
  public func collectAndReset(attribute: [String: AttributeValue]) -> [ExemplarData] {
    return [ExemplarData]()
  }

  public func offerDoubleMeasurement(value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) {}

  public func offerLongMeasurement(value: Int, attributes: [String: OpenTelemetryApi.AttributeValue]) {}
}

public class NoopExemplarReservoir: ExemplarReservoir {
  override public func offerDoubleMeasurement(value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) {
    // noop
  }

  override public func offerLongMeasurement(value: Int, attributes: [String: OpenTelemetryApi.AttributeValue]) {
    // noop
  }

  override public func collectAndReset(attribute: [String: AttributeValue]) -> [ExemplarData] {
    return [ExemplarData]()
  }
}

public enum ExemplarReservoirCollection {
  static func doubleNoSamples() -> ExemplarReservoir {
    return NoopExemplarReservoir()
  }

  static func longNoSamples() -> ExemplarReservoir {
    return NoopExemplarReservoir()
  }
}

public class FixedSizedExemplarReservoir: ExemplarReservoir {
  var storage: [ReservoirCell]
  let reservoirCellSelector: ReservoirCellSelector
  let mapAndResetCell: (ReservoirCell, [String: AttributeValue]) -> ExemplarData?
  let hasMeasurements = Locked<Bool>(initialValue: false)

  init(clock: Clock, size: Int, reservoirCellSelector: ReservoirCellSelector, mapAndResetCell: @escaping (ReservoirCell, [String: AttributeValue]) -> ExemplarData?) {
    storage = [ReservoirCell]()
    self.reservoirCellSelector = reservoirCellSelector
    self.mapAndResetCell = mapAndResetCell

    for _ in 0 ..< size {
      storage.append(ReservoirCell(clock: clock))
    }
  }

  override public func offerLongMeasurement(value: Int, attributes: [String: AttributeValue]) {
    let bucketIndex = reservoirCellSelector.reservoirCellIndex(for: storage, value: value, attributes: attributes)

    if bucketIndex != -1 {
      storage[bucketIndex].recordLongValue(value: value, attributes: attributes)
      hasMeasurements.protectedValue = true
    }
  }

  override public func offerDoubleMeasurement(value: Double, attributes: [String: AttributeValue]) {
    let bucketIndex = reservoirCellSelector.reservoirCellIndex(for: storage, value: value, attributes: attributes)

    if bucketIndex != -1 {
      storage[bucketIndex].recordDoubleValue(value: value, attributes: attributes)
      hasMeasurements.protectedValue = true
    }
  }

  override public func collectAndReset(attribute: [String: AttributeValue]) -> [ExemplarData] {
    var results = [ExemplarData]()

    if !hasMeasurements.protectedValue {
      return results
    }
    for cell in storage {
      if let result = mapAndResetCell(cell, attribute) {
        results.append(result)
      }
    }
    reservoirCellSelector.reset()
    hasMeasurements.protectedValue = false
    return results
  }
}

public class RandomFixedSizedExemplarReservoir: FixedSizedExemplarReservoir {
  private init(clock: Clock, size: Int, mapAndResetCell: @escaping (ReservoirCell, [String: AttributeValue]) -> ExemplarData?) {
    super.init(clock: clock, size: size, reservoirCellSelector: RandomCellSelector(), mapAndResetCell: mapAndResetCell)
  }

  static func createLong(clock: Clock, size: Int) -> RandomFixedSizedExemplarReservoir {
    return RandomFixedSizedExemplarReservoir(clock: clock, size: size, mapAndResetCell: { cell, attributes in
      cell.getAndResetLong(pointAttributes: attributes)
    })
  }

  static func createDouble(clock: Clock, size: Int) -> RandomFixedSizedExemplarReservoir {
    return RandomFixedSizedExemplarReservoir(clock: clock, size: size, mapAndResetCell: { cell, attributes in
      cell.getAndResetDouble(pointAttributes: attributes)
    })
  }

  class RandomCellSelector: ReservoirCellSelector {
    var numMeasurements: Locked<Int> = .init(initialValue: 0)

    func reservoirCellIndex(for cells: [ReservoirCell], value: Int, attributes: [String: OpenTelemetryApi.AttributeValue]) -> Int {
      return getIndex(cells: cells)
    }

    func reservoirCellIndex(for cells: [ReservoirCell], value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) -> Int {
      return getIndex(cells: cells)
    }

    func reset() {
      numMeasurements.protectedValue = 0
    }

    private func getIndex(cells: [ReservoirCell]) -> Int {
      let count = numMeasurements.locking {
        $0 += 1
        return $0
      }
      let index = Int.random(in: Int.min ... Int.max) > 0 ? count : 1
      if index < cells.count {
        return index
      }
      return -1
    }
  }
}
