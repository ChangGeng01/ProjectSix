// MARK: - BASChengluRealModelE2EHarness — chapter 三百三二 / M819
//
// Phase F (附录 X) 第十刀 — **the real-validation chapter**:
// gated test harness that loads actual `.mlpackage` files from
// the local filesystem and proves the附录 X typed pipeline works
// against real CoreML inference,not just stub closures。
//
// ## Why this exists (honest acknowledgement)
//
// Chapters 三百二〇-三百三〇 shipped 9 typed primitives + 2 docs
// chapters establishing the附录 X pipeline。**Every test in those
// chapters used parametric closure init — no real `.mlpackage`
// file was ever loaded into the typed adapter chain。**
//
// The pipeline contract was proven correct (compile-time + behavior)
// but the production reality was untested。This chapter closes
// that gap by providing a path-based real-MLModel loader gated
// on env vars,so when `.mlpackage` files exist on disk:
//   - `QINAO_COREML_E2E=1` enables the E2E test path
//   - `QINAO_CHENGLU_PREFLIGHT_PATH=<path>` points to the real
//     model file
// Tests skip gracefully when env vars not set (CI-safe)。
//
// ## What this ships
//
//   - `BASChengluRealModelE2EHarness.loadMLModel(at:)` — typed
//     `MLModel` loader from absolute file URL
//   - `BASChengluRealModelE2EHarness.envPath(_:)` — env-var-based
//     path resolver with sensible variable names
//   - `BASChengluRealModelE2EHarness.shouldRunE2E()` — gate
//     predicate (true when `QINAO_COREML_E2E=1`)
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — harness is read-only,no
//     production decision path mutation
//   - 红线 7 watcher hint only — harness is observability only
//   - 单提交口 (L11/L14) 不变 — harness doesn't issue permits
//   - chapter 二百一一 single-source-of-truth: ONE path-resolver
//     namespace,no scattered env-var lookups in test code
//   - chapter 一百八十五 anti-magic-number: env var names typed-
//     pinned as constants
//   - chapter 三百二〇 (M807) BASCoreMLLayerHead: harness validates
//     the adapter loads real MLModel correctly
//   - chapter 三百二一 (M808) BASChengluMeshRegistration:
//     harness validates real assembly path
//
// ## CI safety
//
// Tests using this harness MUST guard with `shouldRunE2E()`:
//
//     func testRealModelInference() throws {
//         try XCTSkipUnless(
//             BASChengluRealModelE2EHarness.shouldRunE2E(),
//             "QINAO_COREML_E2E not set — skipping real-model " +
//             "E2E test")
//         // ... use harness to load real model ...
//     }

import Foundation

#if canImport(CoreML)
import CoreML
#endif

// MARK: - Env var constants (anti-magic-number doctrine)

public enum BASChengluRealModelE2EHarnessEnvVars {
    /// Master gate enabling E2E tests。Set to `"1"` to enable。
    public static let masterGate: String = "QINAO_COREML_E2E"

    /// Path env var for ChengluPreflight_v0.mlpackage
    public static let preflightPath: String =
        "QINAO_CHENGLU_PREFLIGHT_PATH"

    /// Path env var for ChengluMultiHead_v0.mlpackage
    public static let multiHeadPath: String =
        "QINAO_CHENGLU_MULTIHEAD_PATH"

    /// Path env var for ChengluPermitPredict_v0.mlpackage
    public static let permitPredictPath: String =
        "QINAO_CHENGLU_PERMIT_PREDICT_PATH"

    /// Path env var for ChengluLengthHead_v0.mlpackage
    public static let lengthHeadPath: String =
        "QINAO_CHENGLU_LENGTH_PATH"

    /// Path env var for ChengluLatencyHead_v0.mlpackage
    public static let latencyHeadPath: String =
        "QINAO_CHENGLU_LATENCY_PATH"
}

// MARK: - Harness namespace

public enum BASChengluRealModelE2EHarness {

    // MARK: - Gate predicate

    /// True when caller has explicitly enabled E2E tests via env
    /// var。CI / hosted-runners default to false (skipped)。
    public static func shouldRunE2E() -> Bool {
        ProcessInfo.processInfo.environment[
            BASChengluRealModelE2EHarnessEnvVars.masterGate]
            == "1"
    }

    // MARK: - Path resolution

    /// Resolve an env var to an absolute file URL。Returns nil if
    /// the env var is unset or empty。Trims whitespace。
    public static func envPath(
        _ envVar: String
    ) -> URL? {
        guard let raw = ProcessInfo.processInfo
            .environment[envVar]
        else { return nil }
        let trimmed = raw.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed)
    }

    /// Convenience:resolve path to ChengluPreflight model URL。
    public static var preflightModelURL: URL? {
        envPath(BASChengluRealModelE2EHarnessEnvVars
            .preflightPath)
    }

    /// Convenience:resolve path to ChengluMultiHead model URL。
    public static var multiHeadModelURL: URL? {
        envPath(BASChengluRealModelE2EHarnessEnvVars
            .multiHeadPath)
    }

    /// Convenience:resolve path to ChengluPermitPredict model URL。
    public static var permitPredictModelURL: URL? {
        envPath(BASChengluRealModelE2EHarnessEnvVars
            .permitPredictPath)
    }

    /// Convenience:resolve path to ChengluLengthHead model URL。
    public static var lengthHeadModelURL: URL? {
        envPath(BASChengluRealModelE2EHarnessEnvVars
            .lengthHeadPath)
    }

    /// Convenience:resolve path to ChengluLatencyHead model URL。
    public static var latencyHeadModelURL: URL? {
        envPath(BASChengluRealModelE2EHarnessEnvVars
            .latencyHeadPath)
    }

    // MARK: - File existence check

    /// Check whether the file URL points to an existing
    /// `.mlpackage` directory or `.mlmodelc` directory。
    public static func packageExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    // MARK: - MLModel loading (Apple platforms only)

    #if canImport(CoreML)

    /// Load `.mlpackage` (or compiled `.mlmodelc`) from a file URL。
    /// CoreML auto-compiles `.mlpackage` on first load — caller
    /// can pass either format。
    ///
    /// - Throws: rethrows MLModel loading errors (e.g. invalid
    ///   format, missing weights)。Caller should let the error
    ///   propagate to surface real-world model issues。
    public static func loadMLModel(
        at url: URL
    ) throws -> MLModel {
        // For .mlpackage paths, MLModel(contentsOf:) auto-compiles
        // and loads。For pre-compiled .mlmodelc paths, same call
        // works directly。
        if url.pathExtension == "mlpackage" {
            // Compile to .mlmodelc on first load (one-time cost)
            let compiledURL = try MLModel.compileModel(at: url)
            return try MLModel(contentsOf: compiledURL)
        } else {
            return try MLModel(contentsOf: url)
        }
    }

    #endif
}
