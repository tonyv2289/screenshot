import Foundation

struct ScreenshotInboxManifest: Codable, Identifiable {
    let id: String
    let createdAt: Date
    let imageFilename: String
    let originalSuggestedName: String?
    let originalTypeIdentifier: String?
    let sourceBundleIdentifier: String?
    let byteCount: Int
}

struct ScreenshotInboxItem: Identifiable {
    let manifest: ScreenshotInboxManifest
    let manifestURL: URL
    let imageURL: URL

    var id: String { manifest.id }
}

enum ScreenshotInboxStore {
    enum InboxError: Error {
        case emptyImageData
        case missingImageFile
    }

    private static let manifestExtension = "json"

    static func enqueueImageData(
        _ data: Data,
        suggestedName: String?,
        typeIdentifier: String?,
        sourceBundleIdentifier: String?,
        preferredExtension: String?
    ) throws -> ScreenshotInboxManifest {
        guard !data.isEmpty else { throw InboxError.emptyImageData }

        let inbox = SharedContainer.sharedInboxURL()
        let id = UUID().uuidString
        let fileExtension = sanitizedFileExtension(preferredExtension) ?? "img"
        let imageFilename = "\(id).\(fileExtension)"
        let imageURL = inbox.appendingPathComponent(imageFilename)
        let temporaryImageURL = inbox.appendingPathComponent("\(id).tmp")
        let manifestURL = inbox.appendingPathComponent("\(id).\(manifestExtension)")

        try data.write(to: temporaryImageURL, options: [.atomic, .completeFileProtection])
        if FileManager.default.fileExists(atPath: imageURL.path) {
            try FileManager.default.removeItem(at: imageURL)
        }
        try FileManager.default.moveItem(at: temporaryImageURL, to: imageURL)

        let manifest = ScreenshotInboxManifest(
            id: id,
            createdAt: Date(),
            imageFilename: imageFilename,
            originalSuggestedName: suggestedName,
            originalTypeIdentifier: typeIdentifier,
            sourceBundleIdentifier: sourceBundleIdentifier,
            byteCount: data.count
        )

        let manifestData = try JSONEncoder.screenshotRoll.encode(manifest)
        try manifestData.write(to: manifestURL, options: [.atomic, .completeFileProtection])
        return manifest
    }

    static func pendingItems() -> [ScreenshotInboxItem] {
        let inbox = SharedContainer.sharedInboxURL()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: inbox,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension.lowercased() == manifestExtension }
            .compactMap { manifestURL -> ScreenshotInboxItem? in
                guard let data = try? Data(contentsOf: manifestURL),
                      let manifest = try? JSONDecoder.screenshotRoll.decode(ScreenshotInboxManifest.self, from: data) else {
                    return nil
                }

                let imageURL = inbox.appendingPathComponent(manifest.imageFilename)
                guard FileManager.default.fileExists(atPath: imageURL.path) else { return nil }
                return ScreenshotInboxItem(manifest: manifest, manifestURL: manifestURL, imageURL: imageURL)
            }
            .sorted { $0.manifest.createdAt < $1.manifest.createdAt }
    }

    static func markProcessed(_ item: ScreenshotInboxItem) {
        removeIfPresent(item.imageURL)
        removeIfPresent(item.manifestURL)
    }

    static func quarantine(_ item: ScreenshotInboxItem) {
        let failedDirectory = SharedContainer.failedInboxURL()
        moveIfPresent(item.imageURL, to: failedDirectory.appendingPathComponent(item.imageURL.lastPathComponent))
        moveIfPresent(item.manifestURL, to: failedDirectory.appendingPathComponent(item.manifestURL.lastPathComponent))
    }

    private static func sanitizedFileExtension(_ preferredExtension: String?) -> String? {
        guard let preferredExtension else { return nil }
        let normalized = preferredExtension
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .lowercased()
        guard !normalized.isEmpty, normalized.count <= 8 else { return nil }
        return normalized
    }

    private static func removeIfPresent(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func moveIfPresent(_ source: URL, to destination: URL) {
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        removeIfPresent(destination)
        try? FileManager.default.moveItem(at: source, to: destination)
    }
}

private extension JSONEncoder {
    static var screenshotRoll: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var screenshotRoll: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
