// MARK: - BASJournalCLIIntegrationTests
//
// End-to-end verification of "The Ledger" (#20 first daily workload). Spawns the real
// BASJournalCLI binary against a THROWAWAY journal dir (QINAO_JOURNAL_DIR) and asserts the
// sovereignty loop: add → recall (paginated full-history read) → forget (tombstone +
// secure-deleted content) → recall-no-longer-returns-it. NOT tautological — it drives the
// live event-sourced memory + deletion-doctrine path the workload exists to fire.

#if os(macOS)
import XCTest
import Foundation

final class BASJournalCLIIntegrationTests: XCTestCase {

    private func cliBinaryURL() -> URL? {
        let candidates = [
            ".build/debug/BASJournalCLI",
            ".build/release/BASJournalCLI",
            ".build/arm64-apple-macosx/debug/BASJournalCLI",
            ".build/x86_64-apple-macosx/debug/BASJournalCLI",
        ]
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath
        for path in candidates {
            let url = URL(fileURLWithPath: cwd).appendingPathComponent(path)
            if fm.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private struct CLIResult { let stdout: String; let exit: Int32 }

    private func run(_ args: [String], journalDir: URL) throws -> CLIResult {
        guard let binary = cliBinaryURL() else {
            throw XCTSkip("BASJournalCLI binary not found — run `swift build` first.")
        }
        let p = Process()
        p.executableURL = binary
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["QINAO_JOURNAL_DIR"] = journalDir.path
        p.environment = env
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        try p.run()
        p.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return CLIResult(stdout: String(data: data, encoding: .utf8) ?? "", exit: p.terminationStatus)
    }

    func testSovereigntyLoopAddRecallForget() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        // First touch seeds 3 marathon threads.
        let seeded = try run(["count"], journalDir: dir)
        XCTAssertEqual(seeded.exit, 0)
        XCTAssertTrue(seeded.stdout.contains("3 entries"), "first run seeds 3: \(seeded.stdout)")

        // add a distinctive entry (a fresh process — proves cross-process persistence).
        let secret = "H14-pagination-fail-closed-\(Int.random(in: 1000...9999))"
        let added = try run(["add", secret], journalDir: dir)
        XCTAssertEqual(added.exit, 0)
        XCTAssertTrue(added.stdout.contains("logged"), added.stdout)

        // recall must return the entry's CONTENT across processes (content sidecar, since
        // the event log persists digest-only) — a filtered recall finds exactly it.
        let recalled = try run(["recall", "fail-closed"], journalDir: dir)
        XCTAssertTrue(recalled.stdout.contains(secret),
            "recall must return real content cross-process (got: \(recalled.stdout))")

        // Grab the id prefix, forget it, and prove it's gone from BOTH projection + content.
        let idPrefix = recalled.stdout.split(separator: "\n").first
            .map { String($0.prefix(8)) } ?? ""
        XCTAssertFalse(idPrefix.isEmpty)
        let forgot = try run(["forget", idPrefix], journalDir: dir)
        XCTAssertTrue(forgot.stdout.contains("verified gone"),
            "forget must verify the entry is gone (deletion doctrine): \(forgot.stdout)")

        let afterForget = try run(["recall", "fail-closed"], journalDir: dir)
        XCTAssertFalse(afterForget.stdout.contains(secret),
            "forgotten entry must NOT resurface in recall (H11 tombstone): \(afterForget.stdout)")

        // The secure-deleted content file must be physically gone from disk.
        let contentDir = dir.appendingPathComponent("content")
        let survivors = (try? FileManager.default.contentsOfDirectory(atPath: contentDir.path)) ?? []
        XCTAssertFalse(survivors.contains { $0.hasPrefix(idPrefix) },
            "forgotten entry's content file must be secure-deleted from disk")
    }
}
#endif
