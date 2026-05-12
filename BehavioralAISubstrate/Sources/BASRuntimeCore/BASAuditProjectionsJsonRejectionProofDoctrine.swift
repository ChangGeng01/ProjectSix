// MARK: - BASAuditProjectionsJsonRejectionProofDoctrine
// chapter 五百五十八 / M1610 — typed surface
//                              commemorating the
//                              JSON REJECTION PROOF
//                              shipped at M1609
//
// ## Why this typed surface exists
//
// Chapter 三百九二 replay-determinism doctrine has TWO
// halves:
//
//   1. Valid input → byte-identical round-trip
//      (PROOFed in chapters 554-557)
//   2. Invalid input → clean rejection
//      (PROOFed at M1609)
//
// Without (2),a corrupted JSON ledger entry could
// silently decode into a wrong-state struct producing
// replay drift。 M1609 shipped 11 PROOF tests covering:
//
//   - Truncated JSON rejection (Bundle + 2 Blocks)
//   - Malformed JSON rejection (Bundle + 1 Block)
//   - Empty-string rejection (Bundle + 1 Block)
//   - Wrong-type rejection (1 Block)
//   - Missing-required-field rejection (Bundle)
//   - Forward-compat:unknown-extra-fields tolerated
//   - Decoder state isolation:rejection doesn't
//     pollut subsequent valid decode
//
// This typed surface records the rejection-PROOF
// status so the JSON PROOF doctrine catalogue has a
// single source-of-truth for "yes,corrupted input is
// rejected cleanly"。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface,no production changes
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth for the
//     rejection-PROOF status
//   - chapter 三百九二:closes the SECOND half of
//     replay-determinism (rejection of malformed input)
//   - chapter 四百二十九:typed-surface count 98 → 99
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1609 → M1610

import Foundation

/// Typed surface commemorating the M1609 PROOF that
/// the audit-projection emission family REJECTS
/// malformed JSON input cleanly。
public enum BASAuditProjectionsJsonRejectionProofDoctrine {

    /// Chapter where this PROOF was shipped。
    public static let chapterTag: String =
        "chapter 五百五十八"

    /// M-number of the PROOF test commit。
    public static let proofMNumber: Int = 1609

    /// Number of PROOF tests shipped at M1609。
    public static let proofTestCount: Int = 11

    /// 5 categories of malformed input covered by the
    /// rejection PROOFs。
    public static let rejectionCategories: [String] = [
        "truncated-json",
        "malformed-json-garbage-bytes",
        "empty-string",
        "wrong-type-string-where-array-expected",
        "missing-required-field"
    ]

    /// Total category count = 5。
    public static var rejectionCategoryCount: Int {
        return rejectionCategories.count
    }

    /// 6 surfaces exercised by the rejection PROOFs:
    /// the bundle + the 5 ProjectionsBlock types。
    public static let surfacesExercised: [String] = [
        "BASRuntimeAuditProjectionsBundle",
        "BASAuditObservationProjectionsCthulhuAggregatesBlock",
        "BASAuditObservationProjectionsCthulhuLeftoversBlock",
        "BASAuditObservationProjectionsClosureBlock",
        "BASAuditObservationProjectionsKunlunAuditSchemasBlock",
        "BASAuditObservationProjectionsKunlunProtocolBlock"
    ]

    /// Total surfaces exercised = 6。
    public static var totalSurfacesExercised: Int {
        return surfacesExercised.count
    }

    /// Forward-compat PROOF:unknown extra fields are
    /// tolerated when all required fields are also
    /// present。
    public static let toleratesUnknownExtraFields: Bool =
        true

    /// Decoder state isolation PROOF:malformed input
    /// throws but does NOT taint subsequent valid
    /// decode。
    public static let decoderStateIsolatedAcrossErrors:
        Bool = true

    /// Replay determinism contract status:both halves
    /// proven (valid round-trip + invalid rejection)。
    public static let replayDeterminismContractClosed:
        Bool = true

    /// PROOF method:JSONDecoder().decode() throws
    /// DecodingError on malformed input。
    public static let proofMethod: String =
        "json-decoder-decoding-error-on-malformed-input"

    /// Reference to chapter 三百九二 replay-determinism
    /// doctrine — the doctrine this PROOF closes the
    /// second half of。
    public static let replayDeterminismDoctrineRef:
        String =
        "chapter 三百九二"

    /// V1 byte-equality preserved at every commit
    /// boundary。
    public static let byteEqualityPreserved: Bool = true
}
