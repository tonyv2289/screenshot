import UIKit

enum IndexingService {
    static let duplicateHammingThreshold: Int = 10

    static func processImportedImage(_ image: UIImage, source: AssetSource, importBatchId: String, savedURL: URL, width: Int, height: Int) async {
        let ocrText = await OCRService.recognizeText(in: image)
        let kind = TaggingService.inferKind(from: ocrText)
        let tickers = TickerService.shared.extractTickers(from: ocrText)
        let phash = HashingService.perceptualHash(image)
        let maybeDup = DatabaseService.shared.findPotentialDuplicate(of: phash, hammingThreshold: duplicateHammingThreshold)

        // Knowledge graph: classify content and extract entities
        let classifier = ContentClassifier.shared
        let (contentType, _) = classifier.classifyContent(ocrText)
        let entities = classifier.extractEntities(from: ocrText)

        let asset = Asset(
            id: 0,
            filePath: savedURL.path,
            createdAt: Date(),
            width: width,
            height: height,
            kind: kind,
            tickersCSV: tickers.joined(separator: ","),
            perceptualHash: phash,
            source: source,
            importBatchId: importBatchId,
            duplicateOfAssetId: maybeDup
        )
        let tagsText = TaggingService.tagsFor(kind: kind).joined(separator: ",")
        let newId = DatabaseService.shared.insertAsset(asset, ocrText: ocrText, tagsText: tagsText)

        if newId > 0 {
            // Store content type
            DatabaseService.shared.updateContentType(contentType, forAssetId: newId)

            // Store extracted entities
            DatabaseService.shared.insertEntities(entities, forAssetId: newId)

            // Build knowledge links based on shared entities
            KnowledgeGraphService.shared.buildLinks(forAssetId: newId, entities: entities)

            if let dupOf = maybeDup {
                DatabaseService.shared.markAsDuplicate(assetId: newId, duplicateOf: dupOf)
            }
        }
    }
}
