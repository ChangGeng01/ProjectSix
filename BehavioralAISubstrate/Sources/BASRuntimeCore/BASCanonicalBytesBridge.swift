// MARK: - BASCanonicalBytesBridge — 全面进化 T2.1a
//
// Swift bridge for the bas-canonical-bytes crate's 1.2.0 INJECTIVE
// length-prefixed assembler (`bas_canonical_bytes_assemble_v1_2`,
// crate ABI v2)。 Mirrors the Swift incumbent
// `basSovereignAuditCanonicalBytes` (BASSovereign,1.2.0 branch)
// byte-for-byte — pinned by golden-vector + seeded-random parity
// tests (`BASCanonicalBytesRustParityTests`)。
//
// ## ADR-014 OPT-IN preserved (banned-in-spine until flipped)
//
// This bridge is PASSTHROUGH-only:NO production caller is changed。
// The audit ledger keeps signing via the Swift incumbent。 This
// surface banks the cross-language parity evidence required before
// any future Rust audit-ledger lane could even be considered (and
// such a flip would additionally require its own 5-axis gate +
// human-read verdict — 门从不自动晋升)。
//
// ## Marshalling design
//
// Rust takes raw (ptr,len) byte-slice pairs + three parallel
// (ptrs,lens,count) array triplets。 Swift `String.withCString`
// nesting is impractical at 13 fields,so an Arena copies every
// UTF-8 buffer into allocated memory that outlives the single FFI
// call,then deallocates。 Two-pass:size query (null out) →
// allocate → fill。 The assembler is pure;both passes see the
// same inputs and MUST agree (asserted)。

import Foundation

#if os(iOS) || os(macOS)

@_silgen_name("bas_canonical_bytes_abi_version")
private func _bas_canonical_bytes_abi_version() -> Int32

@_silgen_name("bas_canonical_bytes_assemble_v1_2")
private func _bas_canonical_bytes_assemble_v1_2(
    _ schemaVersion: UnsafePointer<UInt8>?, _ schemaVersionLen: Int,
    _ auditID: UnsafePointer<UInt8>?, _ auditIDLen: Int,
    _ sessionID: UnsafePointer<UInt8>?, _ sessionIDLen: Int,
    _ turnID: UnsafePointer<UInt8>?, _ turnIDLen: Int,
    _ verdictRef: UnsafePointer<UInt8>?, _ verdictRefLen: Int,
    _ ruleIDsPtrs: UnsafePointer<UnsafePointer<UInt8>?>?,
    _ ruleIDsLens: UnsafePointer<Int>?, _ ruleIDsCount: Int,
    _ signalRefsPtrs: UnsafePointer<UnsafePointer<UInt8>?>?,
    _ signalRefsLens: UnsafePointer<Int>?, _ signalRefsCount: Int,
    _ actionRefsPtrs: UnsafePointer<UnsafePointer<UInt8>?>?,
    _ actionRefsLens: UnsafePointer<Int>?, _ actionRefsCount: Int,
    _ snapshotRef: UnsafePointer<UInt8>?, _ snapshotRefLen: Int,
    _ actor: UnsafePointer<UInt8>?, _ actorLen: Int,
    _ appendedAtMs: Int64,
    _ priorHash: UnsafePointer<UInt8>?, _ priorHashLen: Int,
    _ signingNamespace: UnsafePointer<UInt8>?, _ signingNamespaceLen: Int,
    _ outBuf: UnsafeMutablePointer<UInt8>?, _ outCap: Int
) -> Int

/// Typed Swift wrapper for the bas-canonical-bytes 1.2.0 injective
/// assembler。 Pure pass-through;no production path consumes this
/// (parity tests + ABI registry only,until a gate says otherwise)。
public enum BASCanonicalBytesBridge {

    /// Pinned crate ABI version。 Mismatch with `liveAbiVersion()`
    /// ⇒ rebuild XCFramework OR roll Swift back。
    ///
    /// History:
    ///   - 1 = chapter 七百三 initial (legacy delimiter-join
    ///         assembler,abi_version symbol only)
    ///   - 2 = 全面进化 T2.1a (+`bas_canonical_bytes_assemble_v1_2`,
    ///         the 1.2.0 injective length-prefixed form)
    public static let abiVersion: Int32 = 2

    /// Read the ABI version actually compiled into the linked
    /// Rust staticlib。 Tests assert `abiVersion == liveAbiVersion()`。
    public static func liveAbiVersion() -> Int32 {
        return _bas_canonical_bytes_abi_version()
    }

    /// Owns C-side copies of every input byte buffer for the
    /// duration of ONE FFI call。 `release()` MUST run after the
    /// call (callers use `defer`)。 Copying (not borrowing) keeps
    /// the pointer lifetimes trivially correct across 13 fields +
    /// 3 dynamic arrays — this surface is test/evidence-only,so
    /// the extra copy is irrelevant to any hot path。
    private struct Arena {
        private var byteBuffers: [UnsafeMutableBufferPointer<UInt8>] = []
        private var ptrArrays: [UnsafeMutableBufferPointer<UnsafePointer<UInt8>?>] = []
        private var lenArrays: [UnsafeMutableBufferPointer<Int>] = []

        mutating func intern(_ s: String) -> (ptr: UnsafePointer<UInt8>?, len: Int) {
            let bytes = Array(s.utf8)
            guard !bytes.isEmpty else { return (nil, 0) }
            let buf = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: bytes.count)
            _ = buf.initialize(from: bytes)
            byteBuffers.append(buf)
            return (UnsafePointer(buf.baseAddress), bytes.count)
        }

        mutating func internArray(_ strings: [String]) -> (
            ptrs: UnsafePointer<UnsafePointer<UInt8>?>?,
            lens: UnsafePointer<Int>?,
            count: Int
        ) {
            guard !strings.isEmpty else { return (nil, nil, 0) }
            let ptrsBuf = UnsafeMutableBufferPointer<UnsafePointer<UInt8>?>
                .allocate(capacity: strings.count)
            let lensBuf = UnsafeMutableBufferPointer<Int>
                .allocate(capacity: strings.count)
            for (i, s) in strings.enumerated() {
                let interned = intern(s)
                ptrsBuf[i] = interned.ptr
                lensBuf[i] = interned.len
            }
            ptrArrays.append(ptrsBuf)
            lenArrays.append(lensBuf)
            return (
                UnsafePointer(ptrsBuf.baseAddress),
                UnsafePointer(lensBuf.baseAddress),
                strings.count)
        }

        func release() {
            for b in byteBuffers { b.deallocate() }
            for p in ptrArrays { p.deallocate() }
            for l in lenArrays { l.deallocate() }
        }
    }

    /// Assemble the 1.2.0 injective canonical bytes via the Rust
    /// kernel。 Field-for-field mirror of the Swift incumbent's
    /// 1.2.0 branch:`actor` is the enum rawValue;`appendedAtMs`
    /// is `Int64(entry.appendedAt.timeIntervalSince1970 * 1000)`
    /// truncated exactly as Swift's `Int(...)` does。
    ///
    /// Returns nil only if the two FFI passes disagree (impossible
    /// for the pure assembler unless the bridge or binary is
    /// broken — parity tests assert non-nil)。
    public static func assembleV1_2(
        schemaVersion: String,
        auditID: String,
        sessionID: String,
        turnID: String,
        verdictRef: String,
        ruleIDs: [String],
        signalRefs: [String],
        actionRefs: [String],
        snapshotRef: String,
        actor: String,
        appendedAtMs: Int64,
        priorHash: String,
        signingNamespace: String
    ) -> Data? {
        var arena = Arena()
        defer { arena.release() }
        let sv = arena.intern(schemaVersion)
        let aid = arena.intern(auditID)
        let sid = arena.intern(sessionID)
        let tid = arena.intern(turnID)
        let vref = arena.intern(verdictRef)
        let rules = arena.internArray(ruleIDs)
        let signals = arena.internArray(signalRefs)
        let actions = arena.internArray(actionRefs)
        let snap = arena.intern(snapshotRef)
        let act = arena.intern(actor)
        let prior = arena.intern(priorHash)
        let ns = arena.intern(signingNamespace)

        func call(_ out: UnsafeMutablePointer<UInt8>?, _ cap: Int) -> Int {
            return _bas_canonical_bytes_assemble_v1_2(
                sv.ptr, sv.len,
                aid.ptr, aid.len,
                sid.ptr, sid.len,
                tid.ptr, tid.len,
                vref.ptr, vref.len,
                rules.ptrs, rules.lens, rules.count,
                signals.ptrs, signals.lens, signals.count,
                actions.ptrs, actions.lens, actions.count,
                snap.ptr, snap.len,
                act.ptr, act.len,
                appendedAtMs,
                prior.ptr, prior.len,
                ns.ptr, ns.len,
                out, cap)
        }

        // Pass 1:pure size query (null out buffer)。 The 1.2.0
        // form always emits ≥ one length prefix per part,so a
        // non-positive answer means the linked binary is broken。
        let needed = call(nil, 0)
        guard needed > 0 else { return nil }
        // Pass 2:allocate + fill。 Same pure inputs ⇒ same length。
        var out = [UInt8](repeating: 0, count: needed)
        let written = out.withUnsafeMutableBufferPointer { ob in
            call(ob.baseAddress, ob.count)
        }
        guard written == needed else { return nil }
        return Data(out)
    }
}

#endif  // os(iOS) || os(macOS)
