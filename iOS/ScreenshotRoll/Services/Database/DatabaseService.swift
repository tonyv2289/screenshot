import Foundation
import SQLite3

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
            text, tags, asset_id UNINDEXED,
            tokenize = 'unicode61 remove_diacritics 2 tokenchars "$_"'
        );
        """

        execute(createAssets)
        execute(createFTS)
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
            Loggers.db.error("Failed to prepare insert statement: \(String(cString: sqlite3_errmsg(db)))")
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
            Loggers.db.error("Failed to insert asset: \(String(cString: sqlite3_errmsg(db)))")
            return -1
        }

        let rowId = sqlite3_last_insert_rowid(db)

        // Insert into FTS index
        let insertFTS = "INSERT INTO ocr_fts(text, tags, asset_id) VALUES(?,?,?);"
        var stmt2: OpaquePointer?

        guard sqlite3_prepare_v2(db, insertFTS, -1, &stmt2, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare FTS insert: \(String(cString: sqlite3_errmsg(db)))")
            return rowId // Asset was inserted, FTS failed
        }
        defer { sqlite3_finalize(stmt2) }

        sqlite3_bind_text(stmt2, 1, (ocrText as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt2, 2, (tagsText as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt2, 3, rowId)

        if sqlite3_step(stmt2) != SQLITE_DONE {
            Loggers.db.error("Failed to insert FTS: \(String(cString: sqlite3_errmsg(db)))")
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
            Loggers.db.error("Failed to prepare search: \(String(cString: sqlite3_errmsg(db)))")
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
            Loggers.db.error("Failed to prepare topTickers: \(String(cString: sqlite3_errmsg(db)))")
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
            Loggers.db.error("Failed to prepare duplicate search: \(String(cString: sqlite3_errmsg(db)))")
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
            Loggers.db.error("Failed to prepare markAsDuplicate: \(String(cString: sqlite3_errmsg(db)))")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, duplicateOf)
        sqlite3_bind_int64(stmt, 2, assetId)

        if sqlite3_step(stmt) != SQLITE_DONE {
            Loggers.db.error("Failed to mark as duplicate: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    // MARK: - Data Management

    func deleteAllData() {
        execute("DELETE FROM ocr_fts;")
        execute("DELETE FROM assets;")
    }

    func fetchOCRPreview(assetId: Int64) -> String? {
        let sql = "SELECT text FROM ocr_fts WHERE asset_id = ? LIMIT 1"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Loggers.db.error("Failed to prepare fetchOCRPreview: \(String(cString: sqlite3_errmsg(db)))")
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
