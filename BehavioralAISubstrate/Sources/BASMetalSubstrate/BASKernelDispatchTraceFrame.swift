// MARK: - BASKernelDispatchTraceFrame
// chapter 四百八十一 / M1302 — first REAL
// BASFrameEnvelope<Body> typealias migration in the
// substrate。 6th total generic-primitive adoption。
//
// Frame envelopes carry a typed header (schema version
// + correlation ID + producer + emission timestamp) +
// a typed body。 BASKernelDispatchTraceFrame wraps a
// kernel invocation summary in an envelope suitable
// for event-log persistence + cross-session replay。

import Foundation
import BASRuntimeCore

/// FIRST real `BASFrameEnvelope<Body>` typealias
/// migration in the substrate。 Wraps a kernel
/// invocation summary in a typed frame envelope。
public typealias BASKernelDispatchTraceFrame =
    BASFrameEnvelope<BASKernelInvocationResultBody>

extension BASFrameEnvelope
    where Body == BASKernelInvocationResultBody
{

    /// Build a typed dispatch trace frame from a kernel
    /// invocation result + correlation ID + producer
    /// identity。 Schema version pinned to "1.0.0"。
    public static func dispatchTrace(
        from result: BASKernelInvocationResult,
        correlationID: String,
        producer: String = "host.kernel-dispatch",
        emittedAtMs: Int64
    ) -> BASKernelDispatchTraceFrame {
        let header = BASFrameEnvelopeHeader(
            schemaVersion: "1.0.0",
            correlationID: correlationID,
            producer: producer,
            emittedAtMs: emittedAtMs)
        return BASKernelDispatchTraceFrame(
            header: header,
            body: result.body)
    }
}
