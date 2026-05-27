import Foundation

enum ScreenshotCategory: String, Codable, CaseIterable, Identifiable {
    case document
    case chart
    case social
    case receipt
    case meme
    case interface
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .document: return "Document"
        case .chart: return "Chart"
        case .social: return "Social"
        case .receipt: return "Receipt"
        case .meme: return "Meme"
        case .interface: return "UI"
        case .unknown: return "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .document: return "doc.text"
        case .chart: return "chart.xyaxis.line"
        case .social: return "bubble.left.and.bubble.right"
        case .receipt: return "receipt"
        case .meme: return "face.smiling"
        case .interface: return "square.grid.2x2"
        case .unknown: return "questionmark.circle"
        }
    }
}

enum ScreenshotImportSource: String, Codable {
    case photoPicker = "photo_picker"
}

enum LibrarySortMode: String, CaseIterable, Identifiable {
    case newest
    case relevance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return "Newest"
        case .relevance: return "Relevance"
        }
    }
}