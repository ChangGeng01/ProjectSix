import XCTest
@testable import BASMLXAdapter

/// B3 轨迹熵早退 — the pure stop-rule state machine (no MLX, no model). Frontier basis
/// (FRONTIER_2026H2_EVOLUTION.md B3): EntroCut/DEER-class convergence exits cut 25-50% of the
/// thinking trace training-free; the TRAP is answer-confidence overconfidence — so the rule is
/// (a) a windowed entropy CONVERGENCE signal fired only at boundary tokens after a minimum trace,
/// and (b) a deterministic BUDGET guard that reserves an answer tail (the 96-tok co-gate artifact
/// fix). Marker-gated: with no `<think>` in the stream the policy must never intervene.
final class BASTraceExitPolicyTests: XCTestCase {

    private var cfg: BASTraceExitConfig {
        BASTraceExitConfig(
            thinkOpenToken: 68, thinkCloseToken: 69,
            closeSequence: [10, 69, 11],
            boundaryTokens: [10, 11],
            minThinkTokens: 4, entropyWindow: 3, entropyThresholdMillinats: 500,
            answerReserveTokens: 8)
    }

    private func observeAll(
        _ policy: inout BASTraceExitPolicy, tokens: [(tok: Int, ent: Int?)],
        outStart: Int = 0, maxTokens: Int = 1000
    ) -> [BASTraceExitPolicy.Verdict] {
        var out = outStart
        return tokens.map { t in
            out += 1
            return policy.observe(token: t.tok, entropyMillinats: t.ent, outCount: out, maxTokens: maxTokens)
        }
    }

    func testNoMarkersNeverFires() {
        var p = BASTraceExitPolicy(config: cfg)
        let vs = observeAll(&p, tokens: (0 ..< 50).map { (tok: 100 + $0 % 3, ent: 1) }, maxTokens: 20)
        XCTAssertTrue(vs.allSatisfy { if case .none = $0 { return true } else { return false } },
                      "no <think> in stream ⇒ zero intervention, even past any budget")
    }

    func testEntropyConvergenceFiresAtBoundaryAfterMinThink() {
        var p = BASTraceExitPolicy(config: cfg)
        // open, then 3 low-entropy non-boundary tokens (window fills, minThink not yet met at 3)
        var vs = observeAll(&p, tokens: [(68, nil), (100, 10), (101, 10), (102, 10)])
        XCTAssertTrue(vs.allSatisfy { if case .none = $0 { return true } else { return false } })
        // 4th think token, low entropy, NOT boundary → still no fire (boundary required)
        vs = observeAll(&p, tokens: [(103, 10)])
        if case .close = vs[0] { XCTFail("must not fire off-boundary") }
        // boundary token, low entropy → fires with reason .entropy
        vs = observeAll(&p, tokens: [(10, 10)])
        guard case .close(let reason) = vs[0], reason == .entropy else {
            return XCTFail("expected entropy close at boundary, got \(vs[0])")
        }
    }

    func testHighEntropyHoldsFire() {
        var p = BASTraceExitPolicy(config: cfg)
        _ = observeAll(&p, tokens: [(68, nil)])
        let vs = observeAll(&p, tokens: (0 ..< 20).map { i in (tok: i % 5 == 0 ? 10 : 100, ent: 5000) })
        XCTAssertTrue(vs.allSatisfy { if case .none = $0 { return true } else { return false } },
                      "un-converged (high-entropy) thinking must run")
    }

    func testNilEntropyDoesNotCorruptWindow() {
        var p = BASTraceExitPolicy(config: cfg)
        _ = observeAll(&p, tokens: [(68, nil)])
        // low entropies interleaved with nil (refeed-path tokens carry no signal)
        _ = observeAll(&p, tokens: [(100, 10), (101, nil), (102, 10), (103, nil), (104, 10)])
        let vs = observeAll(&p, tokens: [(10, 10)])
        guard case .close(.entropy) = vs[0] else {
            return XCTFail("nil-entropy observations must be transparent to the window")
        }
    }

    func testBudgetGuardFiresOffBoundaryAndBeforeEntropy() {
        var p = BASTraceExitPolicy(config: cfg)
        _ = observeAll(&p, tokens: [(68, nil)], maxTokens: 20)
        // high entropy (no convergence), non-boundary, but outCount crosses maxTokens - reserve
        let vs = observeAll(&p, tokens: (0 ..< 15).map { (tok: 200 + $0, ent: 9000) },
                            outStart: 1, maxTokens: 20)
        let fired = vs.compactMap { v -> BASTraceExitPolicy.Reason? in
            if case .close(let r) = v { return r } else { return nil }
        }
        XCTAssertEqual(fired.first, .budget, "budget guard must fire regardless of boundary/entropy")
        // fires when outCount reaches maxTokens - reserve = 12 (outStart 1 + index 11 ⇒ vs[10])
        if case .close = vs[10] {} else { XCTFail("expected fire exactly at the reserve line, got \(vs)") }
    }

    func testModelSelfCloseDisarms() {
        var p = BASTraceExitPolicy(config: cfg)
        _ = observeAll(&p, tokens: [(68, nil), (100, 10), (101, 10), (102, 10), (103, 10)])
        _ = observeAll(&p, tokens: [(69, 10)])   // model closes its own think block
        XCTAssertTrue(p.closed)
        let vs = observeAll(&p, tokens: (0 ..< 30).map { (tok: $0 % 4 == 0 ? 10 : 300, ent: 1) },
                            maxTokens: 25)
        XCTAssertTrue(vs.allSatisfy { if case .none = $0 { return true } else { return false } },
                      "after self-close the policy must never touch the answer")
    }

    func testForcedCloseIsOneShot() {
        var p = BASTraceExitPolicy(config: cfg)
        _ = observeAll(&p, tokens: [(68, nil), (100, 10), (101, 10), (102, 10), (103, 10)])
        guard case .close = observeAll(&p, tokens: [(10, 10)])[0] else { return XCTFail("arm") }
        p.markForcedClose()
        XCTAssertTrue(p.closed)
        // a SECOND <think> later in the same generation must not re-arm (one intervention per turn)
        let vs = observeAll(&p, tokens: [(68, nil), (100, 10), (101, 10), (102, 10), (103, 10), (10, 10)],
                            maxTokens: 10)
        XCTAssertTrue(vs.allSatisfy { if case .none = $0 { return true } else { return false } })
    }

    func testPrimedInThink() {
        var p = BASTraceExitPolicy(config: cfg, primedInThink: true)
        _ = observeAll(&p, tokens: [(100, 10), (101, 10), (102, 10), (103, 10)])
        guard case .close(.entropy) = observeAll(&p, tokens: [(10, 10)])[0] else {
            return XCTFail("primed-in-think must behave as if <think> was seen")
        }
    }

    func testEntropyDisabledLeavesBudgetGuard() {
        var c = cfg
        c.entropyThresholdMillinats = nil     // entropy rule off; budget guard stays
        var p = BASTraceExitPolicy(config: c)
        _ = observeAll(&p, tokens: [(68, nil)], maxTokens: 20)
        // boundary + zero entropy every token: with the entropy rule disabled, nothing may fire
        // until the budget line; the loop contract then latches via markForcedClose().
        var out = 1, fired: [BASTraceExitPolicy.Reason] = [], firedAtOut = -1
        for _ in 0 ..< 14 {
            out += 1
            if case .close(let r) = p.observe(token: 10, entropyMillinats: 0, outCount: out, maxTokens: 20) {
                fired.append(r)
                if firedAtOut < 0 { firedAtOut = out }
                p.markForcedClose()
            }
        }
        XCTAssertEqual(fired, [.budget], "only the budget guard may fire with entropy disabled")
        XCTAssertEqual(firedAtOut, 12, "fire lands exactly on the reserve line (20-8=12)")
    }
}
