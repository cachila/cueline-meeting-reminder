# Architecture

A short tour of how the pieces fit, for anyone hacking on the code.

## Process model

Cueline is a single-process macOS agent app (`LSUIElement = true`). No dock icon, no main menu — just a status bar item and on-demand windows.

```
NSApplicationMain
  └─ AppDelegate (@MainActor)
       ├─ Preferences         (UserDefaults-backed @Published values)
       ├─ CalendarSelection   (set of included EKCalendar identifiers)
       ├─ EventKitProvider    (wraps EKEventStore)
       ├─ EventStore          (in-memory list, refreshed on tick/wake/change)
       ├─ NSStatusItem + NSPopover (MenuBarView)
       ├─ NSWindow on demand  (PreferencesView)
       └─ NotificationScheduler  (UNUserNotificationCenter delegate)
```

## Data source: EventKit

`EventKitProvider` owns the single `EKEventStore`. The first time the app runs it calls `requestFullAccessToEvents()` (macOS 14+) or `requestAccess(to: .event)` (macOS 13). The user sees the standard system permission prompt.

`fetchUpcoming(within:includedCalendarIDs:)` queries `predicateForEvents(withStart:end:calendars:)` for a 24h window and decodes each `EKEvent` into a `CalendarEvent`. Cancelled events are filtered out. Meeting links are detected by `MeetingLinkParser` over `event.url`, `event.location`, and `event.notes` in that order.

## Calendar selection

`CalendarSelection.includedIdentifiers` is a `Set<String>` persisted to UserDefaults. An empty set means "all calendars" (so a fresh install includes everything). When the user toggles a calendar off for the first time, the set is seeded with all visible calendar IDs so the other calendars stay included. When the user toggles all calendars back on, the set is collapsed back to empty.

## Notifications

`NotificationScheduler.sync(events:)` runs whenever the event list changes:
- Computes desired scheduled IDs from events that have a meeting link and start in the future.
- Reads pending notifications via `UNUserNotificationCenter`; removes any that no longer match.
- Schedules new `UNTimeIntervalNotificationTrigger`s for `event.start − leadTime`.
- Carries the meeting URL in `userInfo` so the delegate can open it on click.

The delegate's `willPresent` allows banners even when the app is foreground, and optionally copies the link to the clipboard. `didReceive` opens the meeting URL via `NSWorkspace`.

## Status bar title

The status item shows `<icon> 12m` or `<icon> 14:30`. It's recomputed:
- whenever `events.events` publishes,
- every 30 s via a `Timer` (so the "12m" countdown ticks down without a refresh).

## Refresh triggers

`AppDelegate` refreshes the event store on four signals:
- **Polling timer** — every `preferences.pollSeconds` seconds (default 120). A safety net in case EventKit's change-notification doesn't fire.
- **`EKEventStoreChanged`** — EventKit posts this when any underlying calendar is updated; we refresh immediately.
- **`NSWorkspace.didWake`** — refresh when the Mac wakes from sleep.
- **`CalendarSelection.includedIdentifiers` changes** — refresh whenever the user toggles a calendar in preferences.

## Threading

Everything user-visible is `@MainActor`. EventKit's `EKEventStore` is thread-safe but for simplicity all fetches run on the main actor — they are fast in-process queries, not network calls. The `pollTask` is a `Task` inheriting MainActor isolation, with `await Task.sleep` between refreshes.

## What's deliberately absent

- No `URLSession`, no OAuth, no Keychain. Removing the Google API path was a deliberate trade: it forced calendar setup to live in macOS Calendar.app, but it also eliminated the need for OAuth clients, refresh tokens, and the loopback HTTP listener — and made the app immune to corporate Workspace restrictions on third-party app authorization.
