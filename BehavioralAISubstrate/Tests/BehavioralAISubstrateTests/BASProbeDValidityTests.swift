import XCTest
@testable import BASMLXAdapter
import BASOrgan

/// Probe D validation (frontier playbook): does the prefill last-token HIDDEN STATE predict whether Qwen3.5-4B
/// will get a factual question RIGHT — i.e. can a cheap difference-of-means probe be an ABSTENTION sensor (flag
/// likely-wrong → hedge instead of confabulate)? Feature = lastTokenHiddenState; label = the model's own answer
/// correctness. Leave-one-out difference-of-means AUROC (no train-on-test circularity). ≥0.70 ⇒ viable on-device
/// abstention sensor; ~0.5 ⇒ the hidden state doesn't encode "will I be right" any better than chance. Gated
/// BAS_PROBE_D=1. (Routing-to-a-bigger-model is moot on iPhone-8GB sovereign; this is abstention-only.)
final class BASProbeDValidityTests: XCTestCase {

    // Factual questions spanning easy→very-obscure, with checkable answers — to get BOTH a correct and a wrong class.
    private let cases: [(q: String, a: String)] = [
        ("What is the capital of France?", "paris"), ("What is the largest planet?", "jupiter"),
        ("What is the chemical symbol for gold?", "au"), ("Who wrote the novel 1984?", "orwell"),
        ("What is the capital of Japan?", "tokyo"), ("How many continents are there?", "7"),
        ("What is the capital of Italy?", "rome"), ("What is the chemical symbol for sodium?", "na"),
        ("What is the capital of Kazakhstan?", "astana"), ("What is the atomic number of tungsten?", "74"),
        ("What is the capital of Bhutan?", "thimphu"), ("What is the capital of Nauru?", "yaren"),
        ("In what year was the Eiffel Tower completed?", "1889"), ("Who was the 13th president of the USA?", "fillmore"),
        ("What is the boiling point of nitrogen in Celsius?", "-196"), ("What is the atomic number of uranium?", "92"),
        ("What is the deepest lake in the world?", "baikal"), ("What is the capital of Mongolia?", "ulaanbaatar"),
        ("What is the chemical symbol for tungsten?", "w"), ("What is the atomic number of carbon?", "6"),
        ("Who discovered the neutron?", "chadwick"), ("What is the capital of Kyrgyzstan?", "bishkek"),
        ("What is the speed of sound in air in m/s?", "343"), ("What is the atomic number of seaborgium?", "106"),
        ("What is the chemical symbol for antimony?", "sb"), ("In what year was the transistor invented?", "1947"),
        ("What is the capital of Tuvalu?", "funafuti"), ("Who was the 19th president of the USA?", "hayes"),
        ("What is the smallest prime number?", "2"), ("What is the capital of Egypt?", "cairo"),
    ]

    func testHiddenStatePredictsCorrectness() async throws {
        guard ProcessInfo.processInfo.environment["BAS_PROBE_D"] == "1" else {
            throw XCTSkip("set BAS_PROBE_D=1 to fit a difference-of-means correctness probe on Qwen3.5-4B hidden states")
        }
        let organ = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit)
        try await organ.loadModel()
        await organ.setDecodePlannerAutoSelect(false)

        var feats: [[Float]] = [], labels: [Bool] = []
        for c in cases {
            let req = BASOrganRequest(requestID: "pd", role: .core, preset: .core, instruction: c.q, context: [])
            guard let h = try? await organ.lastTokenHiddenState(for: req), !h.isEmpty else { continue }
            var body = ""
            do { for try await ch in organ.streamDraft(req) { body = ch.cumulativeBody } } catch {}
            let correct = body.lowercased().contains(c.a)
            feats.append(h); labels.append(correct)
        }
        let nC = labels.filter { $0 }.count, nW = labels.count - nC
        print("=== PROBE D — \(feats.count) facts: \(nC) correct, \(nW) wrong ===")
        guard nC >= 3, nW >= 3 else {
            print("  PROBE D INCONCLUSIVE — need ≥3 of each class (model too strong/weak on this set); got \(nC)/\(nW)")
            return
        }
        // Leave-one-out difference-of-means: fit w on all-but-i, score i = dot(feat_i, w), AUROC over LOO scores.
        let dim = feats[0].count
        var scores = [Float](repeating: 0, count: feats.count)
        for i in feats.indices {
            var mC = [Float](repeating: 0, count: dim), mW = mC; var cC = 0, cW = 0
            for j in feats.indices where j != i {
                if labels[j] { for d in 0..<dim { mC[d] += feats[j][d] }; cC += 1 }
                else { for d in 0..<dim { mW[d] += feats[j][d] }; cW += 1 }
            }
            guard cC > 0, cW > 0 else { continue }
            var dot: Float = 0
            for d in 0..<dim { dot += feats[i][d] * (mC[d] / Float(cC) - mW[d] / Float(cW)) }
            scores[i] = dot
        }
        var win = 0.0, pairs = 0.0
        for i in feats.indices where labels[i] {
            for j in feats.indices where !labels[j] {
                pairs += 1
                if scores[i] > scores[j] { win += 1 } else if scores[i] == scores[j] { win += 0.5 }
            }
        }
        let auroc = pairs > 0 ? win / pairs : 0
        print(String(format: "  PROBE D VERDICT: LOO difference-of-means AUROC=%.3f → %@", auroc,
                     auroc >= 0.70 ? "VIABLE abstention sensor (hidden state predicts correctness)"
                                   : "NOT viable (hidden state ~no better than chance at predicting correctness)"))
    }
}
