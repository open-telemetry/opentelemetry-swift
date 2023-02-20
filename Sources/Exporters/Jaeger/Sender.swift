/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !os(watchOS)

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

#endif
