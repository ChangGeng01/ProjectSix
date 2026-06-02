// ch1051 / v1.0 L5 — ConsentMatrix alias (gap-audit slice 2 #12, naming nit).
//
// The outline names the host consent object `ConsentMatrix`; the substrate built it as
// `BASConsentLattice` (a scope grid of consent axes). They are the same object under a different
// name. This typealias surfaces the outline's name without duplicating the type (no drift): the
// lattice remains the single source of record.

import Foundation

public typealias BASConsentMatrix = BASConsentLattice
