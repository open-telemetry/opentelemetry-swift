/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin)
  import Foundation

  /// A first frame read that hasn't reported yet, so its owner can stop it.
  protocol FirstFrameRead: Sendable {
    /// Stops the read and releases what it holds. The completion is never called afterwards, and
    /// cancelling a read that already completed does nothing.
    func cancel()
  }

  /// Reports when the next frame is displayed.
  protocol FirstFrameReader: Sendable {
    /// Starts a read, and returns a handle its owner cancels when the activation it was started
    /// for can no longer end at a first frame, for example because the app left the foreground.
    @discardableResult
    func readFirstFrame(_ completion: @escaping (Date) -> Void) -> FirstFrameRead
  }

  #if canImport(UIKit) && !os(watchOS)
    import QuartzCore

    /// Reads the next frame with a `CADisplayLink` on the main run loop, which it invalidates once
    /// the frame is displayed, or when the read is cancelled.
    struct DisplayLinkFirstFrameReader: FirstFrameReader {
      @discardableResult
      func readFirstFrame(_ completion: @escaping (Date) -> Void) -> FirstFrameRead {
        let target = DisplayLinkTarget(completion: completion)
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        return DisplayLinkRead(target: target, link: LinkBox(link))
      }
    }

    /// `CADisplayLink` isn't `Sendable`, and this only ever reaches it on the main thread.
    private final class LinkBox: @unchecked Sendable {
      let link: CADisplayLink

      init(_ link: CADisplayLink) {
        self.link = link
      }
    }

    /// A display link pauses in the background, so without cancellation a read the app left before
    /// its second tick would keep the link registered on the main run loop, holding its target and
    /// whatever its completion captured until the app came back.
    private struct DisplayLinkRead: FirstFrameRead {
      let target: DisplayLinkTarget
      let link: LinkBox

      func cancel() {
        // Takes effect immediately, wherever this is called from, so the completion can't run
        // after the activation it belongs to was abandoned.
        target.cancel()
        // The link is main-thread bound. Cancelling from the main thread is the normal case,
        // because the lifecycle notifications are posted there.
        let link = link
        if Thread.isMainThread {
          link.link.invalidate()
        } else {
          DispatchQueue.main.async { link.link.invalidate() }
        }
      }
    }

    private final class DisplayLinkTarget: NSObject, @unchecked Sendable {
      private let lock = NSLock()
      private var completion: ((Date) -> Void)?
      private var hasTicked = false

      init(completion: @escaping (Date) -> Void) {
        self.completion = completion
      }

      /// Drops the completion, so a tick that's already queued reports nothing.
      func cancel() {
        lock.withLock { completion = nil }
      }

      @objc func tick(_ link: CADisplayLink) {
        // A frame committed before a display refresh is rendered during it and displayed at the
        // next one, so the first callback's `timestamp` is a refresh before the frame appeared.
        guard hasTicked else {
          hasTicked = true
          return
        }
        link.invalidate()
        let completion: ((Date) -> Void)? = lock.withLock {
          defer { self.completion = nil }
          return self.completion
        }
        guard let completion else { return }
        // `timestamp` is on the media clock, so convert it to wall-clock time relative to now.
        completion(Date(timeIntervalSinceNow: link.timestamp - CACurrentMediaTime()))
      }
    }
  #endif
#endif
