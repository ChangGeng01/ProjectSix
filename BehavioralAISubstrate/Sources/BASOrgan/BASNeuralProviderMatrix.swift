import Foundation

/// PURE, deterministic task→provider ranking observation (ADR-041 §D).
///
/// This matrix ranks `BASOrganDescriptor`s by metadata and returns reasons. It does not resolve a registry
/// adapter, mutate registry state, or choose the explicit provider ID used for invocation. It never touches the
/// byte-deterministic governance spine (红线 7 — reasoning-side, hint-only).
///
/// Determinism: no Date / UUID / clock / randomness / call-order dependence. Same inputs → same `Selection`
/// (ties broken lexicographically by `providerID`), so it is replay-stable. The reason codes are fixed
/// uppercase constants — it never names a Metal dispatcher or an approximate value (banned-in-spine).
public enum BASNeuralProviderMatrix {

    // MARK: - Inputs / outputs

    /// What the caller is selecting FOR. The two preferences are ADVISORY biases, not gates.
    public struct SelectionContext: Sendable, Equatable {
        public let role: BASOrganRole
        /// Bias toward `certificationTier == .certified` (e.g. a high-consequence turn).
        public let preferCertified: Bool
        /// Bias toward the smallest `modelSizeHint` that supports the role (e.g. a fast scout pass).
        public let preferSmallest: Bool

        public init(role: BASOrganRole, preferCertified: Bool = false, preferSmallest: Bool = false) {
            self.role = role
            self.preferCertified = preferCertified
            self.preferSmallest = preferSmallest
        }
    }

    /// One ranked candidate. `rank == 0` is the chosen provider; higher ranks are fallbacks, best→worst.
    public struct Ranked: Sendable, Equatable {
        public let providerID: String
        public let rank: Int
        public let isOffDevice: Bool
        public let reasonCodes: [String]
    }

    /// The full selection. `chosen == ranked.first`; `chosen == nil` iff no candidate supports the role.
    public struct Selection: Sendable, Equatable {
        public let chosen: Ranked?
        public let ranked: [Ranked]
        /// Candidates that do NOT support `context.role` (skipped), sorted for determinism.
        public let unsupportedProviderIDs: [String]
    }

    // MARK: - Reason codes (machine-grep-able, fixed constants)

    public enum Reason {
        public static let onDevice = "ON_DEVICE"
        public static let offDevice = "OFF_DEVICE"
        public static let noOnDeviceCandidate = "NO_ON_DEVICE_CANDIDATE"
        public static let certCertified = "CERT_CERTIFIED"
        public static let certExperimental = "CERT_EXPERIMENTAL"
        public static let kindAppleNative = "KIND_APPLE_NATIVE"
        public static let kindMLX = "KIND_MLX"
        public static let kindDeterministic = "KIND_DETERMINISTIC"
        public static let kindRemote = "KIND_REMOTE"
        public static let sizeSmallerPreferred = "SIZE_SMALLER_PREFERRED"
        public static let sizeUnknown = "SIZE_UNKNOWN"
    }

    // MARK: - Selection

    /// Rank `candidates` for `context`. Pure + deterministic.
    public static func select(
        context: SelectionContext,
        candidates: [BASOrganDescriptor]
    ) -> Selection {
        var unsupported: [String] = []
        var scored: [(score: Int, descriptor: BASOrganDescriptor, codes: [String])] = []

        let anyOnDevice = candidates.contains { $0.runsOnDevice && $0.supportedRoles.contains(context.role) }

        for descriptor in candidates {
            guard descriptor.supportedRoles.contains(context.role) else {
                unsupported.append(descriptor.providerID)
                continue
            }
            let (score, codes) = scoreOf(descriptor, context: context, anyOnDeviceEligible: anyOnDevice)
            scored.append((score, descriptor, codes))
        }
        unsupported.sort()

        // Total order: score DESC, then providerID ASC (providerIDs are unique → fully deterministic).
        scored.sort { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score : lhs.descriptor.providerID < rhs.descriptor.providerID
        }

        let ranked = scored.enumerated().map { index, entry in
            Ranked(
                providerID: entry.descriptor.providerID,
                rank: index,
                isOffDevice: !entry.descriptor.runsOnDevice,
                reasonCodes: entry.codes)
        }

        return Selection(chosen: ranked.first, ranked: ranked, unsupportedProviderIDs: unsupported)
    }

    /// Pure score + reason codes for one role-eligible descriptor. Higher score = preferred.
    private static func scoreOf(
        _ d: BASOrganDescriptor,
        context: SelectionContext,
        anyOnDeviceEligible: Bool
    ) -> (Int, [String]) {
        var score = 0
        var codes: [String] = []

        // 1. On-device sovereignty — the dominant factor.
        if d.runsOnDevice {
            score += 1000
            codes.append(Reason.onDevice)
        } else {
            codes.append(Reason.offDevice)
            // Surface the fallback explicitly when nothing on-device supports the role.
            if !anyOnDeviceEligible { codes.append(Reason.noOnDeviceCandidate) }
        }

        // 2. Certification preference (only when asked).
        if context.preferCertified {
            switch d.certificationTier {
            case .certified: score += 200; codes.append(Reason.certCertified)
            case .experimental: score -= 50; codes.append(Reason.certExperimental)
            case .none: break
            }
        }

        // 3. Provider-kind bias (small — only breaks near-ties between same-locality providers).
        switch d.providerKind {
        case .appleNative: score += 30; codes.append(Reason.kindAppleNative)
        case .mlx: score += 20; codes.append(Reason.kindMLX)
        case .deterministic: score += 5; codes.append(Reason.kindDeterministic)
        case .remote: codes.append(Reason.kindRemote)
        case .none: break
        }

        // 4. Size fit (only when asked) — smaller models score higher (scaled by ~100M params per point).
        if context.preferSmallest {
            if let size = d.modelSizeHint {
                score -= size / 100_000_000
                codes.append(Reason.sizeSmallerPreferred)
            } else {
                codes.append(Reason.sizeUnknown)
            }
        }

        return (score, codes)
    }
}
