// Copyright © 2022 Elasticsearch BV
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

import Foundation

public protocol RawCounterMetric {
    associatedtype T
    
    func record(sum: T, startDate : Date, endDate: Date)
}


public struct AnyRawCounterMetric<T> :RawCounterMetric {
    let internalCounter : Any
    private let _record: (T, Date, Date) -> Void
    public func record(sum: T, startDate: Date, endDate: Date) {
        _record(sum, startDate, endDate)
    }
    
    public init<U: RawCounterMetric>(_ countable: U) where U.T == T {
            internalCounter = countable
        _record = countable.record(sum:startDate:endDate:)
    }
    
}

public struct NoopRawCounterMetric<T> : RawCounterMetric {
    public func record(sum: T, startDate: Date, endDate: Date) {
        
    }
}
