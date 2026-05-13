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
    private let lookaheadSeconds: TimeInterval = 60 * 60 * 24  // 24h

    init(provider: EventKitProvider, selection: CalendarSelection) {
        self.provider = provider
        self.selection = selection
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

        let events = provider.fetchUpcoming(
            within: lookaheadSeconds,
            includedCalendarIDs: selection.asFilter
        )
        self.events = events
        self.lastRefresh = Date()
        self.lastError = nil
    }
}
