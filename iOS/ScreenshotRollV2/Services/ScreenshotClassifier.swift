import Foundation

struct ScreenshotClassifier {
    func categorize(text: String) -> ScreenshotCategory {
        let lowercased = text.lowercased()

        if containsAny(in: lowercased, terms: ["subtotal", "tax", "tip", "order total", "receipt", "cash", "visa"]) {
            return .receipt
        }

        if containsAny(in: lowercased, terms: ["followers", "following", "reposts", "retweets", "likes", "reply", "quote post"]) {
            return .social
        }

        if containsAny(in: lowercased, terms: ["quarter", "revenue", "ebitda", "price target", "market cap", "%", "y/y", "q/q"]) {
            return .chart
        }

        if containsAny(in: lowercased, terms: ["agenda", "summary", "meeting notes", "invoice", "section", "introduction", "conclusion"]) {
            return .document
        }

        if containsAny(in: lowercased, terms: ["settings", "password", "notifications", "profile", "search", "home", "inbox"]) {
            return .interface
        }

        if containsAny(in: lowercased, terms: ["meme", "starter pack", "pov", "nobody:", "me when"]) {
            return .meme
        }

        return .unknown
    }

    func tags(from text: String, category: ScreenshotCategory) -> [String] {
        let lowercased = text.lowercased()
        let keywordUniverse = [
            "earnings", "portfolio", "invoice", "meeting", "todo", "recipe",
            "travel", "design", "fitness", "calendar", "shopping", "note"
        ]

        var tags = [category.title]
        for keyword in keywordUniverse where lowercased.contains(keyword) {
            tags.append(keyword.capitalized)
        }

        var seen = Set<String>()
        return tags.filter { seen.insert($0).inserted }
    }

    private func containsAny(in text: String, terms: [String]) -> Bool {
        terms.contains { text.contains($0) }
    }
}
