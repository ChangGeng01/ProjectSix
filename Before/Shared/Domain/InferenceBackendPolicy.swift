import Foundation

#if canImport(Metal)
import Metal
#endif

enum InferenceBackendPolicy: String, CaseIterable, Codable, Sendable {
    case auto
    case systemManaged
    case coreMLPreferred
    case metalPreferred
    case cpuOnly

    var title: String {
        switch self {
        case .auto: "Auto"
        case .systemManaged: "System managed"
        case .coreMLPreferred: "Core ML preferred"
        case .metalPreferred: "Metal preferred"
        case .cpuOnly: "CPU only"
        }
    }
}

enum InferenceBackendKind: String, Codable, Sendable {
    case systemManaged
    case coreML
    case metal
    case cpu

    var title: String {
        switch self {
        case .systemManaged: "System managed"
        case .coreML: "Core ML"
        case .metal: "Metal"
        case .cpu: "CPU"
        }
    }
}

struct DeviceCapabilitySnapshot: Equatable, Sendable {
    let isSimulator: Bool
    let supportsMetal: Bool
    let supportsCoreMLAcceleration: Bool

    static var current: DeviceCapabilitySnapshot {
        DeviceCapabilitySnapshot(
            isSimulator: isRunningOnSimulator,
            supportsMetal: metalDeviceAvailable,
            supportsCoreMLAcceleration: !isRunningOnSimulator
        )
    }

    private static var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private static var metalDeviceAvailable: Bool {
        #if canImport(Metal)
        MTLCreateSystemDefaultDevice() != nil
        #else
        false
        #endif
    }
}

struct InferenceBackendResolution: Equatable, Sendable {
    let policy: InferenceBackendPolicy
    let effectiveBackend: InferenceBackendKind
    let title: String
    let detail: String
    let isHardwareAccelerated: Bool
}

enum InferenceBackendResolver {
    static func resolve(
        policy: InferenceBackendPolicy,
        device: DeviceCapabilitySnapshot
    ) -> InferenceBackendResolution {
        switch policy {
        case .systemManaged:
            return InferenceBackendResolution(
                policy: policy,
                effectiveBackend: .systemManaged,
                title: "System managed",
                detail: "Leave accelerator choice to the platform runtime. This is the safest fit for Apple Foundation Models and any future delegate-aware local model bridge.",
                isHardwareAccelerated: true
            )
        case .cpuOnly:
            return InferenceBackendResolution(
                policy: policy,
                effectiveBackend: .cpu,
                title: "CPU only",
                detail: "Run the local model on the CPU path only. This is the most conservative option for compatibility and debugging, but usually the slowest.",
                isHardwareAccelerated: false
            )
        case .coreMLPreferred:
            if device.supportsCoreMLAcceleration {
                return InferenceBackendResolution(
                    policy: policy,
                    effectiveBackend: .coreML,
                    title: "Core ML preferred",
                    detail: "Prefer the Core ML / Neural Engine path when the local Gemma runtime grows delegate support. This is the best default for on-device efficiency on physical iPhone hardware.",
                    isHardwareAccelerated: true
                )
            }

            return InferenceBackendResolution(
                policy: policy,
                effectiveBackend: .cpu,
                title: "Core ML unavailable",
                detail: "Core ML acceleration is not available in the current environment, so Before will stay on the CPU path instead.",
                isHardwareAccelerated: false
            )
        case .metalPreferred:
            if device.supportsMetal {
                return InferenceBackendResolution(
                    policy: policy,
                    effectiveBackend: .metal,
                    title: "Metal preferred",
                    detail: "Prefer the Metal GPU path when the local Gemma runtime exposes a GPU delegate. This can help throughput, but only when the graph stays mostly on GPU.",
                    isHardwareAccelerated: true
                )
            }

            return InferenceBackendResolution(
                policy: policy,
                effectiveBackend: .cpu,
                title: "Metal unavailable",
                detail: "No Metal device is available here, so Before will stay on the CPU path instead.",
                isHardwareAccelerated: false
            )
        case .auto:
            if device.isSimulator {
                return InferenceBackendResolution(
                    policy: policy,
                    effectiveBackend: .cpu,
                    title: "Auto -> CPU",
                    detail: "On Simulator, Before defaults to the CPU path to keep testing stable and avoid pretending accelerator behavior is representative.",
                    isHardwareAccelerated: false
                )
            }

            if device.supportsCoreMLAcceleration {
                return InferenceBackendResolution(
                    policy: policy,
                    effectiveBackend: .coreML,
                    title: "Auto -> Core ML",
                    detail: "On device, Before prefers the Core ML / Neural Engine path first, then falls back to Metal or CPU as needed.",
                    isHardwareAccelerated: true
                )
            }

            if device.supportsMetal {
                return InferenceBackendResolution(
                    policy: policy,
                    effectiveBackend: .metal,
                    title: "Auto -> Metal",
                    detail: "Core ML acceleration is unavailable, so Before will prefer the Metal path next.",
                    isHardwareAccelerated: true
                )
            }

            return InferenceBackendResolution(
                policy: policy,
                effectiveBackend: .cpu,
                title: "Auto -> CPU",
                detail: "No hardware acceleration path is available, so Before will use the CPU path.",
                isHardwareAccelerated: false
            )
        }
    }
}
