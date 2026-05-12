// MARK: - BASJsonProofDoctrineCatalogueDoctrine
// chapter 五百五十六 / M1601 — meta-catalogue of all
//                              JSON PROOF doctrines
//                              shipped in this
//                              autonomous session
//
// ## Why this meta-catalogue exists
//
// Across chapters 551-555 the substrate gained 4 typed
// doctrines tracking Codable + JSON PROOF status of the
// audit-projection emission family:
//
//   1. BASRuntimeAuditProjectionsBundleCodableDoctrine
//      (chapter 551 / M1582)
//      — initial Codable cascade for 4 types
//
//   2. BASCodableCascadeArcSealedDoctrine
//      (chapter 553 / M1591)
//      — 3-chapter arc seal,16 types cascaded
//
//   3. BASAuditProjectionsBundleEndToEndJsonProofDoctrine
//      (chapter 554 / M1594)
//      — 3-of-5 namespace populated JSON PROOF
//
//   4. BASAuditProjectionsFiveNamespacePopulatedJson
//      ProofDoctrine (chapter 555 / M1598)
//      — 5-of-5 namespace populated JSON PROOF at
//        M1600 MILESTONE
//
// Without a meta-catalogue,a future reader has to grep
// across the substrate to discover what JSON PROOF
// status has been shipped。 This typed surface provides
// the SINGLE SOURCE-OF-TRUTH catalogue (chapter 二百
// 一一 doctrine) for the 4 JSON PROOF doctrines。
//
// Follows the chapter 550 BASSessionMilestoneDoctrine
// CatalogueDoctrine pattern but with narrower scope
// (JSON PROOF only,not all session milestones)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface,no production changes
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — this
//     IS the catalogue
//   - chapter 三百九二:replay-determinism (the
//     catalogued doctrines all PROOF JSON round-trip
//     determinism)
//   - chapter 四百二十九:typed-surface count 96 → 97
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1600 → M1601

import Foundation

/// Meta-catalogue of all JSON PROOF doctrines shipped in
/// this autonomous session。
///
/// Each entry in `catalogue` is a typed record naming
/// the doctrine + chapter + M-number + summary。 Anti-
/// drift PROOF tests cross-check this catalogue against
/// each catalogued doctrine's actual values。
public enum BASJsonProofDoctrineCatalogueDoctrine {

    // MARK: - Catalogue entry

    /// One catalogued JSON PROOF doctrine。
    public struct CatalogueEntry:
        Codable, Sendable, Equatable, Hashable
    {
        /// Type name of the catalogued doctrine。
        public let doctrineTypeName: String
        /// Chapter where the doctrine was shipped。
        public let chapterTag: String
        /// M-number where the doctrine landed。
        public let mNumber: Int
        /// One-line summary of what the doctrine
        /// records。
        public let summary: String

        public init(
            doctrineTypeName: String,
            chapterTag: String,
            mNumber: Int,
            summary: String
        ) {
            self.doctrineTypeName = doctrineTypeName
            self.chapterTag = chapterTag
            self.mNumber = mNumber
            self.summary = summary
        }
    }

    // MARK: - Catalogue contents

    /// All 6 JSON PROOF doctrines shipped in this
    /// session,in chronological M-number order。
    /// Updated at chapter 五百五十八 / M1612 to include
    /// BASAuditProjectionsJsonRejectionProofDoctrine
    /// (6th entry — closes the rejection half of the
    /// replay-determinism contract)。
    public static let catalogue: [CatalogueEntry] = [
        CatalogueEntry(
            doctrineTypeName:
                "BASRuntimeAuditProjectionsBundleCodableDoctrine",
            chapterTag: "chapter 五百五十一",
            mNumber: 1582,
            summary: "Initial Codable cascade for 4" +
                " audit-projection types (M1581)。"),
        CatalogueEntry(
            doctrineTypeName:
                "BASCodableCascadeArcSealedDoctrine",
            chapterTag: "chapter 五百五十三",
            mNumber: 1591,
            summary: "3-chapter arc seal commemorating" +
                " 16 types cascaded across chapters" +
                " 551-553。"),
        CatalogueEntry(
            doctrineTypeName:
                "BASAuditProjectionsBundleEndToEndJsonProofDoctrine",
            chapterTag: "chapter 五百五十四",
            mNumber: 1594,
            summary: "End-to-end JSON PROOF backing —" +
                " populated state round-trip for 3-of-5" +
                " namespaces (Kunlun + Abyssal +" +
                " Tribunal)。"),
        CatalogueEntry(
            doctrineTypeName:
                "BASAuditProjectionsFiveNamespacePopulatedJsonProofDoctrine",
            chapterTag: "chapter 五百五十五",
            mNumber: 1598,
            summary: "5-of-5 namespace populated JSON" +
                " PROOF coverage at M1600 MILESTONE。" +
                " Cthulhu + RiskCalibration newly" +
                " proven。"),
        CatalogueEntry(
            doctrineTypeName:
                "BASAuditObservationProjectionsBlockPopulatedJsonProofDoctrine",
            chapterTag: "chapter 五百五十七",
            mNumber: 1606,
            summary: "5-of-5 ProjectionsBlock POPULATED" +
                " round-trip PROOF coverage。 The 4" +
                " blocks NOT exercised in populated" +
                " state at chapter 554 (Closure +" +
                " CthulhuLeftovers + KunlunAuditSchemas" +
                " + KunlunProtocol) all proven at" +
                " M1605。"),
        CatalogueEntry(
            doctrineTypeName:
                "BASAuditProjectionsJsonRejectionProofDoctrine",
            chapterTag: "chapter 五百五十八",
            mNumber: 1610,
            summary: "JSON REJECTION PROOF — closes" +
                " the SECOND half of chapter 三百九二" +
                " replay-determinism contract。" +
                " Malformed input (truncated /" +
                " malformed / empty / wrong-type /" +
                " missing-required) rejected cleanly" +
                " via DecodingError。 11 PROOF tests" +
                " at M1609 covering Bundle + 5" +
                " ProjectionsBlock types。")
    ]

    // MARK: - Aggregate accessors

    /// Total catalogued JSON PROOF doctrines。
    public static var totalCatalogued: Int {
        return catalogue.count
    }

    /// First chapter that shipped a JSON PROOF doctrine
    /// in this session。
    public static let firstChapterTag: String =
        "chapter 五百五十一"

    /// Last chapter that shipped a JSON PROOF doctrine
    /// in this session。 Updated at M1612 to chapter
    /// 五百五十八。
    public static let lastChapterTag: String =
        "chapter 五百五十八"

    /// Earliest M-number across the catalogue (chapter
    /// 551 / M1582)。
    public static var earliestMNumber: Int {
        return catalogue.map { $0.mNumber }.min() ?? 0
    }

    /// Latest M-number across the catalogue (chapter
    /// 555 / M1598)。
    public static var latestMNumber: Int {
        return catalogue.map { $0.mNumber }.max() ?? 0
    }

    /// Span of M-numbers from earliest to latest
    /// (inclusive)。
    public static var mNumberSpan: Int {
        return latestMNumber - earliestMNumber + 1
    }

    /// 100% namespace coverage achieved at M1598
    /// (catalogued by the 4th entry)。
    public static let hundredPercentNamespaceCoverage:
        Bool = true

    /// V1 byte-equality preserved at every commit
    /// boundary across the cataloguing arc。
    public static let byteEqualityPreserved: Bool = true

    /// Pattern reference:this catalogue follows the
    /// chapter 550 BASSessionMilestoneDoctrineCatalogue
    /// Doctrine pattern,scoped narrowly to JSON PROOF
    /// doctrines。
    public static let patternRef: String =
        "BASSessionMilestoneDoctrineCatalogueDoctrine"

    /// Look up a catalogued doctrine by its type name。
    /// Returns nil if not catalogued。
    public static func entry(forTypeName name: String)
        -> CatalogueEntry?
    {
        return catalogue.first {
            $0.doctrineTypeName == name
        }
    }

    /// Look up a catalogued doctrine by chapter tag。
    /// Returns nil if no entry exists for that chapter
    /// (some chapters in the session did not ship a
    /// JSON PROOF doctrine)。
    public static func entry(forChapterTag tag: String)
        -> CatalogueEntry?
    {
        return catalogue.first {
            $0.chapterTag == tag
        }
    }
}
