/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin)
  import Foundation

  /// Reports when the next frame is displayed.
  protocol FirstFrameReader: Sendable {
    func readFirstFrame(_ completion: @escaping (Date) -> Void)
  }

  #if canImport(UIKit) && !os(watchOS)
    import QuartzCore

    /// Reads the next frame with a `CADisplayLink` on the main run loop, which it invalidates once
    /// the frame is displayed.
    struct DisplayLinkFirstFrameReader: FirstFrameReader {
      func readFirstFrame(_ completion: @escaping (Date) -> Void) {
        let target = DisplayLinkTarget(completion: completion)
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
      }
    }

    private final class DisplayLinkTarget: NSObject {
      private var completion: ((Date) -> Void)?
      private var hasTicked = false

      init(completion: @escaping (Date) -> Void) {
        self.completion = completion
      }

      @objc func tick(_ link: CADisplayLink) {
        // A frame committed before a display refresh is rendered during it and displayed at the
        // next one, so the first callback's `timestamp` is a refresh before the frame appeared.
        guard hasTicked else {
          hasTicked = true
          return
        }
        link.invalidate()
        guard let completion else { return }
        self.completion = nil
        // `timestamp` is on the media clock, so convert it to wall-clock time relative to now.
        completion(Date(timeIntervalSinceNow: link.timestamp - CACurrentMediaTime()))
      }
    }
  #endif
#endif
