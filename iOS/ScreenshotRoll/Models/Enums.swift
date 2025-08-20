import Foundation

enum AssetKind: String, Codable, CaseIterable, Identifiable {
    case tweet
    case chart
    case meme
    case receipt
    case doc
    case unknown

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .tweet: return "Tweet/X"
        case .chart: return "Chart"
        case .meme: return "Meme"
        case .receipt: return "Receipt"
        case .doc: return "Doc"
        case .unknown: return "Unknown"
        }
    }
}

enum AssetSource: String, Codable {
    case picker
    case share
    case files
}

struct DateRangeFilter: Equatable {
    var start: Date?
    var end: Date?
}

