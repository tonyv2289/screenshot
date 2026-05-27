import Foundation

enum ScreenshotRollV2Paths {
    private static let folderName = "ScreenshotRollV2"

    static func baseDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
        try ensureDirectory(base)
        return base
    }

    static func imagesDirectory() throws -> URL {
        let directory = try baseDirectory().appendingPathComponent("Images", isDirectory: true)
        try ensureDirectory(directory)
        return directory
    }

    static func metadataURL() throws -> URL {
        try baseDirectory().appendingPathComponent("library.json")
    }

    static func imageURL(for storedFilename: String) throws -> URL {
        try imagesDirectory().appendingPathComponent(storedFilename)
    }

    private static func ensureDirectory(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
        }
    }
}