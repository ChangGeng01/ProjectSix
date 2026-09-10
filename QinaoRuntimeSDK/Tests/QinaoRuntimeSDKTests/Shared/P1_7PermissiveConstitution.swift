import BASMemory

/// deep-audit P1-7 (2026-07-13) — a permissive constitution (write-scope "all",
/// promotion "auto", no restricted/sensitive domains) reproducing the pre-P1-7 blind
/// admit outcome (governed at `preferredTier`) the LEGITIMATE way: through a host that
/// actually holds promotion authority.
///
/// The blind `QinaoMemory.admit(_:)` now HOLDS survivors as `.candidate` (no constitution
/// → no authority to certify promotion — see `QinaoMemoryConstitutionGateTests`). Façade /
/// flow / seam tests that pin recall / L8 / frontstage behaviour need GOVERNED memory, so
/// they admit `under:` this constitution. The governance-authority semantics themselves are
/// pinned in the gate suite; here it is just the "authorized host" scaffolding.
func p1_7PermissiveConstitution(hostID: String = "p1-7-test-host") -> BASHostConstitution {
    var c = BASHostConstitution(hostID: hostID, activeVersion: "v1")
    c.consentLattice.memoryWriteScope = "all"
    c.consentLattice.memoryPromotionScope = "auto"
    return c
}
