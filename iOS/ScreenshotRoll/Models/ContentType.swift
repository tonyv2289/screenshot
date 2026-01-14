import Foundation

/// Types of content that can be detected in screenshots
enum ContentType: String, Codable, CaseIterable {
    case tweet = "tweet"
    case chart = "chart"
    case code = "code"
    case article = "article"
    case conversation = "conversation"
    case meme = "meme"
    case receipt = "receipt"
    case note = "note"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .tweet: return "Tweet"
        case .chart: return "Chart/Graph"
        case .code: return "Code"
        case .article: return "Article"
        case .conversation: return "Conversation"
        case .meme: return "Meme"
        case .receipt: return "Receipt"
        case .note: return "Note"
        case .unknown: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .tweet: return "bubble.left"
        case .chart: return "chart.line.uptrend.xyaxis"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .article: return "doc.text"
        case .conversation: return "bubble.left.and.bubble.right"
        case .meme: return "face.smiling"
        case .receipt: return "receipt"
        case .note: return "note.text"
        case .unknown: return "photo"
        }
    }
}

/// Extracted entity from screenshot content
struct ExtractedEntity: Codable, Identifiable {
    let id: UUID
    let type: EntityType
    let value: String
    let confidence: Double
    let metadata: [String: String]

    init(type: EntityType, value: String, confidence: Double = 1.0, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.confidence = confidence
        self.metadata = metadata
    }
}

enum EntityType: String, Codable {
    case username = "username"      // @handle
    case hashtag = "hashtag"        // #topic
    case url = "url"                // links
    case date = "date"              // dates mentioned
    case number = "number"          // statistics, prices
    case person = "person"          // names
    case topic = "topic"            // extracted themes
    case quote = "quote"            // quoted text
}

/// Represents a connection between two assets in the knowledge graph
struct KnowledgeLink: Codable, Identifiable {
    let id: UUID
    let sourceAssetId: String
    let targetAssetId: String
    let relationshipType: RelationshipType
    let strength: Double  // 0.0 to 1.0

    init(source: String, target: String, type: RelationshipType, strength: Double = 0.5) {
        self.id = UUID()
        self.sourceAssetId = source
        self.targetAssetId = target
        self.relationshipType = type
        self.strength = strength
    }
}

enum RelationshipType: String, Codable {
    case sameTopic = "same_topic"
    case sameAuthor = "same_author"
    case sameSource = "same_source"
    case similar = "similar"
    case reply = "reply"
    case thread = "thread"
    case relatedConcept = "related_concept"
}
