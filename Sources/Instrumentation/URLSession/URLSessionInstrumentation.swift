/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

struct NetworkRequestState {
    var request: URLRequest?
    var dataProcessed: Data?

    mutating func setRequest(_ request: URLRequest) {
        self.request = request
    }

    mutating func setData(_ data: URLRequest) {
        request = data
    }
}

private var idKey: Void?

public class URLSessionInstrumentation {
    private var requestMap = [String: NetworkRequestState]()

    var configuration: URLSessionInstrumentationConfiguration

    private let queue = DispatchQueue(label: "io.opentelemetry.ddnetworkinstrumentation")

    static var instrumentedKey = "io.opentelemetry.instrumentedCall"

    static let avAssetDownloadTask: AnyClass? = NSClassFromString("__NSCFBackgroundAVAssetDownloadTask")

    public private(set) var tracer: Tracer

    public var startedRequestSpans: [Span] {
        var spans = [Span]()
        URLSessionLogger.runningSpansQueue.sync {
            spans = Array(URLSessionLogger.runningSpans.values)
        }
        return spans
    }

    public init(configuration: URLSessionInstrumentationConfiguration) {
        self.configuration = configuration
        tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "NSURLSession", instrumentationVersion: "0.0.1")
        injectInNSURLClasses()
    }

    private func injectInNSURLClasses() {
        #if swift(<5.7)
            let selectors = [
                #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:)),
                #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:)),
                #selector(URLSessionDataDelegate.urlSession(_:task:didCompleteWithError:)),
                #selector(URLSessionDataDelegate.urlSession(_:dataTask:didBecome:)! as (URLSessionDataDelegate) -> (URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void),
                #selector(URLSessionDataDelegate.urlSession(_:dataTask:didBecome:)! as (URLSessionDataDelegate) -> (URLSession, URLSessionDataTask, URLSessionStreamTask) -> Void),
            ]
        #else
            let selectors = [
                #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:)),
                #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:)),
                #selector(URLSessionDataDelegate.urlSession(_:task:didCompleteWithError:)),
                #selector(URLSessionDataDelegate.urlSession(_:dataTask:didBecome:) as (URLSessionDataDelegate) -> ((URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void)?),
                #selector(URLSessionDataDelegate.urlSession(_:dataTask:didBecome:) as (URLSessionDataDelegate) -> ((URLSession, URLSessionDataTask, URLSessionStreamTask) -> Void)?),
            ]
        #endif
        let classes = configuration.delegateClassesToInstrument ?? InstrumentationUtils.objc_getClassList()
        let selectorsCount = selectors.count
        DispatchQueue.concurrentPerform(iterations: classes.count) { iteration in
            let theClass: AnyClass = classes[iteration]
            guard theClass != Self.self else { return }
            var selectorFound = false
            var methodCount: UInt32 = 0
            guard let methodList = class_copyMethodList(theClass, &methodCount) else { return }
            defer { free(methodList) }

            for j in 0 ..< selectorsCount {
                for i in 0 ..< Int(methodCount) {
                    if method_getName(methodList[i]) == selectors[j] {
                        selectorFound = true
                        injectIntoDelegateClass(cls: theClass)
                        break
                    }
                }
                if selectorFound {
                    break
                }
            }
        }

        if #available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) {
            injectIntoNSURLSessionCreateTaskMethods()
        }
        injectIntoNSURLSessionCreateTaskWithParameterMethods()
        injectIntoNSURLSessionAsyncDataAndDownloadTaskMethods()
        injectIntoNSURLSessionAsyncUploadTaskMethods()
        injectIntoNSURLSessionTaskResume()
    }

    private func injectIntoDelegateClass(cls: AnyClass) {
        // Sessions
        injectTaskDidReceiveDataIntoDelegateClass(cls: cls)
        injectTaskDidReceiveResponseIntoDelegateClass(cls: cls)
        injectTaskDidCompleteWithErrorIntoDelegateClass(cls: cls)
        injectRespondsToSelectorIntoDelegateClass(cls: cls)
        // For future use
        if #available(OSX 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
            injectTaskDidFinishCollectingMetricsIntoDelegateClass(cls: cls)
        }

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
            #selector(URLSession.downloadTask(withResumeData:)),
        ].forEach {
            let selector = $0
            guard let original = class_getInstanceMethod(cls, selector) else {
                print("injectInto \(selector.description) failed")
                return
            }
            var originalIMP: IMP?

            let block: @convention(block) (URLSession, AnyObject) -> URLSessionTask = { session, argument in
                if let url = argument as? URL {
                    let request = URLRequest(url: url)
                    if self.configuration.shouldInjectTracingHeaders?(request) ?? true {
                        if selector == #selector(URLSession.dataTask(with:) as (URLSession) -> (URL) -> URLSessionDataTask) {
                            return session.dataTask(with: request)
                        } else {
                            return session.downloadTask(with: request)
                        }
                    }
                }

                let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (URLSession, Selector, Any) -> URLSessionDataTask).self)
                var task: URLSessionTask
                let sessionTaskId = UUID().uuidString

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
            #selector(URLSession.uploadTask(with:fromFile:)),
        ].forEach {
            let selector = $0
            guard let original = class_getInstanceMethod(cls, selector) else {
                print("injectInto \(selector.description) failed")
                return
            }
            var originalIMP: IMP?

            let block: @convention(block) (URLSession, URLRequest, AnyObject) -> URLSessionTask = { session, request, argument in
                let sessionTaskId = UUID().uuidString
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
            #selector(URLSession.downloadTask(withResumeData:completionHandler:)),
        ].forEach {
            let selector = $0
            guard let original = class_getInstanceMethod(cls, selector) else {
                print("injectInto \(selector.description) failed")
                return
            }
            var originalIMP: IMP?

            let block: @convention(block) (URLSession, AnyObject, ((Any?, URLResponse?, Error?) -> Void)?) -> URLSessionTask = { session, argument, completion in

                if let url = argument as? URL {
                    let request = URLRequest(url: url)

                    if self.configuration.shouldInjectTracingHeaders?(request) ?? true {
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
                let sessionTaskId = UUID().uuidString

                var completionBlock = completion

                if completionBlock != nil {
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
                }

                if let request = argument as? URLRequest, objc_getAssociatedObject(argument, &idKey) == nil {
                    let instrumentedRequest = URLSessionLogger.processAndLogRequest(request, sessionTaskId: sessionTaskId, instrumentation: self, shouldInjectHeaders: true)
                    task = castedIMP(session, selector, instrumentedRequest ?? request, completionBlock)
                } else {
                    task = castedIMP(session, selector, argument, completionBlock)
                    if objc_getAssociatedObject(argument, &idKey) == nil,
                       let currentRequest = task.currentRequest {
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
            #selector(URLSession.uploadTask(with:fromFile:completionHandler:)),
        ].forEach {
            let selector = $0
            guard let original = class_getInstanceMethod(cls, selector) else {
                print("injectInto \(selector.description) failed")
                return
            }
            var originalIMP: IMP?

            let block: @convention(block) (URLSession, URLRequest, AnyObject, ((Any?, URLResponse?, Error?) -> Void)?) -> URLSessionTask = { session, request, argument, completion in

                let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (URLSession, Selector, URLRequest, AnyObject, ((Any?, URLResponse?, Error?) -> Void)?) -> URLSessionDataTask).self)

                var task: URLSessionTask!
                let sessionTaskId = UUID().uuidString

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

    private func injectIntoNSURLSessionTaskResume() {
        var methodsToSwizzle = [Method]()

        if let method = class_getInstanceMethod(URLSessionTask.self, #selector(URLSessionTask.resume)) {
            methodsToSwizzle.append(method)
        }

        if let cfURLSession = NSClassFromString("__NSCFURLSessionTask"),
           let method = class_getInstanceMethod(cfURLSession, NSSelectorFromString("resume")) {
            methodsToSwizzle.append(method)
        }

        if NSClassFromString("AFURLSessionManager") != nil {
            let classes = InstrumentationUtils.objc_getClassList()
            classes.forEach {
                if let method = class_getInstanceMethod($0, NSSelectorFromString("af_resume")) {
                    methodsToSwizzle.append(method)
                }
            }
        }

        methodsToSwizzle.forEach {
            let theMethod = $0

            var originalIMP: IMP?
            let block: @convention(block) (URLSessionTask) -> Void = { anyTask in
                self.urlSessionTaskWillResume(anyTask)
                guard anyTask.currentRequest != nil else { return }
                let key = String(theMethod.hashValue)
                objc_setAssociatedObject(anyTask, key, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (Any) -> Void).self)
                castedIMP(anyTask)
                objc_setAssociatedObject(anyTask, key, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
            originalIMP = method_setImplementation(theMethod, swizzledIMP)
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

    private func injectTaskDidFinishCollectingMetricsIntoDelegateClass(cls: AnyClass) {
        let selector = #selector(URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:))
        guard let original = class_getInstanceMethod(cls, selector) else {
            let block: @convention(block) (Any, URLSession, URLSessionTask, URLSessionTaskMetrics) -> Void = { _, session, task, metrics in
                self.urlSession(session, task: task, didFinishCollecting: metrics)
            }
            let imp = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
            class_addMethod(cls, selector, imp, "@@@")
            return
        }
        var originalIMP: IMP?
        let block: @convention(block) (Any, URLSession, URLSessionTask, URLSessionTaskMetrics) -> Void = { object, session, task, metrics in
            if objc_getAssociatedObject(session, &idKey) == nil {
                self.urlSession(session, task: task, didFinishCollecting: metrics)
            }
            let key = String(selector.hashValue)
            objc_setAssociatedObject(session, key, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            let castedIMP = unsafeBitCast(originalIMP, to: (@convention(c) (Any, Selector, URLSession, URLSessionTask, URLSessionTaskMetrics) -> Void).self)
            castedIMP(object, selector, session, task, metrics)
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
        #if swift(<5.7)
            let selector = #selector(URLSessionDataDelegate.urlSession(_:dataTask:didBecome:)! as (URLSessionDataDelegate) -> (URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void)
        #else
            let selector = #selector(URLSessionDataDelegate.urlSession(_:dataTask:didBecome:) as (URLSessionDataDelegate) -> ((URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void)?)
        #endif
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
        guard let taskId = objc_getAssociatedObject(dataTask, &idKey) as? String else {
            return
        }
        let dataCopy = data
        queue.sync {
            if (requestMap[taskId]?.request) != nil {
                createRequestState(for: taskId)
                if requestMap[taskId]?.dataProcessed == nil {
                    requestMap[taskId]?.dataProcessed = Data()
                }
                requestMap[taskId]?.dataProcessed?.append(dataCopy)
            }
        }
    }

    private func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard configuration.shouldRecordPayload?(session) ?? false else { return }
        guard let taskId = objc_getAssociatedObject(dataTask, &idKey) as? String else {
            return
        }
        queue.sync {
            if (requestMap[taskId]?.request) != nil {
                createRequestState(for: taskId)
                if response.expectedContentLength < 0 {
                    requestMap[taskId]?.dataProcessed = Data()
                } else {
                    requestMap[taskId]?.dataProcessed = Data(capacity: Int(response.expectedContentLength))
                }
            }
        }
    }

    private func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let taskId = objc_getAssociatedObject(task, &idKey) as? String else {
            return
        }
        var requestState: NetworkRequestState?
        queue.sync {
            requestState = requestMap[taskId]
            if requestState != nil {
                requestMap[taskId] = nil
            }
        }
        if let error = error {
            let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
            URLSessionLogger.logError(error, dataOrFile: requestState?.dataProcessed, statusCode: status, instrumentation: self, sessionTaskId: taskId)
        } else if let response = task.response {
            URLSessionLogger.logResponse(response, dataOrFile: requestState?.dataProcessed, instrumentation: self, sessionTaskId: taskId)
        }
    }

    private func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        guard let taskId = objc_getAssociatedObject(dataTask, &idKey) as? String else {
            return
        }
        setIdKey(value: taskId, for: downloadTask)
    }

    private func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let taskId = objc_getAssociatedObject(task, &idKey) as? String else {
            return
        }
        var requestState: NetworkRequestState?
        queue.sync {
            requestState = requestMap[taskId]

            if requestState?.request != nil {
                requestMap[taskId] = nil
            }
        }

        guard requestState?.request != nil else {
            return
        }

        /// Code for instrumenting collection should be written here
        if let error = task.error {
            let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
            URLSessionLogger.logError(error, dataOrFile: requestState?.dataProcessed, statusCode: status, instrumentation: self, sessionTaskId: taskId)
        } else if let response = task.response {
            URLSessionLogger.logResponse(response, dataOrFile: requestState?.dataProcessed, instrumentation: self, sessionTaskId: taskId)
        }
    }

    private func urlSessionTaskWillResume(_ task: URLSessionTask) {
        // AV Asset Tasks cannot be auto instrumented, they dont include request attributes, skip them
        if let avAssetTaskClass = Self.avAssetDownloadTask,
           task.isKind(of: avAssetTaskClass) {
            return
        }

        let taskId = idKeyForTask(task)
        if let request = task.currentRequest {
            queue.sync {
                if requestMap[taskId] == nil {
                    requestMap[taskId] = NetworkRequestState()
                }
                requestMap[taskId]?.setRequest(request)
            }

            if #available(OSX 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
                guard Task.basePriority != nil else {
                    // If not inside a Task basePriority is nil
                    return
                }
                let instrumentedRequest = URLSessionLogger.processAndLogRequest(request, sessionTaskId: taskId, instrumentation: self, shouldInjectHeaders: true)
                task.setValue(instrumentedRequest, forKey: "currentRequest")
                self.setIdKey(value: taskId, for: task)


                if task.delegate == nil && task.state != .running {
                    task.delegate = FakeDelegate()
                }
            }
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

    private func createRequestState(for id: String) {
        var state = requestMap[id]
        if requestMap[id] == nil {
            state = NetworkRequestState()
            requestMap[id] = state
        }
    }
}

class FakeDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {}
}
