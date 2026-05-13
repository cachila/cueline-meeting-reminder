import Foundation
import Combine

@MainActor
final class CalendarSelection: ObservableObject {
    @Published var includedIdentifiers: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(includedIdentifiers), forKey: key)
        }
    }
    private let key = "cueline.includedCalendarIDs"

    init() {
        if let arr = UserDefaults.standard.array(forKey: key) as? [String] {
            self.includedIdentifiers = Set(arr)
        } else {
            self.includedIdentifiers = []  // empty = "all"
        }
    }

    func toggle(_ identifier: String, include: Bool) {
        if include {
            includedIdentifiers.insert(identifier)
        } else {
            includedIdentifiers.remove(identifier)
        }
    }

    /// nil means "all calendars" — empty selection is treated as "all".
    var asFilter: Set<String>? {
        includedIdentifiers.isEmpty ? nil : includedIdentifiers
    }
}
