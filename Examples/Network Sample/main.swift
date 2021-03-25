// Copyright 2021, OpenTelemetry Authors
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
//

import Foundation
import OpenTelemetrySdk
import StdoutExporter
import URLSessionInstrumentation


func simpleNetworkCall() {
    let url = URL(string: "http://httpbin.org/get")!
    let request = URLRequest(url: url)
    let semaphore = DispatchSemaphore(value: 0)

    let task = URLSession.shared.dataTask(with: request) { data, _, _ in
        if let data = data {
            let string = String(data: data, encoding: .utf8)
            print(string ?? "")
        }
        semaphore.signal()
    }
    task.resume()

    semaphore.wait()
}

let spanProcessor = SimpleSpanProcessor(spanExporter: StdoutExporter(isDebug: true))
OpenTelemetrySDK.instance.tracerProvider.addSpanProcessor(spanProcessor)

let networkInstrumentation = URLSessionInstrumentation(configuration: URLSessionConfiguration())

simpleNetworkCall()
sleep(1)
