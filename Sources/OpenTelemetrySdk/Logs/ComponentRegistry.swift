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
    private var componentByNameVersionSchema = [ String: [String : [String: T]]]()
    private var allComponents = [T]()
    
    private let builder : (InstrumentationScopeInfo) -> T
    
    init(_ builder : @escaping (InstrumentationScopeInfo) -> T){
        self.builder = builder
    }
    
    public func get(name: String, version: String?, schemaUrl : String?) -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        if let version = version, let schemaUrl = schemaUrl {
            return componentByNameVersionSchema[name, default: [String: [String: T]]()][version, default: [String:T]()][schemaUrl, default: buildComponent(InstrumentationScopeInfo(name: name, version:version, schemaUrl: schemaUrl))]
        } else if let version = version {
            return componentByNameVersion[name, default: [String: T]()][version, default: buildComponent(InstrumentationScopeInfo(name:name, version:version))]
        } else if let schemaUrl = schemaUrl {
            return componentByNameSchema[name, default: [String:T]()][schemaUrl, default: buildComponent(InstrumentationScopeInfo(name: name, version: nil, schemaUrl: schemaUrl))]
        } else {
            return componentByName[name, default: buildComponent(InstrumentationScopeInfo(name:name))]
        }
    }
    
    private func buildComponent(_ scope: InstrumentationScopeInfo) -> T {
        let component = builder(scope)
        allComponents.append(component)
        return component
    }
    
    public func getComponents() -> [T] {
        return [T](allComponents)
    }
}
