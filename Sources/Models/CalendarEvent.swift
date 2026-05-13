import Foundation

struct CalendarEvent: Identifiable, Hashable {
    let id: String              // stable: EventKit eventIdentifier
    let calendarTitle: String   // e.g. "Work"
    let sourceTitle: String     // e.g. "you@company.com" (Google source) or "iCloud"
    let title: String
    let start: Date
    let end: Date
    let meetingLink: MeetingLink?
    let location: String?

    var isAllDay: Bool {
        let cal = Calendar.current
        return cal.startOfDay(for: start) == start && end.timeIntervalSince(start) >= 86_400 - 1
    }
}
