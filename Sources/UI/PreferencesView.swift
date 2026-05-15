import SwiftUI
import EventKit

struct PreferencesView: View {
    @EnvironmentObject var preferences: Preferences
    @EnvironmentObject var selection: CalendarSelection
    @EnvironmentObject var events: EventStore

    var onGrantAccess: () -> Void

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            calendarsTab
                .tabItem { Label("Calendars", systemImage: "calendar") }
        }
        .padding(20)
        .frame(width: 500, height: 420)
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                Stepper(value: $preferences.leadTimeMinutes, in: 0...60) {
                    HStack {
                        Text("Notify before event:")
                        Text("\(preferences.leadTimeMinutes) min")
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Copy meeting link to clipboard on notification", isOn: $preferences.copyLinkOnNotify)
                Stepper(value: $preferences.pollSeconds, in: 60...900, step: 30) {
                    HStack {
                        Text("Refresh every:")
                        Text("\(preferences.pollSeconds)s")
                            .foregroundStyle(.secondary)
                    }
                }
                Stepper(value: $preferences.lookaheadDays, in: 1...14) {
                    HStack {
                        Text("Days to look ahead:")
                        Text("\(preferences.lookaheadDays) \(preferences.lookaheadDays == 1 ? "day" : "days")")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let err = events.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(4)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var calendarsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            let auth = events.provider.authState
            switch auth {
            case .granted:
                grantedCalendarsList
            case .undetermined:
                accessPrompt(message: "Cueline can read events from your Mac's Calendar.app. Click below to grant permission.", actionLabel: "Grant Calendar Access")
            case .denied:
                accessPrompt(message: "Calendar access was denied. Open System Settings → Privacy & Security → Calendars and enable Cueline.", actionLabel: "Open System Settings")
            case .restricted:
                Text("Calendar access is restricted on this Mac (parental controls or MDM).")
                    .foregroundStyle(.red)
            case .writeOnly:
                accessPrompt(message: "Cueline was granted write-only calendar access. Reset it in System Settings → Privacy & Security → Calendars and try again.", actionLabel: "Open System Settings")
            }
            Spacer()
        }
    }

    private var grantedCalendarsList: some View {
        let calendars = events.provider.calendars()
        let allIDs = calendars.map(\.calendarIdentifier)
        let grouped = Dictionary(grouping: calendars) { $0.source.title }
        let groupKeys = grouped.keys.sorted()
        let everySelected = selection.includedIdentifiers.isEmpty

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(everySelected
                    ? "All calendars are included."
                    : "\(selection.includedIdentifiers.count) of \(calendars.count) calendars included.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !everySelected {
                    Button("Include all") {
                        selection.includedIdentifiers.removeAll()
                    }
                    .buttonStyle(.borderless)
                }
            }

            List {
                ForEach(groupKeys, id: \.self) { source in
                    Section(source) {
                        ForEach(grouped[source] ?? [], id: \.calendarIdentifier) { cal in
                            CalendarRow(calendar: cal, allCalendarIDs: allIDs, selection: selection)
                        }
                    }
                }
            }
            .listStyle(.bordered)
            .frame(minHeight: 200)
        }
    }

    private func accessPrompt(message: String, actionLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button(actionLabel, action: onGrantAccess)
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 20)
    }
}

struct CalendarRow: View {
    let calendar: EKCalendar
    let allCalendarIDs: [String]
    @ObservedObject var selection: CalendarSelection

    var body: some View {
        let included = selection.includedIdentifiers.isEmpty
            || selection.includedIdentifiers.contains(calendar.calendarIdentifier)
        Toggle(isOn: Binding(
            get: { included },
            set: { newValue in
                // Seed the set when the user first opts out from the implicit "all" state.
                if selection.includedIdentifiers.isEmpty {
                    selection.includedIdentifiers = Set(allCalendarIDs)
                }
                selection.toggle(calendar.calendarIdentifier, include: newValue)
                // Collapse "everything selected" back to "empty = all".
                if Set(allCalendarIDs) == selection.includedIdentifiers {
                    selection.includedIdentifiers.removeAll()
                }
            }
        )) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(nsColor: calendar.cgColor.map { NSColor(cgColor: $0) ?? .systemGray } ?? .systemGray))
                    .frame(width: 10, height: 10)
                Text(calendar.title)
            }
        }
    }
}
