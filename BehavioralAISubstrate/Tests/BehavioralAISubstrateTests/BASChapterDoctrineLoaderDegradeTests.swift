import XCTest
import Foundation
@testable import BASRuntimeCore

/// Thread-safe capture for the @Sendable failure hook.
private final class ErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Error?
    var error: Error? { lock.lock(); defer { lock.unlock() }; return stored }
    func set(_ e: Error) { lock.lock(); stored = e; lock.unlock() }
    func reset() { lock.lock(); stored = nil; lock.unlock() }
}

/// audit runtimecore-b MED-4 — the chapter-doctrine loader degrades, not crashes.
///
/// The loader hydrates NON-safety development-history metadata; a build that
/// fails to bundle its .sql resources must degrade to EMPTY (CI's frozen-hash
/// pins catch the packaging bug) + SURFACE the failure — not fatalError the whole
/// process (7 abort points). These drive the forced-failure path directly (the
/// non-memoized loader funcs, not the lazy property).
final class BASChapterDoctrineLoaderDegradeTests: XCTestCase {

    override func tearDown() {
        BASChapterDoctrineSQLLoader._forceLoadFailureForTesting = false
        BASChapterDoctrineSQLLoader._onLoadFailure = nil
        super.tearDown()
    }

    func testLoadFailureDegradesToEmptyAndSurfaces() {
        let box = ErrorBox()
        BASChapterDoctrineSQLLoader._onLoadFailure = { box.set($0) }
        BASChapterDoctrineSQLLoader._forceLoadFailureForTesting = true

        let chapters = BASChapterDoctrineSQLLoader.loadChapterDoctrineFromSQL()
        XCTAssertTrue(chapters.literals.isEmpty && chapters.phase2.isEmpty,
            "a load failure must DEGRADE to empty collections, not abort the process")
        XCTAssertNotNil(box.error, "the failure must be SURFACED (was a swallowed fatalError)")

        box.reset()
        let entropy = BASChapterDoctrineSQLLoader.loadEntropyChapterIndexFromSQL()
        XCTAssertTrue(entropy.radical.isEmpty && entropy.phase2.isEmpty && entropy.postSweep.isEmpty,
            "entropy index also degrades to empty")
        XCTAssertNotNil(box.error, "the entropy load failure surfaced too")
    }

    func testHealthyLoadStillProducesData() {
        BASChapterDoctrineSQLLoader._forceLoadFailureForTesting = false
        let chapters = BASChapterDoctrineSQLLoader.loadChapterDoctrineFromSQL()
        XCTAssertFalse(chapters.literals.isEmpty,
            "the correctly-bundled build still loads the doctrine (degrade didn't break the happy path)")
    }
}
