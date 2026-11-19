/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  import Foundation
  #if canImport(UIKit)
    import UIKit
  #else
    import AppKit
  #endif

  /// The notifications and app state each platform reports its lifecycle with.
  extension AppLaunchRuntime {
    #if canImport(UIKit)
      static let defaultDidBecomeActiveNotification = UIApplication.didBecomeActiveNotification
      static let defaultWillEnterForegroundNotification: Notification.Name? = UIApplication.willEnterForegroundNotification
      static let defaultDidEnterBackgroundNotification: Notification.Name? = UIApplication.didEnterBackgroundNotification
      static let defaultSceneWillConnectNotification: Notification.Name? = UIScene.willConnectNotification
      static let defaultDidFinishLaunchingNotification: Notification.Name? = UIApplication.didFinishLaunchingNotification
      static var defaultFirstFrameReader: FirstFrameReader? { DisplayLinkFirstFrameReader() }

      /// Whether the app is active, or `false` if that can't be read off the main thread.
      package static func readIsAppActive() -> Bool {
        guard Thread.isMainThread else { return false }
        return MainActor.assumeIsolated {
          // `UIApplication.shared` is unavailable in app extensions, so look it up dynamically, as
          // Datadog does.
          let application = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication
          return application?.applicationState == .active
        }
      }
    #else
      static let defaultDidBecomeActiveNotification = NSApplication.didBecomeActiveNotification
      static let defaultWillEnterForegroundNotification: Notification.Name? = nil
      static let defaultDidEnterBackgroundNotification: Notification.Name? = nil
      static let defaultSceneWillConnectNotification: Notification.Name? = nil
      static let defaultDidFinishLaunchingNotification: Notification.Name? = NSApplication.didFinishLaunchingNotification
      static var defaultFirstFrameReader: FirstFrameReader? { nil }

      /// Whether the app is active, or `false` if that can't be read off the main thread.
      package static func readIsAppActive() -> Bool {
        guard Thread.isMainThread else { return false }
        return MainActor.assumeIsolated {
          // `NSApp` is nil until the app creates its `NSApplication`, so this doesn't create one.
          let application: NSApplication? = NSApp
          return application?.isActive ?? false
        }
      }
    #endif
  }
#endif
