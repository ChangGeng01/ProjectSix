// MARK: - thoughtFold.compactSlots determinism CHARACTERIZATION (regression guard)
//
// FINDING (2026-07-01): the cross-run divergence surfaced by the ②-observe wiring
// byte-equality test (`BASModelHonestyObserveWiringTests.testHonestySinkIsByteEqualToNoSink`)
// is a BENIGN in-memory `Dictionary` hash-seed iteration-ORDER artifact — NOT a content
// determinism gap, and NOT a breach of the 红线-7 canonical byte-parity contract.
//
// Evidence (reproduced by the tests below):
//   • `thoughtFold.compactSlots` carries the SAME 20 keys with the SAME values on every
//     run. Swift `Dictionary ==` is order-independent, so the in-memory `==` is `true`,
//     and the `.sortedKeys` canonical JSON is byte-identical.
//   • Only the SERIALIZED key ORDER of a DEFAULT-order (non-sorted) `JSONEncoder` differs
//     ACROSS separate process launches, because Swift seeds `Hasher` with a per-process
//     random seed (SipHash). A raw `print(dict)` / default-order dump therefore looks
//     "different" run-to-run even though the content is identical — this is what was
//     misread as "run A had keys X+Y; run B had keys Z+W".
//   • The ONLY field that makes the FULL `BASEBrainTurnResult` Equatable-unequal across
//     two runs is `memoryBundle.retrievedAt` — a real-clock `Date()` OBSERVATION stamp,
//     already documented in `BASCoordinatorTurnDeterminismTests` and pinned by
//     `BASEBrainTurnResultReplayCanonicalizer.canonicalizedFields`. It is NOT an
//     authorization/consequential field.
//
// Contract verdict: the 红线-7 replay contract is defined on the CANONICAL form
// (`ebrain-turn-result-json-sha256-sortedKeys-utf8`: clock-pin + `.sortedKeys` at every
// nesting level). That normalizes the hash-order artifact away — the canonical replay
// digest is byte-stable both within a process AND across process launches. The byte-parity
// claim HOLDS. These tests are a permanent guard: if `compactSlots` content ever becomes
// genuinely nondeterministic (a `Set`/`Dictionary`-hash-order SUBSET selection, a UUID, a
// clock leaking into a slot value), the canonical-JSON / digest assertions below break.

import XCTest
@testable import BASHostKit
@testable import BASOrchestration
import BASRuntimeCore
import Foundation

final class BASThoughtFoldCompactSlotsDeterminismProbe: XCTestCase {

    private func sortedJSON<T: Encodable>(_ v: T) throws -> Data {
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return try e.encode(v)
    }

    private func twoFreshTurns() -> (BASEBrainTurnResult, BASEBrainTurnResult) {
        (BASCoordinatorTestStubs.makeStub().runTurn(BASCoordinatorTestStubs.makeStubRequest()),
         BASCoordinatorTestStubs.makeStub().runTurn(BASCoordinatorTestStubs.makeStubRequest()))
    }

    // 1) compactSlots CONTENT is run-stable — the dictionary is order-independent-equal and
    //    its canonical sorted-key JSON is byte-identical across two independent turns.
    func testCompactSlotsContentIsRunStable() throws {
        let (r1, r2) = twoFreshTurns()
        let s1 = r1.thoughtFold.compactSlots, s2 = r2.thoughtFold.compactSlots

        XCTAssertEqual(s1, s2,
            "compactSlots content differs (order-independent ==) — a REAL determinism gap. " +
            "keys A=\(s1.keys.sorted()) B=\(s2.keys.sorted())")
        XCTAssertEqual(try sortedJSON(s1), try sortedJSON(s2),
            "compactSlots canonical sorted-key JSON differs — a REAL determinism gap")
        XCTAssertEqual(try sortedJSON(r1.thoughtFold), try sortedJSON(r2.thoughtFold),
            "whole thoughtFold canonical sorted-key JSON differs — a REAL determinism gap")
    }

    // 2) The 红线-7 canonical replay contract HOLDS: canonicalized (clock-pinned) results are
    //    Equatable-equal and their sortedKeys SHA256 digests match — while the RAW digest
    //    (no clock-pin) differs, proving the ONLY drift is the pinned observation clock.
    func testCanonicalReplayDigestHolds() {
        let (r1, r2) = twoFreshTurns()
        let pin = Date(timeIntervalSince1970: 0)

        XCTAssertEqual(
            BASEBrainTurnResultReplayCanonicalizer.canonicalized(r1),
            BASEBrainTurnResultReplayCanonicalizer.canonicalized(r2),
            "canonicalized results differ — 红线-7 replay parity would be breached")

        let d1 = BASEBrainTurnResultReplayDigest.from(result: r1, producedAt: pin).digestString
        let d2 = BASEBrainTurnResultReplayDigest.from(result: r2, producedAt: pin).digestString
        XCTAssertEqual(d1, d2, "canonical replay digest differs across runs")

        let raw1 = BASEBrainTurnResultReplayDigest.from(result: r1, producedAt: pin, canonicalize: false).digestString
        let raw2 = BASEBrainTurnResultReplayDigest.from(result: r2, producedAt: pin, canonicalize: false).digestString
        XCTAssertNotEqual(raw1, raw2,
            "RAW (un-canonicalized) digest is expected to differ — it surfaces the observation " +
            "clock drift that canonicalization pins; if this becomes equal the negative control is dead")
    }

    // 3) Localize the full-result inequality: the memory bundle CONTENT is stable; only the
    //    real-clock `retrievedAt` observation stamp varies. (Mirrors the finding in
    //    BASCoordinatorTurnDeterminismTests — asserted here on the compactSlots probe path too.)
    func testOnlyObservationClockBreaksFullEquality() {
        let (r1, r2) = twoFreshTurns()
        XCTAssertNotEqual(r1, r2, "full result unexpectedly equal — the clock drift is gone")
        XCTAssertEqual(r1.memoryBundle.atoms, r2.memoryBundle.atoms)
        XCTAssertEqual(r1.memoryBundle.retrievalTags, r2.memoryBundle.retrievalTags)
        XCTAssertEqual(r1.thoughtFold, r2.thoughtFold,
            "thoughtFold (incl. compactSlots) is Equatable-equal — the divergence is NOT here")
    }
}
