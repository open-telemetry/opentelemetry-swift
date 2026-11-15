//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

class ComponentRegistry<T> {
  private var lock = Lock()
  private var componentByName = [String: T]()
  private var componentByNameVersion = [String: [String: T]]()
  private var componentByNameSchema = [String: [String: T]]()
  private var componentByNameVersionSchema = [String: [String: [String: T]]]()
  private let allComponents = ReadWriteLocked<[T]>(initialValue: [])

  private let builder: (InstrumentationScopeInfo) -> T

  init(_ builder: @escaping (InstrumentationScopeInfo) -> T) {
    self.builder = builder
  }

  public func get(name: String, version: String? = nil, schemaUrl: String? = nil, attributes: [String: AttributeValue]? = nil) -> T {
    lock.lock()
    defer {
      lock.unlock()
    }
    if let version, let schemaUrl {
      if componentByNameVersionSchema[name] == nil {
        componentByNameVersionSchema[name] = [String: [String: T]]()
      }

      if componentByNameVersionSchema[name]![version] == nil {
        componentByNameVersionSchema[name]![version] = [String: T]()
      }

      if componentByNameVersionSchema[name]![version]![schemaUrl] == nil {
        componentByNameVersionSchema[name]![version]![schemaUrl] = buildComponent(InstrumentationScopeInfo(name: name, version: version, schemaUrl: schemaUrl, attributes: attributes))
      }
      return componentByNameVersionSchema[name]![version]![schemaUrl]!
    } else if let version {
      if componentByNameVersion[name] == nil {
        componentByNameVersion[name] = [String: T]()
      }

      if componentByNameVersion[name]![version] == nil {
        componentByNameVersion[name]![version] = buildComponent(
          InstrumentationScopeInfo(
            name: name,
            version: version,
            attributes: attributes
          )
        )
      }

      return componentByNameVersion[name]![version]!

    } else if let schemaUrl {
      if componentByNameSchema[name] == nil {
        componentByNameSchema[name] = [String: T]()
      }

      if componentByNameSchema[name]![schemaUrl] == nil {
        componentByNameSchema[name]![schemaUrl] = buildComponent(
          InstrumentationScopeInfo(
            name: name,
            schemaUrl: schemaUrl,
            attributes: attributes
          )
        )
      }

      return componentByNameSchema[name]![schemaUrl]!

    } else {
      if componentByName[name] == nil {
        componentByName[name] = buildComponent(
          InstrumentationScopeInfo(name: name, attributes: attributes)
        )
      }
      return componentByName[name]!
    }
  }

  private func buildComponent(_ scope: InstrumentationScopeInfo) -> T {
    let component = builder(scope)
    allComponents.writeLocking {
      $0.append(component)
    }
    return component
  }

  public func getComponents() -> [T] {
    return [T](allComponents.protectedValue)
  }
}
