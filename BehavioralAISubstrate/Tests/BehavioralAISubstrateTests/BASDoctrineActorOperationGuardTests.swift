import XCTest
@testable import BASRuntimeCore

/// 四十九 — cross-pillar guard contract tests.
///
/// Doctrine pinned:
/// - Compliant operation → empty violations
/// - Doctrine D violation alone → 1 entry (actorOutputClassDenied)
/// - Doctrine B violation alone → 1 entry (scopeMismatch)
/// - Doctrine C violation alone → 1 entry (velocityViolatesScope)
/// - Multiple violations accumulate
/// - `isCompliant(_:)` is empty-list shorthand
/// - Codable round-trip on violations
final class BASDoctrineActorOperationGuardTests: XCTestCase {

    // MARK: - Compliant

    func test_compliantOperation_noViolations() {
        // Neural network's canonical: produce advisory at
        // parameter scope with veryLow velocity. All 3
        // pillars hold.
        let op = BASDoctrineActorOperation(
            actor: .neuralNetwork,
            outputClass: .advisory,
            stateUpdateScope: .parameter,
            stateUpdateVelocity: .veryLow)
        XCTAssertEqual(
            BASDoctrineActorOperationGuard.check(op), [])
        XCTAssertTrue(
            BASDoctrineActorOperationGuard.isCompliant(op))
    }

    func test_hostCompliantOperation() {
        let op = BASDoctrineActorOperation(
            actor: .host,
            outputClass: .directive,
            stateUpdateScope: .individual,
            stateUpdateVelocity: .fast)
        XCTAssertTrue(
            BASDoctrineActorOperationGuard.isCompliant(op))
    }

    func test_secondBrainCompliantOperation() {
        let op = BASDoctrineActorOperation(
            actor: .secondBrain,
            outputClass: .authoritative,
            stateUpdateScope: .process,
            stateUpdateVelocity: .medium)
        XCTAssertTrue(
            BASDoctrineActorOperationGuard.isCompliant(op))
    }

    func test_sdkCompliantOperation() {
        let op = BASDoctrineActorOperation(
            actor: .sdk,
            outputClass: .execution,
            stateUpdateScope: .device,
            stateUpdateVelocity: .immediate)
        XCTAssertTrue(
            BASDoctrineActorOperationGuard.isCompliant(op))
    }

    // MARK: - Doctrine D violations

    func test_neuralNetworkAttemptsExecution_doctrineDViolation()
    {
        // Neural network claiming execution authority — typed
        // violation surfaces.
        let op = BASDoctrineActorOperation(
            actor: .neuralNetwork,
            outputClass: .execution,
            stateUpdateScope: .parameter,
            stateUpdateVelocity: .veryLow)
        let violations =
            BASDoctrineActorOperationGuard.check(op)
        XCTAssertTrue(violations.contains(
            .actorOutputClassDenied(
                .neuralNetwork, .execution)))
    }

    func test_sdkAttemptsAuthoritative_doctrineDViolation() {
        let op = BASDoctrineActorOperation(
            actor: .sdk,
            outputClass: .authoritative,
            stateUpdateScope: .device,
            stateUpdateVelocity: .immediate)
        let violations =
            BASDoctrineActorOperationGuard.check(op)
        XCTAssertTrue(violations.contains(
            .actorOutputClassDenied(.sdk, .authoritative)))
    }

    // MARK: - Doctrine B violations

    func test_neuralNetworkAtWrongScope_doctrineBViolation() {
        // Neural network's canonical is .parameter; trying to
        // update at .device scope violates Doctrine B.
        let op = BASDoctrineActorOperation(
            actor: .neuralNetwork,
            outputClass: .advisory,
            stateUpdateScope: .device,
            stateUpdateVelocity: .immediate)
        let violations =
            BASDoctrineActorOperationGuard.check(op)
        XCTAssertTrue(violations.contains(
            .scopeMismatch(.neuralNetwork, .device)))
    }

    // MARK: - Doctrine C violations

    func test_parameterScopeAtFastVelocity_doctrineCViolation()
    {
        // Doctrine C: .parameter scope MUST be .veryLow only.
        // Anything else violates.
        let op = BASDoctrineActorOperation(
            actor: .neuralNetwork,
            outputClass: .advisory,
            stateUpdateScope: .parameter,
            stateUpdateVelocity: .fast)
        let violations =
            BASDoctrineActorOperationGuard.check(op)
        XCTAssertTrue(violations.contains(
            .velocityViolatesScope(.parameter, .fast)))
    }

    func test_processScopeAtImmediateVelocity_doctrineCViolation()
    {
        // Process canonical floor is .medium; .immediate
        // exceeds it.
        let op = BASDoctrineActorOperation(
            actor: .secondBrain,
            outputClass: .authoritative,
            stateUpdateScope: .process,
            stateUpdateVelocity: .immediate)
        let violations =
            BASDoctrineActorOperationGuard.check(op)
        XCTAssertTrue(violations.contains(
            .velocityViolatesScope(.process, .immediate)))
    }

    // MARK: - Multiple violations accumulate

    func test_neuralNetworkClaimingDeviceExecution_dPlusBViolations()
    {
        // Neural network claiming execution authority + at
        // device scope. C check runs against operation's scope
        // (.device), and .immediate is at-or-below .device's
        // canonical floor (.immediate), so C does not fire.
        // Result: D + B violations = 2.
        let op = BASDoctrineActorOperation(
            actor: .neuralNetwork,
            outputClass: .execution,
            stateUpdateScope: .device,
            stateUpdateVelocity: .immediate)
        let violations =
            BASDoctrineActorOperationGuard.check(op)
        XCTAssertEqual(violations.count, 2)
        XCTAssertTrue(violations.contains(
            .actorOutputClassDenied(
                .neuralNetwork, .execution)))
        XCTAssertTrue(violations.contains(
            .scopeMismatch(.neuralNetwork, .device)))
    }

    func test_neuralNetworkClaimingProcessScopeAtFastVelocity_threeViolations()
    {
        // Truly all 3 pillars violated:
        // - D: NN claiming authoritative (its set is {advisory})
        // - B: NN claims .process scope (canonical is .parameter)
        // - C: .process scope at .fast velocity (floor is .medium)
        let op = BASDoctrineActorOperation(
            actor: .neuralNetwork,
            outputClass: .authoritative,
            stateUpdateScope: .process,
            stateUpdateVelocity: .fast)
        let violations =
            BASDoctrineActorOperationGuard.check(op)
        XCTAssertEqual(violations.count, 3)
        XCTAssertTrue(violations.contains(
            .actorOutputClassDenied(
                .neuralNetwork, .authoritative)))
        XCTAssertTrue(violations.contains(
            .scopeMismatch(.neuralNetwork, .process)))
        XCTAssertTrue(violations.contains(
            .velocityViolatesScope(.process, .fast)))
    }

    // MARK: - Pure value-check semantics

    func test_isCompliantConvenienceMatchesEmptyList() {
        let compliant = BASDoctrineActorOperation(
            actor: .host,
            outputClass: .directive,
            stateUpdateScope: .individual,
            stateUpdateVelocity: .fast)
        XCTAssertTrue(
            BASDoctrineActorOperationGuard.isCompliant(
                compliant))
        XCTAssertEqual(
            BASDoctrineActorOperationGuard.check(compliant)
                .count,
            0)

        let bad = BASDoctrineActorOperation(
            actor: .neuralNetwork,
            outputClass: .execution,
            stateUpdateScope: .parameter,
            stateUpdateVelocity: .veryLow)
        XCTAssertFalse(
            BASDoctrineActorOperationGuard.isCompliant(bad))
    }

    // MARK: - Codable round-trip

    func test_violationCodableRoundTrip() throws {
        let cases: [BASDoctrineViolation] = [
            .actorOutputClassDenied(
                .neuralNetwork, .execution),
            .scopeMismatch(.host, .device),
            .velocityViolatesScope(.parameter, .fast),
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(
                BASDoctrineViolation.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }

    func test_operationCodableRoundTrip() throws {
        let original = BASDoctrineActorOperation(
            actor: .secondBrain,
            outputClass: .authoritative,
            stateUpdateScope: .process,
            stateUpdateVelocity: .medium)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASDoctrineActorOperation.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
