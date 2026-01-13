import Foundation

enum TaggingService {
    // Minimum characters in a line to be considered for meme detection
    private static let minMemeLineLength = 5
    // Minimum number of all-caps lines to classify as meme
    private static let minAllCapsLinesForMeme = 2

    static func inferKind(from ocrText: String) -> AssetKind {
        let lower = ocrText.lowercased()

        // Tweet/X cues
        if lower.contains("reply") || lower.contains("repost") || lower.contains("retweet") || lower.contains("t.co/") || lower.contains("@") {
            return .tweet
        }

        // Chart cues
        let chartCues = ["open", "high", "low", "close", "%", "yoy", "mom", "intraday", "candlestick", "volume", "rsi", "macd"]
        if chartCues.contains(where: { lower.contains($0) }) {
            return .chart
        }

        // Meme cues: multiple lines with ALL CAPS text (use original text, not lowercased!)
        let allCapsLines = ocrText.split(separator: "\n").filter { line in
            let letters = line.filter { $0.isLetter }
            // Must have enough letters and all must be uppercase
            return letters.count >= minMemeLineLength && letters.allSatisfy { $0.isUppercase }
        }
        if allCapsLines.count >= minAllCapsLinesForMeme {
            return .meme
        }

        // Receipt/docs
        if lower.contains("subtotal") || lower.contains("total") || lower.contains("invoice") || lower.contains("receipt") {
            return .receipt
        }
        if lower.contains("page ") || lower.contains("document") || lower.contains("pdf") {
            return .doc
        }

        return .unknown
    }

    static func tagsFor(kind: AssetKind) -> [String] {
        switch kind {
        case .tweet: return ["tweet", "x"]
        case .chart: return ["chart"]
        case .meme: return ["meme"]
        case .receipt: return ["receipt"]
        case .doc: return ["doc"]
        case .unknown: return []
        }
    }
}
