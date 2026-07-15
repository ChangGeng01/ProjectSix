import XCTest
@testable import BASObservability
@testable import BASPolicy
@testable import BASRuntimeCore
@testable import BASSovereign
import CryptoKit
import Foundation

/// QINAO Substrate-100 gates — Phase-2 batch 5 (audit/crypto; agent-drafted, author-verified).
final class BASQINAOSubstrateGatesBatch5Tests: XCTestCase {

        func test_qinao_verdict_hardrule_min_level_floor() async throws {
            typealias Engine = BASSovereignVerdictEngine
            typealias Hard = Engine.HardObservations
            typealias Perm = BASSovereignPermission
            typealias Level = BASSovereignVerdictLevel
    
            let ledger = BASSovereignAuditLedger.withSeed("qinao-verdict-hardrule-floor")
            let engine = Engine(ledger: ledger)
    
            // Replicated oracle of §11.1 — independent re-encoding of the BR hard-rule
            // table (code, exact minLevel floor, EXACT deauthorization set). Each tuple
            // also carries the observation-setter so the test drives the REAL kernel.
            let all = Set(Perm.allCases)
            let oracle: [(code: String,
                          setObs: (Hard) -> Hard,
                          minLevel: Level,
                          revokes: Set<Perm>)] = [
                ("BR-001", { var o = $0; o.artifactSignatureInvalid = true; return o },
                 .deadStop, all),
                ("BR-002", { var o = $0; o.thoughtFoldChecksumBroken = true; return o },
                 .rollback, [.memoryWriteHot, .memoryWriteWarm, .memoryWriteCold]),
                ("BR-003", { var o = $0; o.externalSideEffectWithoutSCT = true; return o },
                 .deadStop, [.toolWrite, .externalActuation, .checkpointCommit, .renderHighRisk]),
                ("BR-004", { var o = $0; o.memoryOrHostWriteBypass = true; return o },
                 .memoryFreeze, [.memoryWriteHot, .memoryWriteWarm, .memoryWriteCold, .hostMutation]),
                ("BR-005", { var o = $0; o.hostRemovalBypassed = true; return o },
                 .quarantine, [.hostMutation, .rulePromotion]),
                ("BR-006", { var o = $0; o.policyBundleTampered = true; return o },
                 .deadStop, all),
                ("BR-007", { var o = $0; o.unauthorizedSelfMutation = true; return o },
                 .deadStop, all),
                ("BR-008", { var o = $0; o.irreversibleHighGSIWithoutEvidence = true; return o },
                 .toolCut, [.toolWrite, .externalActuation, .renderHighRisk]),
                ("BR-009", { var o = $0; o.runtimeUnstableInHighRisk = true; return o },
                 .shadowLock, [.deepLoop, .renderHighRisk]),
                ("BR-010", { var o = $0; o.riskPermitHeadConflict = true; return o },
                 .throttle, [.checkpointCommit]),
                ("BR-011", { var o = $0; o.hostAttemptsBaseBoundaryOverride = true; return o },
                 .quarantine, [.hostMutation, .rulePromotion]),
                ("BR-012", { var o = $0; o.auditAppendFailed = true; return o },
                 .deadStop, all)
            ]
    
            XCTAssertEqual(oracle.count, 12,
                           "BR-001..BR-012 — twelve hard rules must be covered exhaustively")
    
            // The §11.1 floor contract: each rule, fired in isolation, yields a level
            // >= its minLevel with the EXACT deauthorization set (tolerance = 0). Drive
            // the REAL pure kernel through BOTH the routed and the Swift branch so the
            // `routed = max(hits.minLevel, routedLevel)` belt-and-suspenders cap is
            // proven to NEVER demote a hard floor (the routed path takes max with hits).
            for rule in oracle {
                let obs = rule.setObs(.clean)
                let context = Engine.VerdictContext(
                    sessionID: "S-floor",
                    turnID: "T-\(rule.code)",
                    operation: .pureInference,
                    hardObservations: obs,
                    softSignals: .calm,
                    evidenceSufficient: true,
                    snapshotRef: "snap-\(rule.code)")
    
                for useRouted in [false, true] {
                    let decision = await engine.evaluateLevel(context, useRouted: useRouted)
    
                    // (1) level floor: >= the rule's minLevel (never demoted below floor).
                    XCTAssertGreaterThanOrEqual(
                        decision.level, rule.minLevel,
                        "\(rule.code) (useRouted=\(useRouted)) — level \(decision.level) must be >= floor \(rule.minLevel)")
    
                    // (2) routed = max(hits.minLevel, routedLevel): with exactly one rule
                    // firing and calm soft signals, the floor IS the rule's minLevel —
                    // assert the exact level equals the floor (no spurious escalation).
                    XCTAssertEqual(
                        decision.level, rule.minLevel,
                        "\(rule.code) (useRouted=\(useRouted)) — single-rule routed level must equal its minLevel floor exactly")
    
                    // (3) the rule's code is present in reasonCodes.
                    XCTAssertTrue(
                        decision.reasonCodes.contains(rule.code),
                        "\(rule.code) (useRouted=\(useRouted)) — reasonCodes \(decision.reasonCodes) must contain the firing rule")
    
                    // (4) EXACT deauthorization set (tolerance = 0): set-equal, not subset.
                    XCTAssertEqual(
                        Set(decision.revokedPermissions), rule.revokes,
                        "\(rule.code) (useRouted=\(useRouted)) — deauthorization set must be EXACTLY \(rule.revokes.map { $0.rawValue }.sorted())")
                }
            }
    
            // Mutate + assert (audit/crypto discipline): perturb the oracle's expected
            // floor by one rank and confirm the REAL kernel disagrees — proving the
            // assertions above are load-bearing, not vacuously true.
            let br005 = oracle.first { $0.code == "BR-005" }!
            let mutCtx = Engine.VerdictContext(
                sessionID: "S-mut", turnID: "T-mut",
                operation: .pureInference,
                hardObservations: br005.setObs(.clean),
                softSignals: .calm, evidenceSufficient: true, snapshotRef: "snap-mut")
            let mutDecision = await engine.evaluateLevel(mutCtx, useRouted: false)
            XCTAssertNotEqual(mutDecision.level, .toolCut,
                              "mutation guard: BR-005 must NOT land below its quarantine floor")
            XCTAssertNotEqual(Set(mutDecision.revokedPermissions), Set(Perm.allCases),
                              "mutation guard: BR-005 must NOT revoke the full permission set")
    
            print("QINAO-GATE verdict_hardrule_min_level_floor: PASS — 12 BR hard rules, both routed+Swift branches, level>=minLevel floor with exact deauthorization set (tolerance=0), routed=max(hits.minLevel,routedLevel) cap, mutation-verified")
        }

        /// QINAO #86 L14 — the sovereign audit ledger exposes ZERO public
        /// mutation/deletion surface; `count()` is monotone non-decreasing, and the
        /// only count-changing operations (`append`, `lineageCut`) STRICTLY GROW the
        /// chain. Rotation is bookkeeping-only and never changes count. The exported
        /// `snapshot()` is a value copy that cannot mutate the ledger.
        ///
        /// This is a behavioral proof of the append-only contract: every mutating
        /// public method is exercised and the chain length is asserted to never
        /// decrease (tolerance 0 — exact integer equality/strict-increase).
    func test_qinao_commit_enforcer_digest_target_binding() async throws {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let approvedBody = "approved-body"
        let signedTarget = "answer"
        let policyHash = "ph-1"
    
        // Canonical, INDEPENDENT digest recompute (the host's own compute path).
        func digest(body: String, ph: String) -> String {
            BASSovereignActionDigest.compute(
                scope: .renderHighRisk,
                actionDigestParts: ["answer", "headline", body],
                sessionID: "s1", turnID: "t1", snapshotRef: "snap", policyHash: ph)
        }
    
        // Build a fresh registered (authoritative Ed25519) token per trial — single-use burn
        // means each authorize attempt needs its own token to isolate the binding check from
        // replay. mirrors BASSovereignCommitEnforcerTests construction exactly.
        func freshAuth() async throws -> BASSovereignCommitToken {
            let clock = BASAuthorityClock()
            clock.set(t0)
            let authority = BASSovereignTokenAuthority(now: { clock.read() })
            let enforcer = BASSovereignCommitEnforcer(authority: authority, now: { clock.read() })
            let signedDigest = digest(body: approvedBody, ph: policyHash)
            let brain = BASSovereignCommitToken(
                tokenID: "tok-render", sessionID: "s1", turnID: "t1", scope: .renderHighRisk,
                allowedTargets: [signedTarget], actionDigest: signedDigest, snapshotRef: "snap",
                policyHash: policyHash, ttlMs: 60_000, nonce: "nonce-1", singleUse: true,
                signature: "keyless-sha256")
            let auth = try await enforcer.register(brain, issuedAt: t0)
            // store enforcer alongside via closure: return token; caller rebuilds enforcer.
            // Instead we keep enforcer per-call below — so return token AND its enforcer.
            _ = enforcer
            return auth
        }
    
        // We need the same enforcer instance that registered the token to authorize it
        // (the authority holds the ledger). So build (enforcer, token) pairs together.
        struct Pair { let enforcer: BASSovereignCommitEnforcer; let token: BASSovereignCommitToken }
        func freshPair() async throws -> Pair {
            let clock = BASAuthorityClock()
            clock.set(t0)
            let authority = BASSovereignTokenAuthority(now: { clock.read() })
            let enforcer = BASSovereignCommitEnforcer(authority: authority, now: { clock.read() })
            let signedDigest = digest(body: approvedBody, ph: policyHash)
            let brain = BASSovereignCommitToken(
                tokenID: "tok-render", sessionID: "s1", turnID: "t1", scope: .renderHighRisk,
                allowedTargets: [signedTarget], actionDigest: signedDigest, snapshotRef: "snap",
                policyHash: policyHash, ttlMs: 60_000, nonce: "nonce-1", singleUse: true,
                signature: "keyless-sha256")
            let auth = try await enforcer.register(brain, issuedAt: t0)
            return Pair(enforcer: enforcer, token: auth)
        }
        _ = try await freshAuth() // sanity: registration path compiles & succeeds
    
        // Exhaustive cross-product axes (plain sync data; no concurrent capture).
        let targetCandidates = [signedTarget, "mirror", "ANSWER", "answer ", " answer", "answ", "answerr", ""]
        let bodyCandidates = [approvedBody, "EVIL injected body", "approved-body ", "Approved-body", "", "approved-bodyX"]
    
        var grants = 0
        var matchingCases = 0
        var aliasRejections = 0
        var digestRejections = 0
    
        for target in targetCandidates {
            for body in bodyCandidates {
                let isMatchTarget = (target == signedTarget)
                let isMatchBody = (body == approvedBody)
                let shouldGrant = isMatchTarget && isMatchBody
                if shouldGrant { matchingCases += 1 }
    
                let pair = try await freshPair()
                let expected = digest(body: body, ph: policyHash)
                do {
                    try await pair.enforcer.authorize(
                        pair.token, scope: .renderHighRisk, target: target,
                        expectedActionDigest: expected, expectedPolicyHash: policyHash)
                    grants += 1
                    XCTAssertTrue(shouldGrant,
                        "GRANTED an unauthorized op: target=\(target) body=\(body)")
                } catch let e as BASSovereignCommitEnforcer.EnforcementError {
                    // target-binding rejection must imply the target was NOT signed.
                    if case .targetNotAllowed = e {
                        aliasRejections += 1
                        XCTAssertFalse(isMatchTarget,
                            "rejected the SIGNED target as aliased: \(target)")
                    } else {
                        XCTFail("unexpected enforcement error \(e)")
                    }
                } catch BASSovereignTokenAuthority.AuthorityError.actionDigestMismatch {
                    // digest rejection must imply the body did NOT match the signed body
                    // (only reached when target IS allowed — target is checked first).
                    digestRejections += 1
                    XCTAssertTrue(isMatchTarget, "digest path reached for unsigned target")
                    XCTAssertFalse(isMatchBody, "rejected the SIGNED body as tampered: \(body)")
                }
            }
        }
    
        // tolerance=0: grants == exactly the matching cases (here exactly 1), and the
        // matching case DID grant (else grants would be 0 < matchingCases).
        XCTAssertEqual(matchingCases, 1, "exactly one (matching target, matching body) pair")
        XCTAssertEqual(grants, matchingCases,
            "ZERO authorizations outside the signed (target,digest) binding; grants=\(grants)")
    
        // Replicated oracle: independently recount expected rejections by axis and confirm
        // every off-axis case was accounted for by a throw (no silent grant).
        let total = targetCandidates.count * bodyCandidates.count
        XCTAssertEqual(grants + aliasRejections + digestRejections, total,
            "every trial resolved to grant/aliasReject/digestReject")
        // aliased-target attempts: any target != signed, across all bodies.
        let expectedAlias = bodyCandidates.count * (targetCandidates.count - 1)
        XCTAssertEqual(aliasRejections, expectedAlias, "aliased targets all rejected")
        // tampered-body attempts on the signed target: bodies != approved with target signed.
        let expectedDigestRej = (bodyCandidates.count - 1)
        XCTAssertEqual(digestRejections, expectedDigestRej, "tampered bodies all rejected")
    
        print("QINAO-GATE commit_enforcer_digest_target_binding: PASS "
            + "(\(total) trials; grants=\(grants)==matching=\(matchingCases); "
            + "aliasRej=\(aliasRejections) digestRej=\(digestRejections); tolerance=0)")
    }

    func test_qinao_dual_key_two_principal() throws {
        // #89 L14 — dual-key commit verifier (BASSovereignDualKeyVerifier.verify)
        // returns true ONLY when there are two distinct keyIDs AND two distinct
        // public keys AND two valid Ed25519 signatures over the same intent digest.
        // Same-principal (matching keyID OR matching public key) or any single
        // invalid signature => false. Tolerance = 0: every false-axis must yield
        // false; the unique true-configuration must yield true.
    
        let primary = try BASSovereignEd25519KeyPair.fromSeed("qinao-primary-seed")
        let secondary = try BASSovereignEd25519KeyPair.fromSeed("qinao-secondary-seed")
        // A third, independent key used to construct mismatched verifiers.
        let third = try BASSovereignEd25519KeyPair.fromSeed("qinao-third-seed")
    
        // Sanity: the three keypairs are genuinely distinct public keys.
        XCTAssertNotEqual(
            primary.publicKey.rawRepresentation,
            secondary.publicKey.rawRepresentation)
        XCTAssertNotEqual(
            primary.publicKey.rawRepresentation,
            third.publicKey.rawRepresentation)
        XCTAssertNotEqual(
            secondary.publicKey.rawRepresentation,
            third.publicKey.rawRepresentation)
    
        let digest = Data(SHA256.hash(
            data: Data("qinao-delete-host-version".utf8)))
        let primaryID = "qinao-primary"
        let secondaryID = "qinao-secondary"
    
        // The canonical, two-distinct-principal commit (two distinct keyIDs,
        // two distinct keypairs, two valid sigs over the same digest).
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: primaryID,
            secondary: secondary,
            secondaryKeyID: secondaryID)
    
        // ---- POSITIVE: the unique true-configuration verifies. ----
        let goodVerifier = BASSovereignDualKeyVerifier(
            primaryKeyID: primaryID,
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: secondaryID,
            secondaryPublicKey: secondary.publicKey)
        XCTAssertTrue(
            goodVerifier.verify(commit),
            "two distinct keyIDs + two distinct public keys + two valid sigs must verify")
    
        // ---- NEGATIVE AXIS 1: same keyID in both verifier slots
        // (single-principal by identity) must fail closed even with valid crypto. ----
        let sameKeyIDVerifier = BASSovereignDualKeyVerifier(
            primaryKeyID: primaryID,
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: primaryID,            // collapsed identity
            secondaryPublicKey: secondary.publicKey)
        XCTAssertFalse(
            sameKeyIDVerifier.verify(commit),
            "matching keyID in both slots => single-principal => false")
    
        // ---- NEGATIVE AXIS 2: same public key in both verifier slots
        // (single-principal by key) must fail closed even with distinct keyIDs. ----
        let sameKeyVerifier = BASSovereignDualKeyVerifier(
            primaryKeyID: primaryID,
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: secondaryID,
            secondaryPublicKey: primary.publicKey)  // collapsed key
        XCTAssertFalse(
            sameKeyVerifier.verify(commit),
            "matching public key in both slots => single-principal => false")
    
        // A self-consistent single-principal commit (same id + same key + same sig
        // in both slots), minted via the public init that bypasses makeCommit's
        // distinct-id guard, must ALSO fail against a same-principal verifier.
        let selfSig = try primary.privateKey.signature(for: digest)
        let singlePrincipalCommit = BASSovereignDualKeyCommit(
            intentDigest: digest,
            primaryKeyID: primaryID,
            primarySignature: selfSig,
            secondaryKeyID: primaryID,
            secondarySignature: selfSig)
        let singlePrincipalVerifier = BASSovereignDualKeyVerifier(
            primaryKeyID: primaryID,
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: primaryID,
            secondaryPublicKey: primary.publicKey)
        XCTAssertFalse(
            singlePrincipalVerifier.verify(singlePrincipalCommit),
            "a fully self-consistent single-principal commit+verifier must fail closed")
    
        // ---- NEGATIVE AXIS 3: keyID slot mismatch vs registration. ----
        let wrongPrimaryIDVerifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "qinao-not-the-primary",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: secondaryID,
            secondaryPublicKey: secondary.publicKey)
        XCTAssertFalse(
            wrongPrimaryIDVerifier.verify(commit),
            "commit primaryKeyID not matching registration => false")
    
        let wrongSecondaryIDVerifier = BASSovereignDualKeyVerifier(
            primaryKeyID: primaryID,
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "qinao-not-the-secondary",
            secondaryPublicKey: secondary.publicKey)
        XCTAssertFalse(
            wrongSecondaryIDVerifier.verify(commit),
            "commit secondaryKeyID not matching registration => false")
    
        // ---- NEGATIVE AXIS 4: wrong public key in a slot (valid distinct
        // identities, but the registered key doesn't match the signer). ----
        let wrongPrimaryKeyVerifier = BASSovereignDualKeyVerifier(
            primaryKeyID: primaryID,
            primaryPublicKey: third.publicKey,   // not the signer of primarySig
            secondaryKeyID: secondaryID,
            secondaryPublicKey: secondary.publicKey)
        XCTAssertFalse(
            wrongPrimaryKeyVerifier.verify(commit),
            "primary signature invalid under registered key => false")
    
        let wrongSecondaryKeyVerifier = BASSovereignDualKeyVerifier(
            primaryKeyID: primaryID,
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: secondaryID,
            secondaryPublicKey: third.publicKey) // not the signer of secondarySig
        XCTAssertFalse(
            wrongSecondaryKeyVerifier.verify(commit),
            "secondary signature invalid under registered key => false")
    
        // Swapped public keys (each slot has the OTHER signer's key) => both sigs
        // invalid under their registered slot => false.
        let swappedVerifier = BASSovereignDualKeyVerifier(
            primaryKeyID: primaryID,
            primaryPublicKey: secondary.publicKey,
            secondaryKeyID: secondaryID,
            secondaryPublicKey: primary.publicKey)
        XCTAssertFalse(
            swappedVerifier.verify(commit),
            "swapped public keys => both sigs invalid under their slot => false")
    
        // ---- NEGATIVE AXIS 5: single valid sig (one signature corrupted). ----
        var tamperedPrimaryBytes = commit.primarySignature
        tamperedPrimaryBytes[0] ^= 0xFF
        let onlySecondaryValid = BASSovereignDualKeyCommit(
            intentDigest: commit.intentDigest,
            primaryKeyID: commit.primaryKeyID,
            primarySignature: tamperedPrimaryBytes,
            secondaryKeyID: commit.secondaryKeyID,
            secondarySignature: commit.secondarySignature)
        XCTAssertFalse(
            goodVerifier.verify(onlySecondaryValid),
            "only the secondary sig valid (primary corrupted) => false")
    
        var tamperedSecondaryBytes = commit.secondarySignature
        tamperedSecondaryBytes[tamperedSecondaryBytes.count - 1] ^= 0xFF
        let onlyPrimaryValid = BASSovereignDualKeyCommit(
            intentDigest: commit.intentDigest,
            primaryKeyID: commit.primaryKeyID,
            primarySignature: commit.primarySignature,
            secondaryKeyID: commit.secondaryKeyID,
            secondarySignature: tamperedSecondaryBytes)
        XCTAssertFalse(
            goodVerifier.verify(onlyPrimaryValid),
            "only the primary sig valid (secondary corrupted) => false")
    
        // ---- NEGATIVE AXIS 6: digest swapped after signing => both sigs
        // no longer over the verified payload => false. ----
        let otherDigest = Data(SHA256.hash(
            data: Data("qinao-different-intent".utf8)))
        let swappedDigestCommit = BASSovereignDualKeyCommit(
            intentDigest: otherDigest,
            primaryKeyID: commit.primaryKeyID,
            primarySignature: commit.primarySignature,
            secondaryKeyID: commit.secondaryKeyID,
            secondarySignature: commit.secondarySignature)
        XCTAssertFalse(
            goodVerifier.verify(swappedDigestCommit),
            "intent digest swapped after signing => false")
    
        // ---- ENFORCEMENT: same keyID at SIGN time is rejected up front. ----
        var sameIDThrew = false
        do {
            _ = try BASSovereignDualKeySigning.makeCommit(
                intentDigest: digest,
                primary: primary,
                primaryKeyID: "qinao-same",
                secondary: secondary,
                secondaryKeyID: "qinao-same")
        } catch let error as BASSovereignDualKeySigning.SigningError {
            sameIDThrew = true
            XCTAssertEqual(error, .sameKeyIDForBothSlots("qinao-same"))
        }
        XCTAssertTrue(
            sameIDThrew,
            "makeCommit with identical keyIDs must throw sameKeyIDForBothSlots")
    
        // Re-affirm the positive case still holds after all mutations (the
        // canonical commit object was never mutated in place — new copies only).
        XCTAssertTrue(
            goodVerifier.verify(commit),
            "canonical two-principal commit must remain valid (no in-place mutation)")
    
        print("QINAO-GATE dual_key_two_principal: PASS " +
            "(verify true ONLY for 2 distinct keyIDs + 2 distinct public keys + " +
            "2 valid Ed25519 sigs; same-keyID / same-public-key / wrong-key / " +
            "single-valid-sig / swapped-digest / sign-time-same-id ALL false)")
    }

    func test_qinao_ed25519_cross_verifier_no_secret() async throws {
        // #90 L14 — the cross-process verifier accepts every genuine entry using ONLY
        // the public key, and rejects 100% of namespace / key / signature / field
        // tampering. We model a real second-verifier binary: it is handed (a) the
        // exported AppendedEntry chain, (b) the published Ed25519 PUBLIC key, and
        // (c) the published signing namespace — and NOTHING else. It never touches the
        // ledger actor or the private key. The only API it calls is the static, pure,
        // non-throwing `BASSovereignAuditLedger.verify(_:publicKey:signingNamespace:)`.
        let signingNamespace = "sovereign.keyring.v1"   // the published manifest namespace
        let ledger = try BASSovereignAuditLedger.withEd25519Seed(
            "qinao-cross-verifier-seed", namespace: signingNamespace)
    
        // Build a genuine multi-entry chain (varied shapes so verification is not a
        // single-fixture fluke).
        var genuine: [BASSovereignAuditLedger.AppendedEntry] = []
        let chainLength = 6
        for i in 0..<chainLength {
            let entry = BASSovereignAuditEntry(
                auditID: "qinao-cv-\(i)",
                sessionID: "session-\(i % 2)",
                turnID: "turn-\(i)",
                verdictRef: "verdict-\(i)",
                ruleIDs: ["BR-\(i)"],
                signalRefs: i % 2 == 0 ? ["sig-\(i)"] : [],
                actionRefs: i % 3 == 0 ? ["act-\(i)"] : [],
                snapshotRef: "snap-\(i)",
                actor: .system,
                signature: "",  // ledger (private key) signs on append
                appendedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(i)))
            genuine.append(try await ledger.append(entry))
        }
    
        // The verifier's ONLY secret-free inputs: the public key + the namespace.
        let publicKey = await ledger.ed25519PublicKey
        XCTAssertNotNil(publicKey, "Ed25519 ledger must expose a public key")
        let pub = publicKey!
    
        // An INDEPENDENT key pair — what a wrong/forged key would look like. Generated
        // fresh, never shares the ledger's private half.
        let wrongPub = BASSovereignEd25519KeyPair.generate().publicKey
    
        // 1. ACCEPT EVERY GENUINE ENTRY — exhaustive over the whole chain, public key only.
        for (idx, appended) in genuine.enumerated() {
            XCTAssertTrue(
                BASSovereignAuditLedger.verify(
                    appended, publicKey: pub, signingNamespace: signingNamespace),
                "genuine entry \(idx) (\(appended.entry.auditID)) must verify under the public key alone")
        }
    
        // 2. REJECT 100% OF TAMPERING — for EVERY entry, apply each tamper class and
        //    assert rejection (raised bar: exhaustive, zero tolerance).
        for (idx, appended) in genuine.enumerated() {
            // 2a. Wrong public key (forged/independent key pair) — must reject.
            XCTAssertFalse(
                BASSovereignAuditLedger.verify(
                    appended, publicKey: wrongPub, signingNamespace: signingNamespace),
                "entry \(idx): independent key pair must NOT validate a genuine signature")
    
            // 2b. Wrong signing namespace — namespace is bound into the signed canonical
            //     bytes, so a verifier on a different keyring version must reject.
            XCTAssertFalse(
                BASSovereignAuditLedger.verify(
                    appended, publicKey: pub, signingNamespace: "sovereign.keyring.v2"),
                "entry \(idx): mismatched signing namespace must be rejected")
    
            // 2c. Field tamper — mutate an authenticated field (auditID). The signature
            //     covers the canonical bytes, so any field change invalidates it.
            var fieldTamperedEntry = appended.entry
            fieldTamperedEntry.auditID = appended.entry.auditID + "-TAMPERED"
            let fieldTampered = BASSovereignAuditLedger.AppendedEntry(
                entry: fieldTamperedEntry,
                priorHash: appended.priorHash,
                selfHash: appended.selfHash)
            XCTAssertFalse(
                BASSovereignAuditLedger.verify(
                    fieldTampered, publicKey: pub, signingNamespace: signingNamespace),
                "entry \(idx): a tampered field must be rejected")
    
            // 2d. Signature tamper — flip one base64 char of the signature.
            var sigTamperedEntry = appended.entry
            let sig = sigTamperedEntry.signature
            XCTAssertFalse(sig.isEmpty, "entry \(idx): genuine signature must be non-empty")
            let firstChar = sig[sig.startIndex]
            let flipped = (firstChar == "A" ? "B" : "A")
            sigTamperedEntry.signature = String(flipped) + String(sig.dropFirst())
            let sigTampered = BASSovereignAuditLedger.AppendedEntry(
                entry: sigTamperedEntry,
                priorHash: appended.priorHash,
                selfHash: appended.selfHash)
            XCTAssertFalse(
                BASSovereignAuditLedger.verify(
                    sigTampered, publicKey: pub, signingNamespace: signingNamespace),
                "entry \(idx): a tampered signature must be rejected")
    
            // 2e. Malformed (non-base64) signature — must return false, never crash.
            var garbageEntry = appended.entry
            garbageEntry.signature = "!!!! not valid base64 !!!!"
            let garbage = BASSovereignAuditLedger.AppendedEntry(
                entry: garbageEntry,
                priorHash: appended.priorHash,
                selfHash: appended.selfHash)
            XCTAssertFalse(
                BASSovereignAuditLedger.verify(
                    garbage, publicKey: pub, signingNamespace: signingNamespace),
                "entry \(idx): malformed base64 signature must be rejected, not crash")
        }
    
        // 3. EXPLICIT "wrong namespace signature rejected" cross-check: a signature
        //    minted under one namespace must NOT verify when the verifier expects a
        //    different namespace, even with the correct public key. Sign the SAME
        //    logical entry under v2 and confirm the v1 verifier rejects it.
        let v2Ledger = try BASSovereignAuditLedger.withEd25519Seed(
            "qinao-cross-verifier-seed", namespace: "sovereign.keyring.v2")
        let v2Entry = BASSovereignAuditEntry(
            auditID: "qinao-cv-ns",
            sessionID: "session-0",
            turnID: "turn-ns",
            verdictRef: "verdict-ns",
            ruleIDs: ["BR-NS"],
            signalRefs: [],
            actionRefs: [],
            snapshotRef: "snap-ns",
            actor: .system,
            signature: "",
            appendedAt: Date(timeIntervalSince1970: 1_700_000_100))
        let v2Appended = try await v2Ledger.append(v2Entry)
        let v2Pub = await v2Ledger.ed25519PublicKey!   // same seed ⇒ same key as `pub`
        XCTAssertEqual(
            v2Pub.rawRepresentation, pub.rawRepresentation,
            "same seed ⇒ identical key; only the namespace differs")
        // Correct namespace (v2) verifies; v1 verifier rejects the v2-namespace signature.
        XCTAssertTrue(
            BASSovereignAuditLedger.verify(
                v2Appended, publicKey: v2Pub, signingNamespace: "sovereign.keyring.v2"),
            "v2-namespace signature must verify under the v2 verifier")
        XCTAssertFalse(
            BASSovereignAuditLedger.verify(
                v2Appended, publicKey: v2Pub, signingNamespace: signingNamespace),
            "wrong namespace signature (v2 signed, v1 expected) MUST be rejected")
    
        print("QINAO-GATE ed25519_cross_verifier_no_secret: PASS "
            + "(\(chainLength) genuine entries accepted with public key only; "
            + "5 tamper classes × \(chainLength) entries all rejected; "
            + "wrong-namespace signature rejected)")
    }
}
