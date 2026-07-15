// MARK: - QINAOCrossLanguageSchemaAlphabetParityTests
//
// QINAO substrate gate #98 / L14:
//   "the Chenglu feature alphabet must be consistent across the
//    language boundary."
//
// ## Source of truth
//
// The cross-language contract surface is `BASChengluFeatureEncoder`
// (Sources/BASAppleAdapters/BASChengluCoreMLAdapters.swift). Its
// doc-comment (line 83-85) states the Swift alphabet "mirrors
// `chenglu_feature_schema.py`" and that "cross-language parity is
// verified by `scripts/check_chenglu_schema_parity.py`".
//
// BOTH the Python schema AND that parity script are ABSENT from
// the repo. True cross-LANGUAGE parity therefore strictly needs an
// absent Python encoder and CANNOT be asserted host-side.
//
// This gate authors the STRONGEST host-runnable Swift-internal
// invariant instead: a FROZEN-MANIFEST anti-drift hash over the
// full canonical alphabet (the exact bytes that any Python side
// must agree with). It mirrors the construction of
// `BASRegistryFrozenHashTests` (chapter 473) verbatim:
//   - canonical JSON (sortedKeys) of the live encoder alphabet
//   - SHA256 compared to a frozen committed hash, tolerance = 0
//   - full coverage of all 6 alphabets + mutation-seed + key order
//   - a MUTATION assertion proving the gate actually catches drift
//
// If the alphabet drifts on the Swift side (silently or
// intentionally) the hash changes and this gate fails loudly,
// which is the precise event that would break cross-language
// parity. host_complete = false: the Python half is unverifiable
// in-process.

import XCTest
import CryptoKit
@testable import BASAppleAdapters
@testable import BASRuntimeCore

final class QINAOCrossLanguageSchemaAlphabetParityTests: XCTestCase {

    /// SHA256 of the canonical-JSON-encoded live Chenglu alphabet
    /// manifest. Frozen at gate-author time. Any drift in
    /// `BASChengluFeatureEncoder`'s 6 category lists, mutation-seed
    /// count, total dimension, or canonical key order changes this
    /// hash and fails the gate. Regenerate intentionally only when
    /// the Python `chenglu_feature_schema.py` is updated in lock-
    /// step; commit message MUST justify the move.
    static let frozenAlphabetSha256: String =
        "f76ee1e9bd32ee7de4e71d6bd4e73416ede0e554e172021a87b5b0e462fd130a"

    /// Build the canonical alphabet manifest DIRECTLY from the live
    /// `BASChengluFeatureEncoder` values, then canonical-JSON
    /// encode it (sortedKeys) exactly as `BASRegistryFrozenHashTests`
    /// does. The frozen hash was captured from precisely these bytes.
    private func canonicalAlphabetManifest() -> [String: [String]] {
        return [
            "tones": BASChengluFeatureEncoder.tones,
            "domains": BASChengluFeatureEncoder.domains,
            "stakes": BASChengluFeatureEncoder.stakes,
            "timeframes": BASChengluFeatureEncoder.timeframes,
            "confidants": BASChengluFeatureEncoder.confidants,
            "askShapes": BASChengluFeatureEncoder.askShapes,
            "mutationSeedCount":
                [String(BASChengluFeatureEncoder.mutationSeedCount)],
            "totalDimension":
                [String(BASChengluFeatureEncoder.totalDimension)],
            "canonicalKeyOrder":
                BASChengluFeatureEncoder.canonicalKeyOrder
        ]
    }

    private func sha256Hex(of manifest: [String: [String]]) throws
        -> String
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(manifest)
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    func test_qinao_cross_language_schema_alphabet_parity() throws {
        // --- Coverage assertions over the FULL alphabet (the
        //     contract surface a Python encoder must match). These
        //     pin every cardinality the 43-dim one-hot depends on. ---
        XCTAssertEqual(
            BASChengluFeatureEncoder.tones.count, 8,
            "tone alphabet cardinality drifted")
        XCTAssertEqual(
            BASChengluFeatureEncoder.domains.count, 10,
            "domain alphabet cardinality drifted")
        XCTAssertEqual(
            BASChengluFeatureEncoder.stakes.count, 6,
            "stake alphabet cardinality drifted")
        XCTAssertEqual(
            BASChengluFeatureEncoder.timeframes.count, 7,
            "timeframe alphabet cardinality drifted")
        XCTAssertEqual(
            BASChengluFeatureEncoder.confidants.count, 4,
            "confidant alphabet cardinality drifted")
        XCTAssertEqual(
            BASChengluFeatureEncoder.askShapes.count, 3,
            "askShape alphabet cardinality drifted")
        XCTAssertEqual(
            BASChengluFeatureEncoder.mutationSeedCount, 5,
            "mutation seed slot count drifted")
        XCTAssertEqual(
            BASChengluFeatureEncoder.totalDimension, 43,
            "total feature dimension drifted from 43")
        XCTAssertEqual(
            BASChengluFeatureEncoder.canonicalKeyOrder.count, 43,
            "canonical key order length drifted from 43")

        // --- Every alphabet entry must be free of the featureRef
        //     field separator, otherwise the cross-language pipe-
        //     encoded `featureRef` round-trip silently corrupts. ---
        let allValues: [String] =
            BASChengluFeatureEncoder.tones
            + BASChengluFeatureEncoder.domains
            + BASChengluFeatureEncoder.stakes
            + BASChengluFeatureEncoder.timeframes
            + BASChengluFeatureEncoder.confidants
            + BASChengluFeatureEncoder.askShapes
        for value in allValues {
            XCTAssertFalse(
                BASChengluFeatureRefBuilder.containsSeparator(value),
                "alphabet value '\(value)' contains the field" +
                " separator — breaks featureRef cross-language" +
                " round-trip")
        }

        // --- Key-order parity: the canonical keys must be exactly
        //     the prefixed one-hot slots in declared order. This is
        //     the precise ordering a Python MLMultiArray must use. ---
        var expectedKeys: [String] = []
        for tone in BASChengluFeatureEncoder.tones {
            expectedKeys.append("tone_\(tone)")
        }
        for domain in BASChengluFeatureEncoder.domains {
            expectedKeys.append("domain_\(domain)")
        }
        for stake in BASChengluFeatureEncoder.stakes {
            expectedKeys.append("stake_\(stake)")
        }
        for timeframe in BASChengluFeatureEncoder.timeframes {
            expectedKeys.append("timeframe_\(timeframe)")
        }
        for confidant in BASChengluFeatureEncoder.confidants {
            expectedKeys.append("confidant_\(confidant)")
        }
        for askShape in BASChengluFeatureEncoder.askShapes {
            expectedKeys.append("askshape_\(askShape)")
        }
        for i in 0..<BASChengluFeatureEncoder.mutationSeedCount {
            expectedKeys.append("mutation_seed_\(i)")
        }
        XCTAssertEqual(
            BASChengluFeatureEncoder.canonicalKeyOrder,
            expectedKeys,
            "canonical key order drifted from declared alphabet" +
            " order — Python feature positions would misalign")

        // --- FROZEN-MANIFEST anti-drift hash (tolerance = 0).
        //     Mirrors BASRegistryFrozenHashTests exactly. ---
        let liveManifest = canonicalAlphabetManifest()
        let liveHex = try sha256Hex(of: liveManifest)
        XCTAssertEqual(
            liveHex,
            Self.frozenAlphabetSha256,
            "Chenglu feature alphabet drifted。 If the change is" +
            " INTENTIONAL, update frozenAlphabetSha256 to:" +
            "\n    \"\(liveHex)\"\n" +
            "AND update chenglu_feature_schema.py + re-run" +
            " scripts/check_chenglu_schema_parity.py in lock-step," +
            " then justify in the commit message。 If UNEXPECTED," +
            " the Swift alphabet has silently diverged from the" +
            " Python language boundary。")

        // --- MUTATION proof: the gate MUST catch a single-entry
        //     drift. A mutated manifest must NOT match the frozen
        //     hash, proving the gate is not vacuous. ---
        var mutated = liveManifest
        mutated["tones"] =
            BASChengluFeatureEncoder.tones + ["__drift_probe__"]
        let mutatedHex = try sha256Hex(of: mutated)
        XCTAssertNotEqual(
            mutatedHex,
            Self.frozenAlphabetSha256,
            "mutation probe did not change the hash — the parity" +
            " gate is vacuous and would not catch real drift")

        print(
            "QINAO-GATE cross_language_schema_alphabet_parity:" +
            " PASS (host-only) — 43-dim Chenglu alphabet frozen-" +
            "manifest parity held (6 alphabets + seed + key order," +
            " tolerance=0, mutation-probe caught); Python-side" +
            " chenglu_feature_schema.py parity NOT verifiable in-" +
            "process (encoder + check_chenglu_schema_parity.py" +
            " absent from repo)")
    }
}
