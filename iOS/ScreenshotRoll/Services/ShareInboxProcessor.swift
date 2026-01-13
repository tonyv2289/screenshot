import UIKit

enum ShareInboxProcessor {
    static func processPending() async {
        let inbox = SharedContainer.sharedInboxURL()
        guard let files = try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension.lowercased() == "jpg" || file.pathExtension.lowercased() == "png" {
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

