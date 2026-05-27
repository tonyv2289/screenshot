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

    var icon: String {
        switch self {
        case .tweet: return "bubble.left"
        case .chart: return "chart.line.uptrend.xyaxis"
        case .meme: return "face.smiling"
        case .receipt: return "receipt"
        case .doc: return "doc.text"
        case .unknown: return "questionmark.circle"
        }
    }
}

enum AssetSource: String, Codable {
    case picker
    case share
    case files

    var displayName: String {
        switch self {
        case .picker: return "Photos Import"
        case .share: return "Share Sheet"
        case .files: return "Files"
        }
    }

    var icon: String {
        switch self {
        case .picker: return "photo.on.rectangle"
        case .share: return "square.and.arrow.up"
        case .files: return "folder"
        }
    }
}

struct DateRangeFilter: Equatable {
    var start: Date?
    var end: Date?
}
