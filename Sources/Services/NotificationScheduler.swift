import Foundation
import UserNotifications
import AppKit

@MainActor
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private var preferences: Preferences?
    private static let idPrefix = "cueline:"

    func bootstrap(preferences: Preferences) {
        self.preferences = preferences
        center.delegate = self
        Task { await requestAuthorization() }
    }

    private func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            NSLog("Cueline notification auth error: \(error.localizedDescription)")
        }
    }

    func sync(events: [CalendarEvent]) async {
        guard let prefs = preferences else { return }
        let lead = TimeInterval(prefs.leadTimeMinutes * 60)
        let now = Date()

        // Always replace all cueline-owned pending requests so subtitle/body stay fresh
        // (they freeze at schedule time on macOS) and stale ones from prior versions disappear.
        let pending = await center.pendingNotificationRequests()
        let cuelineIDs = pending.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
        if !cuelineIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: cuelineIDs)
        }

        let candidates = events.filter { $0.meetingLink != nil && $0.start > now }

        for event in candidates {
            let fire = event.start.addingTimeInterval(-lead)
            if fire <= now.addingTimeInterval(1) { continue }  // must be strictly in the future

            let id = Self.idPrefix + event.id
            let content = makeContent(for: event, prefs: prefs)

            // UNCalendarNotificationTrigger fires at an absolute clock time — more reliable
            // than UNTimeIntervalNotificationTrigger for long-horizon (multi-hour) scheduling.
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fire
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                NSLog("Cueline failed to schedule notification: \(error)")
            }
        }
    }

    private func makeContent(for event: CalendarEvent, prefs: Preferences) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = event.title
        let provider = event.meetingLink?.provider.displayName ?? "Meeting"
        content.subtitle = subtitleText(provider: provider, leadMinutes: prefs.leadTimeMinutes)
        content.body = eventTimeText(event)
        content.sound = .default
        content.userInfo = [
            "url": event.meetingLink!.url.absoluteString,
            "copyOnNotify": prefs.copyLinkOnNotify,
        ]
        return content
    }

    private func subtitleText(provider: String, leadMinutes: Int) -> String {
        if leadMinutes <= 0 { return "\(provider) — starting now" }
        if leadMinutes == 1 { return "\(provider) — in 1 min" }
        return "\(provider) — in \(leadMinutes) min"
    }

    private func eventTimeText(_ event: CalendarEvent) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "HH:mm"
        return "\(f.string(from: event.start)) – \(f.string(from: event.end))"
    }

    // MARK: - Delegate

    // Show banners even when the app is foregrounded (e.g. popover open).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        if let info = notification.request.content.userInfo as? [String: Any],
           let copy = info["copyOnNotify"] as? Bool, copy,
           let urlStr = info["url"] as? String {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(urlStr, forType: .string)
        }
        return [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let urlStr = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: urlStr) else { return }
        NSWorkspace.shared.open(url)
    }
}
