import Foundation
import CoreGraphics

struct Asset: Identifiable, Hashable {
    let id: Int64
    let filePath: String
    let createdAt: Date
    let width: Int
    let height: Int
    let kind: AssetKind
    let tickersCSV: String
    let perceptualHash: UInt64
    let source: AssetSource
    let importBatchId: String
    let duplicateOfAssetId: Int64?

    var imageURL: URL { URL(fileURLWithPath: filePath) }
    var tickers: [String] { tickersCSV.split(separator: ",").map { String($0) }.filter { !$0.isEmpty } }
}

