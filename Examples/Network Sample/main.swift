/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter
import URLSessionInstrumentation


func simpleNetworkCall() {
    let url = URL(string: "http://httpbin.org/get")!
    let request = URLRequest(url: url)
    let semaphore = DispatchSemaphore(value: 0)

    let task = URLSession.shared.dataTask(with: request) { data, _, _ in
        if let data = data {
            let string = String(decoding: data, as: UTF8.self)
            print(string)
        }
        semaphore.signal()
    }
    task.resume()

    semaphore.wait()
}


class SessionDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    let semaphore = DispatchSemaphore(value: 0)

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        semaphore.signal()
    }
}
let delegate = SessionDelegate()

func simpleNetworkCallWithDelegate() {

    let session = URLSession(configuration: .default, delegate: delegate, delegateQueue:nil)

    let url = URL(string: "http://httpbin.org/get")!
    let request = URLRequest(url: url)

    let task = session.dataTask(with: request)
    task.resume()

    delegate.semaphore.wait()
}


let spanProcessor = SimpleSpanProcessor(spanExporter: StdoutExporter(isDebug: true))
OpenTelemetry.registerTracerProvider(tracerProvider:
    TracerProviderBuilder()
        .add(spanProcessor: spanProcessor)
        .build()
)

let networkInstrumentation = URLSessionInstrumentation(configuration: URLSessionInstrumentationConfiguration())

simpleNetworkCall()
simpleNetworkCallWithDelegate()
sleep(1)
