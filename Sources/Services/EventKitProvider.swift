import Foundation
import EventKit

enum EventKitError: LocalizedError {
    case denied
    case restricted
    case writeOnly
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .denied: return "Cueline doesn't have permission to read your calendars. Grant access in System Settings → Privacy & Security → Calendars."
        case .restricted: return "Calendar access is restricted on this Mac (parental controls or MDM)."
        case .writeOnly: return "Cueline was only granted write-only calendar access. Reset the permission in System Settings → Privacy & Security → Calendars and try again."
        case .underlying(let err): return err.localizedDescription
        }
    }
}

@MainActor
final class EventKitProvider {
    let store = EKEventStore()

    enum AuthState {
        case undetermined
        case granted
        case denied
        case restricted
        case writeOnly  // macOS 14+ can grant write-only
    }

    var authState: AuthState {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined: return .undetermined
        case .denied: return .denied
        case .restricted: return .restricted
        case .authorized: return .granted
        case .fullAccess: return .granted
        case .writeOnly: return .writeOnly
        @unknown default: return .denied
        }
    }

    func requestAuthorization() async throws -> AuthState {
        if #available(macOS 14.0, *) {
            do {
                let granted = try await store.requestFullAccessToEvents()
                return granted ? .granted : .denied
            } catch {
                throw EventKitError.underlying(error)
            }
        } else {
            return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AuthState, Error>) in
                store.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        cont.resume(throwing: EventKitError.underlying(error))
                    } else {
                        cont.resume(returning: granted ? .granted : .denied)
                    }
                }
            }
        }
    }

    func calendars() -> [EKCalendar] {
        store.calendars(for: .event).sorted {
            ($0.source.title, $0.title) < ($1.source.title, $1.title)
        }
    }

    func fetchUpcoming(until end: Date, includedCalendarIDs: Set<String>?) -> [CalendarEvent] {
        let allCalendars = store.calendars(for: .event)
        let included: [EKCalendar]
        if let ids = includedCalendarIDs, !ids.isEmpty {
            included = allCalendars.filter { ids.contains($0.calendarIdentifier) }
        } else {
            included = allCalendars
        }
        guard !included.isEmpty else { return [] }

        let now = Date()
        guard end > now else { return [] }
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: included)
        let raw = store.events(matching: predicate)

        return raw.compactMap { event -> CalendarEvent? in
            guard let identifier = event.eventIdentifier, !identifier.isEmpty else { return nil }
            guard let start = event.startDate, let end = event.endDate else { return nil }
            // Organizer-side cancellation
            if let status = event.status as EKEventStatus?, status == .canceled { return nil }
            // The current user RSVPed "No" — don't notify for meetings you've declined.
            if let attendees = event.attendees,
               let me = attendees.first(where: { $0.isCurrentUser }),
               me.participantStatus == .declined {
                return nil
            }

            let candidates: [String?] = [
                event.url?.absoluteString,
                event.location,
                event.notes,
            ]
            let link = MeetingLinkParser.first(in: candidates)

            return CalendarEvent(
                id: identifier,
                calendarTitle: event.calendar.title,
                sourceTitle: event.calendar.source.title,
                title: event.title ?? "(no title)",
                start: start,
                end: end,
                meetingLink: link,
                location: event.location
            )
        }
        .sorted { $0.start < $1.start }
    }
}
