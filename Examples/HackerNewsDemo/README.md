# Hacker News Demo

Special thanks to maintainers of the HackerNews API! Checkout their work https://github.com/HackerNews/API

## Getting Started

Open `HackerNewsDemo.xcodeproj` and run the `HackerNewsDemo` scheme. Telemetry is configured in `HackerNewsDemo/Telemetry.swift` and exported over OTLP/HTTP to `http://localhost:4318` (see `Examples/OTLP HTTP Exporter` for a collector setup).

Instrumentation used from this repo:

- `URLSessionInstrumentation` - spans for every Hacker News API request
- `Sessions` - session IDs on spans/logs plus session start/end events
- `ResourceExtension` - device/OS/app resource attributes
- `OpenTelemetryProtocolExporterHTTP` - OTLP/HTTP trace and log export

Not yet available natively (tracked as `TODO` comments in `Telemetry.swift` and `SettingsView.swift`): app startup, crash, app hang, UIKit/SwiftUI view instrumentation, and a user ID manager. The Settings rows that depend on these (User ID, Trigger App Hang, Trigger App Crash, CPU Test, Memory Test) are shown grayed out with a "Coming soon" badge; the picker views stay in `SettingsView.swift` for when the instrumentations land.

1. The `Home` tab is built entirely with UIKit, and each post/comment involved triggers a separate HTTP request.
2. And the `Settings` tab is built with SwiftUI! Both view types are tracked.

## HackerNewsViewController

<table>
<tr>
<td width="600px" style="vertical-align: top;">

**HackerNewsViewController** - this is the root home tab controller responsible for showing the list of stories.

**Actions:**

1. Scroll up to refresh
2. Scroll down to infinite scroll
3. Click on "top", "best", or "new" to switch the ranking algorithm
4. Click on "three dots" icon to share the story link
5. Click on story title to navigate to see the full discussion thread
6. Click on username to navigate to a user view

</td>
<td width="300px" style="vertical-align: top;">

<img src="img/HackerNewsViewController.png" width="300">

</td>
</tr>
</table>

## CommentsViewController

<table>
<tr>
<td width="600px" style="vertical-align: top;">

**CommentsViewController** - this view is responsible for showing the full comment thread for a particular story in hierarchical and collapsible tree-format.

**Actions:**

1. Scroll up to refresh
2. Scroll down to infinite scroll
3. Click on "new" or "hot" to change the ranking algorithm.
4. Click on load replies to fetch more replies, which will trigger additional HTTP requests
5. Click on the arrow on the top right corner of each post to collapse an individual comment thread
6. Click on username to navigate to UserView
7. Click on the link to open the article in a browser

</td>
<td width="300px" style="vertical-align: top;">

<img src="img/CommentsViewController.png" width="300">

</td>
</tr>
</table>

## UserViewController

<table>
<tr>
<td width="600px" style="vertical-align: top;">

**UserViewController** - this view is responsible for showing details about a particular user, in addition to any recent stories or comments that they have posted.

**Actions:**

1. The comments and story components are re-used from the other views described earlier
2. Click on show parent to see more context regarding an individual comment, and will navigate you to ParentCommentViewController. If the parent comment is a story instead of another comment, then you will instead be redirected to CommentsViewController.

</td>
<td width="300px" style="vertical-align: top;">

<img src="img/UserViewController.png" width="300">

</td>
</tr>
</table>

## ParentCommentViewController

<table>
<tr>
<td width="600px" style="vertical-align: top;">

**ParentCommentViewController** - this view is responsible for showing more context about a particular comment, and is only accessible via UserViewController.

**Actions:**

1. The same actions regarding show parent and username apply
2. To navigate backwards, either click on the back button on the top left or swipe left.
3. To clear the navigation stack, click on the home button

</td>
<td width="300px" style="vertical-align: top;">

<img src="img/ParentCommentViewController.png" width="300">

</td>
</tr>
</table>

## Settings Tab

The Settings tab is primarily made with SwiftUI, though the root controller is made with UIKit.

### SettingsHostingController

<table>
<tr>
<td width="600px" style="vertical-align: top;">

**SettingsHostingController** - this is the root view responsible for the Settings tab

**Actions:**

1. Click on Tap to configure for "Load Test" to generate custom logs and spans
2. "User ID", "Trigger App Hang", "Trigger App Crash", "CPU Test" and "Memory Test" are grayed out with a "Coming soon" badge until the matching instrumentation exists

</td>
<td width="300px" style="vertical-align: top;">

<img src="img/SettingsViewController.png" width="300">

</td>
</tr>
</table>

### HangPickerView

<table>
<tr>
<td width="600px" style="vertical-align: top;">

**HangPickerView** - this SwiftUI view is responsible for configuring app hangs. Please note that based on Apple recommendation, only app hangs longer than 250 ms are reported.

</td>
<td width="300px" style="vertical-align: top;">

<img src="img/HangPickerView.png" width="300">

</td>
</tr>
</table>

### CrashPickerView

<table>
<tr>
<td width="600px" style="vertical-align: top;">

**CrashPickerView** - this SwiftUI view allows you to cause crashes of various types e.g. force unwrap, index out of bounds, etc. Note that these crash types are sorted by frequency of occurrence in the real world.

</td>
<td width="300px" style="vertical-align: top;">

<img src="img/CrashPickerView.png" width="300">

</td>
</tr>
</table>

### UserIdEditorView

<table>
<tr>
<td width="600px" style="vertical-align: top;">

**UserIdEditorView** - You can edit your userId using this modal. Please keep in mind that if you manually set this user ID in production, then you could be storing personally identifiable information (PII) so it is recommended to hash these values.

</td>
<td width="300px" style="vertical-align: top;">

<img src="img/UserIdEditorView.png" width="300">

</td>
</tr>
</table>