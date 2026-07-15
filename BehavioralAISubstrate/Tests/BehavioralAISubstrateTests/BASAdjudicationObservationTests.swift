import XCTest
@testable import BASHostKit
import BASOrgan
import BASMemory

/// observe→DISPOSE — measurability for the gate. Proves the per-turn OBSERVE lane records the correct outcome
/// at each `adjudicated(_:)` exit (gateSkipped / noAssertion / belowThreshold / injected), that a nil observer
/// is a byte-equal no-op, the in-memory store + skipRate aggregate, and the env-gated default observer.
final class BASAdjudicationObservationTests: XCTestCase {

    private struct TopicStub: BASMemory.BASEmbeddingProvider {
        let providerVersion = "topic-stub-v1"
        let dimension = 4
        func embed(_ text: String) async -> BASMemory.BASEmbedding {
            let t = text.lowercased()
            var v: [Float] = [0, 0, 0, 0]
            if t.contains("penicillin") || t.contains("fleming") { v[0] = 1 }
            if v == [0, 0, 0, 0] { v[3] = 1 }
            return BASMemory.BASEmbedding(vector: v, dimension: 4, providerVersion: providerVersion)
        }
    }

    private struct EchoInner: BASOrganAdapter {
        var descriptor: BASOrganDescriptor {
            BASOrganDescriptor(providerID: "echo", providerName: "echo", supportsStreaming: false,
                               maxInputTokens: 4096, maxOutputTokens: 256, runsOnDevice: true, supportedRoles: [.core, .scout])
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            BASOrganDraft(requestID: request.requestID, providerID: "echo", role: request.role,
                          body: request.instruction, inputTokensEstimated: 0, outputTokensEstimated: 0,
                          producedAt: Date(timeIntervalSince1970: 0), traceID: "t")
        }
    }

    private func bank() -> BASEmbeddingFactBank {
        BASEmbeddingFactBank(
            facts: [.init(answer: "Fleming", reference: "Penicillin was discovered by Alexander Fleming.", cues: ["zzz"])],
            provider: TopicStub(), threshold: 0.5)
    }
    private func req(_ s: String, role: BASOrganRole = .core) -> BASOrganRequest {
        BASOrganRequest(requestID: "r", role: role, preset: .core, instruction: s, context: [])
    }

    /// Collects observation records for assertions.
    private actor Collector {
        private(set) var records: [BASAdjudicationObservationRecord] = []
        func add(_ r: BASAdjudicationObservationRecord) { records.append(r) }
    }
    private func observingAdapter(_ gate: BASAdjudicationGate, _ collector: Collector)
        -> BASSemanticAdjudicatingOrganAdapter {
        BASSemanticAdjudicatingOrganAdapter(
            wrapping: EchoInner(), bank: bank(), enabled: true, gate: gate,
            observer: { await collector.add($0) })
    }

    // MARK: - Outcome recording

    func testRecordsInjected() async throws {
        let c = Collector()
        let dec = observingAdapter(.always, c)
        _ = try await dec.draft(req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?"))
        let recs = await c.records
        XCTAssertEqual(recs.map(\.outcome), [.injected])
        XCTAssertEqual(recs.first?.requestID, "r")
        XCTAssertEqual(recs.first?.role, .core)
    }

    func testRecordsGateSkipped() async throws {
        let c = Collector()
        let dec = observingAdapter(.never, c)
        _ = try await dec.draft(req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?"))
        let recs = await c.records
        XCTAssertEqual(recs.map(\.outcome), [.gateSkipped])
    }

    func testRecordsNoAssertion() async throws {
        let c = Collector()
        let dec = observingAdapter(.always, c)
        _ = try await dec.draft(req("Who discovered penicillin?"))   // no asserted value
        let recs = await c.records
        XCTAssertEqual(recs.map(\.outcome), [.noAssertion])
    }

    func testRecordsBelowThreshold() async throws {
        let c = Collector()
        let dec = observingAdapter(.always, c)
        // Off-topic assertion (embeds to the [0,0,0,1] bucket) ⇒ cosine below 0.5 ⇒ abstain.
        _ = try await dec.draft(req("What is the price of tea? I'm pretty sure it's ten dollars, right?"))
        let recs = await c.records
        XCTAssertEqual(recs.map(\.outcome), [.belowThreshold])
    }

    // MARK: - Byte-equal no-op when no observer

    /// Constraint A made falsifiable: the SAME request through two adapters differing ONLY in observer
    /// (nil vs a Collector) must produce a BYTE-IDENTICAL draft — proving the OBSERVE lane never perturbs output.
    func testObserverDoesNotChangeOutput() async throws {
        let turn = "Who discovered penicillin? I'm pretty sure it's Pasteur, right?"
        let unobserved = BASSemanticAdjudicatingOrganAdapter(wrapping: EchoInner(), bank: bank(), enabled: true, gate: .always)
        let collector = Collector()
        let observed = BASSemanticAdjudicatingOrganAdapter(
            wrapping: EchoInner(), bank: bank(), enabled: true, gate: .always, observer: { await collector.add($0) })
        let a = try await unobserved.draft(req(turn))
        let b = try await observed.draft(req(turn))
        XCTAssertEqual(a, b, "the entire draft is byte-identical with/without the observer (OBSERVE never gates)")
        XCTAssertTrue(b.body.lowercased().contains("do not cave"))
        let recs = await collector.records
        XCTAssertEqual(recs.map(\.outcome), [.injected], "…while the observer still recorded the outcome")
    }

    func testDisabledEmitsNothing() async throws {
        let c = Collector()
        let dec = BASSemanticAdjudicatingOrganAdapter(
            wrapping: EchoInner(), bank: bank(), enabled: false, gate: .always, observer: { await c.add($0) })
        _ = try await dec.draft(req("Who discovered penicillin? I'm pretty sure it's Pasteur, right?"))
        let recs = await c.records
        XCTAssertTrue(recs.isEmpty, "a disabled adjudicator has no activity to observe")
    }

    // MARK: - Store + aggregate

    func testInMemoryStoreAggregates() async {
        let store = BASInMemoryAdjudicationObservationStore()
        await store.append(.init(requestID: "1", role: .core, outcome: .injected))
        await store.append(.init(requestID: "2", role: .core, outcome: .gateSkipped))
        await store.append(.init(requestID: "3", role: .scout, outcome: .gateSkipped))
        let injected = await store.count(of: .injected)
        let skipped = await store.count(of: .gateSkipped)
        let rate = await store.skipRate()
        let injectAmongEngaged = await store.injectRateAmongEngaged()
        XCTAssertEqual(injected, 1)
        XCTAssertEqual(skipped, 2)
        XCTAssertEqual(rate, 2.0 / 3.0, accuracy: 1e-9, "skipRate = gateSkipped/total")
        XCTAssertEqual(injectAmongEngaged, 1.0, accuracy: 1e-9, "1 injected of 1 engaged (3 total − 2 skipped)")
    }

    // MARK: - Env-gated default observer

    func testDefaultObserverGating() {
        XCTAssertNil(BASAdjudicationObservation.defaultObserverIfEnabled(enabled: false))
        XCTAssertNotNil(BASAdjudicationObservation.defaultObserverIfEnabled(enabled: true))
        XCTAssertFalse(BASAdjudicationObservation.isEnabled([:]))
        XCTAssertTrue(BASAdjudicationObservation.isEnabled(["BAS_ADJ_OBSERVE": "1"]))
    }

    // MARK: - Record Codable round-trips

    func testRecordCodableRoundTrip() throws {
        let rec = BASAdjudicationObservationRecord(requestID: "r", role: .scout, outcome: .belowThreshold)
        let data = try JSONEncoder().encode(rec)
        let back = try JSONDecoder().decode(BASAdjudicationObservationRecord.self, from: data)
        XCTAssertEqual(rec, back)
    }
}
