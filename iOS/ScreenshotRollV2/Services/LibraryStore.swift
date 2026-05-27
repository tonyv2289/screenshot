import Foundation

actor LibraryStore {
    static let shared = LibraryStore()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var snapshotCache: ScreenshotLibrarySnapshot?

    init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadItems() throws -> [ScreenshotItem] {
        try loadSnapshot().items.sorted { $0.importedAt > $1.importedAt }
    }

    func item(matchingHash hash: String) throws -> ScreenshotItem? {
        try loadSnapshot().items.first { $0.exactHash == hash }
    }

    func saveImportedItem(_ item: ScreenshotItem, data: Data) throws {
        let imageURL = try ScreenshotRollV2Paths.imageURL(for: item.storedFilename)
        var snapshot = try loadSnapshot()

        try data.write(to: imageURL, options: [.atomic, .completeFileProtection])
        snapshot.items.insert(item, at: 0)

        do {
            try persist(snapshot)
        } catch {
            try? FileManager.default.removeItem(at: imageURL)
            throw error
        }
    }

    func updateCategory(_ category: ScreenshotCategory, for itemID: UUID) throws {
        var snapshot = try loadSnapshot()
        guard let index = snapshot.items.firstIndex(where: { $0.id == itemID }) else { return }
        snapshot.items[index].category = category
        try persist(snapshot)
    }

    func deleteAll() throws {
        let baseDirectory = try ScreenshotRollV2Paths.baseDirectory()
        if FileManager.default.fileExists(atPath: baseDirectory.path) {
            try FileManager.default.removeItem(at: baseDirectory)
        }
        snapshotCache = ScreenshotLibrarySnapshot()
        _ = try ScreenshotRollV2Paths.baseDirectory()
        _ = try ScreenshotRollV2Paths.imagesDirectory()
        try persist(ScreenshotLibrarySnapshot())
    }

    private func loadSnapshot() throws -> ScreenshotLibrarySnapshot {
        if let snapshotCache {
            return snapshotCache
        }

        let metadataURL = try ScreenshotRollV2Paths.metadataURL()
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            let snapshot = ScreenshotLibrarySnapshot()
            snapshotCache = snapshot
            return snapshot
        }

        let data = try Data(contentsOf: metadataURL)
        let snapshot = try decoder.decode(ScreenshotLibrarySnapshot.self, from: data)
        snapshotCache = snapshot
        return snapshot
    }

    private func persist(_ snapshot: ScreenshotLibrarySnapshot) throws {
        let data = try encoder.encode(snapshot)
        let url = try ScreenshotRollV2Paths.metadataURL()
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        snapshotCache = snapshot
    }
}
