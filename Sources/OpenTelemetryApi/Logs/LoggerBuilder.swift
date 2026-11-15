/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LoggerBuilder {
  /// Set the event domain of the resulting Logger.
  /// NOTE: Event domain is required to use `Logger.eventBuilder(name: String) -> EventBuilder
  /// The event domain will be included in the event.domain attribute for every event produced
  ///  by the resulting Logger.
  /// - Parameter eventDomain: The event domain, which acts as a namespace for event names.
  ///                          Within a particular event domain, event name defines a particular
  ///                          class or type of event.
  /// - Returns: self
  @available(*, deprecated, message: "Event domain is deprecated. Use event_name field directly.")
  func setEventDomain(_ eventDomain: String) -> Self

  /// Assign an OpenTelemetry schema URL to the resulting Logger
  ///
  /// - Parameter schemaUrl: the URL of the OpenTelemetry schema being used by this instrumentation scope
  /// - Returns: self
  func setSchemaUrl(_ schemaUrl: String) -> Self

  /// Assign a version to the instrumentation scope that is used in the resulting Logger.
  ///
  /// - Parameter instrumentationVersion: the version of the instrumentation scope.
  /// - Returns: self
  func setInstrumentationVersion(_ instrumentationVersion: String) -> Self

  /// Specifies whether the trace context should automatically be passed on to the events and logs emitted by the Logger.
  ///
  /// - Parameter includeTraceContext: whether the trace context should be automatically passed.
  /// - Returns: self
  func setIncludeTraceContext(_ includeTraceContext: Bool) -> Self

  /// Specifies the instrumentation scope attributes to associate with emitted telemetry.
  ///
  /// - Parameter attributes: the attributes that will be assigned to all events and logs emitted by the Logger.
  /// - Returns: self
  func setAttributes(_ attributes: [String: AttributeValue]) -> Self

  func build() -> Logger
}
