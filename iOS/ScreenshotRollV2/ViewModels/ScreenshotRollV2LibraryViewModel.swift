import Foundation
import PhotosUI

struct LibraryStats {
    let totalCount: Int
    let textReadyCount: Int
    let duplicateCount: Int
}

@MainActor
final class ScreenshotRollV2LibraryViewModel: ObservableObject {
    @Published private(set) var items: [ScreenshotItem] = []
    @Published var query: String = ""
    @Published var selectedCategory: ScreenshotCategory?
    @Published var sortMode: LibrarySortMode = .newest
    @Published var showsDuplicates: Bool = true
    @Published var isImporting: Bool = false
    @Published var importCompleted: Int = 0
    @Published var importTotal: Int = 0
    @Published var statusMessage: String?

    private let store: LibraryStore
    private let importer: ImportPipeline

    init(store: LibraryStore = .shared, importer: ImportPipeline = .shared) {
        self.store = store
        self.importer = importer
    }

    var stats: LibraryStats {
        LibraryStats(
            totalCount: items.count,
            textReadyCount: items.filter { !$0.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count,
            duplicateCount: items.filter(\.isDuplicate).count
        )
    }

    var availableCategories: [ScreenshotCategory] {
        ScreenshotCategory.allCases.filter { category in
            items.contains { $0.category == category }
        }
    }

    var filteredItems: [ScreenshotItem] {
        let normalizedTokens = query
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }

        return items
            .filter { item in
                guard showsDuplicates || !item.isDuplicate else { return false }
                guard selectedCategory == nil || item.category == selectedCategory else { return false }
                guard !normalizedTokens.isEmpty else { return true }
                return normalizedTokens.allSatisfy { item.searchableText.contains($0) }
            }
            .sorted { lhs, rhs in
                switch sortMode {
                case .newest:
                    return lhs.importedAt > rhs.importedAt
                case .relevance:
                    let lhsScore = relevanceScore(for: lhs, tokens: normalizedTokens)
                    let rhsScore = relevanceScore(for: rhs, tokens: normalizedTokens)
                    if lhsScore == rhsScore {
                        return lhs.importedAt > rhs.importedAt
                    }
                    return lhsScore > rhsScore
                }
            }
    }

    func refresh() async {
        do {
            items = try await store.loadItems()
        } catch {
            statusMessage = "Could not load the local library."
        }
    }

    func importItems(from pickerItems: [PhotosPickerItem]) async {
        guard !pickerItems.isEmpty else { return }

        isImporting = true
        importCompleted = 0
        importTotal = pickerItems.count
        statusMessage = nil

        var importedCount = 0
        var duplicateCount = 0
        var failureCount = 0

        for item in pickerItems {
            do {
                let importedItem = try await importer.importPickerItem(item)
                importedCount += 1
                if importedItem.isDuplicate {
                    duplicateCount += 1
                }
            } catch {
                failureCount += 1
            }

            importCompleted += 1
        }

        await refresh()
        isImporting = false
        statusMessage = importSummary(importedCount: importedCount, duplicateCount: duplicateCount, failureCount: failureCount)
    }

    func updateCategory(for itemID: UUID, to category: ScreenshotCategory) async {
        do {
            try await store.updateCategory(category, for: itemID)
            await refresh()
        } catch {
            statusMessage = "Could not save that category change."
        }
    }

    func deleteAll() async {
        do {
            try await store.deleteAll()
            await refresh()
            statusMessage = "Deleted the v2 library."
        } catch {
            statusMessage = "Could not clear the v2 library."
        }
    }

    func imageURL(for item: ScreenshotItem) -> URL? {
        try? ScreenshotRollV2Paths.imageURL(for: item.storedFilename)
    }

    private func importSummary(importedCount: Int, duplicateCount: Int, failureCount: Int) -> String {
        var parts = ["Imported \(importedCount) screenshot" + (importedCount == 1 ? "" : "s")]
        if duplicateCount > 0 {
            parts.append("\(duplicateCount) exact duplicate" + (duplicateCount == 1 ? "" : "s") + " flagged")
        }
        if failureCount > 0 {
            parts.append("\(failureCount) failed")
        }
        return parts.joined(separator: " • ")
    }

    private func relevanceScore(for item: ScreenshotItem, tokens: [String]) -> Int {
        guard !tokens.isEmpty else { return 0 }
        return tokens.reduce(into: 0) { partialResult, token in
            partialResult += item.searchableText.components(separatedBy: token).count - 1
        }
    }
}