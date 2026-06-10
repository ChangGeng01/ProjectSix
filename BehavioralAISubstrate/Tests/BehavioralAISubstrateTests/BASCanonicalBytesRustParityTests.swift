// MARK: - BASCanonicalBytesRustParityTests — 全面进化 T2.1a
//
// SAFETY-CRITICAL parity gate:proves the Rust 1.2.0 injective
// canonical-bytes assembler (`bas_canonical_bytes_assemble_v1_2`,
// crate ABI v2,reached via `BASCanonicalBytesBridge`) emits bytes
// IDENTICAL to the Swift incumbent `basSovereignAuditCanonicalBytes`
// for every input shape — including the exact in-band-separator
// hazards (U+001F / U+001E / ":") that motivated the 1.2.0 form.
//
// Three tiers:
//   1. Golden vectors — hand-computed expected bytes (pins BOTH
//      implementations to the spec,not just to each other)。
//   2. Adversarial vectors — in-band separators,unicode,empty
//      fields/elements,pre-epoch dates。
//   3. 200 seeded-random entries — deterministic SplitMix64 PRNG
//      over a hazard-weighted charset。
//
// The bridge is evidence-only (ADR-014 OPT-IN):no production
// caller routes through Rust。 These tests bank the cross-language
// evidence a future Rust audit-ledger lane would require。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASSovereign

#if os(iOS) || os(macOS)

final class BASCanonicalBytesRustParityTests: XCTestCase {

    // MARK: - ABI hygiene

    func testCanonicalBytesABIVersionMatchesLiveBinary() {
        XCTAssertEqual(
            BASCanonicalBytesBridge.abiVersion, 2,
            "T2.1a pinned crate ABI v2 (1.2.0 assembler added)")
        XCTAssertEqual(
            BASCanonicalBytesBridge.liveAbiVersion(),
            BASCanonicalBytesBridge.abiVersion,
            "Linked staticlib ABI must match the Swift bridge pin " +
            "— rebuild the XCFramework or roll the bridge back")
    }

    func testABIRegistryTracksCanonicalBytes() {
        XCTAssertTrue(
            BASRustABIRegistry.probes.contains {
                $0.crateName == "bas-canonical-bytes" },
            "Registry row must land in the same cut as the ABI bump")
        XCTAssertTrue(
            BASRustABIRegistry.auditMismatches().isEmpty,
            "No ABI drift across the whole registry: " +
            "\(BASRustABIRegistry.auditMismatches())")
    }

    // MARK: - Helpers

    /// Mirror of the incumbent's millisecond derivation:
    /// `String(Int(appendedAt.timeIntervalSince1970 * 1000))`。
    /// Swift `Int(Double)` truncates toward zero — Int64(Double)
    /// has identical semantics,pinned here by construction。
    private func appendedAtMs(_ date: Date) -> Int64 {
        return Int64(Int(date.timeIntervalSince1970 * 1000))
    }

    private func rustBytes(
        _ entry: BASSovereignAuditEntry,
        priorHash: String,
        signingNamespace: String
    ) -> Data? {
        return BASCanonicalBytesBridge.assembleV1_2(
            schemaVersion: entry.schemaVersion,
            auditID: entry.auditID,
            sessionID: entry.sessionID,
            turnID: entry.turnID,
            verdictRef: entry.verdictRef,
            ruleIDs: entry.ruleIDs,
            signalRefs: entry.signalRefs,
            actionRefs: entry.actionRefs,
            snapshotRef: entry.snapshotRef,
            actor: entry.actor.rawValue,
            appendedAtMs: appendedAtMs(entry.appendedAt),
            priorHash: priorHash,
            signingNamespace: signingNamespace)
    }

    /// Assert Swift incumbent == Rust for one entry,with a
    /// readable diff on failure。
    private func assertParity(
        _ entry: BASSovereignAuditEntry,
        priorHash: String,
        signingNamespace: String,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let swift = basSovereignAuditCanonicalBytes(
            for: entry,
            priorHash: priorHash,
            signingNamespace: signingNamespace)
        guard let rust = rustBytes(
            entry, priorHash: priorHash,
            signingNamespace: signingNamespace)
        else {
            XCTFail("[\(label)] Rust bridge returned nil",
                    file: file, line: line)
            return
        }
        XCTAssertEqual(
            swift, rust,
            "[\(label)] swift(\(swift.count)B)=" +
            "\(String(decoding: swift, as: UTF8.self)) vs " +
            "rust(\(rust.count)B)=" +
            "\(String(decoding: rust, as: UTF8.self))",
            file: file, line: line)
    }

    private func makeEntry(
        auditID: String,
        sessionID: String = "session-parity",
        turnID: String = "turn-1",
        verdictRef: String = "verdict-1",
        ruleIDs: [String] = [],
        signalRefs: [String] = [],
        actionRefs: [String] = [],
        snapshotRef: String = "snap-1",
        actor: BASSovereignAuditActor = .system,
        appendedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> BASSovereignAuditEntry {
        return BASSovereignAuditEntry(
            schemaVersion:
                BASSovereignAuditEntry.hardenedSchemaVersion,
            auditID: auditID,
            sessionID: sessionID,
            turnID: turnID,
            verdictRef: verdictRef,
            ruleIDs: ruleIDs,
            signalRefs: signalRefs,
            actionRefs: actionRefs,
            snapshotRef: snapshotRef,
            actor: actor,
            signature: "",
            appendedAt: appendedAt)
    }

    // MARK: - Tier 1: golden vectors (pin the SPEC, not just parity)

    func testGoldenMinimalEntryExactBytes() {
        // Mirrors the Rust-side `golden_minimal` unit test so both
        // languages are pinned to ONE hand-computed expectation。
        let entry = BASSovereignAuditEntry(
            schemaVersion: "1.2.0",
            auditID: "a",
            sessionID: "",
            turnID: "t",
            verdictRef: "v",
            ruleIDs: [],
            signalRefs: [],
            actionRefs: [],
            snapshotRef: "s",
            actor: .system,
            signature: "",
            appendedAt: Date(timeIntervalSince1970: 0))
        let expected = Data(
            "5:1.2.01:a0:1:t1:v1:01:01:01:s6:system1:07:GENESIS2:ns"
                .utf8)
        let swift = basSovereignAuditCanonicalBytes(
            for: entry, priorHash: "GENESIS",
            signingNamespace: "ns")
        XCTAssertEqual(swift, expected,
            "Swift incumbent drifted from the hand-computed vector")
        XCTAssertEqual(
            rustBytes(entry, priorHash: "GENESIS",
                      signingNamespace: "ns"),
            expected,
            "Rust assembler drifted from the hand-computed vector")
    }

    func testGoldenArrayWithElementsExactBytes() {
        // Arrays emit a count-marker part then one part per element:
        // ruleIDs ["r1","rr2"] → "1:2" + "2:r1" + "3:rr2"。
        let entry = makeEntry(
            auditID: "a",
            sessionID: "s",
            turnID: "t",
            verdictRef: "v",
            ruleIDs: ["r1", "rr2"],
            snapshotRef: "sn",
            appendedAt: Date(timeIntervalSince1970: 1))
        // Typed-array joined() — a 15-term `+` chain times out the
        // Swift 6 type-checker (Xcode 27 beta lane; audited)。
        let expectedParts: [String] = [
            "5:1.2.0", "1:a", "1:s", "1:t", "1:v",
            "1:2", "2:r1", "3:rr2",
            "1:0", "1:0",
            "2:sn", "6:system", "4:1000", "1:p", "1:n",
        ]
        let expected = Data(expectedParts.joined().utf8)
        let swift = basSovereignAuditCanonicalBytes(
            for: entry, priorHash: "p", signingNamespace: "n")
        XCTAssertEqual(swift, expected)
        XCTAssertEqual(
            rustBytes(entry, priorHash: "p", signingNamespace: "n"),
            expected)
    }

    // MARK: - Tier 2: adversarial vectors

    func testParityWithInBandUnitAndRecordSeparators() {
        // THE hazard class that motivated 1.2.0:U+001F/U+001E
        // legitimately appear inside refs (composite delimiters)。
        let entry = makeEntry(
            auditID: "audit\u{001F}id",
            sessionID: "sess\u{001E}ion",
            verdictRef: "shadow_trial\u{001F}trial-42",
            ruleIDs: ["rule\u{001F}A", "rule\u{001E}B"],
            signalRefs: ["wit\u{001F}1\u{001E}2"],
            actionRefs: ["a\u{001F}", "\u{001E}b"])
        assertParity(entry, priorHash: "prior\u{001F}hash",
                     signingNamespace: "ns\u{001E}x",
                     "in-band-separators")
    }

    func testParityWithInBandColonsAndDigits() {
        // ":" + leading digits attack the length-prefix framing
        // itself ("3:abc" content vs framing)。
        let entry = makeEntry(
            auditID: "3:abc",
            sessionID: "12:34:56",
            turnID: ":",
            verdictRef: "0:",
            ruleIDs: ["5:1.2.0", ":::"],
            signalRefs: ["7:GENESIS"])
        assertParity(entry, priorHash: "2:ns",
                     signingNamespace: "1:0", "in-band-colons")
    }

    func testParityWithUnicodeMultibyteContent() {
        // Length prefixes are UTF-8 BYTE counts,not character
        // counts — multibyte content is the proof。
        let entry = makeEntry(
            auditID: "审计-标识",
            sessionID: "会话🧠",
            verdictRef: "裁决\u{001F}中文",
            ruleIDs: ["规则一", "règle-é", "🔒"],
            actionRefs: ["行动\u{0000}null"])
        assertParity(entry, priorHash: "前-hash",
                     signingNamespace: "命名空间", "unicode")
    }

    func testParityWithEmptyAndWhitespaceFields() {
        let entry = makeEntry(
            auditID: "",
            sessionID: " ",
            turnID: "\n",
            verdictRef: "",
            ruleIDs: ["", "", ""],
            signalRefs: [""],
            snapshotRef: "")
        assertParity(entry, priorHash: "",
                     signingNamespace: "", "empty-fields")
    }

    func testParityWithPreEpochDate() {
        // Negative milliseconds must format identically ("-1500")。
        let entry = makeEntry(
            auditID: "pre-epoch",
            appendedAt: Date(timeIntervalSince1970: -1.5))
        assertParity(entry, priorHash: "p",
                     signingNamespace: "n", "pre-epoch")
    }

    func testParityWithOperatorActor() {
        let entry = makeEntry(auditID: "op", actor: .operator)
        assertParity(entry, priorHash: "p",
                     signingNamespace: "n", "operator-actor")
    }

    // MARK: - Tier 3: 200 seeded-random entries

    /// SplitMix64 — deterministic across platforms/runs,so a
    /// failure reproduces from the printed seed alone。
    private struct SplitMix64 {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func below(_ bound: Int) -> Int {
            return Int(next() % UInt64(bound))
        }
    }

    /// Hazard-weighted charset:ASCII,framing chars (":",digits),
    /// legacy separators (U+001F/U+001E),multibyte unicode。
    private static let hazardChars: [String] = [
        "a", "b", "z", "A", "Z", "0", "1", "9", "-", "_", ".",
        ":", ":", "|", ",", " ",
        "\u{001F}", "\u{001E}",
        "中", "文", "é", "🧠", "\u{0000}"
    ]

    private func randomString(
        _ rng: inout SplitMix64, maxLen: Int = 24
    ) -> String {
        let len = rng.below(maxLen + 1)
        var out = ""
        for _ in 0..<len {
            out += Self.hazardChars[
                rng.below(Self.hazardChars.count)]
        }
        return out
    }

    private func randomArray(
        _ rng: inout SplitMix64, maxCount: Int = 6
    ) -> [String] {
        let count = rng.below(maxCount + 1)
        return (0..<count).map { _ in randomString(&rng) }
    }

    func testTwoHundredSeededRandomEntriesParity() {
        var rng = SplitMix64(state: 0xBA5_CA0_0A1)
        for i in 0..<200 {
            // Dates span pre-epoch → far future,fractional ms。
            let ti = Double(Int64(rng.next() % 4_000_000_000))
                - 1_000_000_000.0
                + Double(rng.below(1000)) / 1000.0
            let entry = makeEntry(
                auditID: randomString(&rng),
                sessionID: randomString(&rng),
                turnID: randomString(&rng),
                verdictRef: randomString(&rng),
                ruleIDs: randomArray(&rng),
                signalRefs: randomArray(&rng),
                actionRefs: randomArray(&rng),
                snapshotRef: randomString(&rng),
                actor: rng.below(2) == 0 ? .system : .operator,
                appendedAt: Date(timeIntervalSince1970: ti))
            assertParity(
                entry,
                priorHash: randomString(&rng, maxLen: 48),
                signingNamespace: randomString(&rng),
                "seeded[\(i)]")
        }
    }

    // MARK: - Injectivity spot-check (cross-language)

    func testLegacyCollidingPairIsDistinctInBothLanguages() {
        // Under 1.1.0 (arrays joined with U+001F),
        // `["a\u{001F}b"]` and `["a", "b"]` produce IDENTICAL
        // joined bytes — the exact collision class that motivated
        // the 1.2.0 injective form。 Both implementations must
        // keep them distinct (and agree with each other)。
        let a = makeEntry(auditID: "x", ruleIDs: ["a\u{001F}b"])
        let b = makeEntry(auditID: "x", ruleIDs: ["a", "b"])
        let swiftA = basSovereignAuditCanonicalBytes(
            for: a, priorHash: "p", signingNamespace: "n")
        let swiftB = basSovereignAuditCanonicalBytes(
            for: b, priorHash: "p", signingNamespace: "n")
        XCTAssertNotEqual(swiftA, swiftB,
            "1.2.0 must separate the legacy-colliding pair")
        let rustA = rustBytes(a, priorHash: "p",
                              signingNamespace: "n")
        let rustB = rustBytes(b, priorHash: "p",
                              signingNamespace: "n")
        XCTAssertNotEqual(rustA, rustB,
            "Rust must separate the legacy-colliding pair")
        XCTAssertEqual(swiftA, rustA)
        XCTAssertEqual(swiftB, rustB)
    }
}

#endif  // os(iOS) || os(macOS)
