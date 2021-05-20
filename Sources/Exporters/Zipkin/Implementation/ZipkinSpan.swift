/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct ZipkinSpan: Encodable {
    var traceId: String
    var parentId: String?
    var id: String
    var kind: String?
    var name: String
    var timestamp: UInt64?
    var duration: UInt64?
    var localEndpoint: ZipkinEndpoint?
    var remoteEndpoint: ZipkinEndpoint?
    var annotations: [ZipkinAnnotation]
    var tags: [String: String]
    var debug: Bool?
    var shared: Bool?

    init(traceId: String, parentId: String?, id: String, kind: String?, name: String, timestamp: UInt64?, duration: UInt64?, localEndpoint: ZipkinEndpoint, remoteEndpoint: ZipkinEndpoint?, annotations: [ZipkinAnnotation], tags: [String: String], debug: Bool?, shared: Bool?) {

        self.traceId = traceId
        self.parentId = parentId
        self.id = id
        self.kind = kind
        self.name = name
        self.timestamp = timestamp
        self.duration = duration
        self.localEndpoint = localEndpoint
        self.remoteEndpoint = remoteEndpoint
        self.annotations = annotations
        self.tags = tags
        self.debug = debug
        self.shared = shared
    }

    public func write() -> [String: Any] {
        var output = [String: Any]()

        output["traceId"] = traceId
        output["name"] = name
        output["parentId"] = parentId
        output["id"] = id
        output["kind"] = kind
        output["timestamp"] = timestamp
        output["duration"] = duration
        output["debug"] = debug
        output["shared"] = shared

        if localEndpoint != nil {
            output["localEndpoint"] = localEndpoint!.write()
        }

        if remoteEndpoint != nil {
            output["localEndpoint"] = remoteEndpoint!.write()
        }

        if annotations.count > 0 {
            let annotationsArray: [Any] = annotations.map {
                var object = [String: Any]()
                object["timestamp"] = $0.timestamp
                object["value"] = $0.value
                return object
            }

            output["annotations"] = annotationsArray
        }

        if tags.count > 0 {
            output["tags"] = tags
        }

        return output
    }
}
