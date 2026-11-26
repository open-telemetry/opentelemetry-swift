/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Darwin) && ((canImport(UIKit) && !os(watchOS)) || canImport(AppKit))
  import Foundation
  import OpenTelemetryApi

  /// When the parts of a launch between the process starting and the app becoming active happened,
  /// if they were observed.
  package struct AppLaunchMarks: Sendable {
    package var didFinishLaunchingEnd: Date?
    package var sceneConnectStart: Date?
  }

  /// An activation, with its launch classified.
  package enum AppStart {
    case launch(LaunchClassification, AppLaunchMarks)
    case resume(AppResume)

    package var launchType: AppLaunchInstrumentationConfiguration.LaunchType {
      switch self {
      case let .launch(classification, _): classification.type
      case .resume: .resume
      }
    }
  }

  /// How an activation ended.
  package enum AppStartEnd {
    case firstFrame(Date)
    /// The app entered the background before the first frame.
    case abandoned(Date)
  }

  /// Decides which activations are recorded, and records them.
  package protocol AppStartRecording: Sendable {
    /// Returns what records `start` once it has ended, or `nil` if it won't be recorded.
    func prepare(_ start: AppStart) -> ((AppStartEnd) -> Void)?
  }
#endif
