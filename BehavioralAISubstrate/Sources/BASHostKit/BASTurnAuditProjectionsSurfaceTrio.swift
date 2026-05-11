// MARK: - BASTurnAuditProjectionsSurfaceTrio
// chapter 四百九十二 / M1344 — surface alias trio fold

import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore

public struct BASTurnAuditProjectionsSurfaceTrio: Sendable {
    public let surfaceMode: BASSurfaceMode?
    public let cthulhuSurfaceAlias: BASCthulhuSurfaceAlias?
    public let kunlunSurfaceAlias: BASKunlunSurfaceAlias?

    public static func compute(
        permitMode: BASActionPermitMode
    ) -> BASTurnAuditProjectionsSurfaceTrio {
        let mode = BASSurfaceModeFromPermit.derive(
            from: permitMode)
        let cthulhu = mode.flatMap {
            BASCthulhuSurfaceAlias.derive(from: $0)
        }
        let kunlun = mode.map {
            BASKunlunSurfaceAlias.derive(from: $0)
        }
        return BASTurnAuditProjectionsSurfaceTrio(
            surfaceMode: mode,
            cthulhuSurfaceAlias: cthulhu,
            kunlunSurfaceAlias: kunlun)
    }
}
