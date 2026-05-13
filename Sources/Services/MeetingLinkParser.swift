import Foundation

enum MeetingLinkParser {
    private static let patterns: [(MeetingProvider, NSRegularExpression)] = {
        let raw: [(MeetingProvider, String)] = [
            (.zoom, #"https?://[\w.-]*zoom\.us/(?:j|s|w|my)/[^\s<>"']+"#),
            (.googleMeet, #"https?://meet\.google\.com/[a-z0-9-]+(?:\?[^\s<>"']*)?"#),
            (.microsoftTeams, #"https?://teams\.(?:microsoft|live)\.com/(?:l/meetup-join|meet)/[^\s<>"']+"#),
        ]
        return raw.map { provider, pattern in
            // swiftlint:disable:next force_try
            (provider, try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))
        }
    }()

    static func first(in candidates: [String?]) -> MeetingLink? {
        for candidate in candidates {
            guard let text = candidate, !text.isEmpty else { continue }
            if let link = first(in: text) { return link }
        }
        return nil
    }

    static func first(in text: String) -> MeetingLink? {
        let range = NSRange(text.startIndex..., in: text)
        for (provider, regex) in patterns {
            guard let match = regex.firstMatch(in: text, options: [], range: range),
                  let r = Range(match.range, in: text) else { continue }
            let raw = String(text[r])
            let cleaned = cleanup(raw)
            guard let url = URL(string: cleaned) else { continue }
            return MeetingLink(provider: provider, url: url)
        }
        return nil
    }

    private static func cleanup(_ url: String) -> String {
        var s = url
        while let last = s.last, ".,;:)]}>".contains(last) { s.removeLast() }
        return s
    }
}
