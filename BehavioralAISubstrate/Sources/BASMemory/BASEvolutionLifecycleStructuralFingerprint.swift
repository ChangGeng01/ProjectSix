import Foundation

/// M341 — typed structural fingerprint of the L13 self-evolution
/// lifecycle. Fills the **regression gate** leg of the v5 doctrine
/// triple (typed pin → measurement → regression gate) for the
/// `L13 self-evolution` candidate parked in
/// `docs/QINAO_MANIFESTO_V5_DOCTRINE.md` appendix.
///
/// ## Why this exists
///
/// `BASEvolutionLifecycleStage` (8 cases) + `BASEvolutionLifecycleAction`
/// (7 cases) + `BASEvolutionLifecyclePolicy.validTransitions(from:)`
/// together encode the canonical L13 state-machine. Any silent change
/// — adding a stage, removing an action, re-routing a transition —
/// would invalidate every prior audit ledger entry that refers to the
/// old shape.
///
/// Pre-M341 the only protection was that downstream tests would break
/// if a transition was deleted; an *additive* change (new stage / new
/// action / new edge) could land without flagging the doctrine impact.
///
/// M341 ships a typed structural fingerprint that pins:
///
///   1. The exact 8 stages and which are terminal vs active.
///   2. The exact 7 actions.
///   3. The full valid-transition table as a deterministic,
///      Codable-stable structure.
///   4. A SHA-256 hex hash of the fingerprint so any drift produces
///      a single grep-able value change.
///
/// `M341EvolutionLifecycleFingerprintTests` pins `current()` against
/// `canonical`. A future PR that touches the policy must either
/// preserve the canonical shape or update the canonical fingerprint
/// in the same PR — there is no silent path.
///
/// ## Doctrine role
///
/// This is **not** an enforcement gate for runtime callers — actual
/// state-machine traversal still runs through `applying(_:)`. The
/// fingerprint is a **doctrine drift detector** at the structural
/// level. It is the regression-gate leg of the v5 triple; together
/// with the typed pin (the enums themselves) and the measurement
/// (M333 `EvolutionLoopDemo` exercising every stage) it makes the
/// L13 self-evolution candidate doctrine-authoring-ready.
public struct BASEvolutionLifecycleStructuralFingerprint:
    Sendable, Equatable, Hashable, Codable
{

    // MARK: - Fields

    /// Sorted list of all stage raw values. Must equal
    /// `BASEvolutionLifecycleStage.allCases.map(\.rawValue).sorted()`.
    public let stageRawValues: [String]

    /// Subset of `stageRawValues` that are terminal.
    public let terminalStageRawValues: [String]

    /// Sorted list of all action raw values. Must equal
    /// `BASEvolutionLifecycleAction.allCases.map(\.rawValue).sorted()`.
    public let actionRawValues: [String]

    /// Full valid-transition table:
    ///   `from-stage-raw → action-raw → to-stage-raw`
    /// The outer dict has one key per stage (including terminal
    /// stages, which map to empty inner dicts so a deletion is
    /// detectable).
    public let transitionMatrix: [String: [String: String]]

    /// Hex SHA-256 of the canonical-encoded matrix. Encoded as
    /// `<stage>|<action>=<to>;...` sorted. A single character
    /// change in any transition flips the hash.
    public let matrixHash: String

    public init(
        stageRawValues: [String],
        terminalStageRawValues: [String],
        actionRawValues: [String],
        transitionMatrix: [String: [String: String]],
        matrixHash: String
    ) {
        self.stageRawValues = stageRawValues
        self.terminalStageRawValues = terminalStageRawValues
        self.actionRawValues = actionRawValues
        self.transitionMatrix = transitionMatrix
        self.matrixHash = matrixHash
    }

    // MARK: - Constructors

    /// Derive the fingerprint from the live runtime types. Run this
    /// in tests to compare against `.canonical`.
    public static func current()
        -> BASEvolutionLifecycleStructuralFingerprint
    {
        let stages = BASEvolutionLifecycleStage.allCases
            .map(\.rawValue)
            .sorted()
        let terminals = BASEvolutionLifecycleStage.allCases
            .filter(\.isTerminal)
            .map(\.rawValue)
            .sorted()
        let actions = BASEvolutionLifecycleAction.allCases
            .map(\.rawValue)
            .sorted()
        var matrix: [String: [String: String]] = [:]
        for stage in BASEvolutionLifecycleStage.allCases {
            let edges = BASEvolutionLifecyclePolicy
                .validTransitions(from: stage)
            var inner: [String: String] = [:]
            for (action, target) in edges {
                inner[action.rawValue] = target.rawValue
            }
            matrix[stage.rawValue] = inner
        }
        return BASEvolutionLifecycleStructuralFingerprint(
            stageRawValues: stages,
            terminalStageRawValues: terminals,
            actionRawValues: actions,
            transitionMatrix: matrix,
            matrixHash:
                Self.computeMatrixHash(matrix: matrix))
    }

    /// The doctrine-pinned canonical fingerprint as of M341.
    /// Updating this requires a doctrine PR (chapter 七十九 or
    /// later); any silent drift in the live runtime will break
    /// the M341 regression test.
    public static let canonical:
        BASEvolutionLifecycleStructuralFingerprint =
        BASEvolutionLifecycleStructuralFingerprint(
            stageRawValues: [
                "candidateRegistered",
                "promoted",
                "proposed",
                "rejected",
                "retracted",
                "shadowTrialing",
                "trialFinalized",
                "withdrawn",
            ],
            terminalStageRawValues: [
                "rejected", "retracted", "withdrawn",
            ],
            actionRawValues: [
                "fail",
                "finalizeTrial",
                "promote",
                "registerCandidate",
                "retract",
                "startShadowTrial",
                "withdraw",
            ],
            transitionMatrix: [
                "proposed": [
                    "registerCandidate": "candidateRegistered",
                    "withdraw": "withdrawn",
                ],
                "candidateRegistered": [
                    "startShadowTrial": "shadowTrialing",
                    "withdraw": "withdrawn",
                ],
                "shadowTrialing": [
                    "finalizeTrial": "trialFinalized",
                    "fail": "rejected",
                    "withdraw": "withdrawn",
                ],
                "trialFinalized": [
                    "promote": "promoted",
                    "fail": "rejected",
                    "withdraw": "withdrawn",
                ],
                "promoted": [
                    "retract": "retracted",
                ],
                "retracted": [:],
                "rejected": [:],
                "withdrawn": [:],
            ],
            matrixHash:
                "9e15d296c25c5b28da42eb5d5ca7d89bf768f407a49cbad21ed0b735eec114f5")

    // MARK: - Drift detection

    /// One human-readable diff between two fingerprints.
    public struct DriftReport: Sendable, Equatable, Codable {
        public let kind: String
        public let detail: String
        public init(kind: String, detail: String) {
            self.kind = kind
            self.detail = detail
        }
    }

    /// Compare a `live` fingerprint to a `pinned` one and return
    /// a sorted list of drift reports. Empty array means no drift.
    public static func detectDrift(
        live: BASEvolutionLifecycleStructuralFingerprint,
        pinned: BASEvolutionLifecycleStructuralFingerprint
    ) -> [DriftReport] {
        var reports: [DriftReport] = []
        if live.stageRawValues != pinned.stageRawValues {
            reports.append(DriftReport(
                kind: "stage-set-changed",
                detail: "live=\(live.stageRawValues) " +
                "pinned=\(pinned.stageRawValues)"))
        }
        if live.terminalStageRawValues
            != pinned.terminalStageRawValues
        {
            reports.append(DriftReport(
                kind: "terminal-set-changed",
                detail: "live=\(live.terminalStageRawValues) " +
                "pinned=\(pinned.terminalStageRawValues)"))
        }
        if live.actionRawValues != pinned.actionRawValues {
            reports.append(DriftReport(
                kind: "action-set-changed",
                detail: "live=\(live.actionRawValues) " +
                "pinned=\(pinned.actionRawValues)"))
        }
        if live.transitionMatrix != pinned.transitionMatrix {
            reports.append(DriftReport(
                kind: "transition-matrix-changed",
                detail: "live-hash=\(live.matrixHash) " +
                "pinned-hash=\(pinned.matrixHash)"))
        }
        if live.matrixHash != pinned.matrixHash {
            // Defensive — typically subsumed by transitionMatrix
            // diff, but a hash mismatch on equal matrices would
            // indicate the hash function itself drifted.
            if !reports.contains(where: {
                $0.kind == "transition-matrix-changed"
            }) {
                reports.append(DriftReport(
                    kind: "matrix-hash-only-changed",
                    detail: "live=\(live.matrixHash) " +
                    "pinned=\(pinned.matrixHash)"))
            }
        }
        return reports.sorted {
            ($0.kind, $0.detail) < ($1.kind, $1.detail)
        }
    }

    // MARK: - Hash computation

    /// Canonical encoding for hashing. Sorted by stage then action
    /// to be order-independent.
    public static func canonicalEncoding(
        matrix: [String: [String: String]]
    ) -> String {
        var lines: [String] = []
        for stage in matrix.keys.sorted() {
            let inner = matrix[stage] ?? [:]
            if inner.isEmpty {
                lines.append("\(stage)|<terminal>")
                continue
            }
            for action in inner.keys.sorted() {
                let target = inner[action] ?? "<missing>"
                lines.append("\(stage)|\(action)=\(target)")
            }
        }
        return lines.joined(separator: ";")
    }

    public static func computeMatrixHash(
        matrix: [String: [String: String]]
    ) -> String {
        let encoding = canonicalEncoding(matrix: matrix)
        return BASEvolutionLifecycleStructuralFingerprintHasher
            .sha256Hex(encoding: encoding)
    }
}

/// Internal SHA-256 helper. Avoids depending on CryptoKit at this
/// layer — uses a small pure-Swift implementation suitable for
/// short input (the canonical encoding is < 1 KB).
internal enum BASEvolutionLifecycleStructuralFingerprintHasher {

    static func sha256Hex(encoding: String) -> String {
        let bytes = Array(encoding.utf8)
        let digest = SHA256.hash(data: bytes)
        return digest
            .map { String(format: "%02x", $0) }
            .joined()
    }

    // Minimal SHA-256 implementation — no external dependencies.
    enum SHA256 {
        static let k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
            0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
            0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
            0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
            0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
            0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
            0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
            0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
            0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
        ]

        static func hash(data: [UInt8]) -> [UInt8] {
            // Pad
            var msg = data
            let originalLen = data.count
            msg.append(0x80)
            while msg.count % 64 != 56 {
                msg.append(0)
            }
            let bitLen = UInt64(originalLen) * 8
            for i in (0..<8).reversed() {
                msg.append(UInt8((bitLen >> (UInt64(i) * 8)) & 0xff))
            }

            var h: [UInt32] = [
                0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
            ]

            // Process each 512-bit chunk
            for chunkStart in stride(
                from: 0, to: msg.count, by: 64)
            {
                var w = [UInt32](repeating: 0, count: 64)
                for i in 0..<16 {
                    let base = chunkStart + i * 4
                    w[i] = (UInt32(msg[base]) << 24)
                        | (UInt32(msg[base + 1]) << 16)
                        | (UInt32(msg[base + 2]) << 8)
                        | UInt32(msg[base + 3])
                }
                for i in 16..<64 {
                    let s0 = rotr(w[i - 15], 7)
                        ^ rotr(w[i - 15], 18)
                        ^ (w[i - 15] >> 3)
                    let s1 = rotr(w[i - 2], 17)
                        ^ rotr(w[i - 2], 19)
                        ^ (w[i - 2] >> 10)
                    w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
                }
                var a = h[0]; var b = h[1]; var c = h[2]
                var d = h[3]; var e = h[4]; var f = h[5]
                var g = h[6]; var hh = h[7]

                for i in 0..<64 {
                    let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                    let ch = (e & f) ^ (~e & g)
                    let t1 = hh &+ s1 &+ ch &+ k[i] &+ w[i]
                    let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                    let mj = (a & b) ^ (a & c) ^ (b & c)
                    let t2 = s0 &+ mj
                    hh = g
                    g = f
                    f = e
                    e = d &+ t1
                    d = c
                    c = b
                    b = a
                    a = t1 &+ t2
                }
                h[0] = h[0] &+ a
                h[1] = h[1] &+ b
                h[2] = h[2] &+ c
                h[3] = h[3] &+ d
                h[4] = h[4] &+ e
                h[5] = h[5] &+ f
                h[6] = h[6] &+ g
                h[7] = h[7] &+ hh
            }
            var out: [UInt8] = []
            for word in h {
                out.append(UInt8((word >> 24) & 0xff))
                out.append(UInt8((word >> 16) & 0xff))
                out.append(UInt8((word >> 8) & 0xff))
                out.append(UInt8(word & 0xff))
            }
            return out
        }

        static func rotr(
            _ x: UInt32, _ n: UInt32
        ) -> UInt32 {
            (x >> n) | (x << (32 - n))
        }
    }
}
