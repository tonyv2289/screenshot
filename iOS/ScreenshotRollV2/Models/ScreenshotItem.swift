import Foundation

struct ScreenshotItem: Identifiable, Codable, Hashable {
    let id: UUID
    let importedAt: Date
    let originalFilename: String
    let storedFilename: String
    let pixelWidth: Int
    let pixelHeight: Int
    let source: ScreenshotImportSource
    let exactHash: String
    var category: ScreenshotCategory
    let extractedText: String
    let tags: [String]
    let isDuplicate: Bool
    let originalItemID: UUID?

    var searchableText: String {
        ([category.title] + tags + [extractedText])
            .joined(separator: " ")
            .lowercased()
    }

    var aspectRatio: Double {
        guard pixelHeight > 0 else { return 1 }
        return Double(pixelWidth) / Double(pixelHeight)
    }
}

struct ScreenshotLibrarySnapshot: Codable {
    var schemaVersion: Int = 1
    var items: [ScreenshotItem] = []
}