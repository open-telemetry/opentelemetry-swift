/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi


class RawHistogramMetricSdkBase<T> : RawHistogramMetric {
    
    func record(explicitBoundaries: Array<T>, counts: Array<Int>, startDate: Date, endDate: Date, count: Int, sum: T, labelset: LabelSet) {
        // noop
    }
    
    func record(explicitBoundaries: Array<T>, counts: Array<Int>, startDate: Date, endDate: Date, count: Int, sum: T, labels: [String : String]) {
        // noop
    }
    
    private let bindUnbindLock = Lock()
    public private(set) var boundInstruments = [LabelSet: BoundRawHistogramMetricSdkBase<T>]()
    let metricName : String
    
    init(name: String) {
        metricName = name
    }
    
    func bind(labelset: LabelSet) -> BoundRawHistogramMetric<T> {
        bind(labelset: labelset, isShortLived: false)
    }
    
    func bind(labels: [String : String]) -> BoundRawHistogramMetric<T> {
        bind(labelset: LabelSet(labels: labels), isShortLived: false)

    }
    
    internal func bind(labelset: LabelSet, isShortLived: Bool) -> BoundRawHistogramMetric<T> {
         var boundInstrument : BoundRawHistogramMetricSdkBase<T>?
         bindUnbindLock.withLockVoid {
             boundInstrument = boundInstruments[labelset]
             
             if boundInstrument == nil {
                 let status = isShortLived ? RecordStatus.updatePending : RecordStatus.bound
                 boundInstrument = createMetric(recordStatus: status)
                 boundInstruments[labelset] = boundInstrument
             }
         }
         
         boundInstrument!.statusLock.withLockVoid {
             switch boundInstrument!.status {
             case .noPendingUpdate:
                 boundInstrument!.status = .updatePending
                 break;
             case .candidateForRemoval:
                 bindUnbindLock.withLockVoid {
                     boundInstrument!.status = .updatePending
                     if boundInstruments[labelset] == nil {
                         boundInstruments[labelset] = boundInstrument!
                     }
                 }
                 break;
             case .bound, .updatePending:
                 break;
             }
         }
         return boundInstrument!
     }
    
    
    internal func unBind(labelSet: LabelSet) {
        bindUnbindLock.withLockVoid {
            if let boundInstrument = boundInstruments[labelSet] {
                boundInstrument.statusLock.withLockVoid {
                    if boundInstrument.status == .candidateForRemoval {
                        boundInstruments[labelSet] = nil
                    }
                }
            }
        }
    }

    func createMetric(recordStatus: RecordStatus) -> BoundRawHistogramMetricSdkBase<T> {
        //noop
        fatalError()
    }
    
}
