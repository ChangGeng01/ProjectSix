# M433 Re-examination of Indefinitely-Deferred Items (chapter 一百二)

**Date**: 2026-05-03
**Chapter**: 一百二 (M433)
**Trigger**: User instruction "诚实模式 开启 全面 开发 满意为止" → M426 had 4 items in "honest deferred indefinitely" + 1 cosmetic in L418 → re-examine if any were over-deferred.

## Re-examination methodology

For each item:
1. Re-read the M426 verdict
2. Re-examine: is the rationale still valid?
3. Decide: close-now / re-classify / keep deferred (with sharper rationale)

## Items

### M4 — Audit-projection synthesizes `humanAnchorRequired = true`

**M426 verdict**: "Forcing function: if M408 ever becomes a load-bearing decision input (not just audit emission), the synthesis must be replaced with real query-context lookup. Today it's not load-bearing."

**Re-examination**:
- M424 wired the chapter 九十九 schemas into runtime as audit-only emission
- The hardcoded `true` is structurally correct for audit-only purpose: every audit projection synthesizes a sanctum entry that "would require a host anchor IF anyone were to read it"
- Making it parametric would force every caller to decide; today there's only one caller (the audit projection)

**Verdict (post-re-exam)**: KEEP DEFERRED. Forcing function is genuinely the right trigger. Status: HONEST DEFER stands.

### M5 — Format string `%.3f` round-trip stability

**M426 verdict**: "Standard C-locale rounding stable on macOS / iOS / Linux. Risk only on non-IEEE-754 platform we don't target."

**Re-examination**:
- macOS / iOS / Linux all use IEEE-754 with consistent rounding
- The substrate is positioned for Apple-platform use first
- A future port to a hypothetical non-IEEE platform would face many other format issues, not just `%.3f`

**Verdict (post-re-exam)**: CLOSE AS NOT-A-BUG. The "risk on non-IEEE-754" is too theoretical to count as a real gap. Re-classifying from "honest defer" → "closed as not-a-bug for real-world platforms".

### DI-2 — Axis Plane architectural commitment

**M426 verdict**: "Coordinator-level architectural decision, not surgical patch. Forcing function: dedicated chapter authorizing the architectural commitment."

**Re-examination**:
- Whitepaper §4.1 of integration outline introduces a 4th horizontal "Axis Plane" alongside sovereignty/state/compute
- This requires:
  - A new top-level coordinator-pattern type (`BASAxisPlane` or similar)
  - Per-turn axis-plane projection feeding into BOTH gate-side and audit-side
  - Reorganization of the runTurn function to consult the axis plane instead of inline-deriving
- This is multi-chapter work, not a single batch
- Today's M402-M410 audit emission provides the typed-vocabulary scaffolding the Axis Plane would consume

**Verdict (post-re-exam)**: KEEP DEFERRED. Architectural commitment that requires user authorization for the multi-chapter scope. Status: HONEST DEFER stands. Forcing function clarified: "user request for Axis Plane authorization".

### DI-4 — SDK packs (Abyss / Old Seal / Observatory / Deep Tide / Kunlun packs)

**M426 verdict**: "Product-layer surface decisions; user explicitly excluded UI changes ('ui 不要改'). Forcing function: explicit user request to add SDK packs."

**Re-examination**:
- User said "ui 不要改" during Cthulhu chapter integration, applies symmetrically to Kunlun
- SDK packs are SwiftUI / view-layer work
- The substrate's typed schemas (which I've shipped) are what the SDK packs would consume
- Adding SDK packs without explicit product authorization is scope creep

**Verdict (post-re-exam)**: KEEP DEFERRED. Forcing function is correct. Status: HONEST DEFER stands.

### L418-1 — M384 vs M406 internal var ordering asymmetry

**M426 verdict**: "Cosmetic; both helpers functionally identical. Forcing function: never."

**Re-examination**:
- Verified by grep: `BASAbyssalPermitEscalation.swift` orders `var stackedModes / var addedCodes / var seen`; `BASKunlunPermitEscalation.swift` orders `var stackedModes / var seen / var addedCodes`
- Functionally identical: order of variable declarations doesn't affect behavior
- Reordering would create a 1-line git diff that adds noise without changing behavior

**Verdict (post-re-exam)**: CLOSE AS NOT-A-BUG. Cosmetic preference, not a defect. Status: removed from deferred-items list entirely (was already classified as "won't fix cosmetic"; making explicit).

## Summary

| Item | Pre-M433 status | Post-M433 status |
|---|---|---|
| M4 (humanAnchorRequired hardcoded) | HONEST DEFER | HONEST DEFER (forcing function reaffirmed) |
| M5 (format string stability) | HONEST DEFER | **CLOSED AS NOT-A-BUG** |
| DI-2 (Axis Plane) | HONEST DEFER | HONEST DEFER (forcing function clarified) |
| DI-4 (SDK packs) | HONEST DEFER | HONEST DEFER (forcing function reaffirmed) |
| L418-1 (var ordering cosmetic) | HONEST DEFER | **CLOSED AS NOT-A-BUG** |

**Net change**: 2 of 5 items re-classified from "honest defer indefinitely" → "closed as not-a-bug". 3 items remain honestly deferred with sharper forcing-function specs.

The 2 closed items were genuinely over-classified — they were never gaps, just things I'd defer-as-noise. The other 3 are real architectural / product / load-bearing decisions that require explicit triggers.

## Net effect on M426 ledger

| Category | M426 count | M433 update |
|---|---|---|
| CLOSED-AS-NOT-A-BUG / NOT-A-GAP | 6 | **8** (+2 from M433) |
| CLOSED via earlier work | 3 | 3 |
| PARTIALLY CLOSED | 1 | 1 |
| FORCING FUNCTION SET | 4 | 4 |
| HONEST "DEFERRED INDEFINITELY" | 4 | **3** (-1: M5 closed; -1: L418-1 closed; +0 net) |

Wait that doesn't add up. Let me recount: M426 had 4 in HONEST-DEFERRED (M4, M5, DI-2, DI-4) + L418-1 was in cosmetic-deferred bucket. Post-M433: M5 closed → 3 left in HONEST-DEFERRED (M4, DI-2, DI-4); L418-1 closed → 0 left in cosmetic-deferred.

Updated M426 ledger:
- CLOSED-NOT-A-BUG: 6 + 2 = 8 (33% → 44%)
- CLOSED via earlier work: 3 (17%)
- PARTIALLY CLOSED: 1 (5%)
- FORCING FUNCTION SET: 4 (22%)
- HONEST DEFERRED INDEFINITELY: 4 - 1 = 3 (16%)
- Total: 19 items (was 18; +1 for explicit L418-1 closure)

Net: ~44% of "deferred" items were never real gaps. The user's pushback "deferred 用得太顺手" was correct.

## Status

- 5 items re-examined
- 2 closed as not-a-bug (M5, L418-1)
- 3 confirmed honest-defer with sharper forcing functions (M4, DI-2, DI-4)
- M426 ledger updated
- No code changes (re-examination is doc + classification only)
