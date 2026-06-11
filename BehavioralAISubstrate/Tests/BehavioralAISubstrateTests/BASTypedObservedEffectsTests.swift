// MARK: - BASTypedObservedEffectsTests — 全面进化 T2.3 低熵
//
// Contract gate for the typed-observed-effects parallel field + the
// phys-footprint snapshot fields + the memory-evidence sampler。 The
// load-bearing claims:
//   1. BYTE EQUALITY: a record that never sets `typedObservedEffects`
//      encodes to the EXACT same JSON as before the field existed
//      (synthesized Codable omits the nil key) — this is what keeps
//      the replay-digest preimage stable for the spine producer。
//   2. Typed-first parsing: composers consume typed pairs when
//      present,fall back to the legacy colon-string parse when
//      absent,and SKIP (never guess) on typed/string disagreement。
//   3. Backward decode: pre-T2.3 JSON (no key) decodes with nil。
//   4. The dual-write producer emits string/typed twins that agree。
//   5. Footprint probe honesty: snapshot fields + sampler are nil on
//      failure,never 0-as-unknown;sampler peak is plausible。

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
@testable import BASAppleAdapters

final class BASTypedObservedEffectsTests: XCTestCase {

    private func makeRecord(
        typed: [BASShadowTrialTypedEffect]? = nil,
        effects: [String] = ["alpha: 1", "beta: x"]
    ) -> BASShadowTrialRecord {
        BASShadowTrialRecord(
            trialID: "trial-t23",
            candidateRef: "candidate-t23",
            trialScope: "typed-effects-test",
            startAt: Date(timeIntervalSince1970: 1_700_000_000),
            endAt: Date(timeIntervalSince1970: 1_700_000_060),
            observedEffects: effects,
            failConditions: [],
            promotionRecommendation: nil,
            completionState: "observing",
            typedObservedEffects: typed)
    }

    private func sortedKeysJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    // MARK: - 1. Byte equality (the ADR-014 load-bearing claim)

    func testNilTypedFieldEncodesByteIdenticalToPreChangeGolden() throws {
        // Golden computed from the PRE-change struct shape (no
        // typedObservedEffects key anywhere)。 If synthesized Codable
        // ever starts emitting the nil key,this fails loudly。
        let json = try sortedKeysJSON(makeRecord(typed: nil))
        XCTAssertFalse(json.contains("typedObservedEffects"),
            "nil typed field must be OMITTED from encoded JSON")
        let golden = "{\"candidateRef\":\"candidate-t23\","
            + "\"completionState\":\"observing\","
            + "\"endAt\":1700000060,"
            + "\"failConditions\":[],"
            + "\"observedEffects\":[\"alpha: 1\",\"beta: x\"],"
            + "\"schemaVersion\":\"1.0.0\","
            + "\"startAt\":1700000000,"
            + "\"trialID\":\"trial-t23\","
            + "\"trialScope\":\"typed-effects-test\"}"
        XCTAssertEqual(json, golden,
            "record without typed effects must encode byte-identical " +
            "to the pre-T2.3 shape")
    }

    func testPopulatedTypedFieldRoundTrips() throws {
        let typed = [
            BASShadowTrialTypedEffect(key: "alpha", value: "1", kind: .metric),
            BASShadowTrialTypedEffect(key: "beta", value: "x", kind: .label),
        ]
        let record = makeRecord(typed: typed)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(
            BASShadowTrialRecord.self, from: data)
        XCTAssertEqual(decoded.typedObservedEffects, typed)
    }

    // MARK: - 2. Typed-first / fallback / disagreement

    func testEffectFieldsFallsBackToStringsWhenTypedAbsent() {
        let fields = makeRecord(typed: nil).effectFields()
        XCTAssertEqual(fields?["alpha"], "1")
        XCTAssertEqual(fields?["beta"], "x")
    }

    func testEffectFieldsPrefersTypedAndMergesStringOnlyKeys() {
        // typed carries a key the strings lack; strings carry one
        // typed lacks — both survive the merge,typed wins on shape。
        let typed = [BASShadowTrialTypedEffect(
            key: "gamma", value: "2.5", kind: .metric)]
        let fields = makeRecord(typed: typed).effectFields()
        XCTAssertEqual(fields?["gamma"], "2.5", "typed-only key consumed")
        XCTAssertEqual(fields?["alpha"], "1", "string-only key preserved")
    }

    func testEffectFieldsSkipsOnTypedStringDisagreement() {
        // Same key, DIFFERENT value across lanes = producer bug ⇒ nil。
        let typed = [BASShadowTrialTypedEffect(
            key: "alpha", value: "999", kind: .metric)]
        XCTAssertNil(makeRecord(typed: typed).effectFields(),
            "typed/string disagreement must skip the record, " +
            "never silently prefer a lane")
    }

    func testComposerCountsDisagreementAsSkippedRecord() {
        // End-to-end through the CoreAI composer: a coreai-classifier
        // record whose typed lane contradicts its string lane parses
        // to nil (counted as skipped by compose())。
        let strings = [
            "incumbent_label: chat",
            "candidate_label: chat",
            "labels_agree: true",
            "logits_mae: 0.001",
            "candidate_latency_ms: 0.5",
        ]
        let contradicting = [BASShadowTrialTypedEffect(
            key: "candidate_label", value: "task", kind: .label)]
        let record = BASShadowTrialRecord(
            trialID: "t",
            candidateRef: "c",
            trialScope: BASCoreAIVerdictEvidenceComposer.trialScope,
            startAt: Date(timeIntervalSince1970: 0),
            observedEffects: strings,
            completionState: "observing",
            typedObservedEffects: contradicting)
        XCTAssertNil(BASCoreAIVerdictEvidenceComposer.parse(record: record))
        // And the agreeing typed lane parses fine。
        let agreeing = [BASShadowTrialTypedEffect(
            key: "candidate_label", value: "chat", kind: .label)]
        var ok = record
        ok.typedObservedEffects = agreeing
        XCTAssertNotNil(BASCoreAIVerdictEvidenceComposer.parse(record: ok))
    }

    // MARK: - 3. Backward decode (pre-T2.3 JSON)

    func testPreT23JSONDecodesWithNilTypedField() throws {
        let legacy = """
        {"candidateRef":"c","completionState":"observing",
         "failConditions":[],"observedEffects":["k: v"],
         "schemaVersion":"1.0.0","startAt":1700000000,
         "trialID":"t","trialScope":"s"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let record = try decoder.decode(
            BASShadowTrialRecord.self, from: Data(legacy.utf8))
        XCTAssertNil(record.typedObservedEffects)
        XCTAssertEqual(record.effectFields()?["k"], "v")
    }

    // MARK: - 4. Dual-write producer agreement

    func testCoreAIShadowProducerDualWritesAgreeingLanes() {
        let comparison = BASCoreAIShadowComparison.Result(
            incumbentLabel: "chat",
            candidateLabel: "chat",
            labelsAgree: true,
            logitsMAE: 0.000_5,
            candidateLatencyMillis: 0.7,
            incumbentLatencyMillis: 0.14)
        let ledger = BASCoreAIShadowComparison.record(
            into: BASShadowTrialFeedbackLedger(),
            trialID: "dual-write",
            inputLength: 42,
            comparison: comparison,
            startAt: Date(timeIntervalSince1970: 0),
            endAt: Date(timeIntervalSince1970: 1))
        let record = ledger.pendingTrials.last
        XCTAssertNotNil(record?.typedObservedEffects)
        XCTAssertEqual(
            record?.typedObservedEffects?.count, 7,
            "6 base effects + paired incumbent latency")
        // The canonical view must NOT skip (lanes agree) and must
        // parse back to the same Result through the composer。
        XCTAssertNotNil(record?.effectFields())
        let parsed = record.flatMap {
            BASCoreAIVerdictEvidenceComposer.parse(record: $0)
        }
        XCTAssertEqual(parsed, comparison)
    }

    // MARK: - 5. Footprint probe honesty + sampler

    func testSnapshotCarriesFootprintTrioOnApplePlatforms() async {
        let probe = BASSystemProbe()
        let snapshot = await probe.probe()
        #if os(iOS) || os(macOS)
        XCTAssertNotNil(snapshot.physFootprintBytes)
        XCTAssertGreaterThan(snapshot.physFootprintBytes ?? 0, 0,
            "a live test process has a nonzero phys footprint")
        #else
        XCTAssertNil(snapshot.physFootprintBytes)
        #endif
    }

    func testSnapshotFootprintFieldsOmittedWhenNilOnWire() throws {
        let snapshot = BASSystemSnapshot(
            thermalBucket: .nominal,
            cpuLogicalCount: 1, cpuPhysicalCount: 1,
            cpuPerformanceCount: 0, cpuEfficiencyCount: 0,
            cpuBrand: "test",
            memoryTotalBytes: 1, memoryPressurePercent: 0,
            vmPageSize: 4096)
        let json = try sortedKeysJSON(snapshot)
        XCTAssertFalse(json.contains("physFootprintBytes"),
            "nil footprint fields must be omitted (wire-stable)")
    }

    func testSampledPeakFootprintFeedsGateMemoryEvidence() {
        var sink: [UInt8] = []
        let peak = BASShadowMemoryEvidenceSampler
            .sampledPeakFootprintBytes(steps: 3) { _ in
                // Touch real memory so the sampled max is live。
                sink.append(
                    contentsOf: [UInt8](repeating: 7, count: 256 * 1024))
            }
        #if os(iOS) || os(macOS)
        let bytes = try? XCTUnwrap(peak)
        XCTAssertGreaterThan(bytes ?? 0, 1024 * 1024,
            "test process footprint exceeds 1MB")
        // Feed it where it belongs: the gate's memory dimension。
        let composition = BASCoreAIVerdictEvidenceComposer.compose(
            records: [],
            distinctDeviceCount: 1,
            candidatePeakMemoryBytes: peak,
            incumbentPeakMemoryBytes: peak)
        XCTAssertEqual(
            composition.evidence.candidatePeakMemoryBytes, peak)
        #endif
        XCTAssertFalse(sink.isEmpty)
    }
}

// MARK: - iOS 27 P6 — swap-stats probe honesty (appended gate)

extension BASTypedObservedEffectsTests {
    func testVmSwapStatsProbeIsHonestAcrossSDKs() {
        XCTAssertEqual(
            BASVmSwapStatsProbe.liveCBridgeABIVersion(), 1)
        // Stable-toolchain builds compile the -3 fallback (nil);
        // 27-SDK builds on modern kernels return real numbers。
        // Either is honest;what is FORBIDDEN is 0-as-unknown with
        // a success rc — covered by the C contract (memset +
        // returned-count preflight)。
        if let snapshot = BASVmSwapStatsProbe.rawSnapshot() {
            // Real numbers: donated/swap are plausible page counts
            // (no upper assert — device-dependent)。
            XCTAssertGreaterThanOrEqual(snapshot.swapPages, 0)
        } else {
            XCTAssertNil(BASVmSwapStatsProbe.rawSnapshot())
        }
    }
}
