import XCTest
@testable import Before

final class DecisionLocalModelLibrarySnapshotTests: XCTestCase {
    func testSnapshotCarriesOpenModelSlotAndGemmaAssets() {
        let imported = GemmaModelAsset(
            fileName: "gemma-4-E4B-it.litertlm",
            fileSizeBytes: 1_000,
            expectedSizeBytes: nil,
            source: .imported
        )
        let bundled = GemmaModelAsset(
            fileName: "gemma-4-E4B-it-bundled.litertlm",
            fileSizeBytes: 2_000,
            expectedSizeBytes: nil,
            source: .bundled
        )
        let openModel = OpenModelAsset(
            fileName: "mistral-7b.gguf",
            fileSizeBytes: 4_200,
            source: .imported
        )
        let openModelDescriptor = DecisionModelProviderDescriptor(
            kind: .openModel,
            title: "Open model runtime",
            detail: "Reserved integration slot.",
            track: .builtInOpenModel,
            openModel: DecisionOpenModelDescriptor(
                stableID: "substrate/open-model-slot",
                family: "Open model runtime",
                version: "reserved",
                title: "Open model runtime",
                detail: "Reserved integration slot.",
                taskAffinities: [:]
            ),
            taskAffinities: [:]
        )

        let snapshot = DecisionLocalModelLibrarySnapshot.current(
            preferredProvider: .foundationModels,
            preferredGemmaAssetID: imported.assetID,
            preferredGemmaAsset: imported,
            importedGemmaAssets: [imported],
            bundledGemmaAsset: bundled,
            preferredOpenModelAssetID: openModel.assetID,
            preferredOpenModelAsset: openModel,
            importedOpenModelAssets: [openModel],
            openModelDescriptor: openModelDescriptor
        )

        XCTAssertEqual(snapshot.preferredGemmaAsset?.assetID, imported.assetID)
        XCTAssertEqual(snapshot.allGemmaAssets.count, 2)
        XCTAssertEqual(snapshot.preferredOpenModelAsset?.assetID, openModel.assetID)
        XCTAssertEqual(snapshot.importedOpenModelAssets.count, 1)
        XCTAssertEqual(snapshot.openModelSlot?.stableID, "substrate/open-model-slot")
        XCTAssertEqual(snapshot.openModelRuntimeAssetFileName, openModel.fileName)
        XCTAssertEqual(snapshot.openModelRuntimeStatus?.mode, .heuristicPreview)
        XCTAssertEqual(snapshot.openModelRuntimeStatus?.title, "Heuristic preview")
    }

    func testPresentationBuildsPreferredGemmaAndAssetRows() {
        let imported = GemmaModelAsset(
            fileName: "gemma-4-E4B-it.litertlm",
            fileSizeBytes: 1_000,
            expectedSizeBytes: nil,
            source: .imported
        )
        let bundled = GemmaModelAsset(
            fileName: "gemma-4-E4B-it-bundled.litertlm",
            fileSizeBytes: 2_000,
            expectedSizeBytes: nil,
            source: .bundled
        )
        let openModel = OpenModelAsset(
            fileName: "mistral-7b.gguf",
            fileSizeBytes: 4_200,
            source: .imported
        )

        let snapshot = DecisionLocalModelLibrarySnapshot.current(
            preferredProvider: .gemmaE4B,
            preferredGemmaAssetID: imported.assetID,
            preferredGemmaAsset: imported,
            importedGemmaAssets: [imported],
            bundledGemmaAsset: bundled,
            preferredOpenModelAssetID: openModel.assetID,
            preferredOpenModelAsset: openModel,
            importedOpenModelAssets: [openModel],
            openModelDescriptor: nil
        )

        let presentation = DecisionLocalModelLibraryPresentation.build(from: snapshot)

        XCTAssertEqual(presentation.supportedRuntimeValue, "Gemma 4 E4B (.litertlm)")
        XCTAssertEqual(presentation.gemmaAssets.count, 2)
        XCTAssertTrue(presentation.gemmaAssets.contains(where: {
            $0.asset.assetID == imported.assetID && $0.isExplicitlySelected && $0.canRemove
        }))
        XCTAssertTrue(presentation.gemmaAssets.contains(where: {
            $0.asset.assetID == bundled.assetID && !$0.canRemove
        }))
        XCTAssertEqual(
            presentation.preferredGemmaSelectionDetail,
            "Gemma will currently use imported asset gemma-4-E4B-it.litertlm."
        )
        XCTAssertNil(presentation.emptyGemmaLibraryMessage)
        XCTAssertEqual(
            presentation.preferredOpenModelSelectionDetail,
            "Open model runtime is currently pinned to imported asset mistral-7b.gguf and running in heuristic preview mode."
        )
        XCTAssertEqual(presentation.openModelRuntimeTitle, "Heuristic preview")
        XCTAssertTrue(presentation.openModelRuntimeDetail?.contains("mistral-7b.gguf") == true)
        XCTAssertEqual(presentation.openModelAssets.count, 1)
        XCTAssertEqual(
            presentation.openModelAssets.first?.detail,
            "4 KB • GGUF • heuristic preview bridge"
        )
        XCTAssertNil(presentation.emptyOpenModelLibraryMessage)
    }

    func testPresentationShowsEmptyStateWhenNoGemmaAssetExists() {
        let openModelDescriptor = DecisionModelProviderDescriptor(
            kind: .openModel,
            title: "Open model runtime",
            detail: "Reserved integration slot.",
            track: .builtInOpenModel,
            openModel: DecisionOpenModelDescriptor(
                stableID: "substrate/open-model-slot",
                family: "Open model runtime",
                version: "reserved",
                title: "Open model runtime",
                detail: "Reserved integration slot.",
                taskAffinities: [:]
            ),
            taskAffinities: [:]
        )

        let snapshot = DecisionLocalModelLibrarySnapshot.current(
            preferredProvider: .foundationModels,
            preferredGemmaAssetID: nil,
            preferredGemmaAsset: nil,
            importedGemmaAssets: [],
            bundledGemmaAsset: nil,
            preferredOpenModelAssetID: nil,
            preferredOpenModelAsset: nil,
            importedOpenModelAssets: [],
            openModelDescriptor: openModelDescriptor
        )

        let presentation = DecisionLocalModelLibraryPresentation.build(from: snapshot)

        XCTAssertTrue(presentation.gemmaAssets.isEmpty)
        XCTAssertEqual(
            presentation.emptyGemmaLibraryMessage,
            "No local Gemma asset is available yet."
        )
        XCTAssertEqual(
            presentation.emptyOpenModelLibraryMessage,
            "No imported open-model asset is available yet."
        )
        XCTAssertNil(presentation.preferredGemmaSelectionDetail)
        XCTAssertNil(presentation.preferredOpenModelSelectionDetail)
        XCTAssertEqual(presentation.openModelRuntimeTitle, "Waiting for import")
        XCTAssertEqual(
            presentation.openModelRuntimeDetail,
            "The generic open-model slot is reserved but not active yet. Import or download a GGUF, ONNX, SafeTensors, LiteRTLM, or BIN asset to light up the local runtime path."
        )
    }
}
