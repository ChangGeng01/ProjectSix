import XCTest
@testable import BASRuntimeCore

/// 四十五.7+ — typed actor role + Doctrine D matrix tests.
///
/// Doctrine pinned:
/// - 4 actors / 4 output classes
/// - Doctrine D core invariant: neural network NEVER permits
///   execution, NEVER permits authoritative
/// - SDK is execution-exclusive (no other actor permits
///   execution)
/// - Authoritative is second-brain-exclusive
/// - Directive is host-exclusive
/// - Advisory shared by neural network + second brain
/// - Codable round-trip
final class BASActorRoleTests: XCTestCase {

    // MARK: - Cardinality

    func test_fourActors() {
        XCTAssertEqual(BASActor.allCases.count, 4)
    }

    func test_fourOutputClasses() {
        XCTAssertEqual(
            BASActorOutputClass.allCases.count, 4)
    }

    // MARK: - Per-actor permitted sets

    func test_hostPermitsOnlyDirective() {
        XCTAssertEqual(
            BASActor.host.permittedOutputClasses,
            [.directive])
    }

    func test_secondBrainPermitsAuthoritativeAndAdvisory() {
        XCTAssertEqual(
            BASActor.secondBrain.permittedOutputClasses,
            [.authoritative, .advisory])
    }

    func test_neuralNetworkPermitsOnlyAdvisory() {
        XCTAssertEqual(
            BASActor.neuralNetwork.permittedOutputClasses,
            [.advisory])
    }

    func test_sdkPermitsOnlyExecution() {
        XCTAssertEqual(
            BASActor.sdk.permittedOutputClasses,
            [.execution])
    }

    // MARK: - Doctrine D core invariants

    func test_neuralNetworkNeverPermitsExecution() {
        XCTAssertFalse(
            BASActor.neuralNetwork.permits(
                outputClass: .execution),
            "Doctrine D: neural network must not produce execution")
    }

    func test_neuralNetworkNeverPermitsAuthoritative() {
        XCTAssertFalse(
            BASActor.neuralNetwork.permits(
                outputClass: .authoritative),
            "Doctrine D: only second brain produces authoritative")
    }

    func test_neuralNetworkNeverPermitsDirective() {
        XCTAssertFalse(
            BASActor.neuralNetwork.permits(
                outputClass: .directive),
            "Doctrine D: directive is host-exclusive")
    }

    func test_executionIsSDKExclusive() {
        let executors = BASActor.allCases.filter {
            $0.permits(outputClass: .execution)
        }
        XCTAssertEqual(executors, [.sdk])
    }

    func test_authoritativeIsSecondBrainExclusive() {
        let authors = BASActor.allCases.filter {
            $0.permits(outputClass: .authoritative)
        }
        XCTAssertEqual(authors, [.secondBrain])
    }

    func test_directiveIsHostExclusive() {
        let directors = BASActor.allCases.filter {
            $0.permits(outputClass: .directive)
        }
        XCTAssertEqual(directors, [.host])
    }

    func test_advisorySharedByNeuralAndSecondBrain() {
        let advisers = BASActor.allCases.filter {
            $0.permits(outputClass: .advisory)
        }
        XCTAssertEqual(
            Set(advisers), [.secondBrain, .neuralNetwork])
    }

    // MARK: - SDK never produces brain-side outputs

    func test_sdkNeverPermitsBrainSideOutputs() {
        XCTAssertFalse(
            BASActor.sdk.permits(outputClass: .advisory))
        XCTAssertFalse(
            BASActor.sdk.permits(outputClass: .authoritative))
        XCTAssertFalse(
            BASActor.sdk.permits(outputClass: .directive))
    }

    func test_hostNeverPermitsBrainOrSDKOutputs() {
        XCTAssertFalse(
            BASActor.host.permits(outputClass: .advisory))
        XCTAssertFalse(
            BASActor.host.permits(outputClass: .authoritative))
        XCTAssertFalse(
            BASActor.host.permits(outputClass: .execution))
    }

    // MARK: - Codable round-trip

    func test_actorCodableRoundTrip() throws {
        for actor in BASActor.allCases {
            let data = try JSONEncoder().encode(actor)
            let decoded = try JSONDecoder().decode(
                BASActor.self, from: data)
            XCTAssertEqual(decoded, actor)
        }
    }

    func test_outputClassCodableRoundTrip() throws {
        for cls in BASActorOutputClass.allCases {
            let data = try JSONEncoder().encode(cls)
            let decoded = try JSONDecoder().decode(
                BASActorOutputClass.self, from: data)
            XCTAssertEqual(decoded, cls)
        }
    }

    // MARK: - Raw values

    func test_actorRawValuesPinned() {
        XCTAssertEqual(BASActor.host.rawValue, "host")
        XCTAssertEqual(
            BASActor.secondBrain.rawValue, "secondBrain")
        XCTAssertEqual(
            BASActor.neuralNetwork.rawValue, "neuralNetwork")
        XCTAssertEqual(BASActor.sdk.rawValue, "sdk")
    }

    func test_outputClassRawValuesPinned() {
        XCTAssertEqual(
            BASActorOutputClass.directive.rawValue,
            "directive")
        XCTAssertEqual(
            BASActorOutputClass.advisory.rawValue,
            "advisory")
        XCTAssertEqual(
            BASActorOutputClass.authoritative.rawValue,
            "authoritative")
        XCTAssertEqual(
            BASActorOutputClass.execution.rawValue,
            "execution")
    }
}
