// MARK: - BASMPSGraphProbe
// chapter 一千零三十四 / M3901 — on-device MPSGraph kernel exercise
//
// ## Mandate
//
// User mandate「全面 修复」 → systematic ship of the audited
// coverage-widening backlog。 ch 1034(renumbered from the collided
// "ch 1030")per the 2026-05-29 pre-ship audit。
//
// ## What the audit found(Docs/CH_1024_PLUS_OPTIMIZATION_BACKLOG.md
// "Audit 2 — ch 1034 MPSGraph kernel rotation:LOW risk")
//
// The 10-hour ch 1025.7 endurance exercised MLX(which calls Metal
// directly,C++ `mlx::core::metal`)but NEVER the substrate's own
// MPSGraph kernel pool — the ch 870/871 `BASMPSGraph*Kernel` actors。
// BACKLOG #20 also conflated two layers:`BASMetalLinearAlgebra
// Dispatchers`(raw MSL)≠ the MPSGraph cache the chapter names。
// The real wires are public actors in `BASBuiltinKernels/`。
//
// ## GPU contention(the audit's key question)
//
// LOW risk。 MPSGraph kernels share the singleton A19 `MTLDevice`
// with MLX but use their own command queues — Metal's standard
// multi-queue model,no crash risk。 Contention is performance-only,
// and this probe sidesteps it by running SERIAL(not concurrent with
// any MLX draft)— it runs once at app boot via onAppear,before/
// outside the ch 1025 endurance loop。
//
// ## What this probe does
//
// Exercises 3 of the 5 MPSGraph kernels — the ones with a public
// `BASCanonicalKernelInputBuilders` factory(matMul / rmsNorm /
// rotaryEmbedding;attention + layerNorm need hand-rolled descriptors,
// deferred)。 Each kernel dispatches `repeatsEach` times(identical
// shape → exercises the `BASMPSGraphExecutableCache` warm path on
// repeats 2+)。 Logs per-kernel `executionNanos`(first/last/avg)so
// the build-overhead-amortization the cache provides is observable。
//
// Emitted as `📊 ch1034 mpsgraph …`(idevicesyslog-visible,os.Logger,
// same pattern as ch 1027 BASRustVerifyProbe)。 Proves the substrate's
// MPSGraph kernel pool resolves + executes on a physical iPhone(MLX
// alone never touches it)。

import Foundation
import os
import BASMetalSubstrate

enum BASMPSGraphProbe {

    private static let log = Logger(
        subsystem: BASDeviceLog.subsystem,
        category: "ch1034-mpsgraph")

    /// Identical-shape repeats per kernel。 Repeats 2+ exercise the
    /// MPSGraph executable cache warm path(if the kernel wired it)。
    private static let repeatsEach = 5

    /// Run all MPSGraph kernel dispatches serially,emit detail
    /// lines,return a short verdict for the UI surface。 async
    /// because `BASMetalKernel.evaluate` is async。
    @discardableResult
    static func run() async -> String {
        emit("📊 ch1034 mpsgraph START repeats_each=\(repeatsEach)")
        let cache = BASMPSGraphExecutableCache()
        let total = 3
        var kernelsOK = 0

        if await dispatchMatMul() { kernelsOK += 1 }
        if await dispatchRMSNorm(cache: cache) { kernelsOK += 1 }
        if await dispatchRotary(cache: cache) { kernelsOK += 1 }

        let allOK = kernelsOK == total
        emit("📊 ch1034 mpsgraph VERDICT " +
             "kernels_ok=\(kernelsOK)/\(total) all_ok=\(allOK)")
        return allOK
            ? "✓ \(kernelsOK)/\(total) (matmul/rmsnorm/rope)"
            : "✗ \(kernelsOK)/\(total) (see ch1034 log)"
    }

    // MARK: - Per-kernel dispatch

    private static func dispatchMatMul() async -> Bool {
        do {
            // MatMul kernel has no cache param(init() throws)。
            let kernel = try BASMPSGraphMatMulKernel()
            let inputs = BASCanonicalKernelInputBuilders.matMul(
                a: [1, 2, 3, 4, 5, 6, 7, 8,
                    9, 10, 11, 12, 13, 14, 15, 16],
                b: [1, 0, 0, 0, 0, 1, 0, 0,
                    0, 0, 1, 0, 0, 0, 0, 1],
                M: 4, K: 4, N: 4)
            return await runRepeats(
                name: "matmul", kernel: kernel, inputs: inputs)
        } catch let BASKernelError.frameworkUnavailable(f) {
            emit("📊 ch1034 mpsgraph kernel=matmul " +
                 "SKIP framework_unavailable=\(f)")
            return false
        } catch {
            emit("⚠️ ch1034 mpsgraph kernel=matmul " +
                 "init_error=\(error)")
            return false
        }
    }

    private static func dispatchRMSNorm(
        cache: BASMPSGraphExecutableCache
    ) async -> Bool {
        do {
            let kernel = try BASMPSGraphRMSNormKernel(cache: cache)
            // batchSeq=4 hiddenDim=8 → input[32] gamma[8]
            let inputs = BASCanonicalKernelInputBuilders.rmsNorm(
                input: [Float](repeating: 0.5, count: 32),
                gamma: [Float](repeating: 1.0, count: 8),
                batchSeq: 4, hiddenDim: 8)
            return await runRepeats(
                name: "rmsnorm", kernel: kernel, inputs: inputs)
        } catch let BASKernelError.frameworkUnavailable(f) {
            emit("📊 ch1034 mpsgraph kernel=rmsnorm " +
                 "SKIP framework_unavailable=\(f)")
            return false
        } catch {
            emit("⚠️ ch1034 mpsgraph kernel=rmsnorm " +
                 "init_error=\(error)")
            return false
        }
    }

    private static func dispatchRotary(
        cache: BASMPSGraphExecutableCache
    ) async -> Bool {
        do {
            let kernel =
                try BASMPSGraphRotaryEmbeddingKernel(cache: cache)
            // ch 1034 FINDING(2026-05-29):
            // `BASCanonicalKernelInputBuilders.rotaryEmbedding` emits
            // a RANK-3 descriptor `[seq,heads,headDim]`,but
            // `BASMPSGraphRotaryEmbeddingKernel.evaluate` REQUIRES
            // RANK-2 `[seq,headDim]`(validation at kernel line
            // 205-207)。 The builder + kernel each have their own
            // unit tests but were NEVER co-tested — this probe is the
            // first call site to feed builder→kernel and exposed the
            // mismatch。 See BACKLOG "ch 1034.1" finding。
            // Workaround:hand-roll the rank-2 input the kernel
            // contract wants(mirrors BASMPSGraphRotaryEmbeddingKernel
            // Tests),so the probe exercises the kernel for real。
            let seqLen = 4, headDim = 4, halfDim = 2
            let inputs = BASKernelInputs(
                descriptors: [
                    BASTensorDescriptor.contiguous(
                        shape: [seqLen, headDim],
                        dataType: .float32,
                        backingKind: .cpuBytes,
                        rankTag: "rank-2-matrix"),
                    BASTensorDescriptor.contiguous(
                        shape: [seqLen, halfDim],
                        dataType: .float32,
                        backingKind: .cpuBytes,
                        rankTag: "rank-2-matrix"),
                    BASTensorDescriptor.contiguous(
                        shape: [seqLen, halfDim],
                        dataType: .float32,
                        backingKind: .cpuBytes,
                        rankTag: "rank-2-matrix"),
                ],
                payloads: [
                    BASCanonicalKernelInputBuilders
                        .floatArrayToData([Float](
                            repeating: 0.5,
                            count: seqLen * headDim)),
                    BASCanonicalKernelInputBuilders
                        .floatArrayToData([Float](
                            repeating: 1.0,
                            count: seqLen * halfDim)),
                    BASCanonicalKernelInputBuilders
                        .floatArrayToData([Float](
                            repeating: 0.0,
                            count: seqLen * halfDim)),
                ])
            return await runRepeats(
                name: "rope", kernel: kernel, inputs: inputs)
        } catch let BASKernelError.frameworkUnavailable(f) {
            emit("📊 ch1034 mpsgraph kernel=rope " +
                 "SKIP framework_unavailable=\(f)")
            return false
        } catch {
            emit("⚠️ ch1034 mpsgraph kernel=rope " +
                 "init_error=\(error)")
            return false
        }
    }

    // MARK: - Shared dispatch loop

    private static func runRepeats(
        name: String,
        kernel: any BASMetalKernel,
        inputs: BASKernelInputs
    ) async -> Bool {
        var nanos: [UInt64] = []
        do {
            for _ in 0..<repeatsEach {
                let out = try await kernel.evaluate(inputs: inputs)
                nanos.append(out.executionNanos)
            }
        } catch {
            emit("⚠️ ch1034 mpsgraph kernel=\(name) " +
                 "dispatch_error=\(error)")
            return false
        }
        guard !nanos.isEmpty else { return false }
        let sum = nanos.reduce(0, &+)
        let avg = sum / UInt64(nanos.count)
        emit("📊 ch1034 mpsgraph kernel=\(name) " +
             "dispatches=\(nanos.count) " +
             "first_ns=\(nanos.first ?? 0) " +
             "last_ns=\(nanos.last ?? 0) avg_ns=\(avg)")
        return true
    }

    private static func emit(_ line: String) {
        print(line)
        log.notice("\(line, privacy: .public)")
    }
}
