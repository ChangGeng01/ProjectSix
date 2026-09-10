// MARK: - BASEnvVarBridgeDoctrine
// chapter 六百七十 / M2059 — typed surface commemorating
//                            Phase K env var bridge for
//                            BAS_RUNTIME_MODE。

import Foundation

public enum BASEnvVarBridgeDoctrine {
    public static let chapterTag: String =
        "chapter 六百七十"
    public static let phase: String = "Phase K"

    public static let firstKnifeMNumber: Int = 2057
    public static let secondKnifeMNumber: Int = 2058
    public static let thirdKnifeMNumber: Int = 2059
    public static let fourthKnifeMNumber: Int = 2060

    public static let bridgeTypeName: String =
        "BASSampleHostRuntimeModeEnvVarBridge"

    public static let envVarName: String =
        "BAS_RUNTIME_MODE"

    public static let envVarValidValues: [String] = [
        "v1-byte-equal",
        "native-v2",
        "stress-sweep-dual"
    ]

    public static var envVarValidValueCount: Int {
        envVarValidValues.count
    }

    public static let defaultModeRawValue: String =
        "v1-byte-equal"

    public static let unrecognizedValueFallback: String =
        "v1-byte-equal"

    public static let bridgeApiSurfaces: [String] = [
        "envVarName",
        "defaultModeWhenAbsent",
        "currentRuntimeMode(environment:)",
        "isOptedInToNonDefault(environment:)"
    ]

    public static var bridgeApiSurfaceCount: Int {
        bridgeApiSurfaces.count
    }

    public static let proofTestCount: Int = 13

    public static let priorChapter669Ref: String =
        "BASPhaseKDualModeStressSweepDoctrine"

    public static let adr014OptInPreserved: Bool = true
    public static let byteEqualityPreserved: Bool = true
    public static let isOptInOnly: Bool = true
}
