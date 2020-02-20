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

/// EntryTtl is an an that represents number of hops an entry can propagate.
/// Anytime a sender serializes a entry, sends it over the wire and receiver deserializes the
/// entry then the entry is considered to have travelled one hop.
/// There could be one or more proxy(ies) between sender and receiver. Proxies are treated as
/// transparent entities and they are not counted as hops.
/// For now, only special values of EntryTtl are supported.
public enum EntryTtl: Equatable {
    /// An Entry with .noPropagation is considered to have local scope and
    /// is used within the process where it's created.
    case noPropagation

    /// NUmber of times a sender serializes an entry, sends it over the wireand receiver
    /// deserializes the entry
    case hops(Int)

    /// An Entry with .unlimitedPropagation can propagate unlimited hops.
    /// However, it is still subject to outgoing and incoming (on remote side) filter criteria.
    /// .unlimitedPropagation is typical used to track a request, which may be
    /// processed across multiple entities.
    case unlimitedPropagation
}

public struct EntryMetadata: Equatable {
    var entryTtl: EntryTtl

    public init(entryTtl: EntryTtl) {
        self.entryTtl = entryTtl
    }
}
