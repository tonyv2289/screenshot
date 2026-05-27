import UIKit

final class ImportService {
    static let shared = ImportService()
    private init() {}

    struct ImportResult {
        let savedURL: URL
        let width: Int
        let height: Int
        let contentHash: String
        let didCreateFile: Bool
    }

    enum ImportError: Error {
        case invalidImageData
        case emptyEncodedImage
    }

    func saveImageToLibrary(_ image: UIImage) throws -> ImportResult {
        guard let data = image.jpegData(compressionQuality: 0.95), !data.isEmpty else {
            throw ImportError.emptyEncodedImage
        }
        return try saveImageDataToLibrary(data, preferredExtension: "jpg")
    }

    func saveImageDataToLibrary(_ data: Data, preferredExtension: String? = nil) throws -> ImportResult {
        guard let image = UIImage(data: data) else {
            throw ImportError.invalidImageData
        }

        let contentHash = HashingService.sha256Hex(data)
        let fileExtension = fileExtension(for: data, preferredExtension: preferredExtension)
        let targetDir = SharedContainer.assetsDirectoryURL()
        let filename = "\(contentHash).\(fileExtension)"
        let url = targetDir.appendingPathComponent(filename)

        let didCreateFile: Bool
        if FileManager.default.fileExists(atPath: url.path) {
            didCreateFile = false
        } else {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            didCreateFile = true
        }

        return ImportResult(
            savedURL: url,
            width: Int(image.size.width),
            height: Int(image.size.height),
            contentHash: contentHash,
            didCreateFile: didCreateFile
        )
    }

    func image(from result: ImportResult) -> UIImage? {
        UIImage(contentsOfFile: result.savedURL.path)
    }

    private func fileExtension(for data: Data, preferredExtension: String?) -> String {
        if let preferredExtension = sanitizeExtension(preferredExtension) {
            return preferredExtension
        }

        let bytes = Array(data.prefix(12))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if bytes.starts(with: [0xFF, 0xD8]) { return "jpg" }
        if bytes.starts(with: [0x47, 0x49, 0x46]) { return "gif" }
        if bytes.count >= 12,
           String(bytes: bytes[4..<12], encoding: .ascii)?.contains("ftyp") == true {
            return "heic"
        }
        return "img"
    }

    private func sanitizeExtension(_ value: String?) -> String? {
        guard let value else { return nil }
        let sanitized = value
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .lowercased()
        guard !sanitized.isEmpty, sanitized.count <= 8 else { return nil }
        return sanitized
    }
}
