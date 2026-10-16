/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import OpenTelemetryApi

// The lock implementations moved to OpenTelemetryApi (see
// `OpenTelemetryApi/Internal/Locks.swift`). `Locked` and `ReadWriteLocked`
// were previously public symbols of this module, so these aliases keep
// consumers that reach them through `import OpenTelemetrySdk` alone
// source-compatible. They are the only two symbols that moved; a blanket
// `@_exported import OpenTelemetryApi` is not an option because it would
// surface the API's `OpenTelemetry` type through the SDK and create
// ambiguity for consumers of OpenTelemetryConcurrency, whose design
// deliberately shadows that type.
public typealias Locked<Value> = OpenTelemetryApi.Locked<Value>
public typealias ReadWriteLocked<Value> = OpenTelemetryApi.ReadWriteLocked<Value>
