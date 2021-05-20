/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class DefaultTracerProvider: TracerProvider {
    public static let instance = DefaultTracerProvider()

    public func get(instrumentationName: String, instrumentationVersion: String? = nil) -> Tracer {
        return DefaultTracer.instance
    }
}
