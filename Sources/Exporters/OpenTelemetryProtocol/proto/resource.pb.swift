// DO NOT EDIT.
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: opentelemetry/proto/resource/v1/resource.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

// Copyright 2019, OpenTelemetry Authors
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

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that your are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

/// Resource information.
public struct Opentelemetry_Proto_Resource_V1_Resource {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// Set of labels that describe the resource.
  public var attributes: [Opentelemetry_Proto_Common_V1_KeyValue] = []

  /// dropped_attributes_count is the number of dropped attributes. If the value is 0, then
  /// no attributes were dropped.
  public var droppedAttributesCount: UInt32 = 0

  public var unknownFields = SwiftProtobuf.UnknownStorage()

  public init() {}
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "opentelemetry.proto.resource.v1"

extension Opentelemetry_Proto_Resource_V1_Resource: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".Resource"
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "attributes"),
    2: .standard(proto: "dropped_attributes_count"),
  ]

  public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      switch fieldNumber {
      case 1: try decoder.decodeRepeatedMessageField(value: &self.attributes)
      case 2: try decoder.decodeSingularUInt32Field(value: &self.droppedAttributesCount)
      default: break
      }
    }
  }

  public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.attributes.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.attributes, fieldNumber: 1)
    }
    if self.droppedAttributesCount != 0 {
      try visitor.visitSingularUInt32Field(value: self.droppedAttributesCount, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: Opentelemetry_Proto_Resource_V1_Resource, rhs: Opentelemetry_Proto_Resource_V1_Resource) -> Bool {
    if lhs.attributes != rhs.attributes {return false}
    if lhs.droppedAttributesCount != rhs.droppedAttributesCount {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
