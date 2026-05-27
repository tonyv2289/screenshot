import UIKit

struct ShareInboxProcessResult {
    let importedCount: Int
    let skippedDuplicateCount: Int
    let failedCount: Int
    let remainingCount: Int

    var didChangeLibrary: Bool {
        importedCount > 0 || skippedDuplicateCount > 0
    }
}

enum ShareInboxProcessor {
    @MainActor
    static func processPending() async -> ShareInboxProcessResult {
        let pendingItems = ScreenshotInboxStore.pendingItems()
        guard !pendingItems.isEmpty else {
            return ShareInboxProcessResult(importedCount: 0, skippedDuplicateCount: 0, failedCount: 0, remainingCount: 0)
        }

        let batchId = "share-\(UUID().uuidString)"
        var importedCount = 0
        var skippedDuplicateCount = 0
        var failedCount = 0

        for item in pendingItems {
            do {
                let data = try Data(contentsOf: item.imageURL)
                let saved = try ImportService.shared.saveImageDataToLibrary(
                    data,
                    preferredExtension: item.imageURL.pathExtension
                )

                if DatabaseService.shared.getAsset(byFilePath: saved.savedURL.path) != nil {
                    skippedDuplicateCount += 1
                    ScreenshotInboxStore.markProcessed(item)
                    continue
                }

                let currentCount = DatabaseService.shared.totalAssetCount()
                guard StoreService.shared.allowedImportCount(requested: 1, currentCount: currentCount) > 0 else {
                    if saved.didCreateFile {
                        try? FileManager.default.removeItem(at: saved.savedURL)
                    }
                    break
                }

                guard let image = ImportService.shared.image(from: saved) else {
                    throw ImportService.ImportError.invalidImageData
                }

                await IndexingService.processImportedImage(
                    image,
                    source: .share,
                    importBatchId: batchId,
                    savedURL: saved.savedURL,
                    width: saved.width,
                    height: saved.height
                )
                importedCount += 1
                ScreenshotInboxStore.markProcessed(item)
            } catch {
                failedCount += 1
                Loggers.importFlow.error("Failed to process shared screenshot \(item.id): \(error.localizedDescription)")
                ScreenshotInboxStore.quarantine(item)
            }
        }

        let remainingCount = ScreenshotInboxStore.pendingItems().count
        return ShareInboxProcessResult(
            importedCount: importedCount,
            skippedDuplicateCount: skippedDuplicateCount,
            failedCount: failedCount,
            remainingCount: remainingCount
        )
    }
}
