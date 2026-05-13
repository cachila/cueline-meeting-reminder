import Foundation
import UserNotifications
import AppKit

@MainActor
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private var scheduledIDs: Set<String> = []
    private var preferences: Preferences?

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

        let candidates = events.filter { $0.meetingLink != nil && $0.start > now }
        let desired = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })

        let pending = await center.pendingNotificationRequests()
        for req in pending where req.identifier.hasPrefix("cueline:") {
            if desired[String(req.identifier.dropFirst("cueline:".count))] == nil {
                center.removePendingNotificationRequests(withIdentifiers: [req.identifier])
            }
        }
        let pendingIDs = Set(pending.map(\.identifier))

        for event in candidates {
            let id = "cueline:\(event.id)"
            if pendingIDs.contains(id) { continue }

            let fire = event.start.addingTimeInterval(-lead)
            if fire <= now { continue }

            let content = UNMutableNotificationContent()
            content.title = event.title
            let provider = event.meetingLink?.provider.displayName ?? "Meeting"
            let minutes = max(1, Int(ceil(event.start.timeIntervalSince(now) / 60)))
            content.subtitle = "\(provider) — in \(minutes) min"
            content.body = "Click to join. Calendar: \(event.calendarTitle)"
            content.sound = .default
            content.userInfo = [
                "url": event.meetingLink!.url.absoluteString,
                "copyOnNotify": prefs.copyLinkOnNotify,
            ]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fire.timeIntervalSinceNow, repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            do {
                try await center.add(request)
                scheduledIDs.insert(id)
            } catch {
                NSLog("Cueline failed to schedule notification: \(error)")
            }
        }
    }

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
