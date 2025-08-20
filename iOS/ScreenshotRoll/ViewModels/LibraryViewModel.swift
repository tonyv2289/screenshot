import Foundation
import SwiftUI

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var assets: [Asset] = []
    @Published var query: String = ""
    @Published var selectedKinds: Set<AssetKind> = []
    @Published var selectedTickers: Set<String> = []
    @Published var dateRange = DateRangeFilter(start: nil, end: nil)
    @Published var sortByDate: Bool = true
    @Published var includeDuplicates: Bool = false
    @Published var isImporting: Bool = false
    @Published var importProgress: Double = 0
    @Published var topTickerChips: [String] = []
    @AppStorage("sortByDate") var storedSortByDate: Bool = true

    func runSearch() {
        sortByDate = storedSortByDate
        let result = DatabaseService.shared.search(
            query: query,
            kindFilters: Array(selectedKinds),
            tickers: Array(selectedTickers),
            dateRange: dateRange,
            sortByDate: sortByDate,
            includeDuplicates: includeDuplicates
        )
        self.assets = result
        self.topTickerChips = DatabaseService.shared.topTickers(limit: 8)
    }

    func importImages(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        isImporting = true
        importProgress = 0
        let batchId = UUID().uuidString
        let total = Double(images.count)
        var completed = 0.0

        for image in images {
            do {
                let saved = try ImportService.shared.saveImageToLibrary(image)
                await IndexingService.processImportedImage(image, source: .picker, importBatchId: batchId, savedURL: saved.savedURL, width: saved.width, height: saved.height)
            } catch {
                Loggers.importFlow.error("Import failed: \(error.localizedDescription)")
            }
            completed += 1
            importProgress = completed / total
        }
        isImporting = false
        runSearch()
    }

    func toggleSort() {
        sortByDate.toggle()
        storedSortByDate = sortByDate
        runSearch()
    }
}

