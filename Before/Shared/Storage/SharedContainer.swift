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
        switch (resolvedDefaults == nil, containerURL == nil) {
        case (true, true):
            notice = "Shared surfaces are using local fallback storage because both the app-group defaults and shared container are unavailable, so widgets and shortcuts may not stay in sync until app-group access is restored."
        case (true, false):
            notice = "Shared surfaces are using local fallback defaults because the app-group preferences container is unavailable, so widgets and shortcuts may not stay in sync until app-group access is restored."
        case (false, true):
            notice = "Shared surfaces are using local fallback storage because the shared container URL is unavailable, so widgets and shortcuts may not stay in sync until app-group access is restored."
        case (false, false):
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
