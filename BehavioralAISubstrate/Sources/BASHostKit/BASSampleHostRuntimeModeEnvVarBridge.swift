// MARK: - BASSampleHostRuntimeModeEnvVarBridge
// chapter 六百七十 / M2057 — Phase K env-var bridge。
//                            Reads `BAS_RUNTIME_MODE` env
//                            var via ProcessInfo + maps to
//                            BASTurnRuntimeMode for hosts
//                            to consume。
//
// ## Why this exists
//
// Phase K's plan calls for SampleHost (and any other
// host that opts in) to pick up `BAS_RUNTIME_MODE` env
// var → BASHostRuntime.buildEBrainTurnWithRuntimeMode
// runtimeMode param。 This bridge is the typed reader。
//
// ## How to use
//
//   import BASHostKit
//   let mode = BASSampleHostRuntimeModeEnvVarBridge
//       .currentRuntimeMode()
//   let result = await host
//       .buildEBrainTurnWithRuntimeMode(
//           request: ...,
//           currentBrain: ...,
//           projection: ...,
//           runtimeMode: mode)
//
// ## Env var contract
//
// `BAS_RUNTIME_MODE` accepts 3 values matching
// `BASTurnRuntimeMode.rawValue`:
//
//   - "v1-byte-equal" (or absent) → .v1ByteEqual
//   - "native-v2"                  → .nativeV2
//   - "stress-sweep-dual"          → .stressSweepDual
//
// Any other value falls back to `.v1ByteEqual` with a
// silent default — chapter 670 keeps the bridge OPT-IN
// + safe-by-default per ADR-014。
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — env var defaults to byte-equal
//   - 红线 7 — env var is hint,not authority
//   - chapter 一百八十五 — typed enum mapping,no inline
//     strings outside this bridge
//   - chapter 三百九二 — replay-determinism preserved
//     (env var read once,result cached not recommended
//     since hosts may want to re-read across turns)
//   - ADR-014 OPT-IN — default = v1-byte-equal = M2032
//     baseline behavior

import Foundation

public enum BASSampleHostRuntimeModeEnvVarBridge {

    /// The env var name hosts set to opt into V2 path。
    public static let envVarName: String =
        "BAS_RUNTIME_MODE"

    /// Default mode when env var is absent or invalid。
    /// Phase K contract:safe default = M2032 baseline。
    /// Phase L (chapter 674 / M2074) flips this default
    /// at the `BASTurnRuntimeEngineConfiguration` level
    /// — NOT at this bridge level (which keeps the env
    /// var override predictable)。
    public static let defaultModeWhenAbsent:
        BASTurnRuntimeMode = .v1ByteEqual

    /// Read `BAS_RUNTIME_MODE` env var + map to
    /// `BASTurnRuntimeMode`。 Returns
    /// `defaultModeWhenAbsent` (= `.v1ByteEqual`) when
    /// the env var is missing OR has an unrecognized
    /// value。
    public static func currentRuntimeMode(
        environment:
            [String: String] = ProcessInfo
                .processInfo.environment
    ) -> BASTurnRuntimeMode {
        guard let raw = environment[envVarName] else {
            return defaultModeWhenAbsent
        }
        return BASTurnRuntimeMode(rawValue: raw)
            ?? defaultModeWhenAbsent
    }

    /// Did the env var resolve to a non-default mode?
    /// Hosts use this to log audit notes when they pick
    /// up an opt-in V2 path。
    public static func isOptedInToNonDefault(
        environment:
            [String: String] = ProcessInfo
                .processInfo.environment
    ) -> Bool {
        let mode = currentRuntimeMode(
            environment: environment)
        return mode != defaultModeWhenAbsent
    }
}
