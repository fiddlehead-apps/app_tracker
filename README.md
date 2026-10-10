# Tally for iOS

Count anything, with the details you care about. Native SwiftUI app, iOS 17+.

- **Trackers** with your own name, icon, color and **fields**: text (with suggestions from earlier entries), choice, number with unit (ml, km, €), duration, 1–5 rating, yes/no.
- **21 templates**: water, coffee, sleep, medication, alcohol, headache, sweets & snacks, workout, run, walk, yoga, meditation, mood, gratitude, journaling, reading, language practice, instrument practice, social media, spending, plus the classic Location / Source / Target event from the web Tally.
- **+1 per tracker**: either logs instantly with default values (Undo / Details in the toast) or opens a form. Optional daily goal with progress ring and streak.
- **Detail view**: today / week / month / all-time, 15-week calendar heatmap (tap a day to filter), **timeline line charts** over 14 / 30 / 90 days for the entry count and every field (text fields get one line per value), entry list.
- **Widgets**: small (pick a tracker) and medium (first four trackers), both with an interactive +1 button. The +1 action is also available in the Shortcuts app.
- **Apple Watch app**: tap +1 (or swipe a tracker to the right) and the current time is saved on the watch right away. Then optionally pick values per field from the last few values; the rest can be filled in later on the iPhone. Talks to the iPhone over WatchConnectivity, so it works without iCloud and queues entries while the phone is out of reach.
- **iCloud sync** via SwiftData + CloudKit (private database).
- **CSV import/export**, compatible with the export of the Tally web page (`counter`/`person` columns are understood).
- English and German.

## Setup

1. Open `Config/Config.xcconfig` and set `DEVELOPMENT_TEAM` to your team ID. Change `BUNDLE_ID_PREFIX` if `org.christophschneider` isn't yours.
2. Open `Tally.xcodeproj`. In *Signing & Capabilities* of both targets (`Tally`, `TallyWidgetExtension`) let Xcode register the App Group `group.<prefix>.tally` and the iCloud container `iCloud.<prefix>.tally` (they're already in the entitlements; if Xcode shows an error, click the refresh button under iCloud → Containers or tick the container).
3. Run on your iPhone.

Without a team the app still builds and runs in the simulator; it then stores data locally only (Settings shows "iCloud sync: Off").

To try the widget in the simulator without a team, sign ad hoc so the App Group and iCloud entitlements are embedded (an unsigned widget can't resolve its configuration intent and stays a placeholder):

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /tmp/tally-dd CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

Sync only works with a real Apple Account on a device or simulator that's signed in. For a TestFlight / App Store build, deploy the CloudKit schema to Production in the CloudKit Console first.

## Project layout

```
Config/        xcconfig, Info.plists, entitlements
Shared/        Code used by app and widget: SwiftData models, store, App Intents, helpers, strings
WatchSync/     Code used by app, widget and watch: colors, iPhone ↔ Watch message format
TallyWatch/    Apple Watch app
Tally/         App: views, templates, CSV
TallyWidget/   Widget extension
scripts/       Localization helper
```

Folders are synchronized groups: new files in these folders are picked up by Xcode automatically.

## Localization

UI text is written in English in the code. German translations live in `scripts/de.json`. After adding or changing UI text:

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/tally-dd CODE_SIGNING_ALLOWED=NO build
node scripts/gen-strings.js /tmp/tally-dd
```

The script lists any text that's missing a German translation.
