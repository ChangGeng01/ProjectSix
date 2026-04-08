import Foundation

struct SharedContainerResolution {
    let defaults: UserDefaults
    let isUsingFallback: Bool
    let notice: String?
}

enum SharedContainer {
    static let appGroupID = "group.com.changgeng.before"

    static var defaults: UserDefaults {
        resolve().defaults
    }

    static var notice: String? {
        resolve().notice
    }

    static func resolve(
        suiteName: String = appGroupID,
        defaultsFactory: (String) -> UserDefaults? = { UserDefaults(suiteName: $0) },
        fallback: UserDefaults = .standard
    ) -> SharedContainerResolution {
        guard let defaults = defaultsFactory(suiteName) else {
            return SharedContainerResolution(
                defaults: fallback,
                isUsingFallback: true,
                notice: "Shared surfaces are using local fallback storage, so widgets and shortcuts may not stay in sync until app-group access is restored."
            )
        }

        return SharedContainerResolution(
            defaults: defaults,
            isUsingFallback: false,
            notice: nil
        )
    }
}
