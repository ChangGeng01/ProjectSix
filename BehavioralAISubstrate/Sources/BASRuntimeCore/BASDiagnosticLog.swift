import Foundation
import os

/// Library-internal diagnostic logging (2026-07-11, old-audit substrate-residuals gate + the
/// operator's decision-B library ratification). A substrate LIBRARY must NOT unconditionally
/// `print()` to the host's stdout — decode-lane fail-close warnings, 📊 telemetry, and
/// invariant-violation notes belong in the unified log where the HOST controls verbosity
/// (visible via Console / `log stream`, never spamming an embedding app's stdout).
///
/// This is the routing target for the ~29 production diagnostics the substrate-residuals gate
/// flagged. DeviceTestApp probes keep their own print()/NSLog (that IS their output surface, in
/// the app target, not the library).
public enum BASDiagnosticLog {
    private static let logger = Logger(subsystem: "com.behavioralaisubstrate", category: "diagnostics")

    /// Emit a library diagnostic to the unified log. `@autoclosure` so string interpolation is
    /// only paid when the message is actually recorded.
    public static func emit(_ message: @autoclosure () -> String) {
        let text = message()
        logger.log("\(text, privacy: .public)")
    }
}
