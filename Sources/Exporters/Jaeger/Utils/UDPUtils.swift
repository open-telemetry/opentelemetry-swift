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

/// This code was adapted from Quinn “The Eskimo!” sample code at https://forums.developer.apple.com/thread/99494
/// It uses BSD socket to send UDP Packages
/// Using Network framework would be easier and clearer but only supported from 10.14+.

func addressesFor(host: String, port: Int) throws -> [sockaddr_storage] {
    var hints = addrinfo()
    hints.ai_socktype = SOCK_DGRAM
    var addrList: UnsafeMutablePointer<addrinfo>?
    let err = getaddrinfo(host, "\(port)", &hints, &addrList)
    guard err == 0, let start = addrList else {
        throw NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost, userInfo: nil)
    }
    defer { free(addrList) }
    return sequence(first: start, next: { $0.pointee.ai_next }).map { (addr) -> sockaddr_storage in
        sockaddr_storage(sa: addr.pointee.ai_addr, saLen: addr.pointee.ai_addrlen)
    }
}

extension sockaddr_storage {
    // not actually in Socket API Helper, but an 'obvious' extension

    init(sa: UnsafeMutablePointer<sockaddr>, saLen: socklen_t) {
        var ss = sockaddr_storage()
        withUnsafeMutableBytes(of: &ss) { ssPtr -> Void in
            let addrBuf = UnsafeRawBufferPointer(start: sa, count: Int(saLen))
            assert(addrBuf.count <= MemoryLayout<sockaddr_storage>.size)
            ssPtr.copyMemory(from: addrBuf)
        }
        self = ss
    }

    // from Socket API Helper

    static func fromSockAddr<ReturnType>(_ body: (_ sa: UnsafeMutablePointer<sockaddr>, _ saLen: inout socklen_t) throws -> ReturnType) rethrows -> (ReturnType, sockaddr_storage) {
        // We need a mutable `sockaddr_storage` so that we can pass it to `withUnsafePointer(to:_:)`.
        var ss = sockaddr_storage()
        // Similarly, we need a mutable copy of our length for the benefit of `saLen`.
        var saLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let result = try withUnsafeMutablePointer(to: &ss) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try body($0, &saLen)
            }
        }
        return (result, ss)
    }

    // from Socket API Helper

    func withSockAddr<ReturnType>(_ body: (_ sa: UnsafePointer<sockaddr>, _ saLen: socklen_t) throws -> ReturnType) rethrows -> ReturnType {
        // We need to create a mutable copy of `self` so that we can pass it to `withUnsafePointer(to:_:)`.
        var ss = self
        return try withUnsafePointer(to: &ss) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try body($0, socklen_t(self.ss_len))
            }
        }
    }
}
