// MARK: - BASDecodePlannerABProbe — S4c: flag-off (legacy) vs flag-on (planner) byte-equivalence (BAS_DECODE_PLANNER_AB=1)
//
// The on-device gate before flipping `decodePlannerAutoSelect`. For each workload × elect value, run
// `draft(electAccelerated:)` with the planner OFF (legacy elect→prompt-lookup) and ON (planner auto-select) and
// assert the produced body is BYTE-IDENTICAL. Every decode lane emits the target's argmax (ADR-039), so the planner
// only changes the lane/latency — never the output. This proves that on real MLX before we change the default.
//
// Single staged model (Llama-3.2-3B-3bit-local — already on the device), speculativeDecoding=.off → exercises the
// plain / prompt-lookup / cross-turn(empty)=prompt-lookup equivalence. The draft-model-spec lane's byte-identity is
// covered separately by the shipped greedy-spec byte-identity probes.

import Foundation
import BASOrgan
import BASMLXAdapter

enum BASDecodePlannerABProbe {

    private static let workloads: [(name: String, prompt: String)] = [
        ("rag-quote",
         "Here is a passage:\n\"\"\"\nThe mitochondrion is the powerhouse of the cell. It generates most of the "
         + "cell's supply of adenosine triphosphate.\n\"\"\"\nQuote the passage above back to me verbatim."),
        ("json",
         "Convert these records to a JSON array, one object per line with keys id, name:\n1 Alice\n2 Bob\n3 Carol"),
        ("code",
         "Repeat this Swift function exactly, then repeat it again unchanged:\n"
         + "func add(_ a: Int, _ b: Int) -> Int { return a + b }"),
        ("freeform",
         "Write a short, original opening sentence for a science-fiction story set on a distant moon."),
    ]

    static func run() async {
        let fileLog = ProbeFileLog(filePrefix: "decode-planner-ab", category: "decode-planner-ab", alsoPrint: false)
        defer { fileLog.close() }
        fileLog.emit("📊 decode-planner-ab START — flag-off(pure plain) vs flag-on(planner); expect byte_equal=YES for ALL")
        do {
            let model = MLXModelCatalog.llama3_2_3B_3bit_local
            let adapter = MLXOrganAdapter(model: model, maxOutputTokens: 200, speculativeDecoding: .off)
            try await adapter.loadModel()

            var allEqual = true
            var comparisons = 0
            for w in workloads {
                for elect in [true, false] {
                    let request = BASOrganRequest(
                        requestID: "dpab-\(w.name)-\(elect)", role: .core,
                        preset: .greedyDeterministic, instruction: w.prompt, context: [])
                    await adapter.setDecodePlannerAutoSelect(false)
                    let legacy = try await adapter.draft(request, electAccelerated: elect)
                    await adapter.setDecodePlannerAutoSelect(true)
                    let planner = try await adapter.draft(request, electAccelerated: elect)

                    let equal = legacy.body == planner.body
                    if !equal { allEqual = false }
                    comparisons += 1
                    fileLog.emit(String(
                        format: "📊 dpab workload=%@ elect=%@ byte_equal=%@ legacy_len=%d planner_len=%d",
                        w.name, elect ? "T" : "F", equal ? "YES" : "NO", legacy.body.count, planner.body.count))
                    if !equal {
                        fileLog.emit("   [off    ] \(String(legacy.body.prefix(160)))")
                        fileLog.emit("   [planner] \(String(planner.body.prefix(160)))")
                    }
                }
            }
            fileLog.emit("📊 decode-planner-ab DONE comparisons=\(comparisons) all_byte_equal=\(allEqual ? "YES" : "NO")")
        } catch {
            fileLog.emit("📊 decode-planner-ab ERROR=\(error)")
        }
    }
}
