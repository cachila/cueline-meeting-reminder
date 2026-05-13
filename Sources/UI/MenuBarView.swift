import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var events: EventStore
    @EnvironmentObject var selection: CalendarSelection

    var permissionGranted: Bool
    var onOpenPreferences: () -> Void
    var onRefresh: () -> Void
    var onQuit: () -> Void
    var onGrantAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if !permissionGranted {
                permissionPrompt
            } else if events.events.isEmpty {
                emptyEvents
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedEvents, id: \.0) { day, items in
                            Text(day)
                                .font(.caption.smallCaps())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                            ForEach(items) { event in
                                EventRow(event: event)
                                    .padding(.horizontal, 8)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 360)
            }

            Divider()
            footer
        }
        .frame(width: 360)
    }

    private var header: some View {
        HStack {
            Text("Cueline")
                .font(.headline)
            Spacer()
            if events.refreshing {
                ProgressView()
                    .controlSize(.small)
            } else if let last = events.lastRefresh {
                Text(relativeDate(last))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var permissionPrompt: some View {
        VStack(alignment: .center, spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Cueline needs access to your Mac's calendars")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Grant Calendar Access", action: onGrantAccess)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var emptyEvents: some View {
        VStack(alignment: .center, spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("Nothing on the calendar in the next 24h")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var footer: some View {
        HStack {
            Button("Preferences…", action: onOpenPreferences)
                .buttonStyle(.borderless)
            Spacer()
            Button("Quit", action: onQuit)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var groupedEvents: [(String, [CalendarEvent])] {
        let cal = Calendar.current
        let now = Date()
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .none

        let grouped = Dictionary(grouping: events.events.filter { $0.end > now }) { event in
            cal.startOfDay(for: event.start)
        }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (f.string(from: $0.key), $0.value.sorted { $0.start < $1.start }) }
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing) {
                Text(timeString)
                    .font(.system(.body, design: .monospaced))
                Text(durationString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.body)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let provider = event.meetingLink?.provider {
                        ProviderBadge(provider: provider)
                    }
                    Text(event.calendarTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()

            if let link = event.meetingLink {
                Button("Join") {
                    NSWorkspace.shared.open(link.url)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: event.start)
    }

    private var durationString: String {
        let mins = Int((event.end.timeIntervalSince(event.start)) / 60)
        if mins < 60 { return "\(mins)m" }
        let h = mins / 60
        let m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}

struct ProviderBadge: View {
    let provider: MeetingProvider

    var body: some View {
        Text(provider.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch provider {
        case .zoom: return .blue
        case .googleMeet: return .green
        case .microsoftTeams: return .purple
        }
    }
}
