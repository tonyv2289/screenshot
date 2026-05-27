import Foundation
import ImageIO
import PhotosUI
import SwiftUI
import UIKit

enum ImportPipelineError: LocalizedError {
    case unreadableImage
    case missingTransferableData

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "The selected item could not be decoded as an image."
        case .missingTransferableData:
            return "The selected photo did not provide image data."
        }
    }
}

actor ImportPipeline {
    static let shared = ImportPipeline()

    private let store: LibraryStore
    private let ocrClient: OCRClient
    private let classifier: ScreenshotClassifier

    init(
        store: LibraryStore = .shared,
        ocrClient: OCRClient = .shared,
        classifier: ScreenshotClassifier = ScreenshotClassifier()
    ) {
        self.store = store
        self.ocrClient = ocrClient
        self.classifier = classifier
    }

    func importPickerItem(_ item: PhotosPickerItem) async throws -> ScreenshotItem {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw ImportPipelineError.missingTransferableData
        }

        let fileExtension = item.supportedContentTypes.first?.preferredFilenameExtension
        return try await importImageData(data, preferredFilenameExtension: fileExtension)
    }

    private func importImageData(_ data: Data, preferredFilenameExtension: String?) async throws -> ScreenshotItem {
        guard
            let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw ImportPipelineError.unreadableImage
        }

        let image = UIImage(cgImage: cgImage)
        let exactHash = ImageFingerprint.exactHashHex(for: data)
        let existingItem = try await store.item(matchingHash: exactHash)
        let extractedText = await ocrClient.recognizeText(in: image)
        let category = classifier.categorize(text: extractedText)
        let tags = classifier.tags(from: extractedText, category: category)
        let identifier = UUID()
        let fileExtension = normalizedFileExtension(preferredFilenameExtension)

        let importedItem = ScreenshotItem(
            id: identifier,
            importedAt: Date(),
            originalFilename: "Imported \(identifier.uuidString.prefix(8)).\(fileExtension)",
            storedFilename: "\(identifier.uuidString).\(fileExtension)",
            pixelWidth: cgImage.width,
            pixelHeight: cgImage.height,
            source: .photoPicker,
            exactHash: exactHash,
            category: category,
            extractedText: extractedText,
            tags: tags,
            isDuplicate: existingItem != nil,
            originalItemID: existingItem?.id
        )

        try await store.saveImportedItem(importedItem, data: data)
        return importedItem
    }

    private func normalizedFileExtension(_ value: String?) -> String {
        let fallback = "png"
        guard let value else { return fallback }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
