// Copyright 2020, OpenTelemetry Authors
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
import OpenTelemetryApi
import OpenTelemetrySdk

struct NetworkRequestState {
    var request: URLRequest?
    var dataProcessed: Data?
}

private var idKey: Void?

public class URLSessionInstrumentation {
    private var requestMap = [String: NetworkRequestState]()

    var configuration: URLSessionConfiguration

    private let queue = DispatchQueue(label: "com.datadoghq.ddnetworkinstrumentation")

    static var instrumentedKey = "com.datadoghq.instrumentedCall"

    public private(set) var tracer: TracerSdk

    public var startedRequestSpans: [Span] {
        var spans = [Span]()
        queue.sync {
            spans = Array(URLSessionLogger.runningSpans.values)
        }
        return spans
    }

    public init(configuration: URLSessionConfiguration) {
        self.configuration = configuration
        tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "NSURLSession", instrumentationVersion: "0.0.1") as! TracerSdk
        self.injectInNSURLClasses()
    }

    private func injectInNSURLClasses() {
        let selectors = [
            #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:)),
            #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:)),
            #selector(URLSessionDataDelegate.urlSession(_:task:didCompleteWithError:)),
            #selector(URLSessionDataDelegate.urlSession(_:dataTask:didBecome:)! as (URLSessionDataDelegate) -> (URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void),
            #selector(URLSessionDataDelegate.urlSession(_:dataTask:didBecome:)! as (URLSessionDataDelegate) -> (URLSession, URLSessionDataTask, URLSessionStreamTask) -> Void)
        ]

        let classes = InstrumentationUtils.objc_getClassList()
        classes.forEach {
            guard $0 != Self.self else { return }
            var selectorFound = false
            var methodCount: UInt32 = 0
            guard let methodList = class_copyMethodList($0, &methodCount) else { return }

            for i in 0..<Int(methodCount) {
                for j in 0..<selectors.count {
                    if method_getName(methodList[i]) == selectors[j] {
                        selectorFound = true
                        injectIntoDelegateClass(cls: $0)
                        break
                    }
                }
                if selectorFound {
                    break
                }
            }
        }
        injectIntoNSURLSessionCreateTaskMethods()
        injectIntoNSURLSessionCreateTaskWithParameterMethods()
        injectIntoNSURLSessionAsyncDataAndDownloadTaskMethods()
        injectIntoNSURLSessionAsyncUploadTaskMethods()
    }

    private func injectIntoDelegateClass(cls: AnyClass) {
        // Sessions
        injectTaskDidReceiveDataIntoDelegateClass(cls: cls)
        injectTaskDidReceiveResponseIntoDelegateClass(cls: cls)
        injectTaskDidCompleteWithErrorIntoDelegateClass(cls: cls)
        injectRespondsToSelectorIntoDelegateClass(cls: cls)

        // Data tasks
        injectDataTaskDidBecomeDownloadTaskIntoDelegateClass(cls: cls)
    }

    private func injectIntoNSURLSessionCreateTaskMethods() {
        let cls = URLSession.self
        [
            #selector(URLSession.dataTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDataTask),
            #selector(URLSession.dataTask(with:) as (URLSession) -> (URL) -> URLSessionDataTask),
            #selector(URLSession.uploadTask(withStreamedRequest:)),
            #selector(URLSession.downloadTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDownloadTask),
            #selector(URLSession.downloadTask(with:) as (URLSession) -> (URL) -> URLSessionDownloadTask),
            #selector(URLSession.downloadTask(withResumeData:))
        ].forEach {
            let selector = $0
            guard let original = class_getInstanceMethod(cls, selector) else {
                print("injectInto \(selector.description) failed")
                return
            }
            var originalIMP: IMP?
            let sessionTaskId = UUID().uuidString

            let block: @convention(block) (URLSession, AnyObject) -> URLSessionTask = { session, argument in
                if let url = argument as? URL {
                    var request = URLRequest(url: url)
                    if self.configuration.shouldInjectTracingHeaders?(&request) ?? true {
                        if selector == #selector(URLSession.dataTask(with:) as (URLSession) -> (URL) -> URLSessionDataTask) {
                            return session.dataTask(with: request)
                        } else {
                            return session.downloadTask(with: request)
                        }
                    }
                }

                let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (URLSession, Selector, Any) -> URLSessionDataTask).self)
                var task: URLSessionTask

                if let request = argument as? URLRequest, objc_getAssociatedObject(argument, &idKey) == nil {
                    let instrumentedRequest = URLSessionLogger.processAndLogRequest(request, sessionTaskId: sessionTaskId, instrumentation: self, shouldInjectHeaders: true)
                    task = castedIMP(session, selector, instrumentedRequest ?? request)
                } else {
                    task = castedIMP(session, selector, argument)
                    if objc_getAssociatedObject(argument, &idKey) == nil, let currentRequest = task.currentRequest
                    {
                        URLSessionLogger.processAndLogRequest(currentRequest, sessionTaskId: sessionTaskId, instrumentation: self, shouldInjectHeaders: false)
                    }
                }
                self.setIdKey(value: sessionTaskId, for: task)
                return task
            }
            let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
            originalIMP = method_setImplementation(original, swizzledIMP)
        }
    }

    private func injectIntoNSURLSessionCreateTaskWithParameterMethods() {
        let cls = URLSession.self
        [
            #selector(URLSession.uploadTask(with:from:)),
            #selector(URLSession.uploadTask(with:fromFile:))
        ].forEach {
            let selector = $0
            guard let original = class_getInstanceMethod(cls, selector) else {
                print("injectInto \(selector.description) failed")
                return
            }
            var originalIMP: IMP?
            let sessionTaskId = UUID().uuidString

            let block: @convention(block) (URLSession, URLRequest, AnyObject) -> URLSessionTask = { session, request, argument in
                let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (URLSession, Selector, URLRequest, AnyObject) -> URLSessionDataTask).self)
                let instrumentedRequest = URLSessionLogger.processAndLogRequest(request, sessionTaskId: sessionTaskId, instrumentation: self, shouldInjectHeaders: true)
                let task = castedIMP(session, selector, instrumentedRequest ?? request, argument)
                self.setIdKey(value: sessionTaskId, for: task)
                return task
            }
            let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
            originalIMP = method_setImplementation(original, swizzledIMP)
        }
    }

    private func injectIntoNSURLSessionAsyncDataAndDownloadTaskMethods() {
        let cls = URLSession.self
        [
            #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask),
            #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URL, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask),
            #selector(URLSession.downloadTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask),
            #selector(URLSession.downloadTask(with:completionHandler:) as (URLSession) -> (URL, @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask),
            #selector(URLSession.downloadTask(withResumeData:completionHandler:))
        ].forEach {
            let selector = $0
            guard let original = class_getInstanceMethod(cls, selector) else {
                print("injectInto \(selector.description) failed")
                return
            }
            var originalIMP: IMP?
            let sessionTaskId = UUID().uuidString

            let block: @convention(block) (URLSession, AnyObject, ((Any?, URLResponse?, Error?) -> Void)?) -> URLSessionTask = { session, argument, completion in

                if let url = argument as? URL {
                    var request = URLRequest(url: url)

                    if self.configuration.shouldInjectTracingHeaders?(&request) ?? true {
                        if selector == #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URL, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask) {
                            if let completion = completion {
                                return session.dataTask(with: request, completionHandler: completion)
                            } else {
                                return session.dataTask(with: request)
                            }
                        } else {
                            if let completion = completion {
                                return session.downloadTask(with: request, completionHandler: completion)
                            } else {
                                return session.downloadTask(with: request)
                            }
                        }
                    }
                }

                let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (URLSession, Selector, Any, ((Any?, URLResponse?, Error?) -> Void)?) -> URLSessionDataTask).self)
                var task: URLSessionTask!

                var completionBlock = completion
                if objc_getAssociatedObject(argument, &idKey) == nil {
                    let completionWrapper: (Any?, URLResponse?, Error?) -> Void = { object, response, error in
                        if error != nil {
                            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                            URLSessionLogger.logError(error!, dataOrFile: object, statusCode: status, instrumentation: self, sessionTaskId: sessionTaskId)
                        } else {
                            if let response = response {
                                URLSessionLogger.logResponse(response, dataOrFile: object, instrumentation: self, sessionTaskId: sessionTaskId)
                            }
                        }
                        if let completion = completion {
                            completion(object, response, error)
                        } else {
                            (session.delegate as? URLSessionTaskDelegate)?.urlSession?(session, task: task, didCompleteWithError: error)
                        }
                    }
                    completionBlock = completionWrapper
                }

                if let request = argument as? URLRequest, objc_getAssociatedObject(argument, &idKey) == nil {
                    let instrumentedRequest = URLSessionLogger.processAndLogRequest(request, sessionTaskId: sessionTaskId, instrumentation: self, shouldInjectHeaders: true)
                    task = castedIMP(session, selector, instrumentedRequest ?? request, completionBlock)
                } else {
                    task = castedIMP(session, selector, argument, completionBlock)
                    if objc_getAssociatedObject(argument, &idKey) == nil,
                       let currentRequest = task.currentRequest
                    {
                        URLSessionLogger.processAndLogRequest(currentRequest, sessionTaskId: sessionTaskId, instrumentation: self, shouldInjectHeaders: false)
                    }
                }
                self.setIdKey(value: sessionTaskId, for: task)
                return task
            }
            let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
            originalIMP = method_setImplementation(original, swizzledIMP)
        }
    }

    private func injectIntoNSURLSessionAsyncUploadTaskMethods() {
        let cls = URLSession.self
        [
            #selector(URLSession.uploadTask(with:from:completionHandler:)),
            #selector(URLSession.uploadTask(with:fromFile:completionHandler:))
        ].forEach {
            let selector = $0
            guard let original = class_getInstanceMethod(cls, selector) else {
                print("injectInto \(selector.description) failed")
                return
            }
            var originalIMP: IMP?
            let sessionTaskId = UUID().uuidString

            let block: @convention(block) (URLSession, URLRequest, AnyObject, ((Any?, URLResponse?, Error?) -> Void)?) -> URLSessionTask = { session, request, argument, completion in

                let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (URLSession, Selector, URLRequest, AnyObject, ((Any?, URLResponse?, Error?) -> Void)?) -> URLSessionDataTask).self)

                var task: URLSessionTask!
                var completionBlock = completion
                if objc_getAssociatedObject(argument, &idKey) == nil {
                    let completionWrapper: (Any?, URLResponse?, Error?) -> Void = { object, response, error in
                        if error != nil {
                            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                            URLSessionLogger.logError(error!, dataOrFile: object, statusCode: status, instrumentation: self, sessionTaskId: sessionTaskId)
                        } else {
                            if let response = response {
                                URLSessionLogger.logResponse(response, dataOrFile: object, instrumentation: self, sessionTaskId: sessionTaskId)
                            }
                        }
                        if let completion = completion {
                            completion(object, response, error)
                        } else {
                            (session.delegate as? URLSessionTaskDelegate)?.urlSession?(session, task: task, didCompleteWithError: error)
                        }
                    }
                    completionBlock = completionWrapper
                }

                let processedRequest = URLSessionLogger.processAndLogRequest(request, sessionTaskId: sessionTaskId, instrumentation: self, shouldInjectHeaders: true)
                task = castedIMP(session, selector, processedRequest ?? request, argument, completionBlock)

                self.setIdKey(value: sessionTaskId, for: task)
                return task
            }
            let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
            originalIMP = method_setImplementation(original, swizzledIMP)
        }
    }

    // Delegate methods
    private func injectTaskDidReceiveDataIntoDelegateClass(cls: AnyClass) {
        let selector = #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:))
        guard let original = class_getInstanceMethod(cls, selector) else {
            return
        }
        var originalIMP: IMP?
        let block: @convention(block) (Any, URLSession, URLSessionDataTask, Data) -> Void = { object, session, dataTask, data in
            if objc_getAssociatedObject(session, &idKey) == nil {
                self.urlSession(session, dataTask: dataTask, didReceive: data)
            }
            let key = String(selector.hashValue)
            objc_setAssociatedObject(session, key, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (Any, Selector, URLSession, URLSessionDataTask, Data) -> Void).self)
            castedIMP(object, selector, session, dataTask, data)
            objc_setAssociatedObject(session, key, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        originalIMP = method_setImplementation(original, swizzledIMP)
    }

    private func injectTaskDidReceiveResponseIntoDelegateClass(cls: AnyClass) {
        let selector = #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:))
        guard let original = class_getInstanceMethod(cls, selector) else {
            return
        }
        var originalIMP: IMP?
        let block: @convention(block) (Any, URLSession, URLSessionDataTask, URLResponse, @escaping (URLSession.ResponseDisposition) -> Void) -> Void = { object, session, dataTask, response, completion in
            if objc_getAssociatedObject(session, &idKey) == nil {
                self.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completion)
                completion(.allow)
            }
            let key = String(selector.hashValue)
            objc_setAssociatedObject(session, key, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (Any, Selector, URLSession, URLSessionDataTask, URLResponse, @escaping (URLSession.ResponseDisposition) -> Void) -> Void).self)
            castedIMP(object, selector, session, dataTask, response, completion)
            objc_setAssociatedObject(session, key, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        originalIMP = method_setImplementation(original, swizzledIMP)
    }

    private func injectTaskDidCompleteWithErrorIntoDelegateClass(cls: AnyClass) {
        let selector = #selector(URLSessionDataDelegate.urlSession(_:task:didCompleteWithError:))
        guard let original = class_getInstanceMethod(cls, selector) else {
            return
        }
        var originalIMP: IMP?
        let block: @convention(block) (Any, URLSession, URLSessionTask, Error?) -> Void = { object, session, task, error in
            if objc_getAssociatedObject(session, &idKey) == nil {
                self.urlSession(session, task: task, didCompleteWithError: error)
            }
            let key = String(selector.hashValue)
            objc_setAssociatedObject(session, key, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (Any, Selector, URLSession, URLSessionTask, Error?) -> Void).self)
            castedIMP(object, selector, session, task, error)
            objc_setAssociatedObject(session, key, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        originalIMP = method_setImplementation(original, swizzledIMP)
    }

    func injectRespondsToSelectorIntoDelegateClass(cls: AnyClass) {
        let selector = #selector(NSObject.responds(to:))
        guard let original = class_getInstanceMethod(cls, selector),
              InstrumentationUtils.instanceRespondsAndImplements(cls: cls, selector: selector)
        else {
            return
        }

        var originalIMP: IMP?
        let block: @convention(block) (Any, Selector) -> Bool = { object, respondsTo in
            if respondsTo == #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:)) {
                return true
            }
            let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (Any, Selector, Selector) -> Bool).self)
            return castedIMP(object, selector, respondsTo)
        }
        let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        originalIMP = method_setImplementation(original, swizzledIMP)
    }

    private func injectDataTaskDidBecomeDownloadTaskIntoDelegateClass(cls: AnyClass) {
        let selector = #selector(URLSessionDataDelegate.urlSession(_:dataTask:didBecome:)! as (URLSessionDataDelegate) -> (URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void)
        guard let original = class_getInstanceMethod(cls, selector) else {
            return
        }
        var originalIMP: IMP?
        let block: @convention(block) (Any, URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void = { object, session, dataTask, downloadTask in
            if objc_getAssociatedObject(session, &idKey) == nil {
                self.urlSession(session, dataTask: dataTask, didBecome: downloadTask)
            }
            let key = String(selector.hashValue)
            objc_setAssociatedObject(session, key, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (Any, Selector, URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void).self)
            castedIMP(object, selector, session, dataTask, downloadTask)
            objc_setAssociatedObject(session, key, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        originalIMP = method_setImplementation(original, swizzledIMP)
    }

    // URLSessionTask methods
    private func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard configuration.shouldRecordPayload?(session) ?? false else { return }
        let dataCopy = data
        queue.async {
            let taskId = self.idKeyForTask(dataTask)
            if (self.requestMap[taskId]?.request) != nil {
                var requestState = self.requestState(for: taskId)
                requestState.dataProcessed?.append(dataCopy)
            }
        }
    }

    private func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard configuration.shouldRecordPayload?(session) ?? false else { return }
        queue.async {
            let taskId = self.idKeyForTask(dataTask)
            if (self.requestMap[taskId]?.request) != nil {
                var requestState = self.requestState(for: taskId)
                if response.expectedContentLength < 0 {
                    requestState.dataProcessed = Data()
                } else {
                    requestState.dataProcessed = Data(capacity: Int(response.expectedContentLength))
                }
            }
        }
    }

    private func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskId = self.idKeyForTask(task)
        if (self.requestMap[taskId]?.request) != nil {
            let requestState = self.requestState(for: taskId)
            if let error = error {
                let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
                URLSessionLogger.logError(error, dataOrFile: requestState.dataProcessed, statusCode: status, instrumentation: self, sessionTaskId: taskId)
            } else if let response = task.response {
                URLSessionLogger.logResponse(response, dataOrFile: requestState.dataProcessed, instrumentation: self, sessionTaskId: taskId)
            }
        }
    }

    private func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        queue.async {
            let id = self.idKeyForTask(dataTask)
            self.setIdKey(value: id, for: downloadTask)
        }
    }

    // Helpers
    private func idKeyForTask(_ task: URLSessionTask) -> String {
        var id = objc_getAssociatedObject(task, &idKey) as? String
        if id == nil {
            id = UUID().uuidString
            objc_setAssociatedObject(task, &idKey, id, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        return id!
    }

    private func setIdKey(value: String, for task: URLSessionTask) {
        objc_setAssociatedObject(task, &idKey, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func requestState(for id: String) -> NetworkRequestState {
        var state = requestMap[id]
        if state == nil {
            state = NetworkRequestState()
            requestMap[id] = state
        }
        return state!
    }
}
