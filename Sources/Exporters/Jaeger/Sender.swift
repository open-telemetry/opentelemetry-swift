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
import Network
import Thrift

public class Sender {
    private let host: String
    private let port = 6832

    lazy var address: sockaddr_storage? = {
        guard let addresses = try? addressesFor(host: host, port: port) else {
            return nil
        }
        return addresses[0]
    }()

    public init(host: String) {
        self.host = host
    }

    final func sendBatch(batch: Batch) -> Bool {
        let transport = TMemoryBufferTransport()
        let proto = TBinaryProtocol(on: transport)
        let agent = AgentClient(inoutProtocol: proto)
        var batches = TList<Batch>()
        batches.append(batch)
        do {
            try agent.emitBatch(batch: batch)
        } catch {
            return false
        }

        guard let address = self.address else {
            return false
        }

        let fd = socket(Int32(address.ss_family), SOCK_DGRAM, 0)
        guard fd >= 0 else {
            return false
        }
        defer {
            close(fd)
        }

        let sendResult = transport.writeBuffer.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) -> Int in
            address.withSockAddr { (sa, saLen) -> Int in
                sendto(fd, rawBufferPointer.baseAddress, transport.writeBuffer.count, 0, sa, saLen)
            }
        }

        return sendResult >= 0
    }
}
