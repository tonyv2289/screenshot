import Foundation
import SQLite3

// MARK: - SQLite Helpers

// SQLITE_TRANSIENT tells SQLite to make its own copy of the string data
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Constants

enum DatabaseConstants {
    static let searchResultsLimit = 500
    static let topTickersQueryLimit = 2000
    static let defaultTopTickersCount = 10
}

final class DatabaseService {
    static let shared = DatabaseService()

    private var db: OpaquePointer?

    private init() {
        open()
        migrate()
    }

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    private func open() {
        let url = SharedContainer.databaseURL()
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [
            FileAttributeKey.protectionKey: FileProtectionType.complete
        ])
        // SQLITE_OPEN_FULLMUTEX enables serialized threading mode for thread safety
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &db, flags, nil) != SQLITE_OK {
            let errorMessage = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            Loggers.db.error("Failed to open DB: \(errorMessage)")
            fatalError("Failed to open DB: \(errorMessage)")
        }
        execute("PRAGMA journal_mode=WAL;")
        execute("PRAGMA synchronous=NORMAL;")
        execute("PRAGMA temp_store=MEMORY;")
    }

    private func migrate() {
        let createAssets = """
        CREATE TABLE IF NOT EXISTS assets (
            asset_id INTEGER PRIMARY KEY,
            file_path TEXT NOT NULL,
            created_at REAL NOT NULL,
            width INTEGER NOT NULL,
            height INTEGER NOT NULL,
            kind TEXT NOT NULL,
            tickers TEXT NOT NULL,
            phash INTEGER NOT NULL,
            source TEXT NOT NULL,
            import_batch_id TEXT NOT NULL,
            duplicate_of_asset_id INTEGER
        );
        CREATE INDEX IF NOT EXISTS idx_assets_created_at ON assets(created_at DESC);
        """

        let createFTS = """
        CREATE VIRTUAL TABLE IF NOT EXISTS ocr_fts USING fts5(
            text, tags, asset_id UNINDEXED
        );
        """

        // Knowledge graph tables
        let createEntities = """
        CREATE TABLE IF NOT EXISTS entities (
            entity_id INTEGER PRIMARY KEY,
            asset_id INTEGER NOT NULL,
            type TEXT NOT NULL,
            value TEXT NOT NULL,
            confidence REAL NOT NULL,
            metadata TEXT,
            FOREIGN KEY (asset_id) REFERENCES assets(asset_id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_entities_asset ON entities(asset_id);
        CREATE INDEX IF NOT EXISTS idx_entities_type ON entities(type);
        CREATE INDEX IF NOT EXISTS idx_entities_value ON entities(value);
        """

        let createLinks = """
        CREATE TABLE IF NOT EXISTS knowledge_links (
            link_id INTEGER PRIMARY KEY,
            source_asset_id INTEGER NOT NULL,
            target_asset_id INTEGER NOT NULL,
            relationship_type TEXT NOT NULL,
            strength REAL NOT NULL,
            FOREIGN KEY (source_asset_id) REFERENCES assets(asset_id) ON DELETE CASCADE,
            FOREIGN KEY (target_asset_id) REFERENCES assets(asset_id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_links_source ON knowledge_links(source_asset_id);
        CREATE INDEX IF NOT EXISTS idx_links_target ON knowledge_links(target_asset_id);
        """

        // Add content_type column to assets if not exists
        let addContentType = """
        ALTER TABLE assets ADD COLUMN content_type TEXT DEFAULT 'unknown';
        """

        execute(createAssets)
        execute(createFTS)
        execute(createEntities)
        execute(createLinks)

        // Try to add content_type column (will fail silently if exists)
        execute(addContentType)
    }

    private func execute(_ sql: String) {
        var err: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let message = err.flatMap { String(cString: $0) } ?? "Unknown error"
            Loggers.db.error("SQL error: \(message)")
            if let err = err {
                sqlite3_free(err)
            }
        }
    }

    // MARK: - Insert Operations

    /// Inserts an asset and its OCR text into the database.
    /// Returns the new row ID, or -1 if the insert failed.
    @discardableResult
    func insertAsset(_ asset: Asset, ocrText: String, tagsText: String) -> Int64 {
        let insertAssetSQL = """
            INSERT INTO assets(asset_id, file_path, created_at, width, height, kind, tickers, phash, source, import_batch_id, duplicate_of_asset_id)
            VALUES(?,?,?,?,?,?,?,?,?,?,?);
            """
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, insertAssetSQL, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare insert statement: \(String(cString: sqlite3_errmsg(self.db)))")
            return -1
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_null(stmt, 1)
        sqlite3_bind_text(stmt, 2, (asset.filePath as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, asset.createdAt.timeIntervalSince1970)
        sqlite3_bind_int(stmt, 4, Int32(asset.width))
        sqlite3_bind_int(stmt, 5, Int32(asset.height))
        sqlite3_bind_text(stmt, 6, (asset.kind.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 7, (asset.tickersCSV as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 8, sqlite3_int64(asset.perceptualHash))
        sqlite3_bind_text(stmt, 9, (asset.source.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 10, (asset.importBatchId as NSString).utf8String, -1, SQLITE_TRANSIENT)
        if let dup = asset.duplicateOfAssetId {
            sqlite3_bind_int64(stmt, 11, dup)
        } else {
            sqlite3_bind_null(stmt, 11)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            Loggers.db.error("Failed to insert asset: \(String(cString: sqlite3_errmsg(self.db)))")
            return -1
        }

        let rowId = sqlite3_last_insert_rowid(db)

        // Insert into FTS index
        let insertFTS = "INSERT INTO ocr_fts(text, tags, asset_id) VALUES(?,?,?);"
        var stmt2: OpaquePointer?

        guard sqlite3_prepare_v2(db, insertFTS, -1, &stmt2, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare FTS insert: \(String(cString: sqlite3_errmsg(self.db)))")
            return rowId // Asset was inserted, FTS failed
        }
        defer { sqlite3_finalize(stmt2) }

        sqlite3_bind_text(stmt2, 1, (ocrText as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt2, 2, (tagsText as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt2, 3, rowId)

        if sqlite3_step(stmt2) != SQLITE_DONE {
            Loggers.db.error("Failed to insert FTS: \(String(cString: sqlite3_errmsg(self.db)))")
        }

        return rowId
    }

    // MARK: - Search Operations

    func search(query: String, kindFilters: [AssetKind], tickers: [String], dateRange: DateRangeFilter, sortByDate: Bool, includeDuplicates: Bool) -> [Asset] {
        var conditions: [String] = []
        var params: [Any] = []
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        let hasQuery = !trimmedQuery.isEmpty

        if hasQuery {
            conditions.append("assets.asset_id IN (SELECT asset_id FROM ocr_fts WHERE ocr_fts MATCH ?)")
            params.append(trimmedQuery)
        }

        if !kindFilters.isEmpty {
            let placeholders = kindFilters.map { _ in "?" }.joined(separator: ",")
            conditions.append("kind IN (\(placeholders))")
            kindFilters.forEach { params.append($0.rawValue) }
        }

        if !tickers.isEmpty {
            let tickerConditions = tickers.map { _ in "tickers LIKE ?" }.joined(separator: " AND ")
            conditions.append("(\(tickerConditions))")
            tickers.forEach { params.append("%\($0)%") }
        }

        if let start = dateRange.start {
            conditions.append("created_at >= ?")
            params.append(start.timeIntervalSince1970)
        }
        if let end = dateRange.end {
            conditions.append("created_at <= ?")
            params.append(end.timeIntervalSince1970)
        }

        if !includeDuplicates {
            conditions.append("duplicate_of_asset_id IS NULL")
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")

        // Only use BM25 ranking when we have a query and user wants relevance sorting
        let orderClause: String
        if hasQuery && !sortByDate {
            orderClause = "ORDER BY bm25(ocr_fts) ASC"
        } else {
            orderClause = "ORDER BY created_at DESC"
        }

        // Only join FTS table when needed for relevance sorting
        let joinClause = (hasQuery && !sortByDate) ? "LEFT JOIN ocr_fts ON ocr_fts.asset_id = assets.asset_id" : ""

        let sql = """
        SELECT assets.asset_id, file_path, created_at, width, height, kind, tickers, phash, source, import_batch_id, duplicate_of_asset_id
        FROM assets
        \(joinClause)
        \(whereClause)
        \(orderClause)
        LIMIT \(DatabaseConstants.searchResultsLimit)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare search: \(String(cString: sqlite3_errmsg(self.db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        bind(params, to: stmt)

        var results: [Asset] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let asset = readAssetRow(stmt: stmt)
            results.append(asset)
        }
        return results
    }

    func topTickers(limit: Int = DatabaseConstants.defaultTopTickersCount) -> [String] {
        let sql = "SELECT tickers FROM assets WHERE tickers <> '' LIMIT \(DatabaseConstants.topTickersQueryLimit)"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare topTickers: \(String(cString: sqlite3_errmsg(self.db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var counts: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let textPtr = sqlite3_column_text(stmt, 0) else { continue }
            let csv = String(cString: textPtr)
            for t in csv.split(separator: ",") {
                let key = String(t)
                counts[key, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
    }

    // MARK: - Duplicate Detection

    func findPotentialDuplicate(of hash: UInt64, hammingThreshold: Int) -> Int64? {
        let sql = "SELECT asset_id, phash FROM assets WHERE duplicate_of_asset_id IS NULL"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare duplicate search: \(String(cString: sqlite3_errmsg(self.db)))")
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let existingId = sqlite3_column_int64(stmt, 0)
            let existingHash = UInt64(bitPattern: sqlite3_column_int64(stmt, 1))
            let dist = HashingService.hammingDistance(hash, existingHash)
            if dist <= hammingThreshold {
                return existingId
            }
        }
        return nil
    }

    func markAsDuplicate(assetId: Int64, duplicateOf: Int64) {
        let sql = "UPDATE assets SET duplicate_of_asset_id = ? WHERE asset_id = ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare markAsDuplicate: \(String(cString: sqlite3_errmsg(self.db)))")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, duplicateOf)
        sqlite3_bind_int64(stmt, 2, assetId)

        if sqlite3_step(stmt) != SQLITE_DONE {
            Loggers.db.error("Failed to mark as duplicate: \(String(cString: sqlite3_errmsg(self.db)))")
        }
    }

    // MARK: - Knowledge Graph Operations

    /// Insert extracted entities for an asset
    func insertEntities(_ entities: [ExtractedEntity], forAssetId assetId: Int64) {
        let sql = "INSERT INTO entities(asset_id, type, value, confidence, metadata) VALUES(?,?,?,?,?);"

        for entity in entities {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                Loggers.db.error("Failed to prepare entity insert: \(String(cString: sqlite3_errmsg(self.db)))")
                continue
            }
            defer { sqlite3_finalize(stmt) }

            let metadataJSON = try? JSONEncoder().encode(entity.metadata)
            let metadataString = metadataJSON.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

            sqlite3_bind_int64(stmt, 1, assetId)
            sqlite3_bind_text(stmt, 2, (entity.type.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, (entity.value as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 4, entity.confidence)
            sqlite3_bind_text(stmt, 5, (metadataString as NSString).utf8String, -1, SQLITE_TRANSIENT)

            if sqlite3_step(stmt) != SQLITE_DONE {
                Loggers.db.error("Failed to insert entity: \(String(cString: sqlite3_errmsg(self.db)))")
            }
        }
    }

    /// Update content type for an asset
    func updateContentType(_ type: ContentType, forAssetId assetId: Int64) {
        let sql = "UPDATE assets SET content_type = ? WHERE asset_id = ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare updateContentType: \(String(cString: sqlite3_errmsg(self.db)))")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (type.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 2, assetId)

        if sqlite3_step(stmt) != SQLITE_DONE {
            Loggers.db.error("Failed to update content type: \(String(cString: sqlite3_errmsg(self.db)))")
        }
    }

    /// Create a knowledge link between two assets
    func insertLink(source: Int64, target: Int64, type: RelationshipType, strength: Double) {
        let sql = "INSERT INTO knowledge_links(source_asset_id, target_asset_id, relationship_type, strength) VALUES(?,?,?,?);"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare link insert: \(String(cString: sqlite3_errmsg(self.db)))")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, source)
        sqlite3_bind_int64(stmt, 2, target)
        sqlite3_bind_text(stmt, 3, (type.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 4, strength)

        if sqlite3_step(stmt) != SQLITE_DONE {
            Loggers.db.error("Failed to insert link: \(String(cString: sqlite3_errmsg(self.db)))")
        }
    }

    /// Find assets with a specific entity value (e.g., all tweets from @elonmusk)
    func findAssets(withEntityType type: EntityType, value: String) -> [Int64] {
        let sql = "SELECT DISTINCT asset_id FROM entities WHERE type = ? AND value LIKE ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare entity search: \(String(cString: sqlite3_errmsg(self.db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (type.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, ("%\(value)%" as NSString).utf8String, -1, SQLITE_TRANSIENT)

        var results: [Int64] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(sqlite3_column_int64(stmt, 0))
        }
        return results
    }

    /// Get all entities for an asset
    func getEntities(forAssetId assetId: Int64) -> [ExtractedEntity] {
        let sql = "SELECT type, value, confidence, metadata FROM entities WHERE asset_id = ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare getEntities: \(String(cString: sqlite3_errmsg(self.db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, assetId)

        var results: [ExtractedEntity] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let typeRaw = String(cString: sqlite3_column_text(stmt, 0))
            let value = String(cString: sqlite3_column_text(stmt, 1))
            let confidence = sqlite3_column_double(stmt, 2)
            let metadataStr = String(cString: sqlite3_column_text(stmt, 3))

            guard let type = EntityType(rawValue: typeRaw) else { continue }

            let metadata: [String: String]
            if let data = metadataStr.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                metadata = decoded
            } else {
                metadata = [:]
            }

            results.append(ExtractedEntity(type: type, value: value, confidence: confidence, metadata: metadata))
        }
        return results
    }

    /// Get related assets through knowledge links
    func getRelatedAssets(forAssetId assetId: Int64) -> [(assetId: Int64, type: RelationshipType, strength: Double)] {
        let sql = """
            SELECT target_asset_id, relationship_type, strength FROM knowledge_links WHERE source_asset_id = ?
            UNION
            SELECT source_asset_id, relationship_type, strength FROM knowledge_links WHERE target_asset_id = ?
            ORDER BY strength DESC
        """
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare getRelatedAssets: \(String(cString: sqlite3_errmsg(self.db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, assetId)
        sqlite3_bind_int64(stmt, 2, assetId)

        var results: [(Int64, RelationshipType, Double)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let targetId = sqlite3_column_int64(stmt, 0)
            let typeRaw = String(cString: sqlite3_column_text(stmt, 1))
            let strength = sqlite3_column_double(stmt, 2)
            if let type = RelationshipType(rawValue: typeRaw) {
                results.append((targetId, type, strength))
            }
        }
        return results
    }

    /// Find assets by content type
    func findAssets(byContentType type: ContentType) -> [Asset] {
        let sql = """
            SELECT asset_id, file_path, created_at, width, height, kind, tickers, phash, source, import_batch_id, duplicate_of_asset_id
            FROM assets WHERE content_type = ? AND duplicate_of_asset_id IS NULL
            ORDER BY created_at DESC
            LIMIT \(DatabaseConstants.searchResultsLimit)
        """
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare content type search: \(String(cString: sqlite3_errmsg(self.db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (type.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)

        var results: [Asset] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(readAssetRow(stmt: stmt))
        }
        return results
    }

    /// Get content type counts for smart collections
    func getContentTypeCounts() -> [ContentType: Int] {
        let sql = "SELECT content_type, COUNT(*) FROM assets WHERE duplicate_of_asset_id IS NULL GROUP BY content_type"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare content type counts: \(String(cString: sqlite3_errmsg(self.db)))")
            return [:]
        }
        defer { sqlite3_finalize(stmt) }

        var counts: [ContentType: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let typePtr = sqlite3_column_text(stmt, 0) {
                let typeRaw = String(cString: typePtr)
                let count = Int(sqlite3_column_int(stmt, 1))
                if let type = ContentType(rawValue: typeRaw) {
                    counts[type] = count
                }
            }
        }
        return counts
    }

    /// Get top entities across all screenshots
    func getTopEntities(type: EntityType, limit: Int = 20) -> [(value: String, count: Int)] {
        let sql = "SELECT value, COUNT(*) as cnt FROM entities WHERE type = ? GROUP BY value ORDER BY cnt DESC LIMIT ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare top entities: \(String(cString: sqlite3_errmsg(self.db)))")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (type.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var results: [(String, Int)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let value = String(cString: sqlite3_column_text(stmt, 0))
            let count = Int(sqlite3_column_int(stmt, 1))
            results.append((value, count))
        }
        return results
    }

    // MARK: - Asset Lookups & Updates

    func getAsset(byId id: Int64) -> Asset? {
        let sql = """
            SELECT asset_id, file_path, created_at, width, height, kind, tickers, phash, source, import_batch_id, duplicate_of_asset_id
            FROM assets WHERE asset_id = ? LIMIT 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare getAsset: \(String(cString: sqlite3_errmsg(self.db)))")
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return readAssetRow(stmt: stmt)
        }
        return nil
    }

    func updateKind(_ kind: AssetKind, forAssetId assetId: Int64) {
        let sql = "UPDATE assets SET kind = ? WHERE asset_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare updateKind: \(String(cString: sqlite3_errmsg(self.db)))")
            return
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (kind.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 2, assetId)
        if sqlite3_step(stmt) != SQLITE_DONE {
            Loggers.db.error("Failed to update kind: \(String(cString: sqlite3_errmsg(self.db)))")
        }
    }

    // MARK: - Data Management

    func deleteAllData() {
        execute("DELETE FROM knowledge_links;")
        execute("DELETE FROM entities;")
        execute("DELETE FROM ocr_fts;")
        execute("DELETE FROM assets;")
    }

    func fetchOCRPreview(assetId: Int64) -> String? {
        let sql = "SELECT text FROM ocr_fts WHERE asset_id = ? LIMIT 1"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare fetchOCRPreview: \(String(cString: sqlite3_errmsg(self.db)))")
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, assetId)

        if sqlite3_step(stmt) == SQLITE_ROW, let textPtr = sqlite3_column_text(stmt, 0) {
            return String(cString: textPtr)
        }
        return nil
    }

    // MARK: - Private Helpers

    private func bind(_ params: [Any], to stmt: OpaquePointer?) {
        var index: Int32 = 1
        for param in params {
            if let s = param as? String {
                sqlite3_bind_text(stmt, index, (s as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else if let d = param as? Double {
                sqlite3_bind_double(stmt, index, d)
            } else if let i = param as? Int {
                sqlite3_bind_int(stmt, index, Int32(i))
            } else if let i64 = param as? Int64 {
                sqlite3_bind_int64(stmt, index, i64)
            } else {
                sqlite3_bind_null(stmt, index)
            }
            index += 1
        }
    }

    private func readAssetRow(stmt: OpaquePointer?) -> Asset {
        let id = sqlite3_column_int64(stmt, 0)
        let filePath = String(cString: sqlite3_column_text(stmt, 1))
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
        let width = Int(sqlite3_column_int(stmt, 3))
        let height = Int(sqlite3_column_int(stmt, 4))
        let kindRaw = String(cString: sqlite3_column_text(stmt, 5))
        let tickers = String(cString: sqlite3_column_text(stmt, 6))
        let phash = UInt64(bitPattern: sqlite3_column_int64(stmt, 7))
        let sourceRaw = String(cString: sqlite3_column_text(stmt, 8))
        let batchId = String(cString: sqlite3_column_text(stmt, 9))
        let dup = sqlite3_column_type(stmt, 10) == SQLITE_NULL ? nil : Optional(sqlite3_column_int64(stmt, 10))
        let kind = AssetKind(rawValue: kindRaw) ?? .unknown
        let source = AssetSource(rawValue: sourceRaw) ?? .picker
        return Asset(
            id: id,
            filePath: filePath,
            createdAt: createdAt,
            width: width,
            height: height,
            kind: kind,
            tickersCSV: tickers,
            perceptualHash: phash,
            source: source,
            importBatchId: batchId,
            duplicateOfAssetId: dup
        )
    }
}
