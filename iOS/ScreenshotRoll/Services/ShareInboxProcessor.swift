import UIKit

enum ShareInboxProcessor {
    @MainActor
    static func processPending() async {
        let inbox = SharedContainer.sharedInboxURL()
        guard let files = try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil) else { return }
        let importableFiles = files.filter {
            let ext = $0.pathExtension.lowercased()
            return ext == "jpg" || ext == "png"
        }
        let currentCount = DatabaseService.shared.totalAssetCount()
        let allowedCount = StoreService.shared.allowedImportCount(requested: importableFiles.count, currentCount: currentCount)

        for file in importableFiles.prefix(allowedCount) {
            if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
                let saved = try? ImportService.shared.saveImageToLibrary(image)
                if let saved {
                    await IndexingService.processImportedImage(image, source: .share, importBatchId: "share-\(UUID().uuidString)", savedURL: saved.savedURL, width: saved.width, height: saved.height)
                }
            }
            try? FileManager.default.removeItem(at: file)
        }
    }
}
