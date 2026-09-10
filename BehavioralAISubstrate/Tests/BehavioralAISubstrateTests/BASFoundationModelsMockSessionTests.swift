// MARK: - BASFoundationModelsMockSessionTests — chapter 四百 / M920

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASFoundationModelsMockSessionTests: XCTestCase {

    private func makeRequest(
        instruction: String = "test"
    ) -> BASOrganRequest {
        BASOrganRequest(
            requestID: UUID().uuidString,
            role: .scout,
            preset: .scout,
            instruction: instruction)
    }

    // MARK: - Scripted text

    func testTextResponseRoundTrip() async throws {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "hello world")
            ])
        let draft = try await mock.draft(makeRequest())
        XCTAssertEqual(draft.body, "hello world")

        let exhausted = await mock.isExhausted
        XCTAssertTrue(exhausted)
    }

    // MARK: - Tool call body

    func testToolCallProducesParseableBody() async throws {
        let invocation = BASToolInvocation(
            invocationID: "inv-1",
            toolName: "echo",
            arguments: ["message": "hi"])
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [.toolCall(
                invocation: invocation)])
        let draft = try await mock.draft(makeRequest())

        XCTAssertTrue(draft.body.hasPrefix("TOOL_CALL:echo:"))
        let parsed = BASFoundationModelsMockSession
            .parseToolCallBody(draft.body)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.toolName, "echo")
        XCTAssertTrue(
            parsed?.argumentsJSON.contains("message")
                ?? false)
    }

    func testParseToolCallBodyReturnsNilForPlainText() {
        let parsed = BASFoundationModelsMockSession
            .parseToolCallBody("just a regular response")
        XCTAssertNil(parsed)
    }

    // MARK: - Error scripted

    func testScriptedErrorThrows() async {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .error(reason: "test failure")
            ])
        do {
            _ = try await mock.draft(makeRequest())
            XCTFail("Must throw scripted error")
        } catch BASFoundationModelsMockError
            .scripted(let reason)
        {
            XCTAssertEqual(reason, "test failure")
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // MARK: - Exhaustion

    func testExhaustedScriptThrows() async {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [.text(body: "only")])
        _ = try? await mock.draft(makeRequest())

        do {
            _ = try await mock.draft(makeRequest())
            XCTFail("Must throw scriptExhausted")
        } catch BASFoundationModelsMockError
            .scriptExhausted
        {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // MARK: - Latency

    func testSimulatedLatencyDelaysCall() async throws {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [.text(body: "ok")],
            simulatedLatencyMs: 100)
        let started = Date()
        _ = try await mock.draft(makeRequest())
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertGreaterThanOrEqual(elapsed, 0.09,
            "Latency >= 100ms simulated (with margin)")
    }

    // MARK: - Call records

    func testCallRecordsCaptureRequestsAndResponses()
        async throws
    {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [
                .text(body: "first"),
                .text(body: "second")
            ])
        _ = try await mock.draft(
            makeRequest(instruction: "req-1"))
        _ = try await mock.draft(
            makeRequest(instruction: "req-2"))

        let records = await mock.callRecords()
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(
            records[0].request.instruction, "req-1")
        XCTAssertEqual(
            records[0].respondedWith,
            .text(body: "first"))
        XCTAssertEqual(
            records[1].request.instruction, "req-2")
        XCTAssertEqual(
            records[1].respondedWith,
            .text(body: "second"))
    }

    // MARK: - Mid-test extension

    func testAppendResponsesExtendsScript() async throws {
        let mock = BASFoundationModelsMockSession(
            scriptedResponses: [.text(body: "first")])
        _ = try await mock.draft(makeRequest())

        await mock.appendResponses([
            .text(body: "second"),
            .text(body: "third")
        ])
        let draft2 = try await mock.draft(makeRequest())
        let draft3 = try await mock.draft(makeRequest())
        XCTAssertEqual(draft2.body, "second")
        XCTAssertEqual(draft3.body, "third")
    }
}
