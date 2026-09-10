// ch1050 / v1.0 §11 — Qinao Effort: SDK surface for the substrate effort objects.
//
// Re-exports the BAS effort value types under the outline's `Qinao*` module name. This follows the
// established SDK convention (QinaoMemory / QinaoRisk surface BAS value types directly in their public
// API) rather than the strict mirror used by QinaoWorldPrior / QinaoSovereign. Because these are thin
// aliases — not copies — there is NO mirror-drift risk: the substrate types remain the single source
// of record (§8.1 requested_effort / applied_effort / override_reason).

import BASRuntimeCore

public typealias QinaoEffortLevel = BASEffortLevel
public typealias QinaoEffortBudget = BASEffortBudget
public typealias QinaoEffortPlan = BASEffortPlan
