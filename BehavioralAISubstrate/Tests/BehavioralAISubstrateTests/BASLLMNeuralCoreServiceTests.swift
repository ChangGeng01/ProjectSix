// MARK: - BASLLMNeuralCoreServiceTests — chapter 四百一 / M933

import XCTest
@testable import BASHostKit
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASLLMNeuralCoreServiceTests: XCTestCase {

    func testServiceWrapsEngineAndReturnsResult() async
        throws
    {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "service answer")
            ])
        let log = BASInMemoryEventLogStorage()
        let engine = BASLLMExtractionEngine(
            adapter: mock, eventLog: log)
        let service = BASLLMNeuralCoreService(
            engine: engine)

        let result = try await service.executeLLMTurn(
            rawInput: BASLLMRawInput(
                prompt: "test",
                sessionID: "s-svc"),
            context: .empty,
            toolHints: [],
            outputSchema: nil)

        XCTAssertEqual(result.byproducts.finalAnswer,
            "service answer")
    }

    func testMakeDefaultFactory() async throws {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "factory answer")
            ])
        let log = BASInMemoryEventLogStorage()
        let service = BASLLMNeuralCoreService.makeDefault(
            adapter: mock, eventLog: log)

        let result = try await service.executeLLMTurn(
            rawInput: BASLLMRawInput(
                prompt: "x",
                sessionID: "s-fac"),
            context: .empty,
            toolHints: [],
            outputSchema: nil)

        XCTAssertEqual(result.byproducts.finalAnswer,
            "factory answer")
    }

    func testServiceConformsToProtocol() {
        // Compile-time: BASLLMNeuralCoreService MUST conform
        // to BASLLMNeuralCoreServicing。Cast to verify。
        let log = BASInMemoryEventLogStorage()
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [])
        let service: any BASLLMNeuralCoreServicing =
            BASLLMNeuralCoreService.makeDefault(
                adapter: mock, eventLog: log)
        // Just need to compile + cast — runtime path tested
        // in the round-trip tests above。
        _ = service
    }

    func testMultipleSessionsViaSameService() async throws {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "first"),
                .text(body: "second")
            ])
        let log = BASInMemoryEventLogStorage()
        let service = BASLLMNeuralCoreService.makeDefault(
            adapter: mock, eventLog: log)

        let r1 = try await service.executeLLMTurn(
            rawInput: BASLLMRawInput(
                prompt: "p1", sessionID: "s-A"),
            context: .empty, toolHints: [],
            outputSchema: nil)
        let r2 = try await service.executeLLMTurn(
            rawInput: BASLLMRawInput(
                prompt: "p2", sessionID: "s-B"),
            context: .empty, toolHints: [],
            outputSchema: nil)

        XCTAssertEqual(r1.byproducts.finalAnswer, "first")
        XCTAssertEqual(r2.byproducts.finalAnswer, "second")

        // Both sessions appear in the event log
        let aEvents = await log.events(forSession: "s-A")
        let bEvents = await log.events(forSession: "s-B")
        XCTAssertEqual(aEvents.count, 2)
        XCTAssertEqual(bEvents.count, 2)
    }
}
