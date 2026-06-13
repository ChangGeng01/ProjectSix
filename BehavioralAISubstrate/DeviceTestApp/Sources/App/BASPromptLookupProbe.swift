// MARK: - BASPromptLookupProbe — Track A: universal prompt-lookup SSD on device (BAS_PROMPT_LOOKUP_PROBE=1)
//
// Measures the model-free n-gram speculative decoder (any LLM, no draft model, byte-identical): on REPETITIVE
// workloads (RAG-quoted, JSON, code, verification) it should accelerate; on a free-form CONTROL it should be
// ~neutral (no speedup but no harm). Per workload: spec (prompt-lookup) vs baseline (the SAME decoder with a
// null drafter = pure single-model greedy), compared by TOKEN sequence (true byte-identity) + timing.
//
// Single model resident (Llama-3B, speculativeDecoding=.off → no draft model — the universality headline).
// decode capped (memory-safe). Env sweep: BAS_PL_NGRAM_MIN/MAX, BAS_PL_K, BAS_PL_MAX_DECODE_TOKENS.

import Foundation
import os
import BASOrgan
import BASMLXAdapter

enum BASPromptLookupProbe {

    private static let log = Logger(subsystem: "com.bas.devicetest", category: "prompt-lookup")

    private final class FileLog: @unchecked Sendable {
        private let handle: FileHandle?
        private let lock = NSLock()
        init() {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"; f.locale = Locale(identifier: "en_US_POSIX")
            let stamp = f.string(from: Date())
            guard let docs = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask).first else { handle = nil; return }
            let url = docs.appendingPathComponent("prompt-lookup-\(stamp).log")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
        }
        func emit(_ line: String) {
            BASPromptLookupProbe.log.info("\(line, privacy: .public)")
            guard let data = (line + "\n").data(using: .utf8) else { return }
            lock.lock(); defer { lock.unlock() }
            try? handle?.write(contentsOf: data)
        }
        func close() { lock.lock(); defer { lock.unlock() }; try? handle?.close() }
    }

    // Repetitive workloads (expect hits) + a free-form control (expect ~0 hits).
    private static let workloads: [(name: String, prompt: String)] = [
        ("rag-quote",
         "Here is a passage:\n\"\"\"\nThe mitochondrion is the powerhouse of the cell. It generates most of "
         + "the cell's supply of adenosine triphosphate, used as a source of chemical energy. The mitochondrion "
         + "is the powerhouse of the cell.\n\"\"\"\nQuote the passage above back to me verbatim, word for word."),
        ("json-structured",
         "Convert these records to a JSON array, one object per line with keys id, name, role:\n"
         + "1 Alice engineer\n2 Bob designer\n3 Carol engineer\n4 Dave designer\n5 Eve engineer"),
        ("code-repeat",
         "Repeat this Swift function exactly, then repeat it again unchanged:\n"
         + "func add(_ a: Int, _ b: Int) -> Int { return a + b }"),
        ("verify-claim",
         "Verify each claim, quoting the claim before your verdict: (1) The Great Wall of China is visible from "
         + "the Moon with the naked eye. (2) The Great Wall of China was built entirely during the Ming dynasty "
         + "in a single decade."),
        ("control-freeform",
         "Write a short, original opening paragraph for a science-fiction story set on a distant moon."),
    ]

    static func run() async {
        let fileLog = FileLog()
        defer { fileLog.close() }

        let env = ProcessInfo.processInfo.environment
        let ngramMin = Int(env["BAS_PL_NGRAM_MIN"] ?? "") ?? 1
        let ngramMax = Int(env["BAS_PL_NGRAM_MAX"] ?? "") ?? 3
        let k = Int(env["BAS_PL_K"] ?? "") ?? 4
        let cap = Int(env["BAS_PL_MAX_DECODE_TOKENS"] ?? "") ?? 200
        let adaptive = (env["BAS_PL_ADAPTIVE"] ?? "1") == "1"
        let tree = (env["BAS_PL_TREE"] ?? "0") == "1"      // B2-aggressive: tree-structured vs linear prompt-lookup
        let maxBranch = Int(env["BAS_PL_TREE_BRANCH"] ?? "") ?? 2
        let maxNodes = Int(env["BAS_PL_TREE_NODES"] ?? "") ?? 8
        let drafter = BASPromptLookupDrafter(ngramMin: ngramMin, ngramMax: ngramMax, numDraftTokens: k)
        fileLog.emit("📊 prompt-lookup START ngram=\(ngramMin)..\(ngramMax) K=\(k) cap=\(cap) adaptiveK=\(adaptive) "
            + "tree=\(tree) branch=\(maxBranch) nodes=\(maxNodes)")

        do {
            // Single-model, no draft (prompt-lookup is model-free) → universality + light memory.
            let adapter = MLXOrganAdapter(
                model: MLXModelCatalog.speculativeOptimalTarget,
                maxOutputTokens: cap,
                speculativeDecoding: .off)
            try await adapter.loadModel()

            var repSpeedups: [Double] = []
            var allByteIdentical = true
            var byteCount = 0

            for w in workloads {
                let request = BASOrganRequest(
                    requestID: "pl-\(w.name)", role: .core,
                    preset: .greedyDeterministic, instruction: w.prompt, context: [])
                do {
                    if tree {
                        // Tree-spec vs the SHIPPED linear lane: parity (tree==linear → token-identical to greedy)
                        // + marginal speedup (linear_ms/tree_ms) + tree telemetry.
                        let ab = try await adapter.treeSpecAB(
                            for: request, drafter: drafter, maxBranch: maxBranch, maxNodes: maxNodes)
                        let identical = ab.treeTokens == ab.linearTokens
                        if identical { byteCount += 1 } else { allByteIdentical = false }
                        let speedup = ab.treeMs > 0 ? ab.linearMs / ab.treeMs : 0
                        let meanPath = ab.rounds > 0 ? Double(ab.acceptedTokens) / Double(ab.rounds) : 0
                        if w.name.hasPrefix("control") == false { repSpeedups.append(speedup) }
                        fileLog.emit(String(
                            format: "📊 tree-spec workload=%@ tokens=%d rounds=%d nodes=%d accepted=%d "
                                + "mean_path=%.2f max_path=%d tree_ms=%.0f linear_ms=%.0f vs_linear=%.2fx "
                                + "token_identical=%@",
                            w.name, ab.treeTokens.count, ab.rounds, ab.proposedNodes, ab.acceptedTokens,
                            meanPath, ab.maxPathLen, ab.treeMs, ab.linearMs, speedup, identical ? "YES" : "NO"))
                    } else {
                        let ab = try await adapter.promptLookupAB(
                            for: request, drafter: drafter, adaptiveK: adaptive)
                        let identical = ab.specTokens == ab.baseTokens
                        if identical { byteCount += 1 } else { allByteIdentical = false }
                        let speedup = ab.specMs > 0 ? ab.baseMs / ab.specMs : 0
                        let hitRate = ab.proposed > 0 ? Double(ab.accepted) / Double(ab.proposed) : 0
                        let meanAcc = ab.rounds > 0 ? Double(ab.accepted) / Double(ab.rounds) : 0
                        if w.name.hasPrefix("control") == false { repSpeedups.append(speedup) }
                        fileLog.emit(String(
                            format: "📊 prompt-lookup workload=%@ tokens=%d rounds=%d hit_rate=%.2f mean_acc=%.2f "
                                + "spec_ms=%.0f base_ms=%.0f speedup=%.2fx byte_identical=%@",
                            w.name, ab.specTokens.count, ab.rounds, hitRate, meanAcc,
                            ab.specMs, ab.baseMs, speedup, identical ? "YES" : "NO"))
                    }
                } catch {
                    fileLog.emit("📊 prompt-lookup workload=\(w.name) ERROR=\(error)")
                }
            }

            let repMean = repSpeedups.isEmpty ? 0 : repSpeedups.reduce(0, +) / Double(repSpeedups.count)
            fileLog.emit(String(
                format: "📊 prompt-lookup DONE ngram=%d..%d K=%d repetitive_mean_speedup=%.2fx "
                    + "byte_identical=%d/%d all_identical=%@",
                ngramMin, ngramMax, k, repMean, byteCount, workloads.count,
                allByteIdentical ? "YES" : "NO"))
        } catch {
            fileLog.emit("📊 prompt-lookup ERROR=\(error)")
        }
    }
}
