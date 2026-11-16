/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/**
 * Implementation of a EnvironmentContextPropagation propagation, using W3CTraceContextPropagator
 */
@available(*, deprecated, message: "Use EnvironmentMappingSetter or EnvironmentMappingGetter instead.")
public struct EnvironmentContextPropagator: TextMapPropagator {
  static let traceParent = "TRACEPARENT"
  static let traceState = "TRACESTATE"
  let w3cPropagator = W3CTraceContextPropagator()

  public let fields: Set<String> = [traceState, traceParent]

  public init() {}

  public func inject(spanContext: SpanContext, carrier: inout [String: String], setter: some Setter) {
    var auxCarrier = [String: String]()
    w3cPropagator.inject(spanContext: spanContext, carrier: &auxCarrier, setter: setter)
    carrier[EnvironmentContextPropagator.traceParent] = auxCarrier["traceparent"]
    carrier[EnvironmentContextPropagator.traceState] = auxCarrier["tracestate"]
  }

  public func extract(carrier: [String: String], getter: some Getter) -> SpanContext? {
    var auxCarrier = [String: String]()
    auxCarrier["traceparent"] = carrier[EnvironmentContextPropagator.traceParent]
    auxCarrier["tracestate"] = carrier[EnvironmentContextPropagator.traceState]
    return w3cPropagator.extract(carrier: auxCarrier, getter: getter)
  }
}

/**
 * EnvironmentMappingSetter adapts a `Setter` to normalize propagation keys to environment variable format.
 *
 * Normalization rules per OpenTelemetry specification:
 * - Replaces an empty key name with a single underscore (`_`)
 * - Converts keys to uppercase (e.g., "traceparent" → "TRACEPARENT")
 * - Replaces all non-alphanumeric characters (except underscore) with underscores
 *   (e.g., "x-b3-traceid" → "X_B3_TRACEID")
 *
 * Usage:
 * ```swift
 * let innerSetter = MyCustomSetter()
 * let envSetter = EnvironmentMappingSetter(innerSetter: innerSetter)
 * w3cPropagator.inject(spanContext: context, carrier: &carrier, setter: envSetter)
 * ```
 *
 * See: https://opentelemetry.io/docs/specs/otel/context/env-carriers/
 */
public struct EnvironmentMappingSetter: Setter {
  let innerSetter: any Setter

  public init(innerSetter: any Setter) {
    self.innerSetter = innerSetter
  }

  public func set(carrier: inout [String: String], key: String, value: String) {
    let mappedKey = normalizeKeyForEnvironment(key)
    innerSetter.set(carrier: &carrier, key: mappedKey, value: value)
  }
}

/**
 * EnvironmentMappingGetter adapts a `Getter` to normalize propagation keys to environment variable format.
 *
 * Per the OpenTelemetry specification, it normalizes **only the requested key** and performs a
 * direct lookup in the carrier using that normalized name. Non-normalized carrier keys
 * (e.g. `"traceparent"` instead of `"TRACEPARENT"`) are silently ignored.
 *
 * Normalization rules:
 * - Replaces an empty key name with a single underscore (`_`)
 * - Converts the requested key to uppercase (e.g., `"traceparent"` → `"TRACEPARENT"`)
 * - Replaces every character that is not an ASCII letter, digit, or underscore with `_`
 *   (e.g., `"x-b3-traceid"` → `"X_B3_TRACEID"`)
 * - Prefixes the result with `_` if it would otherwise start with an ASCII digit
 *
 * Usage:
 * ```swift
 * let innerGetter = CapturingGetter()
 * let envGetter = EnvironmentMappingGetter(innerGetter: innerGetter)
 * let spanContext = w3cPropagator.extract(carrier: ProcessInfo.processInfo.environment, getter: envGetter)
 * ```
 *
 * See: https://opentelemetry.io/docs/specs/otel/context/env-carriers/
 */
public struct EnvironmentMappingGetter: Getter {
  let innerGetter: any Getter

  public init(innerGetter: any Getter) {
    self.innerGetter = innerGetter
  }

  public func get(carrier: [String: String], key: String) -> [String]? {
    let mappedKey = normalizeKeyForEnvironment(key)
    return innerGetter.get(carrier: carrier, key: mappedKey)
  }
}

/// Normalizes a key to environment-variable format:
/// - Replaces an empty key name with a single underscore (`_`)
/// - Uppercases ASCII letters (`a–z` → `A–Z`)
/// - Replaces every character that is not an ASCII letter, digit, or underscore with `_`
/// - Prefixes the result with `_` if it would otherwise start with an ASCII digit
private func normalizeKeyForEnvironment(_ key: String) -> String {
  if key.isEmpty {
    return "_"
  }

  var result = ""
  result.reserveCapacity(key.utf8.count + 1)
  // An env-var name must not start with a digit
  if let first = key.unicodeScalars.first, (48...57).contains(first.value) {
    result.append("_")
  }
  for scalar in key.unicodeScalars {
    let v = scalar.value
    switch v {
    case 65...90:           // A–Z: keep as-is
      result.append(Character(scalar))
    case 97...122:          // a–z: uppercase in-place
      result.append(Character(UnicodeScalar(v - 32)!))
    case 48...57, 95:       // 0–9 or _: keep as-is
      result.append(Character(scalar))
    default:                // anything else: _
      result.append("_")
    }
  }
  return result
}
