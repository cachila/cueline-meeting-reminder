import Foundation
import Combine

@MainActor
final class EventStore: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var refreshing = false

    let provider: EventKitProvider
    private let selection: CalendarSelection
    private let preferences: Preferences

    init(provider: EventKitProvider, selection: CalendarSelection, preferences: Preferences) {
        self.provider = provider
        self.selection = selection
        self.preferences = preferences
    }

    func refresh() async {
        guard provider.authState == .granted else {
            self.events = []
            self.lastError = nil
            self.lastRefresh = Date()
            return
        }
        refreshing = true
        defer { refreshing = false }

        let end = endOfWindow()
        let events = provider.fetchUpcoming(until: end, includedCalendarIDs: selection.asFilter)
        self.events = events
        self.lastRefresh = Date()
        self.lastError = nil
    }

    /// Midnight at the end of (today + lookaheadDays). For `lookaheadDays = 1`
    /// this returns midnight at the start of "day after tomorrow", so the
    /// query window covers all of today + tomorrow.
    private func endOfWindow() -> Date {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let days = max(1, preferences.lookaheadDays)
        return cal.date(byAdding: .day, value: days + 1, to: startOfToday) ?? Date().addingTimeInterval(86_400)
    }
}
