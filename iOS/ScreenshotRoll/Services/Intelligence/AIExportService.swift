import Foundation

/// Exports knowledge graph data for AI integration
final class AIExportService {
    static let shared = AIExportService()
    private init() {}

    /// Export format options
    enum ExportFormat {
        case json           // Full structured JSON
        case markdown       // Human-readable markdown
        case contextWindow  // Optimized for AI context windows
    }

    // MARK: - Export Methods

    /// Export the full knowledge base as JSON
    func exportAsJSON() -> Data? {
        let export = KnowledgeExport(
            exportDate: Date(),
            insights: KnowledgeGraphService.shared.getInsightsSummary(),
            topAuthors: getTopAuthorsWithContent(),
            topTopics: getTopTopicsWithContent(),
            recentContent: getRecentContent(limit: 50)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try? encoder.encode(export)
    }

    /// Export as markdown for easy reading
    func exportAsMarkdown() -> String {
        let insights = KnowledgeGraphService.shared.getInsightsSummary()

        var md = """
        # My Screenshot Knowledge Base
        Generated: \(Date().formatted())

        ## Overview
        - Total Screenshots: \(insights.totalScreenshots)

        ### Content Breakdown
        """

        for (type, count) in insights.contentTypeCounts.sorted(by: { $0.value > $1.value }) {
            md += "\n- \(type.displayName): \(count)"
        }

        md += "\n\n## Top Authors I Follow\n"
        for (author, count) in insights.topAuthors.prefix(10) {
            md += "- \(author) (\(count) screenshots)\n"
        }

        md += "\n## Topics I'm Interested In\n"
        for (topic, count) in insights.topTopics.prefix(10) {
            md += "- \(topic) (\(count) screenshots)\n"
        }

        md += "\n## Hashtags I Track\n"
        for (tag, count) in insights.topHashtags.prefix(10) {
            md += "- #\(tag) (\(count) screenshots)\n"
        }

        return md
    }

    /// Export optimized for AI context windows (compact but comprehensive)
    func exportForAIContext(maxTokens: Int = 4000) -> String {
        let insights = KnowledgeGraphService.shared.getInsightsSummary()

        var context = """
        [USER KNOWLEDGE BASE]
        This user has saved \(insights.totalScreenshots) screenshots that reveal their interests and thinking.

        CONTENT TYPES: \(insights.contentTypeCounts.map { "\($0.key.displayName): \($0.value)" }.joined(separator: ", "))

        TOP AUTHORS THEY FOLLOW: \(insights.topAuthors.prefix(5).map { $0.name }.joined(separator: ", "))

        TOPICS THEY CARE ABOUT: \(insights.topTopics.prefix(5).map { $0.topic }.joined(separator: ", "))

        HASHTAGS THEY TRACK: \(insights.topHashtags.prefix(5).map { "#\($0.tag)" }.joined(separator: ", "))

        """

        // Add recent quotes/content if space allows
        let recentContent = getRecentContent(limit: 10)
        if !recentContent.isEmpty {
            context += "\nRECENT SAVED CONTENT:\n"
            for item in recentContent {
                let preview = item.textPreview.prefix(200)
                context += "- [\(item.contentType.displayName)] \(preview)\n"
            }
        }

        return context
    }

    // MARK: - Sharing

    /// Get a shareable URL for the export (saves to temp file)
    func createShareableExport(format: ExportFormat) -> URL? {
        let filename: String
        let content: Data?

        switch format {
        case .json:
            filename = "knowledge-export.json"
            content = exportAsJSON()
        case .markdown:
            filename = "knowledge-export.md"
            content = exportAsMarkdown().data(using: .utf8)
        case .contextWindow:
            filename = "ai-context.txt"
            content = exportForAIContext().data(using: .utf8)
        }

        guard let data = content else { return nil }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    // MARK: - Private Helpers

    private func getTopAuthorsWithContent() -> [AuthorSummary] {
        let topAuthors = DatabaseService.shared.getTopEntities(type: EntityType.username, limit: 20)
        return topAuthors.map { author in
            AuthorSummary(
                username: author.value,
                screenshotCount: author.count
            )
        }
    }

    private func getTopTopicsWithContent() -> [TopicSummary] {
        let topTopics = DatabaseService.shared.getTopEntities(type: EntityType.topic, limit: 20)
        return topTopics.map { topic in
            TopicSummary(
                name: topic.value,
                screenshotCount: topic.count
            )
        }
    }

    private func getRecentContent(limit: Int) -> [ContentSummary] {
        // Get recent assets across all content types
        var summaries: [ContentSummary] = []

        for contentType in ContentType.allCases {
            let assets = DatabaseService.shared.findAssets(byContentType: contentType)
            for asset in assets.prefix(limit / ContentType.allCases.count) {
                if let text = DatabaseService.shared.fetchOCRPreview(assetId: asset.id) {
                    summaries.append(ContentSummary(
                        assetId: asset.id,
                        contentType: contentType,
                        textPreview: String(text.prefix(300)),
                        createdAt: asset.createdAt
                    ))
                }
            }
        }

        return summaries.sorted { $0.createdAt > $1.createdAt }.prefix(limit).map { $0 }
    }
}

// MARK: - Export Data Models

struct KnowledgeExport: Codable {
    let exportDate: Date
    let insights: ExportableInsights
    let topAuthors: [AuthorSummary]
    let topTopics: [TopicSummary]
    let recentContent: [ContentSummary]
}

struct ExportableInsights: Codable {
    let totalScreenshots: Int
    let contentTypeCounts: [String: Int]
    let topAuthors: [String]
    let topTopics: [String]
    let topHashtags: [String]

    init(from insights: KnowledgeInsights) {
        self.totalScreenshots = insights.totalScreenshots
        self.contentTypeCounts = Dictionary(uniqueKeysWithValues: insights.contentTypeCounts.map { ($0.key.rawValue, $0.value) })
        self.topAuthors = insights.topAuthors.map { $0.name }
        self.topTopics = insights.topTopics.map { $0.topic }
        self.topHashtags = insights.topHashtags.map { $0.tag }
    }
}

extension KnowledgeExport {
    init(exportDate: Date, insights: KnowledgeInsights, topAuthors: [AuthorSummary], topTopics: [TopicSummary], recentContent: [ContentSummary]) {
        self.exportDate = exportDate
        self.insights = ExportableInsights(from: insights)
        self.topAuthors = topAuthors
        self.topTopics = topTopics
        self.recentContent = recentContent
    }
}

struct AuthorSummary: Codable {
    let username: String
    let screenshotCount: Int
}

struct TopicSummary: Codable {
    let name: String
    let screenshotCount: Int
}

struct ContentSummary: Codable {
    let assetId: Int64
    let contentType: ContentType
    let textPreview: String
    let createdAt: Date
}
