import Foundation
import SwiftUI
import Combine

// MARK: - Constants

enum ImportConstants {
    static let maxPhotoPickerItems = 200
    static let topTickerChipsCount = 8
}

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
    @Published var importTotal: Int = 0
    @Published var importCompleted: Int = 0
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
        self.topTickerChips = DatabaseService.shared.topTickers(limit: ImportConstants.topTickerChipsCount)
    }

    /// Starts the import process for the given number of items.
    /// Call `importSingleImage` for each image to process.
    func beginImport(totalCount: Int) {
        guard totalCount > 0 else { return }
        isImporting = true
        importProgress = 0
        importTotal = totalCount
        importCompleted = 0
    }

    /// Imports a single image. Call this in a loop to avoid loading all images into memory.
    func importSingleImage(_ image: UIImage, batchId: String) async {
        do {
            let saved = try ImportService.shared.saveImageToLibrary(image)
            if DatabaseService.shared.getAsset(byFilePath: saved.savedURL.path) != nil {
                importCompleted += 1
                importProgress = Double(importCompleted) / Double(importTotal)
                return
            }
            await IndexingService.processImportedImage(
                image,
                source: .picker,
                importBatchId: batchId,
                savedURL: saved.savedURL,
                width: saved.width,
                height: saved.height
            )
        } catch {
            Loggers.importFlow.error("Import failed: \(error.localizedDescription)")
        }

        importCompleted += 1
        importProgress = Double(importCompleted) / Double(importTotal)
    }

    func importSingleImageData(_ data: Data, batchId: String, preferredExtension: String? = nil) async {
        do {
            let saved = try ImportService.shared.saveImageDataToLibrary(data, preferredExtension: preferredExtension)
            if DatabaseService.shared.getAsset(byFilePath: saved.savedURL.path) != nil {
                importCompleted += 1
                importProgress = Double(importCompleted) / Double(importTotal)
                return
            }
            guard let image = ImportService.shared.image(from: saved) else {
                throw ImportService.ImportError.invalidImageData
            }
            await IndexingService.processImportedImage(
                image,
                source: .picker,
                importBatchId: batchId,
                savedURL: saved.savedURL,
                width: saved.width,
                height: saved.height
            )
        } catch {
            Loggers.importFlow.error("Import failed: \(error.localizedDescription)")
        }

        importCompleted += 1
        importProgress = Double(importCompleted) / Double(importTotal)
    }

    /// Ends the import process and refreshes the search.
    func endImport() {
        isImporting = false
        importProgress = 0
        importTotal = 0
        importCompleted = 0
        runSearch()
    }

    // Legacy method for backwards compatibility (processes all at once)
    func importImages(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        let batchId = UUID().uuidString
        beginImport(totalCount: images.count)

        for image in images {
            await importSingleImage(image, batchId: batchId)
        }

        endImport()
    }

    func toggleSort() {
        sortByDate.toggle()
        storedSortByDate = sortByDate
        runSearch()
    }
}
