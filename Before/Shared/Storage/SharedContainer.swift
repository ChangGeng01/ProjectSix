import Foundation

struct SharedContainerResolution: @unchecked Sendable {
    let defaults: UserDefaults
    let containerURL: URL?
    let isUsingFallback: Bool
    let notice: String?
}

enum SharedContainer {
    static let appGroupID = "group.com.changgeng.before"
    private static let defaultResolution = resolve()

    static var defaults: UserDefaults {
        defaultResolution.defaults
    }

    static var containerURL: URL? {
        defaultResolution.containerURL
    }

    static var notice: String? {
        defaultResolution.notice
    }

    static func resolve(
        suiteName: String = appGroupID,
        defaultsFactory: (String) -> UserDefaults? = { UserDefaults(suiteName: $0) },
        fallback: UserDefaults = .standard,
        containerURLProvider: (String) -> URL? = {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    ) -> SharedContainerResolution {
        let resolvedDefaults = defaultsFactory(suiteName)
        let defaults = resolvedDefaults ?? fallback
        let containerURL = containerURLProvider(suiteName)
        let isUsingFallback = resolvedDefaults == nil || containerURL == nil

        guard isUsingFallback else {
            return SharedContainerResolution(
                defaults: defaults,
                containerURL: containerURL,
                isUsingFallback: false,
                notice: nil
            )
        }

        let notice: String
        if containerURL == nil {
            notice = "Shared surfaces are using local fallback storage, so widgets and shortcuts may not stay in sync until app-group access is restored."
        } else {
            notice = "Shared surfaces are using local fallback storage, so widgets and shortcuts may not stay in sync until app-group access is restored."
        }

        return SharedContainerResolution(
            defaults: defaults,
            containerURL: containerURL,
            isUsingFallback: true,
            notice: notice
        )
    }
}
