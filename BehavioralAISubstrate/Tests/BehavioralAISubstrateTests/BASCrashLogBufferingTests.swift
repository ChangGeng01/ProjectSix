import XCTest
import Foundation

/// device-recon id7 — the POSIX buffering premise behind the M1 crash-localization
/// fix (BASQwen35RdarProbe: setvbuf(stderr, _IONBF) + fputs to stderr so STEP lines
/// survive a hard crash where fully-buffered stdout does not). That premise is a
/// pure libc property that reproduces identically on macOS — proven here WITHOUT a
/// fork or a real crash: a hard crash sees exactly what has reached the file
/// descriptor, so reading the backing files BEFORE any flush is an exact stand-in.
final class BASCrashLogBufferingTests: XCTestCase {
#if os(macOS)

    func testUnbufferedWriteLandsImmediatelyFullyBufferedDoesNot() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("id7-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let bufferedPath = dir.appendingPathComponent("buffered.log").path
        let unbufferedPath = dir.appendingPathComponent("unbuffered.log").path

        guard let buffered = fopen(bufferedPath, "w"),
              let unbuffered = fopen(unbufferedPath, "w") else {
            return XCTFail("fopen failed")
        }
        // stdout on a non-TTY defaults to FULLY buffered; stderr in the fix is
        // forced UNBUFFERED via setvbuf(stderr, nil, _IONBF, 0).
        setvbuf(buffered, nil, _IOFBF, 1 << 16)
        setvbuf(unbuffered, nil, _IONBF, 0)

        fputs("STEP-BUFFERED\n", buffered)     // sits in the FILE* buffer
        fputs("STEP-UNBUFFERED\n", unbuffered)  // written to the fd immediately

        // A hard crash (SIGKILL / _exit) runs NO atexit flush — it sees exactly
        // what has reached the fd. Reading the files now models that instant.
        let bufferedNow = (try? String(contentsOfFile: bufferedPath, encoding: .utf8)) ?? ""
        let unbufferedNow = (try? String(contentsOfFile: unbufferedPath, encoding: .utf8)) ?? ""

        XCTAssertTrue(unbufferedNow.contains("STEP-UNBUFFERED"),
            "an unbuffered write reaches the fd immediately ⇒ the crash-localization "
            + "line survives a hard crash (why the fix uses setvbuf(stderr, _IONBF))")
        XCTAssertFalse(bufferedNow.contains("STEP-BUFFERED"),
            "a fully-buffered write stays in the FILE* buffer until flush ⇒ it is LOST "
            + "on a hard crash (why block-buffered stdout swallowed the STEP lines)")

        fclose(buffered)   // NOW the buffered marker flushes
        fclose(unbuffered)
        let afterFlush = (try? String(contentsOfFile: bufferedPath, encoding: .utf8)) ?? ""
        XCTAssertTrue(afterFlush.contains("STEP-BUFFERED"),
            "the buffered marker was real — it lands only after the (crash-skipped) flush")
    }
#endif
}
