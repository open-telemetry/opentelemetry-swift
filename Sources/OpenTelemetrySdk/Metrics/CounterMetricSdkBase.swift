// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import OpenTelemetryApi

class CounterMetricSdkBase<T>: CounterMetric {
    private let bindUnbindLock = Lock()
    public private(set) var boundInstruments = [LabelSet: BoundCounterMetricSdkBase<T>]()
    let metricName: String

    init(name: String) {
        metricName = name
    }

    func add(value: T, labelset: LabelSet) {
        fatalError()
    }

    func add(value: T, labels: [String: String]) {
        fatalError()
    }

    func bind(labelset: LabelSet) -> BoundCounterMetric<T> {
        return bind(labelset: labelset, isShortLived: false)
    }

    func bind(labels: [String: String]) -> BoundCounterMetric<T> {
        return bind(labelset: LabelSet(labels: labels), isShortLived: false)
    }

    internal func bind(labelset: LabelSet, isShortLived: Bool) -> BoundCounterMetric<T> {
        var boundInstrument: BoundCounterMetricSdkBase<T>?
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
                break
            case .candidateForRemoval:
                bindUnbindLock.withLockVoid {
                    boundInstrument!.status = .updatePending

                    if boundInstruments[labelset] == nil {
                        boundInstruments[labelset] = boundInstrument!
                    }
                }
            case .bound, .updatePending:
                break
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

    func createMetric(recordStatus: RecordStatus) -> BoundCounterMetricSdkBase<T> {
        fatalError()
    }
}
