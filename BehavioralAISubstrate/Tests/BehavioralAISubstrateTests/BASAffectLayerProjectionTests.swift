// Phase 2 — materialize TYPED affect on the value path. Proves the projection that lets the SSM caution
// operator consume affect as its third source: one BASAffectLayer per runtime pressure vector, in order,
// with each field a faithful + [0,1]-bounded transform of a real pressure-vector field, deterministic,
// and empty-on-empty. (Typed affect is otherwise absent from the runtime path — it lives only on the
// audit-shape dissection frame.)

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASOrchestration

final class BASAffectLayerProjectionTests: XCTestCase {

    private func pressure(
        _ kind: BASPressureKind, strength: Double, authenticity: Double
    ) -> BASPressureVector {
        BASPressureVector(
            vectorID: "v-\(kind.rawValue)", kind: kind, direction: .compressing,
            strength: strength, authenticity: authenticity, sourceRef: "s")
    }
    private func frame(_ vectors: [BASPressureVector]) -> BASDecomposeFrame {
        BASDecomposeFrame(mirrorText: "t", pressureVectors: vectors)
    }

    func testEmptyPressureYieldsEmptyAffect() {
        XCTAssertTrue(BASAffectLayerProjection.project(from: frame([])).isEmpty,
            "no pressure vectors → no affect layers (SSM builder then zero-pads)")
    }

    func testOneLayerPerPressureVectorInOrder() {
        let layers = BASAffectLayerProjection.project(from: frame([
            pressure(.time, strength: 0.8, authenticity: 0.9),
            pressure(.shame, strength: 0.5, authenticity: 0.2),
        ]))
        XCTAssertEqual(layers.count, 2, "one affect layer per pressure vector")
        XCTAssertEqual(layers.map(\.tone), ["time", "shame"],
            "frame order preserved; tone == pressure kind label")
    }

    func testFieldMappingIsFaithfulAndBounded() {
        let layers = BASAffectLayerProjection.project(from: frame([
            pressure(.consequence, strength: 0.7, authenticity: 0.25),
        ]))
        let a = layers[0]
        XCTAssertEqual(a.intensity, 0.7, accuracy: 1e-12, "intensity == strength")
        XCTAssertEqual(a.volatility, 0.75, accuracy: 1e-12, "volatility == 1 - authenticity")
        XCTAssertEqual(a.spilloverRisk, 0.7 * 0.75, accuracy: 1e-12,
            "spilloverRisk == strength * (1 - authenticity)")
        for layer in layers {
            XCTAssertTrue(layer.intensity >= 0 && layer.intensity <= 1, "intensity bounded")
            XCTAssertTrue(layer.volatility >= 0 && layer.volatility <= 1, "volatility bounded")
            XCTAssertTrue(layer.spilloverRisk >= 0 && layer.spilloverRisk <= 1, "spillover bounded")
        }
    }

    func testDeterministic() {
        let f = frame([
            pressure(.time, strength: 0.6, authenticity: 0.4),
            pressure(.resource, strength: 0.3, authenticity: 0.7),
        ])
        XCTAssertEqual(BASAffectLayerProjection.project(from: f),
                       BASAffectLayerProjection.project(from: f),
                       "same frame → identical typed affect layers")
    }

    func testMaterializedAffectFeedsTheSSMBuilder() throws {
        // The materialized affect is consumed by the SSM builder as a real source.
        let layers = BASAffectLayerProjection.project(from: frame([
            pressure(.shame, strength: 0.9, authenticity: 0.1),
        ]))
        let input = try XCTUnwrap(BASMambaTurnSignalBuilder.scanInput(
            affectLayers: layers, turnHistory: [], candidates: []))
        XCTAssertEqual(input.affectCount, 1,
            "the materialized affect layer is consumed by the SSM builder")
    }
}
