import Foundation

enum BeforeLegacyMigration {
    static let sessionBootstrapIdentifier = "session_bootstrap"
    static let primaryModeIdentifier = "primary"
    static let comparativeModeIdentifier = "comparative"
    static let reflectiveModeIdentifier = "reflective"

    static func normalizedBrainStateUpdateSourceIdentifier(_ identifier: String) -> String {
        switch identifier {
        case "sessionPrime":
            sessionBootstrapIdentifier
        default:
            identifier
        }
    }

    static func normalizedEntryIntentKindIdentifier(_ identifier: String) -> String {
        switch identifier {
        case "quickCapture":
            "capture"
        case "openMode":
            "present"
        case "openEvolutionControl":
            "resume"
        case "reopenTomorrowItem":
            "reopen"
        case "resumeCurrentDecision":
            "resume"
        default:
            identifier
        }
    }

    static func normalizedModeIdentifier(_ identifier: String) -> String {
        switch identifier {
        case "quick":
            primaryModeIdentifier
        case "balance":
            comparativeModeIdentifier
        case "mirror":
            reflectiveModeIdentifier
        default:
            identifier
        }
    }

    static func normalizedHostModeIdentifier(_ identifier: String) -> String {
        switch identifier {
        case primaryModeIdentifier:
            "quick"
        case comparativeModeIdentifier:
            "balance"
        case reflectiveModeIdentifier:
            "mirror"
        default:
            identifier
        }
    }

    static func normalizedMemorySourceIdentifier(_ identifier: String) -> String {
        switch identifier {
        case "history":
            "archive"
        case "reminder":
            "cue"
        default:
            identifier
        }
    }

    static func normalizedHostMemorySourceIdentifier(_ identifier: String) -> String {
        switch identifier {
        case "archive":
            "history"
        case "cue":
            "reminder"
        default:
            identifier
        }
    }
}
