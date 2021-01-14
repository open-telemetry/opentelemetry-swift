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

/// An immutable implementation of the Baggage that does not contain any entries.
public class EmptyBaggage: Baggage {
    private init() {}

    /// Returns the single instance of the EmptyBaggage class.
    public static var instance = EmptyBaggage()

    public static func baggageBuilder() -> BaggageBuilder {
        return EmptyBaggageBuilder()
    }

    public func getEntries() -> [Entry] {
        return [Entry]()
    }

    public func getEntryValue(key: EntryKey) -> EntryValue? {
        return nil
    }
}
