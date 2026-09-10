// MARK: - BASStateLakeReader — the on-device StateLake reader (cross-launch persistence)
//
// Reads a .statelake bundle (header.json + payload.bin) written by Tools/mamba3_statelake_device_prep.py into the decode
// session's initial NDArray states. FAIL-CLOSED: a binding-key mismatch (wrong model/precision/max_seq/version) or a
// payload sha256 mismatch raises — a stale/corrupt state is NEVER silently rehydrated (the audit's #1 danger, on device).
// This is the device half of the StateLake whose host put/get + binding-key is proven in Tools/mamba3_statelake.py.

import Foundation

#if canImport(CoreAI)
import CoreAI

@available(iOS 27, macOS 27, *)
public enum BASStateLakeReader {
    public enum Error: Swift.Error {
        case header(String)
        case bindingKey(String)
        case checksum(String)
        case missing(String)
    }

    public struct Loaded {
        public let states: [NDArray]      // in the requested stateOrder (the decode asset's declared stateNames order)
        public let promptLen: Int
    }

    /// FAIL-CLOSED load for the retained `statelake-device/1` experiment.
    ///
    /// Reader policy caps header bytes at 1 MiB, payload bytes at 64 MiB,
    /// decoded Float16 storage at 128 MiB, records at 1024 and rank at 16.
    /// Larger artifacts are rejected, never truncated. These are local input
    /// limits and make no claim about whole-process memory use.
    public static func load(_ dir: URL, expectedBindingKey: String, stateOrder: [String]) throws -> Loaded {
        let artifact: BASStateLakeDecodedArtifact
        do {
            artifact = try BASStateLakeArtifactDecoder.load(
                dir,
                expectedBindingKey: expectedBindingKey,
                stateOrder: stateOrder
            )
        } catch let error as BASStateLakeDecodeError {
            switch error {
            case .header(let message): throw Error.header(message)
            case .bindingKey(let message): throw Error.bindingKey(message)
            case .checksum(let message): throw Error.checksum(message)
            case .missing(let message): throw Error.missing(message)
            }
        }

        var byName: [String: NDArray] = [:]
        byName.reserveCapacity(artifact.tensors.count)
        for tensor in artifact.tensors {
            byName[tensor.name] = NDArray(scalars: tensor.scalars, shape: tensor.shape)
        }
        let ordered = try stateOrder.map { name in
            guard let array = byName[name] else {
                throw Error.missing("tensor \(name) absent from .statelake")
            }
            return array
        }
        return Loaded(states: ordered, promptLen: artifact.promptLen)
    }
}

#endif
