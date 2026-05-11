// MARK: - BASNeuralOpCard
// chapter 四百八十一 / M1301 — first REAL BASCard<Kind,Body>
// typealias migration in the substrate。
//
// 5th total generic-primitive adoption (after 3 BASBundle
// + 1 BASResult)。 Demonstrates the BASCard<Kind,Body>
// generic carries production payload。
//
// `BASNeuralOpCard = BASCard<BASNeuralOp,
// BASKernelInvocationResultBody>` — a card with the
// neural op as the typed kind discriminator + the last
// invocation summary as the typed body + a short
// headline + presentation hint。 Suitable for kernel-
// dispatch dashboards + audit emission consumers that
// want at-a-glance op summaries。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed kind + body
//   - chapter 二百一一 — single source-of-truth
//   - chapter 三百九二 — Codable + replay-determinism
//   - chapter 四百二十九 — BASCard<Kind,Body> finally
//     adopted in production
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASRuntimeCore

/// FIRST real `BASCard<Kind, Body>` typealias migration
/// in the substrate。 Carries a neural-op kind +
/// invocation-result body + headline + presentation
/// hint。 Useful for kernel-dispatch dashboards + audit
/// surfaces。
public typealias BASNeuralOpCard = BASCard<
    BASNeuralOp,
    BASKernelInvocationResultBody>

// MARK: - Convenience factory

extension BASCard
    where Kind == BASNeuralOp,
          Body == BASKernelInvocationResultBody
{

    /// Build a typed op card from a kernel invocation
    /// result + presentation preference。 Headline
    /// formats as "<op> · <µs>µs"。 Default presentation
    /// "compact-kernel-card"。
    public static func compactKernelCard(
        from result: BASKernelInvocationResult,
        presentation: String = "compact-kernel-card"
    ) -> BASNeuralOpCard {
        let microseconds = Int(
            result.executionMicroseconds.rounded())
        let headline = "\(result.body.kernelKey.operation.rawValue)" +
            " · \(microseconds)µs"
        return BASNeuralOpCard(
            kind: result.body.kernelKey.operation,
            body: result.body,
            headline: headline,
            presentation: presentation)
    }
}
