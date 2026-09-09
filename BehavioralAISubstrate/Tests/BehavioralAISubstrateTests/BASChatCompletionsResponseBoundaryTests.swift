import Foundation
import XCTest
@testable import BASOrgan
@testable import BASChatCompletionsAdapter

/// Scheduled, incremental input at the real URLSession boundary; never contacts a server.
private final class ResponseScript: @unchecked Sendable {
    let chunks: [Data]
    let headerDelay: TimeInterval
    let interval: TimeInterval
    let status: Int
    let error: URLError?
    let failsBeforeHeaders: Bool
    let responseHeaders: [String: String]
    let lock = NSLock()
    private var stopped = false
    private var sent = 0
    private var receivedRequest: URLRequest?
    init(_ chunks: [Data], headerDelay: TimeInterval = 0, interval: TimeInterval = 0.005,
         status: Int = 200, error: URLError? = nil, failsBeforeHeaders: Bool = false,
         responseHeaders: [String: String] = ["Content-Type": "text/event-stream"]) {
        self.chunks = chunks; self.headerDelay = headerDelay; self.interval = interval
        self.status = status; self.error = error
        self.failsBeforeHeaders = failsBeforeHeaders; self.responseHeaders = responseHeaders
    }
    func didSend() { lock.lock(); sent += 1; lock.unlock() }
    func stop() { lock.lock(); stopped = true; lock.unlock() }
    func record(_ request: URLRequest) { lock.lock(); receivedRequest = request; lock.unlock() }
    var recordedRequest: URLRequest? { lock.lock(); defer { lock.unlock() }; return receivedRequest }
    var observations: (stopped: Bool, sent: Int) {
        lock.lock(); defer { lock.unlock() }; return (stopped, sent)
    }
}

private final class BoundaryURLProtocol: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var scripts: [URL: ResponseScript] = [:]
    private let queue = DispatchQueue(label: "response-boundary-fixture")
    private var stopped = false
    private var script: ResponseScript?
    static func register(_ script: ResponseScript) -> URL {
        let url = URL(string: "https://boundary.invalid/\(UUID().uuidString)")!
        lock.lock(); scripts[url] = script; lock.unlock(); return url
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); let selected = Self.scripts.removeValue(forKey: request.url!); Self.lock.unlock()
        guard let selected else { fatalError("unregistered offline request") }
        selected.record(request)
        queue.async {
            self.script = selected
            self.queue.asyncAfter(deadline: .now() + selected.headerDelay) {
                guard !self.stopped else { return }
                if selected.failsBeforeHeaders {
                    self.client?.urlProtocol(self, didFailWithError: selected.error ?? URLError(.cannotConnectToHost))
                    return
                }
                self.client?.urlProtocol(self, didReceive: HTTPURLResponse(url: self.request.url!,
                    statusCode: selected.status, httpVersion: "HTTP/1.1",
                    headerFields: selected.responseHeaders)!, cacheStoragePolicy: .notAllowed)
                self.deliver(0, selected)
            }
        }
    }
    private func deliver(_ index: Int, _ script: ResponseScript) {
        queue.asyncAfter(deadline: .now() + script.interval) {
            guard !self.stopped else { return }
            guard index < script.chunks.count else {
                if let error = script.error { self.client?.urlProtocol(self, didFailWithError: error) }
                else { self.client?.urlProtocolDidFinishLoading(self) }
                return
            }
            script.didSend()
            self.client?.urlProtocol(self, didLoad: script.chunks[index])
            self.deliver(index + 1, script)
        }
    }
    override func stopLoading() {
        queue.async { self.stopped = true; self.script?.stop() }
    }
}

final class BASChatCompletionsResponseBoundaryTests: XCTestCase {
    private func adapter(_ script: ResponseScript, cap: Int, headers: [String: String] = [:]) -> BASChatCompletionsOrganAdapter {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [BoundaryURLProtocol.self]
        config.httpAdditionalHeaders = ["X-Session-Policy": "preserved"]
        return BASChatCompletionsOrganAdapter(
            endpoint: .init(url: BoundaryURLProtocol.register(script), headers: headers, model: "offline"),
            providerID: "offline", providerName: "offline",
            urlSession: URLSession(configuration: config), maxResponseBytes: cap)
    }
    private func request(deadline: Date? = nil) -> BASOrganRequest {
        BASOrganRequest(requestID: "boundary", role: .scout, preset: .scout,
                        instruction: "test", deadline: deadline)
    }
    private func frame(_ text: String) -> Data {
        Data("data: {\"choices\":[{\"delta\":{\"content\":\"\(text)\"}}]}\n\n".utf8)
    }
    private func assertSize(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
        guard case BASOrganError.providerUnavailable(let reason) = error else {
            return XCTFail("unexpected \(error)", file: file, line: line)
        }
        XCTAssertTrue(reason.hasPrefix("response-too-large:"), reason, file: file, line: line)
    }

    // Break caught: buffering to EOF before enforcing the cap leaves the peer running.
    func testNonstreamStopsReceiptAtCapCrossing() async throws {
        let script = ResponseScript(Array(repeating: Data(repeating: 32, count: 16), count: 80))
        do { _ = try await adapter(script, cap: 32).draft(request()); XCTFail("expected size failure") }
        catch { assertSize(error) }
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(script.observations.stopped)
        XCTAssertLessThan(script.observations.sent, 10)
    }

    // Break caught: ignored SSE bytes bypassing decoded-content accounting.
    func testStreamingChargesIgnoredBytesBeforeEOF() async throws {
        let script = ResponseScript(Array(repeating: Data(": ignored\n\n".utf8), count: 80))
        do {
            for try await _ in adapter(script, cap: 32).streamDraft(request()) { XCTFail("no delta") }
            XCTFail("expected size failure")
        } catch { assertSize(error) }
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(script.observations.stopped)
        XCTAssertLessThan(script.observations.sent, 10)
    }

    func testUnterminatedSSELineCannotGrowPastRawCap() async throws {
        let script = ResponseScript([Data("data: ".utf8)]
            + Array(repeating: Data(repeating: 120, count: 16), count: 80))
        do {
            for try await _ in adapter(script, cap: 64).streamDraft(request()) {}
            XCTFail("expected size failure before line termination")
        } catch { assertSize(error) }
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(script.observations.stopped)
        XCTAssertLessThan(script.observations.sent, 10)
    }

    func testLegitimateExactCapAndFinalUnterminatedLine() async throws {
        let json = Data(#"{"choices":[{"message":{"content":"ok"}}]}"#.utf8)
        let draft = try await adapter(ResponseScript([json]), cap: json.count).draft(request())
        XCTAssertEqual(draft.body, "ok")
        let line = Data(#"data: {"choices":[{"delta":{"content":"好"}}]}"#.utf8)
        var values: [BASOrganDraftChunk] = []
        for try await chunk in adapter(ResponseScript([line]), cap: line.count).streamDraft(request()) { values.append(chunk) }
        XCTAssertEqual(values.map(\.bodyDelta), ["好"])
        XCTAssertEqual(values.map(\.cumulativeBody), ["好"])
    }

    func testDeadlineWhileAwaitingHeaders() async throws {
        let json = Data(#"{"choices":[{"message":{"content":"late"}}]}"#.utf8)
        let script = ResponseScript([json], headerDelay: 0.3)
        do { _ = try await adapter(script, cap: 1024).draft(request(deadline: Date().addingTimeInterval(0.05))); XCTFail("expected deadline") }
        catch { XCTAssertEqual(error as? BASOrganError, .deadlineExpired) }
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(script.observations.stopped)
        XCTAssertEqual(script.observations.sent, 0)
    }

    func testCapPlusOneRejectsBothEntrypoints() async throws {
        let json = Data(#"{"choices":[{"message":{"content":"ok"}}]}"#.utf8)
        do { _ = try await adapter(ResponseScript([json]), cap: json.count - 1).draft(request()); XCTFail("expected cap") }
        catch { assertSize(error) }
        let line = frame("ok")
        do {
            for try await _ in adapter(ResponseScript([line]), cap: line.count - 1).streamDraft(request()) {}
            XCTFail("expected cap")
        } catch { assertSize(error) }
    }

    func testPausedConsumerPreservesEveryTinyDeltaAndCumulativeBody() async throws {
        let frames = (0..<40).map { _ in frame("x") }
        let script = ResponseScript(frames, interval: 0.001)
        var iterator = adapter(script, cap: frames.reduce(0) { $0 + $1.count }).streamDraft(request()).makeAsyncIterator()
        let first = try await iterator.next()
        XCTAssertEqual(first?.bodyDelta, "x")
        try await Task.sleep(for: .milliseconds(150))
        for count in 2...40 {
            let chunk = try await iterator.next()
            XCTAssertEqual(chunk?.bodyDelta, "x")
            XCTAssertEqual(chunk?.cumulativeBody, String(repeating: "x", count: count))
        }
        let end = try await iterator.next()
        XCTAssertNil(end)
    }

    func testSplitUnicodeNewlinesAndIgnoredFrames() async throws {
        let text = ": comment\r\ndata: broken\r\ndata: {\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}\n"
            + "data: {\"choices\":[{\"delta\":{\"content\":\"\"}}]}\r\n"
            + String(decoding: frame("你🙂"), as: UTF8.self)
            + "data: {\"choices\":[{\"delta\":{\"content\":\"好\"}}]}"
        let bytes = Data(text.utf8)
        var chunks: [BASOrganDraftChunk] = []
        for try await chunk in adapter(ResponseScript(bytes.map { Data([$0]) }, interval: 0.0001), cap: bytes.count).streamDraft(request()) { chunks.append(chunk) }
        XCTAssertEqual(chunks.map(\.bodyDelta), ["你🙂", "好"])
        XCTAssertEqual(chunks.map(\.cumulativeBody), ["你🙂", "你🙂好"])
    }

    func testDeadlineDuringIdleStreamingReceipt() async throws {
        let script = ResponseScript([frame("late")], interval: 0.3)
        do {
            for try await _ in adapter(script, cap: 1024).streamDraft(request(deadline: Date().addingTimeInterval(0.05))) {}
            XCTFail("expected deadline")
        } catch { XCTAssertEqual(error as? BASOrganError, .deadlineExpired) }
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(script.observations.stopped)
        XCTAssertEqual(script.observations.sent, 0)
    }

    func testDeadlineSurvivesNetworkEOFWhileConsumerPaused() async throws {
        let script = ResponseScript([frame("a"), frame("b")])
        var iterator = adapter(script, cap: 1024).streamDraft(request(deadline: Date().addingTimeInterval(0.1))).makeAsyncIterator()
        let first = try await iterator.next()
        XCTAssertEqual(first?.bodyDelta, "a")
        try await Task.sleep(for: .milliseconds(180))
        XCTAssertEqual(script.observations.sent, 2)
        do { _ = try await iterator.next(); XCTFail("expected deadline instead of buffered b") }
        catch { XCTAssertEqual(error as? BASOrganError, .deadlineExpired) }
    }

    func testRawOverflowStopsReceiptWhileConsumerPaused() async throws {
        let script = ResponseScript([frame("a")] + Array(repeating: Data(": ignored\n\n".utf8), count: 80))
        var iterator = adapter(script, cap: 100).streamDraft(request()).makeAsyncIterator()
        let first = try await iterator.next()
        XCTAssertEqual(first?.bodyDelta, "a")
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertTrue(script.observations.stopped)
        XCTAssertLessThan(script.observations.sent, 15)
        do { _ = try await iterator.next(); XCTFail("expected cap") }
        catch { assertSize(error) }
    }

    func testDoneStopsOnlyOwnedTaskAndRemainsSuccessAfterDeadline() async throws {
        let script = ResponseScript([frame("a"), Data("data: [DONE]\n\n".utf8)]
            + Array(repeating: frame("unwanted"), count: 60))
        var iterator = adapter(script, cap: 1024).streamDraft(request(deadline: Date().addingTimeInterval(0.1))).makeAsyncIterator()
        let first = try await iterator.next()
        XCTAssertEqual(first?.bodyDelta, "a")
        let done = try await iterator.next()
        XCTAssertNil(done)
        try await Task.sleep(for: .milliseconds(150))
        let stillDone = try await iterator.next()
        XCTAssertNil(stillDone)
        XCTAssertTrue(script.observations.stopped)
        XCTAssertLessThan(script.observations.sent, 8)
    }

    func testBufferedValidPrefixPrecedesBodyTransportError() async throws {
        let script = ResponseScript([frame("a"), frame("b")], error: URLError(.networkConnectionLost))
        var iterator = adapter(script, cap: 1024).streamDraft(request()).makeAsyncIterator()
        let first = try await iterator.next()
        XCTAssertEqual(first?.bodyDelta, "a")
        try await Task.sleep(for: .milliseconds(50))
        let second = try await iterator.next()
        XCTAssertEqual(second?.bodyDelta, "b")
        do { _ = try await iterator.next(); XCTFail("expected transfer failure") }
        catch { XCTAssertEqual((error as? URLError)?.code, .networkConnectionLost) }
        do {
            _ = try await adapter(ResponseScript([], error: URLError(.networkConnectionLost)), cap: 1024).draft(request())
            XCTFail("expected mapped transfer failure")
        } catch BASOrganError.providerUnavailable(let reason) { XCTAssertTrue(reason.hasPrefix("transport:")) }
    }

    func testCancellationWakesPendingReadAndStopsReceipt() async throws {
        let script = ResponseScript([frame("late")], headerDelay: 0.3)
        let adapter = adapter(script, cap: 1024)
        let input = request()
        let pending = Task {
            for try await _ in adapter.streamDraft(input) {}
        }
        try await Task.sleep(for: .milliseconds(30))
        pending.cancel()
        do { try await pending.value; XCTFail("expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(script.observations.stopped)
        XCTAssertEqual(script.observations.sent, 0)
    }

    func testAbandonmentStopsReceiptWithoutCancellingInjectedSession() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [BoundaryURLProtocol.self]
        let session = URLSession(configuration: config)
        let script = ResponseScript(Array(repeating: frame("a"), count: 80))
        let adapter = BASChatCompletionsOrganAdapter(endpoint: .init(url: BoundaryURLProtocol.register(script), model: "offline"),
            providerID: "offline", providerName: "offline", urlSession: session, maxResponseBytes: 8192)
        func readOne() async throws {
            var iterator = adapter.streamDraft(request()).makeAsyncIterator()
            let first = try await iterator.next()
            XCTAssertEqual(first?.bodyDelta, "a")
        }
        try await readOne()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(script.observations.stopped)
        XCTAssertLessThan(script.observations.sent, 10)
        let other = ResponseScript([Data(#"{"choices":[{"message":{"content":"alive"}}]}"#.utf8)])
        let otherAdapter = BASChatCompletionsOrganAdapter(endpoint: .init(url: BoundaryURLProtocol.register(other), model: "offline"),
            providerID: "offline", providerName: "offline", urlSession: session)
        let draft = try await otherAdapter.draft(request())
        XCTAssertEqual(draft.body, "alive")
    }

    func testHTTPRejectionPrecedesBodyAndPreservesInjectedRequestPolicy() async throws {
        let script = ResponseScript(Array(repeating: frame("no"), count: 40), status: 429)
        do {
            for try await _ in adapter(script, cap: 1, headers: ["Authorization": "Bearer offline", "X-Custom": "kept"]).streamDraft(request()) {}
            XCTFail("expected HTTP rejection")
        } catch { XCTAssertEqual(error as? BASOrganError, .providerUnavailable(reason: "http-429")) }
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(script.observations.stopped)
        XCTAssertLessThan(script.observations.sent, 3)
        let sent = try XCTUnwrap(script.recordedRequest)
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Authorization"), "Bearer offline")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "X-Custom"), "kept")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "X-Session-Policy"), "preserved")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Accept"), "text/event-stream")
        XCTAssertEqual(sent.httpMethod, "POST")
    }

    func testStreamingStartupTransportFailureIsMapped() async throws {
        let script = ResponseScript([], error: URLError(.cannotConnectToHost), failsBeforeHeaders: true)
        do {
            for try await _ in adapter(script, cap: 1024).streamDraft(request()) {}
            XCTFail("expected startup error")
        } catch BASOrganError.providerUnavailable(let reason) { XCTAssertTrue(reason.hasPrefix("transport:")) }
    }

    func testContentLengthAloneDoesNotRejectWithinCapBody() async throws {
        let json = Data(#"{"choices":[{"message":{"content":"ok"}}]}"#.utf8)
        let script = ResponseScript([json], responseHeaders: ["Content-Length": "999999999"])
        let draft = try await adapter(script, cap: json.count).draft(request())
        XCTAssertEqual(draft.body, "ok")
    }

    func testNonstreamIdleDeadlineAndCancellation() async throws {
        let late = ResponseScript([Data("{}".utf8)], interval: 0.3)
        do { _ = try await adapter(late, cap: 1024).draft(request(deadline: Date().addingTimeInterval(0.05))); XCTFail("expected deadline") }
        catch { XCTAssertEqual(error as? BASOrganError, .deadlineExpired) }
        let canceled = ResponseScript([Data("{}".utf8)], headerDelay: 0.3)
        let adapter = adapter(canceled, cap: 1024)
        let input = request()
        let pending = Task { try await adapter.draft(input) }
        try await Task.sleep(for: .milliseconds(30))
        pending.cancel()
        do { _ = try await pending.value; XCTFail("expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(late.observations.stopped)
        XCTAssertTrue(canceled.observations.stopped)
        XCTAssertEqual(canceled.observations.sent, 0)
    }

    func testStreamingDeadlineBeforeFirstPullAndBeforeHeaders() async throws {
        let script = ResponseScript([frame("late")], headerDelay: 0.3)
        let stream = adapter(script, cap: 1024).streamDraft(request(deadline: Date().addingTimeInterval(0.05)))
        try await Task.sleep(for: .milliseconds(100))
        do {
            for try await _ in stream {}
            XCTFail("expected pre-registration deadline")
        } catch { XCTAssertEqual(error as? BASOrganError, .deadlineExpired) }
        XCTAssertTrue(script.observations.stopped)
        XCTAssertEqual(script.observations.sent, 0)
    }
}
