// MARK: - BASChapterDoctrineSQLLoader — chapter 七百二 SQL pilot
//
// Shared SQLite in-memory loader serving:
//   - BASChapterDoctrineRegistryAllLiterals (Knife 1)
//   - BASChapterDoctrineRegistry             (Knife 2)
//   - BASEntropyChapterIndex                 (Knife 3)
//
// Per user directive 「不要 json 可以的话 就 sql」, the chapter
// doctrine + entropy index literal data lives in .sql resources
// (Sources/BASRuntimeCore/SQL/01x_*.sql + 02x_*.sql)。 At first
// access this loader opens an in-memory SQLite db, runs the
// schema + INSERT scripts, and SELECTs back into the same Swift
// Codable structs the registry has always exposed。
//
// ## Why one shared loader for 3 callers
//
// Schema + data are partitioned across two table groups
// (chapter_doctrine_* + entropy_chapter_entries), but both
// groups live in the same db so a single open/close cycle
// suffices for the process lifetime。

import Foundation
import SQLite3

enum BASChapterDoctrineSQLLoader {

    // MARK: - Lazy decoded collections

    /// Decoded chapter doctrine partitions, lazily produced once
    /// per process。 .literals = collection_tag = 'literals',
    /// .phase2 = collection_tag = 'phase2'。
    static let chapterDoctrineCollections:
        (literals: [BASChapterDoctrineRecord],
         phase2: [BASChapterDoctrineRecord]) = {
        return loadChapterDoctrineFromSQL()
    }()

    /// Decoded entropy chapter index collections。
    static let entropyChapterCollections:
        (radical: [BASEntropyChapterEntry],
         phase2: [BASEntropyChapterEntry],
         postSweep: [BASEntropyChapterEntry]) = {
        return loadEntropyChapterIndexFromSQL()
    }()

    // MARK: - SQLite plumbing

    private static func execScript(
        _ db: OpaquePointer, _ sql: String, _ label: String
    ) {
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) }
                ?? "?"
            sqlite3_free(errMsg)
            fatalError(
                "chapter 七百二 SQL loader" +
                " (\(label)):exec failed rc=\(rc)" +
                " err=\(msg)")
        }
    }

    private static func readResource(
        _ name: String, _ ext: String = "sql"
    ) -> String {
        guard let url = Bundle.module.url(
            forResource: name, withExtension: ext)
        else {
            fatalError(
                "chapter 七百二 SQL loader:" +
                " resource \(name).\(ext) missing" +
                " from BASRuntimeCore Resources")
        }
        do {
            return try String(
                contentsOf: url, encoding: .utf8)
        } catch {
            fatalError(
                "chapter 七百二 SQL loader: read" +
                " \(name).\(ext) failed: \(error)")
        }
    }

    private static func withInMemoryDB<T>(
        _ scripts: [String],
        _ body: (OpaquePointer) -> T
    ) -> T {
        var db: OpaquePointer?
        let openRC = sqlite3_open(":memory:", &db)
        guard openRC == SQLITE_OK, let handle = db else {
            fatalError(
                "chapter 七百二 SQL loader:" +
                " sqlite3_open(:memory:) failed rc=\(openRC)")
        }
        defer { sqlite3_close(handle) }
        for name in scripts {
            execScript(handle, readResource(name), name)
        }
        return body(handle)
    }

    private static func text(
        _ stmt: OpaquePointer, _ index: Int32
    ) -> String {
        guard let cStr = sqlite3_column_text(
            stmt, index)
        else { return "" }
        return String(cString: cStr)
    }

    private static func int(
        _ stmt: OpaquePointer, _ index: Int32
    ) -> Int {
        return Int(sqlite3_column_int64(stmt, index))
    }

    // MARK: - Chapter doctrine load

    private static func loadChapterDoctrineFromSQL()
        -> (literals: [BASChapterDoctrineRecord],
            phase2: [BASChapterDoctrineRecord])
    {
        return withInMemoryDB([
            "010_chapter_doctrine_records_schema",
            "011_chapter_doctrine_literals_data",
            "012_chapter_doctrine_phase2_data"
        ]) { db -> (literals: [BASChapterDoctrineRecord],
                    phase2: [BASChapterDoctrineRecord]) in
            var records: [(tag: String,
                rec: BASChapterDoctrineRecord)] = []
            let parentSQL =
                "SELECT collection_ordinal, chapter_ordinal," +
                " collection_tag, chapter_tag," +
                " m_number_first, m_number_last," +
                " v1_milestone_m_number, v1_milestone_status," +
                " summary FROM chapter_doctrine_records" +
                " ORDER BY collection_ordinal, chapter_ordinal"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(
                db, parentSQL, -1, &stmt, nil) == SQLITE_OK,
                let s = stmt
            else {
                fatalError("prepare parent failed")
            }
            defer { sqlite3_finalize(s) }
            while sqlite3_step(s) == SQLITE_ROW {
                let collOrd = int(s, 0)
                let chOrd = int(s, 1)
                let collTag = text(s, 2)
                let chapterTag = text(s, 3)
                let mFirst = int(s, 4)
                let mLast = int(s, 5)
                let v1M = int(s, 6)
                let v1Status = text(s, 7)
                let summary = text(s, 8)
                let knives = fetchKnives(
                    db, collOrd: collOrd, chOrd: chOrd)
                let entropy = fetchStrings(
                    db, collOrd: collOrd, chOrd: chOrd,
                    table:
                        "chapter_doctrine_entropy_classes")
                let pins = fetchStrings(
                    db, collOrd: collOrd, chOrd: chOrd,
                    table: "chapter_doctrine_pins")
                let cuts = fetchStrings(
                    db, collOrd: collOrd, chOrd: chOrd,
                    table:
                        "chapter_doctrine_planned_cuts")
                let rec = BASChapterDoctrineRecord(
                    chapterTag: chapterTag,
                    mNumberFirst: mFirst,
                    mNumberLast: mLast,
                    v1MilestoneMNumber: v1M,
                    v1MilestoneStatus: v1Status,
                    knives: knives,
                    entropyClassesAttacked: entropy,
                    pinHeld: pins,
                    plannedFutureCuts: cuts,
                    summary: summary)
                records.append((collTag, rec))
            }
            let literals = records
                .filter { $0.tag == "literals" }
                .map(\.rec)
            let phase2 = records
                .filter { $0.tag == "phase2" }
                .map(\.rec)
            return (literals: literals, phase2: phase2)
        }
    }

    private static func fetchKnives(
        _ db: OpaquePointer,
        collOrd: Int, chOrd: Int
    ) -> [BASChapterKnife] {
        let sql =
            "SELECT m_number, knife, concept" +
            " FROM chapter_doctrine_knives" +
            " WHERE collection_ordinal = ?" +
            " AND chapter_ordinal = ?" +
            " ORDER BY knife_ordinal"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db, sql, -1, &stmt, nil) == SQLITE_OK,
            let s = stmt
        else { return [] }
        defer { sqlite3_finalize(s) }
        sqlite3_bind_int64(s, 1, Int64(collOrd))
        sqlite3_bind_int64(s, 2, Int64(chOrd))
        var out: [BASChapterKnife] = []
        while sqlite3_step(s) == SQLITE_ROW {
            out.append(BASChapterKnife(
                mNumber: int(s, 0),
                knife: text(s, 1),
                concept: text(s, 2)))
        }
        return out
    }

    private static func fetchStrings(
        _ db: OpaquePointer,
        collOrd: Int, chOrd: Int,
        table: String
    ) -> [String] {
        let sql =
            "SELECT value FROM \(table)" +
            " WHERE collection_ordinal = ?" +
            " AND chapter_ordinal = ?" +
            " ORDER BY item_ordinal"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db, sql, -1, &stmt, nil) == SQLITE_OK,
            let s = stmt
        else { return [] }
        defer { sqlite3_finalize(s) }
        sqlite3_bind_int64(s, 1, Int64(collOrd))
        sqlite3_bind_int64(s, 2, Int64(chOrd))
        var out: [String] = []
        while sqlite3_step(s) == SQLITE_ROW {
            out.append(text(s, 0))
        }
        return out
    }

    // MARK: - Entropy chapter index load

    private static func loadEntropyChapterIndexFromSQL()
        -> (radical: [BASEntropyChapterEntry],
            phase2: [BASEntropyChapterEntry],
            postSweep: [BASEntropyChapterEntry])
    {
        return withInMemoryDB([
            "021_entropy_chapter_entries_schema",
            "022_entropy_chapter_entries_data"
        ]) { db -> (radical: [BASEntropyChapterEntry],
                    phase2: [BASEntropyChapterEntry],
                    postSweep: [BASEntropyChapterEntry]) in
            // ORDER BY collection_tag, item_ordinal — three
            // collections come out in deterministic blocks
            // 'phase2' < 'postSweep' < 'radical' (alphabetical)
            // but each block is in item_ordinal order so the
            // per-collection sequence matches the pre-port Swift
            // literal order。
            let sql =
                "SELECT collection_tag, chapter_tag," +
                " m_number_first, m_number_last," +
                " knives_count, entropy_classes_count," +
                " pins_count, future_cuts_count, summary" +
                " FROM entropy_chapter_entries" +
                " ORDER BY collection_tag, item_ordinal"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(
                db, sql, -1, &stmt, nil) == SQLITE_OK,
                let s = stmt
            else { fatalError("prepare failed") }
            defer { sqlite3_finalize(s) }
            var radical: [BASEntropyChapterEntry] = []
            var phase2: [BASEntropyChapterEntry] = []
            var postSweep: [BASEntropyChapterEntry] = []
            while sqlite3_step(s) == SQLITE_ROW {
                let tag = text(s, 0)
                let entry = BASEntropyChapterEntry(
                    chapterTag: text(s, 1),
                    mNumberFirst: int(s, 2),
                    mNumberLast: int(s, 3),
                    knivesCount: int(s, 4),
                    entropyClassesCount: int(s, 5),
                    pinsCount: int(s, 6),
                    futureCutsCount: int(s, 7),
                    summary: text(s, 8))
                switch tag {
                case "radical":   radical.append(entry)
                case "phase2":    phase2.append(entry)
                case "postSweep": postSweep.append(entry)
                default:
                    fatalError(
                        "unknown collection_tag '\(tag)'")
                }
            }
            return (radical: radical,
                phase2: phase2,
                postSweep: postSweep)
        }
    }
}
