# Cueline

A small macOS menu bar app that watches the calendars synced to your Mac and reminds you when a meeting is about to start — with one-click join for Zoom, Google Meet, and Microsoft Teams links.

Personal-use project, MIT-licensed. Build it yourself with Xcode. No accounts, no cloud, no third-party APIs — Cueline reads from Calendar.app via EventKit.

## What it does

- Shows your next meeting in the macOS menu bar ("12m" / "14:30").
- Lists upcoming events (next 24h) in a popover, grouped by day, with a **Join** button when a Zoom / Meet / Teams link is detected.
- Fires a native macOS notification N minutes before each meeting with a link — click the notification to open the meeting URL.
- Optional: copies the meeting link to your clipboard at notification time.
- Reads from any calendars you've set up in macOS Calendar.app — Google, iCloud, Exchange, Office 365, local, etc.

## What it does not do

- It makes zero network requests. All calendar data stays on your Mac (read directly from EventKit).
- It does not have its own accounts system. To add a calendar, add it to macOS Calendar.app the normal way (System Settings → Internet Accounts).
- It is not sandboxed and not signed for distribution — it's meant to be built from source.

## Requirements

- macOS 13 or later
- Xcode 15+ (free from the Mac App Store)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project: `brew install xcodegen`

## Build & run

```bash
git clone <this-repo> cueline
cd cueline
make open    # generates Cueline.xcodeproj and opens it in Xcode
```

In Xcode, select the **Cueline** scheme and hit **Run** (⌘R).

## First-run setup

1. The first time the app runs, macOS will prompt: **"Cueline" would like full access to your Calendar.** Click **Allow**.
2. The Cueline menu bar icon appears (calendar with a clock). Click it to see your upcoming events.
3. If you have many calendars and only want some included, open **Preferences… → Calendars** and toggle off the ones you don't want.
4. Tune the notification lead time and refresh interval in **Preferences… → General**.

If you accidentally clicked *Don't Allow*, re-enable Cueline in **System Settings → Privacy & Security → Calendars**.

## Adding a calendar source

Cueline shows whatever Calendar.app shows. To add a new calendar (Google work account, iCloud, etc.):

- **System Settings → Internet Accounts → Add Account…**
- Pick Google / Microsoft Exchange / iCloud / etc., sign in, and enable the Calendars toggle.
- Within a few minutes the new events appear in both Calendar.app and Cueline.

## Preferences

- **Notify before event** — lead time in minutes (0–60, default 2).
- **Copy meeting link to clipboard on notification** — handy if you want to paste the link somewhere else.
- **Refresh every** — how often the app polls EventKit as a safety net (60–900 s, default 120 s). Cueline also refreshes automatically when EventKit reports a change.
- **Calendars** — pick which calendars contribute events.

## Privacy

- All calendar data is read locally via the EventKit framework. No data leaves your Mac.
- The app makes no outgoing network connections.
- The macOS Calendar permission is the only sensitive permission Cueline asks for.

## Architecture (short)

| Layer | File |
|---|---|
| EventKit access + fetch | `Sources/Services/EventKitProvider.swift` |
| Meeting link detection | `Sources/Services/MeetingLinkParser.swift` |
| Event aggregation | `Sources/Services/EventStore.swift` |
| Calendar inclusion prefs | `Sources/Services/CalendarSelection.swift` |
| Notification scheduling | `Sources/Services/NotificationScheduler.swift` |
| Menu bar + popover | `Sources/AppDelegate.swift`, `Sources/UI/MenuBarView.swift` |
| Preferences | `Sources/UI/PreferencesView.swift` |

See [docs/architecture.md](docs/architecture.md) for a deeper tour.

## License

MIT — see [LICENSE](LICENSE).
