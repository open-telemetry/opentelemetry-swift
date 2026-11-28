# Limits and testing

What this instrumentation does not see, and how to run its tests so a failure is visible.

## Known gaps

<dl>
<dt>Navigation types are partial in SwiftUI</dt>
<dd>Without the opt-in modifiers, SwiftUI reports a sheet as a push, its dismissal as a pop, and a tab switch, replace or reset with no type. See each front end's navigation types for what it detects and misses: <a href="../UIKit/README.md#navigation-types">UIKit</a>, <a href="../SwiftUI/README.md#navigation-types">SwiftUI</a>.</dd>
<dt>With navigation tracking off, a dismissed sheet leaves the screen behind</dt>
<dd>The presenter gets no new <code>viewDidAppear(_:)</code> or <code>onAppear</code> when a sheet goes away, so <code>ScreenTracker(tracksNavigation: false)</code> keeps naming the sheet. With tracking on, the default, each front end finds the revealed screen itself.</dd>
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
arch -arm64 swift test --enable-all-traits --filter Screen  # 75 tests; macOS skips the UIKit suite
arch -arm64 xcodebuild test -scheme opentelemetry-swift-Package \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:ScreenTests
                                                  # 109 tests
```

The two counts differ by the UIKit-only tests, and that difference is the point: `swift test` runs on macOS, where `canImport(UIKit)` is false, so every UIKit path and its tests compile out. A green macOS run says nothing about lifecycle behaviour. Run the simulator suite as well for any change touching it.

Annotate each test method with `@MainActor`, never the `XCTestCase` subclass. A class-level `@MainActor` makes the suite hang after the first test while `xcodebuild` still exits 0 and prints `** TEST SUCCEEDED **`. Read the executed-test count rather than the exit status; this suite silently fell from 41 tests to 27 once because nobody did.

## Integration coverage

Two suites assert against the exported OTLP, so they check that these names survive serialization.

<dl>
<dt><code>ScreenInstrumentationTests</code>, against the <code>main</code> launch</dt>
<dd>The first screen's event, span and stamped attributes. Integration test mode runs offline, so the demo starts on the SwiftUI Settings tab, and this suite covers the SwiftUI path only.</dd>
<dt><code>ScreenNavigationTests</code>, against the <code>screen-navigation</code> launch</dt>
<dd>One event per step, with its destination, navigation type and screen type, in sequence order. The launch presents a UIKit flow as a page sheet over Settings and steps it through modal, push, pop_to, pop, replace, reset and dismiss, then presents a SwiftUI <code>NavigationStack</code> and steps it through push, pop_to, pop, replace, reset, and a sheet's modal and dismiss. It also checks that the sequence numbers run unbroken in one session, and that each event names the screen it left.</dd>
</dl>

Neither covers interactive gestures, tab switches or iPad. The unit tests cover those paths with fakes.
