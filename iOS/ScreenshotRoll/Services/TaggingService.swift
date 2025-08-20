import Foundation

enum TaggingService {
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
        // Meme cues: big all caps words often, rough heuristic
        let allCapsLines = lower.split(separator: "\n").filter { line in
            let letters = line.filter { $0.isLetter }
            return !letters.isEmpty && letters.allSatisfy { String($0).uppercased() == String($0) }
        }
        if allCapsLines.count >= 1 { return .meme }

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

