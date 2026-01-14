import Foundation

/// Classifies screenshot content and extracts structured entities
final class ContentClassifier {
    static let shared = ContentClassifier()
    private init() {}

    // MARK: - Content Type Detection

    /// Analyzes OCR text to determine the type of content
    func classifyContent(_ text: String) -> (type: ContentType, confidence: Double) {
        let lowercased = text.lowercased()

        // Tweet detection - check for Twitter/X patterns
        if isTweet(text: text, lowercased: lowercased) {
            return (.tweet, 0.9)
        }

        // Code detection
        if isCode(text: text) {
            return (.code, 0.85)
        }

        // Chart/graph detection
        if isChart(lowercased: lowercased) {
            return (.chart, 0.8)
        }

        // Conversation/chat detection
        if isConversation(text: text) {
            return (.conversation, 0.8)
        }

        // Receipt detection
        if isReceipt(lowercased: lowercased) {
            return (.receipt, 0.85)
        }

        // Article detection
        if isArticle(text: text) {
            return (.article, 0.7)
        }

        // Note detection
        if isNote(lowercased: lowercased) {
            return (.note, 0.6)
        }

        return (.unknown, 0.5)
    }

    private func isTweet(text: String, lowercased: String) -> Bool {
        let twitterIndicators = [
            "retweet", "retweeted", "quote tweet",
            "twitter", "x.com", "tweet",
            "following", "followers",
            "like", "reply", "repost"
        ]

        let hasTwitterUI = twitterIndicators.contains { lowercased.contains($0) }
        let hasHandle = text.contains("@") && text.range(of: "@[a-zA-Z0-9_]+", options: .regularExpression) != nil
        let hasTimestamp = lowercased.contains(regex: "\\d+[hm]\\s*(ago)?") ||
                          lowercased.contains(regex: "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+\\d+")

        return hasTwitterUI || (hasHandle && hasTimestamp)
    }

    private func isCode(text: String) -> Bool {
        let codePatterns = [
            "func ", "function ", "def ", "class ",
            "import ", "const ", "let ", "var ",
            "if (", "if(", "for (", "for(",
            "return ", "=> ", "->",
            "{ }", "{}", "();", ");",
            "//", "/*", "*/", "#include"
        ]

        let matches = codePatterns.filter { text.contains($0) }.count
        return matches >= 3
    }

    private func isChart(lowercased: String) -> Bool {
        let chartIndicators = [
            "chart", "graph", "axis", "plot",
            "percentage", "%", "growth",
            "revenue", "profit", "sales",
            "q1", "q2", "q3", "q4",
            "year over year", "yoy", "mom",
            "billion", "million", "thousand"
        ]

        let matches = chartIndicators.filter { lowercased.contains($0) }.count
        return matches >= 2
    }

    private func isConversation(text: String) -> Bool {
        // Look for chat bubble patterns - multiple short lines with names/timestamps
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 4 else { return false }

        // Check for messaging app patterns
        let hasTimestamps = lines.filter { $0.contains(regex: "\\d{1,2}:\\d{2}") }.count >= 2
        let hasNames = lines.filter { $0.contains(":") }.count >= 2

        return hasTimestamps || hasNames
    }

    private func isReceipt(lowercased: String) -> Bool {
        let receiptIndicators = [
            "total", "subtotal", "tax",
            "payment", "receipt", "invoice",
            "order", "item", "qty",
            "visa", "mastercard", "amex",
            "thank you for", "transaction"
        ]

        let matches = receiptIndicators.filter { lowercased.contains($0) }.count
        return matches >= 3
    }

    private func isArticle(text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 5 else { return false }

        // Articles have longer paragraphs
        let avgLineLength = lines.map { $0.count }.reduce(0, +) / lines.count
        let hasParagraphs = avgLineLength > 50

        return hasParagraphs
    }

    private func isNote(lowercased: String) -> Bool {
        let noteIndicators = [
            "note", "reminder", "todo", "to-do",
            "- ", "• ", "* ", "1.", "2.", "3."
        ]

        return noteIndicators.contains { lowercased.contains($0) }
    }

    // MARK: - Entity Extraction

    /// Extracts structured entities from OCR text
    func extractEntities(from text: String) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []

        entities.append(contentsOf: extractUsernames(from: text))
        entities.append(contentsOf: extractHashtags(from: text))
        entities.append(contentsOf: extractURLs(from: text))
        entities.append(contentsOf: extractNumbers(from: text))
        entities.append(contentsOf: extractDates(from: text))
        entities.append(contentsOf: extractQuotes(from: text))
        entities.append(contentsOf: extractTopics(from: text))

        return entities
    }

    private func extractUsernames(from text: String) -> [ExtractedEntity] {
        let pattern = "@([a-zA-Z0-9_]{1,15})"
        return text.matches(for: pattern).map { match in
            ExtractedEntity(type: .username, value: match)
        }
    }

    private func extractHashtags(from text: String) -> [ExtractedEntity] {
        let pattern = "#([a-zA-Z0-9_]+)"
        return text.matches(for: pattern).map { match in
            ExtractedEntity(type: .hashtag, value: match)
        }
    }

    private func extractURLs(from text: String) -> [ExtractedEntity] {
        let pattern = "https?://[a-zA-Z0-9./\\-_?&=]+"
        return text.matches(for: pattern).map { match in
            ExtractedEntity(type: .url, value: match)
        }
    }

    private func extractNumbers(from text: String) -> [ExtractedEntity] {
        // Match numbers with units like $1.5M, 50%, 1,000
        let pattern = "[$]?[0-9,]+\\.?[0-9]*[KMB%]?"
        return text.matches(for: pattern)
            .filter { $0.count >= 2 }  // Skip single digits
            .prefix(10)  // Limit to prevent noise
            .map { match in
                ExtractedEntity(type: .number, value: match)
            }
    }

    private func extractDates(from text: String) -> [ExtractedEntity] {
        let patterns = [
            "\\d{1,2}/\\d{1,2}/\\d{2,4}",  // 12/25/2024
            "\\d{1,2}-\\d{1,2}-\\d{2,4}",  // 12-25-2024
            "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\s+\\d{1,2},?\\s*\\d{0,4}"  // Jan 15, 2024
        ]

        var entities: [ExtractedEntity] = []
        for pattern in patterns {
            entities.append(contentsOf: text.matches(for: pattern, options: .caseInsensitive).map {
                ExtractedEntity(type: .date, value: $0)
            })
        }
        return entities
    }

    private func extractQuotes(from text: String) -> [ExtractedEntity] {
        // Match text in quotes
        let pattern = "\"([^\"]{10,200})\""
        return text.matches(for: pattern).map { match in
            ExtractedEntity(type: .quote, value: match)
        }
    }

    private func extractTopics(from text: String) -> [ExtractedEntity] {
        // Common topics/themes to detect
        let topicKeywords: [String: [String]] = [
            "AI": ["artificial intelligence", "machine learning", "neural network", "gpt", "llm", "chatgpt", "claude", "ai "],
            "Crypto": ["bitcoin", "ethereum", "crypto", "blockchain", "nft", "web3", "defi"],
            "Startups": ["startup", "founder", "venture", "vc ", "seed round", "series a", "fundraise"],
            "Programming": ["code", "programming", "developer", "software", "api", "github", "javascript", "python", "swift"],
            "Finance": ["stock", "invest", "market", "trading", "portfolio", "dividend", "earnings"],
            "Health": ["health", "fitness", "workout", "diet", "sleep", "meditation", "wellness"],
            "Productivity": ["productivity", "focus", "habit", "routine", "goal", "time management"]
        ]

        let lowercased = text.lowercased()
        var entities: [ExtractedEntity] = []

        for (topic, keywords) in topicKeywords {
            let matchCount = keywords.filter { lowercased.contains($0) }.count
            if matchCount >= 1 {
                let confidence = min(Double(matchCount) * 0.3, 1.0)
                entities.append(ExtractedEntity(
                    type: .topic,
                    value: topic,
                    confidence: confidence
                ))
            }
        }

        return entities
    }
}

// MARK: - String Extensions for Pattern Matching

private extension String {
    func contains(regex pattern: String) -> Bool {
        return range(of: pattern, options: .regularExpression) != nil
    }

    func matches(for pattern: String, options: NSRegularExpression.Options = []) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }

        let range = NSRange(startIndex..., in: self)
        let results = regex.matches(in: self, options: [], range: range)

        return results.compactMap { result in
            guard let range = Range(result.range, in: self) else { return nil }
            return String(self[range])
        }
    }
}
