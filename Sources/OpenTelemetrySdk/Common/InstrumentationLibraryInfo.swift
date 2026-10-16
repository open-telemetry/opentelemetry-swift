/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Holds information about the instrumentation library specified when creating an instance of
/// TracerSdk using TracerProviderSdk.
public struct InstrumentationScopeInfo: Hashable, Codable, Equatable, Sendable {
  public private(set) var name: String = ""
  public private(set) var version: String?
  public private(set) var schemaUrl: String?
  public private(set) var attributes: [String: AttributeValue]?

  ///  Creates a new empty instance of InstrumentationScopeInfo.
  public init() {}

  ///  Creates a new instance of InstrumentationScopeInfo.
  ///  - Parameters:
  ///    - name: name of the instrumentation library
  ///    - version: version of the instrumentation library (e.g., "semver:1.0.0"), might be nil
  public init(name: String, version: String? = nil, schemaUrl: String? = nil, attributes: [String: AttributeValue]? = nil) {
    self.name = name
    self.version = version
    self.schemaUrl = schemaUrl
    self.attributes = attributes
  }
}
