import XCTest
@testable import BASRuntimeCore

/// 四十五.7+ — manifest stream typed reference tests.
///
/// Doctrine pinned:
/// - 3 streams (cognition / permission / growth)
/// - 13 stages total: 5 cognition + 3 permission + 5 growth
/// - Stage → stream is a function (every stage in exactly one
///   stream)
/// - Stream → stages exposes the inverse list
/// - Codable round-trip
/// - Raw values stable
final class BASManifestStreamTests: XCTestCase {

    // MARK: - Stream cardinality

    func test_streamHasThreeCases() {
        XCTAssertEqual(
            BASManifestStream.allCases.count, 3)
    }

    func test_streamRawValuesPinned() {
        XCTAssertEqual(
            BASManifestStream.cognition.rawValue,
            "cognition")
        XCTAssertEqual(
            BASManifestStream.permission.rawValue,
            "permission")
        XCTAssertEqual(
            BASManifestStream.growth.rawValue,
            "growth")
    }

    // MARK: - Stage cardinality

    func test_stageHasThirteenCases() {
        XCTAssertEqual(
            BASManifestStreamStage.allCases.count, 13)
    }

    func test_stageRawValuesPinned() {
        XCTAssertEqual(
            BASManifestStreamStage.input.rawValue, "input")
        XCTAssertEqual(
            BASManifestStreamStage.loopGenerate.rawValue,
            "loopGenerate")
        XCTAssertEqual(
            BASManifestStreamStage.councilDispatch.rawValue,
            "councilDispatch")
        XCTAssertEqual(
            BASManifestStreamStage.neuralIntent.rawValue,
            "neuralIntent")
        XCTAssertEqual(
            BASManifestStreamStage.sdkExecute.rawValue,
            "sdkExecute")
        XCTAssertEqual(
            BASManifestStreamStage.hostFeedback.rawValue,
            "hostFeedback")
        XCTAssertEqual(
            BASManifestStreamStage.versionDelta.rawValue,
            "versionDelta")
    }

    // MARK: - Stage → stream is a function

    func test_eachStageBelongsToOneStream() {
        // Every stage produces exactly one .stream value.
        // (Tested by virtue of `stream` being non-optional;
        // here we assert the partition is exhaustive.)
        var byStream: [
            BASManifestStream: Int
        ] = [:]
        for stage in BASManifestStreamStage.allCases {
            byStream[stage.stream, default: 0] += 1
        }
        XCTAssertEqual(byStream[.cognition], 5)
        XCTAssertEqual(byStream[.permission], 3)
        XCTAssertEqual(byStream[.growth], 5)
    }

    // MARK: - Cognition stream

    func test_cognitionStreamHasFiveStagesInOrder() {
        let stages = BASManifestStream.cognition.stages
        XCTAssertEqual(stages.count, 5)
        XCTAssertEqual(stages, [
            .input,
            .loopGenerate,
            .councilDispatch,
            .decision,
            .surfaceRender,
        ])
    }

    // MARK: - Permission stream (Doctrine D enforcement boundary)

    func test_permissionStreamHasThreeStagesInOrder() {
        let stages = BASManifestStream.permission.stages
        XCTAssertEqual(stages.count, 3)
        XCTAssertEqual(stages, [
            .neuralIntent,
            .secondBrainPermit,
            .sdkExecute,
        ])
    }

    // MARK: - Growth stream (Doctrine A enforcement boundary)

    func test_growthStreamHasFiveStagesInOrder() {
        let stages = BASManifestStream.growth.stages
        XCTAssertEqual(stages.count, 5)
        XCTAssertEqual(stages, [
            .hostFeedback,
            .sdkLog,
            .updateTicket,
            .shadowTrial,
            .versionDelta,
        ])
    }

    // MARK: - Codable round-trip

    func test_streamCodableRoundTrip() throws {
        for stream in BASManifestStream.allCases {
            let data = try JSONEncoder().encode(stream)
            let decoded = try JSONDecoder().decode(
                BASManifestStream.self, from: data)
            XCTAssertEqual(decoded, stream)
        }
    }

    func test_stageCodableRoundTrip() throws {
        for stage in BASManifestStreamStage.allCases {
            let data = try JSONEncoder().encode(stage)
            let decoded = try JSONDecoder().decode(
                BASManifestStreamStage.self, from: data)
            XCTAssertEqual(decoded, stage)
        }
    }

    // MARK: - Doctrine D boundary

    func test_permissionStreamSpansNeuralBrainAndSdk() {
        // Doctrine D: 神经网络 = 产生意向; 第二大脑 = 产生许可;
        // SDK = 执行现实接口. Three stages, one per actor.
        let stages = BASManifestStream.permission.stages
        XCTAssertEqual(stages.count, 3)
        XCTAssertTrue(stages.contains(.neuralIntent))
        XCTAssertTrue(stages.contains(.secondBrainPermit))
        XCTAssertTrue(stages.contains(.sdkExecute))
    }

    // MARK: - Doctrine A boundary

    func test_growthStreamSpansHostThroughVersionDelta() {
        // Doctrine A: 宿主私有经验 NEVER 直接进 L2 权重 —
        // growth flow ends at .versionDelta (L13 / L5 / L8
        // territory), not at training pipeline.
        let stages = BASManifestStream.growth.stages
        XCTAssertEqual(stages.first, .hostFeedback)
        XCTAssertEqual(stages.last, .versionDelta)
        XCTAssertFalse(
            stages.contains(where: {
                $0.rawValue.contains("training")
                    || $0.rawValue.contains("weight")
            }),
            "growth stream MUST NOT contain training/weight " +
            "stages (Doctrine A boundary)")
    }
}
