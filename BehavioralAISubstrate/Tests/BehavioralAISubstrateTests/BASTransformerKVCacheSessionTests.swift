// MARK: - BASTransformerKVCacheSessionTests
// chapter 四百八十二 / M1305

import XCTest
@testable import BASRuntimeCore

final class BASTransformerKVCacheSessionTests: XCTestCase {

    private func sampleToken() -> BASTransformerKVCacheToken {
        return BASTransformerKVCacheToken(
            keyBytes: Data([0, 0, 0, 0]),
            valueBytes: Data([1, 1, 1, 1]),
            elementCount: 1)
    }

    func testEmptySessionHasZeroOffset() {
        let session = BASTransformerKVCacheSession(
            sessionID: "test-session")
        XCTAssertEqual(session.tokenOffset, 0)
        XCTAssertTrue(session.tokensByLayer.isEmpty)
        XCTAssertEqual(session.totalCachedTokens, 0)
        XCTAssertEqual(session.totalCachedBytes, 0)
        XCTAssertEqual(
            session.invalidationPolicy, .explicitOnly)
    }

    func testAppendingTokenAdvancesOffset() {
        let session1 = BASTransformerKVCacheSession(
            sessionID: "test-1")
        let token = sampleToken()
        let session2 = session1.appending(
            token: token, atLayer: 0)
        XCTAssertEqual(session2.tokenOffset, 1)
        XCTAssertEqual(
            session2.tokensByLayer[0]?.count, 1)

        let session3 = session2.appending(
            token: token, atLayer: 0)
        XCTAssertEqual(session3.tokenOffset, 2)
    }

    func testAppendingDifferentLayersTracksIndependent() {
        var session = BASTransformerKVCacheSession(
            sessionID: "test")
        session = session.appending(
            token: sampleToken(), atLayer: 0)
        session = session.appending(
            token: sampleToken(), atLayer: 1)
        session = session.appending(
            token: sampleToken(), atLayer: 0)
        XCTAssertEqual(
            session.tokensByLayer[0]?.count, 2)
        XCTAssertEqual(
            session.tokensByLayer[1]?.count, 1)
        XCTAssertEqual(session.totalCachedTokens, 3)
    }

    func testTotalCachedBytesSumsAcrossLayers() {
        var session = BASTransformerKVCacheSession(
            sessionID: "test")
        for _ in 0..<3 {
            session = session.appending(
                token: sampleToken(), atLayer: 0)
        }
        // 3 tokens × (4 key bytes + 4 value bytes) = 24
        XCTAssertEqual(session.totalCachedBytes, 24)
    }

    func testSessionRoundTripsViaJSON() throws {
        var session = BASTransformerKVCacheSession(
            sessionID: "round-trip",
            invalidationPolicy: .lruByTokenCount)
        session = session.appending(
            token: sampleToken(), atLayer: 5)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(session)
        let decoded = try JSONDecoder().decode(
            BASTransformerKVCacheSession.self,
            from: data)
        XCTAssertEqual(decoded, session,
            "Codable round-trip (chapter 三百九二)")
    }

    func testLayerKeyEqualityRespectsBothFields() {
        let k1 = BASTransformerKVCacheLayerKey(
            sessionID: "s", layerIndex: 0)
        let k2 = BASTransformerKVCacheLayerKey(
            sessionID: "s", layerIndex: 0)
        let k3 = BASTransformerKVCacheLayerKey(
            sessionID: "s", layerIndex: 1)
        XCTAssertEqual(k1, k2)
        XCTAssertNotEqual(k1, k3)
    }

    func testInvalidationPolicyHasThreeCases() {
        XCTAssertEqual(
            BASTransformerKVCacheInvalidationPolicy
                .allCases.count, 3)
    }
}
