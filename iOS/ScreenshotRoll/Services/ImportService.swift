import UIKit

final class ImportService {
    static let shared = ImportService()
    private init() {}

    struct ImportResult {
        let savedURL: URL
        let width: Int
        let height: Int
    }

    func saveImageToLibrary(_ image: UIImage) throws -> ImportResult {
        let targetDir = SharedContainer.assetsDirectoryURL()
        let filename = UUID().uuidString + ".jpg"
        let url = targetDir.appendingPathComponent(filename)
        let data = image.jpegData(compressionQuality: 0.95) ?? Data()
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return ImportResult(savedURL: url, width: Int(image.size.width), height: Int(image.size.height))
    }
}

