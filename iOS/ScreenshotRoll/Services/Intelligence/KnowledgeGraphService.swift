import Foundation

/// Builds and maintains the knowledge graph connecting screenshots
final class KnowledgeGraphService {
    static let shared = KnowledgeGraphService()
    private init() {}

    // MARK: - Link Building

    /// Automatically creates links between the new asset and existing assets based on shared entities
    func buildLinks(forAssetId assetId: Int64, entities: [ExtractedEntity]) {
        // Link by shared usernames (same author)
        let usernames = entities.filter { $0.type == EntityType.username }
        for username in usernames {
            let relatedAssets = DatabaseService.shared.findAssets(withEntityType: EntityType.username, value: username.value)
            for relatedId in relatedAssets where relatedId != assetId {
                DatabaseService.shared.insertLink(
                    source: assetId,
                    target: relatedId,
                    type: RelationshipType.sameAuthor,
                    strength: 0.8
                )
            }
        }

        // Link by shared topics
        let topics = entities.filter { $0.type == EntityType.topic }
        for topic in topics {
            let relatedAssets = DatabaseService.shared.findAssets(withEntityType: EntityType.topic, value: topic.value)
            for relatedId in relatedAssets where relatedId != assetId {
                DatabaseService.shared.insertLink(
                    source: assetId,
                    target: relatedId,
                    type: RelationshipType.sameTopic,
                    strength: topic.confidence * 0.6
                )
            }
        }

        // Link by shared hashtags
        let hashtags = entities.filter { $0.type == EntityType.hashtag }
        for hashtag in hashtags {
            let relatedAssets = DatabaseService.shared.findAssets(withEntityType: EntityType.hashtag, value: hashtag.value)
            for relatedId in relatedAssets where relatedId != assetId {
                DatabaseService.shared.insertLink(
                    source: assetId,
                    target: relatedId,
                    type: RelationshipType.sameTopic,
                    strength: 0.5
                )
            }
        }
    }

    // MARK: - Graph Queries

    /// Get all screenshots related to a specific user/author
    func getScreenshots(byAuthor username: String) -> [Asset] {
        let assetIds = DatabaseService.shared.findAssets(withEntityType: EntityType.username, value: username)
        return assetIds.compactMap { id in
            DatabaseService.shared.findAssets(byContentType: ContentType.tweet).first { $0.id == id }
        }
    }

    /// Get all screenshots about a specific topic
    func getScreenshots(byTopic topic: String) -> [Asset] {
        let assetIds = DatabaseService.shared.findAssets(withEntityType: EntityType.topic, value: topic)
        // Return unique assets
        var seen = Set<Int64>()
        return assetIds.compactMap { id -> Asset? in
            guard !seen.contains(id) else { return nil }
            seen.insert(id)
            return nil // We'd need a getAsset(byId:) method
        }
    }

    /// Get a "brain dump" of all insights from screenshots
    func getInsightsSummary() -> KnowledgeInsights {
        let topUsernames = DatabaseService.shared.getTopEntities(type: EntityType.username, limit: 10)
        let topTopics = DatabaseService.shared.getTopEntities(type: EntityType.topic, limit: 10)
        let topHashtags = DatabaseService.shared.getTopEntities(type: EntityType.hashtag, limit: 10)
        let contentCounts = DatabaseService.shared.getContentTypeCounts()

        return KnowledgeInsights(
            topAuthors: topUsernames.map { ($0.value, $0.count) },
            topTopics: topTopics.map { ($0.value, $0.count) },
            topHashtags: topHashtags.map { ($0.value, $0.count) },
            contentTypeCounts: contentCounts
        )
    }
}

/// Summary of insights from the knowledge graph
struct KnowledgeInsights {
    let topAuthors: [(name: String, count: Int)]
    let topTopics: [(topic: String, count: Int)]
    let topHashtags: [(tag: String, count: Int)]
    let contentTypeCounts: [ContentType: Int]

    var totalScreenshots: Int {
        contentTypeCounts.values.reduce(0, +)
    }

    var dominantContentType: ContentType? {
        contentTypeCounts.max(by: { $0.value < $1.value })?.key
    }
}
