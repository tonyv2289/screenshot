import Foundation
import UIKit

final class TickerService {
    static let shared = TickerService()
    private var whitelist: Set<String> = []

    private init() {
        loadWhitelist()
    }

    private func loadWhitelist() {
        if let dataAsset = NSDataAsset(name: "whitelist") {
            if let dataString = String(data: dataAsset.data, encoding: .utf8) {
                let items = dataString.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }.filter { !$0.isEmpty }
                whitelist = Set(items)
                return
            }
        }
        // Fallback to minimal set
        whitelist = ["AAPL","MSFT","GOOGL","AMZN","META","TSLA","NVDA","AMD","SPY","QQQ"]
    }

    func extractTickers(from text: String) -> [String] {
        // Regex: optional $ then 1-5 uppercase letters
        let pattern = "\\$?[A-Z]{1,5}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        var found: Set<String> = []
        for m in matches {
            if let r = Range(m.range, in: text) {
                var token = String(text[r]).uppercased()
                if token.hasPrefix("$") { token.removeFirst() }
                if whitelist.contains(token) {
                    found.insert(token)
                }
            }
        }
        return Array(found).sorted()
    }
}

