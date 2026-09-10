// ch1050 / v1.0 §11 — Qinao OldSeal: SDK surface for the 旧封 (old-seal) objects.
//
// Thin re-export of the BAS seal value type + sealing helpers under the `Qinao*` name (substrate
// stays source of record). The §9 深渊 doctrine "封印必须生效" / §13.1 "高敏记忆" sealing surface.

import BASMemory

public typealias QinaoSealEnvelope = BASSealEnvelope
public typealias QinaoOldSeal = BASOldSealSealingProtocol
