# Sola Tracker (iOS, watchOS)

The app is called **Sola Tracker** in every language.

Count anything, with the details you care about. Native SwiftUI app, iOS 17+.

- **Trackers** with your own name, icon, color and **fields**: text (with suggestions from earlier entries), choice, number with unit (ml, km, €), duration, 1–5 rating, yes/no.
- **21 templates**: water, coffee, sleep, medication, alcohol, headache, sweets & snacks, workout, run, walk, yoga, meditation, mood, gratitude, journaling, reading, language practice, instrument practice, social media, spending and a generic event with location, source and target.
- **+1 per tracker**: either logs instantly with default values (Undo / Details in the toast) or opens a form. Optional daily goal with progress ring and streak.
- **Detail view**: today / week / month / all-time, 15-week calendar heatmap (tap a day to filter), **timeline line charts** over 14 / 30 / 90 days for the entry count and every field (text fields get one line per value), entry list.
- **Hidden trackers**: tap a tracker five times quickly to hide it. Hidden trackers disappear from the home screen, widgets, Shortcuts suggestions and the watch. Tap the date above the trackers (or the Version row in Settings) five times and confirm with Face ID / Touch ID to see them; touch and hold one (or use the eye button in its detail view) to unhide it. Leaving the app locks them again.
- **Widgets**: small (pick a tracker) and medium (first four trackers), both with an interactive +1 button. The +1 action is also available in the Shortcuts app.
- **Apple Watch app**: tap +1 (or swipe a tracker to the right) and the current time is saved on the watch right away. Then optionally pick values per field from the last few values; the rest can be filled in later on the iPhone. Talks to the iPhone over WatchConnectivity, so it works without iCloud and queues entries while the phone is out of reach.
- **iCloud sync**, off until you turn it on in Settings: SwiftData mirrors the store to the private CloudKit database. The switch takes effect when Settings closes (the store is reopened with or without CloudKit and the view tree is rebuilt). Turning it off asks whether to keep or delete the data in iCloud; the device keeps everything either way. The widget always opens the store local-only; the app mirrors its changes.
- **CSV import/export**: one row per entry; import matches trackers by name and skips rows you already have.
- English and German.

## Setup

1. Team, bundle IDs and the iCloud switch live in `Config/Config.xcconfig` (IDs `eu.fiddlehead.sola.tracker`, `.widget`, `.watchkitapp`, App Group `group.eu.fiddlehead.sola.tracker`, iCloud container `iCloud.eu.fiddlehead.sola.tracker`). For your own copy, change `SOLA_TEAM` and `BUNDLE_ID_PREFIX` there, or override them in `../sola-local.xcconfig`, which every Sola app reads if it exists.
2. `SOLA_ICLOUD = NO` (default) builds without iCloud and push entitlements, so the free Personal Team can sign it; Settings then says the build can't sync. iCloud needs a paid team: put `SOLA_TEAM = <team>` and `SOLA_ICLOUD = YES` into `../sola-local.xcconfig` (or run `../build-sola-apps.sh --icloud tracker`). Xcode registers the App Group and the iCloud container on the first build with `-allowProvisioningUpdates`.
3. Open `SolaTracker.xcodeproj` and run on your iPhone.

To try the widget in the simulator without a team, sign ad hoc so the App Group entitlement is embedded (an unsigned widget can't resolve its configuration intent and stays a placeholder):

```bash
xcodebuild -project SolaTracker.xcodeproj -scheme SolaTracker -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /tmp/solatracker-dd CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

Sync only works with a real Apple Account on a device or simulator that's signed in. For a TestFlight / App Store build, deploy the CloudKit schema to Production in the CloudKit Console first.

## Project layout

```
Config/             xcconfig, Info.plists, entitlements
Shared/             Code used by app and widget: SwiftData models, store, App Intents, helpers, strings
WatchSync/          Code used by app, widget and watch: colors, iPhone ↔ Watch message format
SolaTrackerWatch/   Apple Watch app
SolaTracker/        App: views, templates, CSV
SolaTrackerWidget/  Widget extension
scripts/            Localization helper
```

Folders are synchronized groups: new files in these folders are picked up by Xcode automatically.

## Localization

UI text is written in English in the code. German translations live in `scripts/de.json`. After adding or changing UI text:

```bash
xcodebuild -project SolaTracker.xcodeproj -scheme SolaTracker -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/solatracker-dd CODE_SIGNING_ALLOWED=NO build
node scripts/gen-strings.js /tmp/solatracker-dd
```

The script lists any text that's missing a German translation.
