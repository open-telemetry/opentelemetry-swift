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

public class DefaultBaggageBuilder: BaggageBuilder {
    var parent: Baggage?
    var noImplicitParent: Bool = false
    var entries = [EntryKey: Entry?]()
    
    public init() {}
    
    @discardableResult public func setParent(_ parent: Baggage) -> Self {
        self.parent = parent
        return self
    }
    
    @discardableResult public func setNoParent() -> Self {
        parent = nil
        noImplicitParent = true
        return self
    }
    
    @discardableResult public func put(key: EntryKey, value: EntryValue, metadata: EntryMetadata?) -> Self {
        let entry = Entry(key: key, value: value, metadata: metadata)
        entries[key] = entry
        return self
    }
    
    @discardableResult public func put(key: String, value: String, metadata: String? = nil) -> Self {
        guard let entryKey = EntryKey(name: key),
              let entryValue = EntryValue(string: value) else {
            return self
        }
        let entry = Entry(key: entryKey, value: entryValue, metadata: EntryMetadata(metadata: metadata))
        entries[entryKey] = entry
        return self
    }
    
    @discardableResult public func remove(key: EntryKey) -> Self {
        entries[key] = nil
        if parent?.getEntryValue(key: key) != nil {
            entries.updateValue(nil, forKey: key)
        }
        return self
    }
    
    public func build() -> Baggage {
        var parentCopy = parent
        if parent == nil, !noImplicitParent {
            parentCopy = OpenTelemetry.instance.baggageManager.getCurrentBaggage()
        }
        
        var combined = entries
        if let parent = parentCopy {
            for entry in parent.getEntries() {
                if combined[entry.key] == nil {
                    combined[entry.key] = entry
                }
            }
        }
        return entries.isEmpty ? EmptyBaggage.instance : DefaultBaggage(entries: combined)
    }
}
