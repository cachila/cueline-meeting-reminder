import Foundation
import Combine

@MainActor
final class Preferences: ObservableObject {
    @Published var leadTimeMinutes: Int {
        didSet { UserDefaults.standard.set(leadTimeMinutes, forKey: "cueline.leadTimeMinutes") }
    }
    @Published var copyLinkOnNotify: Bool {
        didSet { UserDefaults.standard.set(copyLinkOnNotify, forKey: "cueline.copyLinkOnNotify") }
    }
    @Published var pollSeconds: Int {
        didSet { UserDefaults.standard.set(pollSeconds, forKey: "cueline.pollSeconds") }
    }
    /// N=1 includes today + tomorrow, N=2 adds the day after, etc.
    @Published var lookaheadDays: Int {
        didSet { UserDefaults.standard.set(lookaheadDays, forKey: "cueline.lookaheadDays") }
    }

    init() {
        let d = UserDefaults.standard
        if d.object(forKey: "cueline.leadTimeMinutes") == nil { d.set(2, forKey: "cueline.leadTimeMinutes") }
        if d.object(forKey: "cueline.copyLinkOnNotify") == nil { d.set(false, forKey: "cueline.copyLinkOnNotify") }
        if d.object(forKey: "cueline.pollSeconds") == nil { d.set(120, forKey: "cueline.pollSeconds") }
        if d.object(forKey: "cueline.lookaheadDays") == nil { d.set(5, forKey: "cueline.lookaheadDays") }
        self.leadTimeMinutes = d.integer(forKey: "cueline.leadTimeMinutes")
        self.copyLinkOnNotify = d.bool(forKey: "cueline.copyLinkOnNotify")
        self.pollSeconds = d.integer(forKey: "cueline.pollSeconds")
        self.lookaheadDays = d.integer(forKey: "cueline.lookaheadDays")
    }
}
