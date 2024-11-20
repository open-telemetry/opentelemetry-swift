/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class DefaultBaggageBuilder: BaggageBuilder {
    var parent: Baggage?
    var noImplicitParent: Bool = false
    var entries = [EntryKey: Entry?]()
    
    public init() {}
    
    @discardableResult public func setParent(_ parent: Baggage?) -> Self {
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
            parentCopy = OpenTelemetry.instance.contextProvider.activeBaggage
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
