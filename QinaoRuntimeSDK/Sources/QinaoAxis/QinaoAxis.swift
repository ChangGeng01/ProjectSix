// ch1050 / v1.0 §11 — Qinao Axis: SDK surface for the 昆仑中轴 (Kunlun axis) objects.
//
// Thin re-export of the BAS axis value types under the `Qinao*` name (substrate stays source of
// record). The axis view + deviation are the §9.1 昆仑 doctrine "中轴 / 离中" judgement objects.

import BASOrchestration

public typealias QinaoAxisView = BASKunlunAxisView
public typealias QinaoAxisDeviation = BASAxisDeviation
