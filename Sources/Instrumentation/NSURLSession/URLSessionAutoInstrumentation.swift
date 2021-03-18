/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

/// `URLSession` Auto Instrumentation feature.
internal class URLSessionAutoInstrumentation {
    static var instance: URLSessionAutoInstrumentation?
    public private(set) var tracer : TracerSdk

    let swizzler: URLSessionSwizzler
    let interceptor: URLSessionInterceptor

    init?(
//        configuration: FeaturesConfiguration.URLSessionAutoInstrumentation,
        dateProvider: DateProvider
    ) {
        do {
            tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "NSURLSession") as! TracerSdk
            self.interceptor = URLSessionInterceptor(
                    tracer: tracer
            )
            self.swizzler = try URLSessionSwizzler()
        } catch {
            print("🔥 SDK error: automatic tracking of `URLSession` requests can't be set up due to error: \(error)"
            )
            return nil
        }
    }

    func enable() {
        swizzler.swizzle()
    }
}
