import XCTest
import Foundation
@testable import BASOrgan

/// Plan piece D — the PURE task→provider selection matrix. Proves deterministic ranking by role + the new
/// (observation-class) descriptor metadata, reason-code transparency, off-device fallback, and that the additive
/// `BASOrganDescriptor` fields keep Codable backward-compatible. No MLX/Apple dependency — all hand-built descriptors.
final class BASNeuralProviderMatrixTests: XCTestCase {

    private func desc(
        _ id: String, onDevice: Bool = true, roles: Set<BASOrganRole> = [.scout, .core],
        kind: BASProviderKind? = nil, tier: BASCertificationTier? = nil, size: Int? = nil
    ) -> BASOrganDescriptor {
        BASOrganDescriptor(
            providerID: id, providerName: id, supportsStreaming: false,
            maxInputTokens: 1000, maxOutputTokens: 1000, runsOnDevice: onDevice, supportedRoles: roles,
            providerKind: kind, certificationTier: tier, modelSizeHint: size)
    }

    // MARK: - Core ranking

    func testPrefersOnDeviceOverRemote() {
        let s = BASNeuralProviderMatrix.select(
            context: .init(role: .core),
            candidates: [desc("remote", onDevice: false, kind: .remote), desc("local", kind: .mlx)])
        XCTAssertEqual(s.chosen?.providerID, "local")
        XCTAssertFalse(s.chosen?.isOffDevice ?? true)
        XCTAssertTrue(s.chosen?.reasonCodes.contains(BASNeuralProviderMatrix.Reason.onDevice) ?? false)
    }

    func testScoutPrefersSmallest() {
        let s = BASNeuralProviderMatrix.select(
            context: .init(role: .scout, preferSmallest: true),
            candidates: [desc("big", kind: .mlx, size: 4_000_000_000),
                         desc("small", kind: .mlx, size: 1_000_000_000)])
        XCTAssertEqual(s.chosen?.providerID, "small")
        XCTAssertTrue(s.chosen?.reasonCodes.contains(BASNeuralProviderMatrix.Reason.sizeSmallerPreferred) ?? false)
    }

    func testCorePrefersCertified() {
        let s = BASNeuralProviderMatrix.select(
            context: .init(role: .core, preferCertified: true),
            candidates: [desc("exp", kind: .mlx, tier: .experimental), desc("cert", kind: .mlx, tier: .certified)])
        XCTAssertEqual(s.chosen?.providerID, "cert")
        XCTAssertTrue(s.chosen?.reasonCodes.contains(BASNeuralProviderMatrix.Reason.certCertified) ?? false)
    }

    func testKindBiasBreaksOnDeviceTie() {
        // Two on-device, no other prefs → appleNative (+30) beats mlx (+20).
        let s = BASNeuralProviderMatrix.select(
            context: .init(role: .core),
            candidates: [desc("mlx", kind: .mlx), desc("apple", kind: .appleNative)])
        XCTAssertEqual(s.chosen?.providerID, "apple")
        XCTAssertTrue(s.chosen?.reasonCodes.contains(BASNeuralProviderMatrix.Reason.kindAppleNative) ?? false)
    }

    // MARK: - Fallback + skip

    func testOffDeviceFallbackWhenNoOnDevice() {
        let s = BASNeuralProviderMatrix.select(
            context: .init(role: .core),
            candidates: [desc("r1", onDevice: false, kind: .remote)])
        XCTAssertEqual(s.chosen?.providerID, "r1")
        XCTAssertTrue(s.chosen?.isOffDevice ?? false)
        XCTAssertTrue(s.chosen?.reasonCodes.contains(BASNeuralProviderMatrix.Reason.noOnDeviceCandidate) ?? false)
    }

    func testUnsupportedRoleSkipped() {
        let s = BASNeuralProviderMatrix.select(
            context: .init(role: .core),
            candidates: [desc("scoutOnly", roles: [.scout]), desc("coreOk", roles: [.core])])
        XCTAssertEqual(s.chosen?.providerID, "coreOk")
        XCTAssertEqual(s.unsupportedProviderIDs, ["scoutOnly"])
    }

    func testNoCandidateSupportsRole() {
        let s = BASNeuralProviderMatrix.select(
            context: .init(role: .core), candidates: [desc("s", roles: [.scout])])
        XCTAssertNil(s.chosen)
        XCTAssertTrue(s.ranked.isEmpty)
        XCTAssertEqual(s.unsupportedProviderIDs, ["s"])
    }

    // MARK: - Determinism + honesty

    func testDeterministicOrderingAndTieBreak() {
        let cands = [desc("b", kind: .mlx), desc("a", kind: .mlx)]   // identical score → tie-break by id asc
        let s1 = BASNeuralProviderMatrix.select(context: .init(role: .core), candidates: cands)
        let s2 = BASNeuralProviderMatrix.select(context: .init(role: .core), candidates: cands)
        XCTAssertEqual(s1, s2, "pure — same inputs ⇒ identical Selection")
        XCTAssertEqual(s1.ranked.map(\.providerID), ["a", "b"], "ties broken lexicographically by providerID")
        XCTAssertEqual(s1.ranked.map(\.rank), [0, 1], "rank is sequential from 0")
    }

    func testReasonCodesNeverNameASpineBannedSymbol() {
        let s = BASNeuralProviderMatrix.select(
            context: .init(role: .core, preferCertified: true, preferSmallest: true),
            candidates: [desc("a", kind: .appleNative, tier: .certified, size: 2_000_000_000),
                         desc("b", onDevice: false, kind: .remote, tier: .experimental)])
        let banned = ["BASMetal", "BASApproxValue", "MLXRuntimeConfig", "approximateOnly", "BASCoreAI"]
        for ranked in s.ranked {
            for code in ranked.reasonCodes {
                for b in banned {
                    XCTAssertFalse(code.contains(b), "reason code must not name a spine-banned symbol: \(code)")
                }
            }
        }
    }

    // MARK: - Additive descriptor fields keep Codable backward-compatible

    func testDescriptorDecodesPreSchemaDJSON() throws {
        // OLD JSON (pre-§D, no providerKind/certificationTier/modelSizeHint) must still decode — fields → nil.
        let oldJSON = Data("""
        {"providerID":"p","providerName":"P","supportsStreaming":false,"maxInputTokens":1000,
         "maxOutputTokens":1000,"runsOnDevice":true,"supportedRoles":["core"]}
        """.utf8)
        let decoded = try JSONDecoder().decode(BASOrganDescriptor.self, from: oldJSON)
        XCTAssertNil(decoded.providerKind)
        XCTAssertNil(decoded.certificationTier)
        XCTAssertNil(decoded.modelSizeHint)
        XCTAssertEqual(decoded.providerID, "p")
        XCTAssertEqual(decoded.supportedRoles, [.core])
    }

    func testPopulatedDescriptorRoundTrips() throws {
        let pop = desc("q", kind: .appleNative, tier: .certified, size: 2_000_000_000)
        let back = try JSONDecoder().decode(BASOrganDescriptor.self, from: try JSONEncoder().encode(pop))
        XCTAssertEqual(back, pop)
        XCTAssertEqual(back.providerKind, .appleNative)
        XCTAssertEqual(back.certificationTier, .certified)
        XCTAssertEqual(back.modelSizeHint, 2_000_000_000)
    }
}
