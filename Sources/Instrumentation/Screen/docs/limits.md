# Limits and testing

What this instrumentation does not see, and how to run its tests so a failure is visible.

## Known gaps

<dl>
<dt>A dismissed sheet leaves the screen behind</dt>
<dd>A <code>.pageSheet</code> or <code>.formSheet</code> going away does not fire <code>viewDidAppear(_:)</code> on the presenting view controller, so the tracker keeps reporting the sheet. Tracking <code>viewDidDisappear</code> would fix it, but needs a stack of visible screens, because split views and multiple windows show more than one screen at a time.</dd>
<dt>Work started before a screen appears belongs to the previous screen</dt>
<dd>A request made from <code>viewDidLoad</code> or <code>viewWillAppear</code> carries the screen the user is still looking at. That is accurate about what was on screen and wrong about what caused the request.</dd>
<dt>A subclass that skips <code>super.viewDidAppear(_:)</code> is invisible</dt>
<dd>The swizzle sits on <code>UIViewController</code>, so a subclass reaches it only through its <code>super</code> call.</dd>
<dt>Multiple windows share one current screen</dt>
<dd>The attribute names the screen that appeared most recently, not the one the span belongs to.</dd>
</dl>

## Running the tests

The UIKit tests drive a real `UIViewController`, so they run on the main actor.

```sh
arch -arm64 swift test --filter Screen            # 33 tests; macOS skips the UIKit suite
arch -arm64 xcodebuild test -scheme opentelemetry-swift-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ScreenTests
                                                  # 47 tests
```

The two counts differ by the UIKit-only tests, and that difference is the point: `swift test` runs on macOS, where `canImport(UIKit)` is false, so every UIKit path and its tests compile out. A green macOS run says nothing about lifecycle behaviour. Run the simulator suite as well for any change touching it.

Annotate each test method with `@MainActor`, never the `XCTestCase` subclass. A class-level `@MainActor` makes the suite hang after the first test while `xcodebuild` still exits 0 and prints `** TEST SUCCEEDED **`. Read the executed-test count rather than the exit status; this suite silently fell from 41 tests to 27 once because nobody did.

## Integration coverage

`Tests/IntegrationTests/Assertions/ScreenInstrumentationTests.swift` asserts against the exported OTLP of the `main` launch, so it checks that these names survive serialization. It needs no scenario of its own, because a screen appears on every launch.

It covers the SwiftUI path only. Integration test mode runs offline, so the demo app replaces the stories list with a bare `UIViewController` in a disabled tab and starts on the Settings tab, whose `SettingsHostingController` is excluded as a hosting controller. The unit tests cover the UIKit path by driving real view controllers. Covering it end to end needs a launch that enables the home tab and pushes a view controller.
