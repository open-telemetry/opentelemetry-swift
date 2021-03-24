/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// The `URLSession` delegate object which enables network requests instrumentation. **It must be
/// used together with** `Datadog.Configuration.track(firstPartyHosts:)`.
///
/// All requests made with the `URLSession` instrumented with this delegate will be intercepted by the SDK.
@objc
open class DDURLSessionDelegate: NSObject, URLSessionDelegate {
    var interceptor: URLSessionInterceptorType?
    var originalDelegate : URLSessionDelegate?
    @objc
     public init(originalDelegate: URLSessionDelegate?) {
        interceptor =   URLSessionAutoInstrumentation.instance?.interceptor
        self.originalDelegate = originalDelegate
        if interceptor == nil {
            print("""
                `Agent.start()` must be called before initializing the `DDURLSessionDelegate` and
                first party hosts must be specified in `Datadog.Configuration`: `track(firstPartyHosts:)`
                to enable network requests tracking.
            """)
        }
        super.init()
    }

    
    open func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        if let delegate = originalDelegate {
        if (delegate.responds(to: #selector(URLSessionTaskDelegate.urlSession(_:task:didFinishCollecting:)))) {
            let originalTaskDelegate = originalDelegate as! URLSessionTaskDelegate
                originalTaskDelegate.urlSession?(session, task: task, didFinishCollecting: metrics)
            }
        }
        interceptor?.taskMetricsCollected(task: task, metrics: metrics)
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // NOTE: This delegate method is only called for `URLSessionTasks` created without the completion handler.
        if let delegate = originalDelegate {
        if (delegate.responds(to: #selector(URLSessionTaskDelegate.urlSession(_:task:didCompleteWithError:)))) {
            let originalTaskDelegate = originalDelegate as! URLSessionTaskDelegate
            originalTaskDelegate.urlSession?(session, task: task, didCompleteWithError: error)
        }
        }
        interceptor?.taskCompleted(task: task, error: error)
    }
    

    open override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let delegate = originalDelegate {
            if delegate.responds(to: aSelector) {
                return originalDelegate
            }
        }
        return nil
    }
    
    override open func isKind(of aClass: AnyClass) -> Bool {
        return Self.self == aClass || ((originalDelegate?.isKind(of: aClass)) != nil)
    }
    
    override open func responds(to aSelector: Selector!) -> Bool {
        if let delegate = originalDelegate {
            return super.responds(to: aSelector) || delegate.responds(to: aSelector)
        }
        return super.responds(to: aSelector)
    }
}
