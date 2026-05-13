import Foundation

enum MeetingProvider: String, Codable {
    case zoom
    case googleMeet
    case microsoftTeams

    var displayName: String {
        switch self {
        case .zoom: return "Zoom"
        case .googleMeet: return "Google Meet"
        case .microsoftTeams: return "Microsoft Teams"
        }
    }
}

struct MeetingLink: Hashable, Codable {
    let provider: MeetingProvider
    let url: URL
}
