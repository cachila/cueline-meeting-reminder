import AppKit
import SwiftUI
import Combine
import EventKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = Preferences()
    let selection = CalendarSelection()
    let provider = EventKitProvider()
    lazy var events = EventStore(provider: provider, selection: selection)

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var prefsWindow: NSWindow?
    private var pollTask: Task<Void, Never>?
    private var tickTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationScheduler.shared.bootstrap(preferences: preferences)
        setupStatusItem()
        setupPopover()
        observeEvents()
        observeSelection()
        observeEventStoreChanges()
        startTicker()
        startPolling()
        observeWake()

        Task {
            await requestAuthorizationIfNeeded()
            await events.refresh()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTask?.cancel()
        tickTimer?.invalidate()
    }

    // MARK: - Authorization

    private func requestAuthorizationIfNeeded() async {
        guard provider.authState == .undetermined else { return }
        _ = try? await provider.requestAuthorization()
    }

    private func handleGrantAccess() {
        switch provider.authState {
        case .undetermined:
            Task {
                _ = try? await provider.requestAuthorization()
                await events.refresh()
            }
        case .denied, .writeOnly, .restricted:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
            }
        case .granted:
            Task { await events.refresh() }
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: "Cueline")
        button.image?.isTemplate = true
        button.imagePosition = .imageLeft
        button.action = #selector(togglePopover(_:))
        button.target = self
        updateStatusTitle()
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 480)
        let view = MenuBarView(
            permissionGranted: provider.authState == .granted,
            onOpenPreferences: { [weak self] in self?.openPreferences() },
            onRefresh: { [weak self] in
                guard let self = self else { return }
                Task { await self.events.refresh() }
            },
            onQuit: { NSApp.terminate(nil) },
            onGrantAccess: { [weak self] in self?.handleGrantAccess() }
        )
        .environmentObject(events)
        .environmentObject(selection)
        popover.contentViewController = NSHostingController(rootView: view)
    }

    private func refreshPopover() {
        let view = MenuBarView(
            permissionGranted: provider.authState == .granted,
            onOpenPreferences: { [weak self] in self?.openPreferences() },
            onRefresh: { [weak self] in
                guard let self = self else { return }
                Task { await self.events.refresh() }
            },
            onQuit: { NSApp.terminate(nil) },
            onGrantAccess: { [weak self] in self?.handleGrantAccess() }
        )
        .environmentObject(events)
        .environmentObject(selection)
        popover.contentViewController = NSHostingController(rootView: view)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            refreshPopover()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Polling & observation

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }
                let seconds = max(60, self.preferences.pollSeconds)
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                if Task.isCancelled { return }
                await self.events.refresh()
            }
        }
    }

    private func observeWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in await self.events.refresh() }
        }
    }

    private func observeEventStoreChanges() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: provider.store,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in await self.events.refresh() }
        }
    }

    private func startTicker() {
        tickTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateStatusTitle() }
        }
    }

    private func observeEvents() {
        events.$events
            .receive(on: RunLoop.main)
            .sink { [weak self] events in
                self?.updateStatusTitle(events: events)
                Task { await NotificationScheduler.shared.sync(events: events) }
            }
            .store(in: &cancellables)
    }

    private func observeSelection() {
        selection.$includedIdentifiers
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { await self.events.refresh() }
            }
            .store(in: &cancellables)
    }

    private func updateStatusTitle(events: [CalendarEvent]? = nil) {
        let events = events ?? self.events.events
        let now = Date()
        guard let next = events.first(where: { $0.end > now }) else {
            statusItem.button?.title = ""
            return
        }
        let mins = Int(ceil(next.start.timeIntervalSince(now) / 60))
        let text: String
        if mins <= 0 {
            text = "live"
        } else if mins < 60 {
            text = "\(mins)m"
        } else {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            text = f.string(from: next.start)
        }
        statusItem.button?.title = " " + text
    }

    // MARK: - Preferences window

    private func openPreferences() {
        if prefsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 440),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Cueline Preferences"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: PreferencesView(onGrantAccess: { [weak self] in self?.handleGrantAccess() })
                    .environmentObject(preferences)
                    .environmentObject(selection)
                    .environmentObject(events)
            )
            prefsWindow = window
        }
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        prefsWindow?.makeKeyAndOrderFront(nil)
    }
}
