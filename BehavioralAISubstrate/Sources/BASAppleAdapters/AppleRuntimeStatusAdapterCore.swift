import Foundation
import BASRuntimeCore

public struct BASAppleProviderRuntimeStatusInput: Codable, Equatable, Sendable {
    public var preferredProviderID: String
    public var allowFallbacks: Bool
    public var runtimeEnabled: Bool
    public var statusesByID: [String: BASProviderStatusRecord]
    public var suspendedProviderIDs: Set<String>
    public var routingPolicy: BASProviderRoutingPolicy
    public var routingRegistryVersion: String?
    public var testingOverrideEnabled: Bool
    public var testingOverrideTitle: String?

    public init(
        preferredProviderID: String,
        allowFallbacks: Bool,
        runtimeEnabled: Bool,
        statusesByID: [String: BASProviderStatusRecord],
        suspendedProviderIDs: Set<String> = [],
        routingPolicy: BASProviderRoutingPolicy,
        routingRegistryVersion: String? = nil,
        testingOverrideEnabled: Bool = false,
        testingOverrideTitle: String? = nil
    ) {
        self.preferredProviderID = preferredProviderID
        self.allowFallbacks = allowFallbacks
        self.runtimeEnabled = runtimeEnabled
        self.statusesByID = statusesByID
        self.suspendedProviderIDs = suspendedProviderIDs
        self.routingPolicy = routingPolicy
        self.routingRegistryVersion = routingRegistryVersion
        self.testingOverrideEnabled = testingOverrideEnabled
        self.testingOverrideTitle = testingOverrideTitle
    }
}

public struct BASAppleHostVisibleRuntimeStatusInput: Codable, Equatable, Sendable {
    public var requestedProviderID: String
    public var effectiveProviderID: String
    public var allowFallbacks: Bool
    public var runtimeEnabled: Bool
    public var statusesByID: [String: BASProviderStatusRecord]
    public var suspendedProviderIDs: Set<String>
    public var routingPolicy: BASProviderRoutingPolicy
    public var routingRegistryVersion: String?
    public var testingOverrideEnabled: Bool
    public var testingOverrideTitle: String?
    public var profileDetail: String

    public init(
        requestedProviderID: String,
        effectiveProviderID: String,
        allowFallbacks: Bool,
        runtimeEnabled: Bool,
        statusesByID: [String: BASProviderStatusRecord],
        suspendedProviderIDs: Set<String> = [],
        routingPolicy: BASProviderRoutingPolicy,
        routingRegistryVersion: String? = nil,
        testingOverrideEnabled: Bool = false,
        testingOverrideTitle: String? = nil,
        profileDetail: String
    ) {
        self.requestedProviderID = requestedProviderID
        self.effectiveProviderID = effectiveProviderID
        self.allowFallbacks = allowFallbacks
        self.runtimeEnabled = runtimeEnabled
        self.statusesByID = statusesByID
        self.suspendedProviderIDs = suspendedProviderIDs
        self.routingPolicy = routingPolicy
        self.routingRegistryVersion = routingRegistryVersion
        self.testingOverrideEnabled = testingOverrideEnabled
        self.testingOverrideTitle = testingOverrideTitle
        self.profileDetail = profileDetail
    }
}

public struct BASAppleProviderRuntimeStatusOutput: Codable, Equatable, Sendable {
    public var preferredProviderID: String
    public var activeProviderID: String
    public var fallbackProviderID: String?
    public var detail: String
    public var orderedProviderIDs: [String]

    public init(
        preferredProviderID: String,
        activeProviderID: String,
        fallbackProviderID: String?,
        detail: String,
        orderedProviderIDs: [String]
    ) {
        self.preferredProviderID = preferredProviderID
        self.activeProviderID = activeProviderID
        self.fallbackProviderID = fallbackProviderID
        self.detail = detail
        self.orderedProviderIDs = orderedProviderIDs
    }
}

public enum BASAppleProviderRuntimeStatusAdapter {
    public static func runtimeStatus(
        from input: BASAppleProviderRuntimeStatusInput
    ) -> BASAppleProviderRuntimeStatusOutput {
        let summary = BASReferenceProviderRuntime.runtimeStatusSummary(
            preferredProviderID: input.preferredProviderID,
            allowFallbacks: input.allowFallbacks,
            runtimeEnabled: input.runtimeEnabled,
            statusesByID: input.statusesByID,
            suspendedProviderIDs: input.suspendedProviderIDs,
            testingOverrideEnabled: input.testingOverrideEnabled,
            testingOverrideTitle: input.testingOverrideTitle
            ,
            routingRegistryVersion: input.routingRegistryVersion,
            routingPolicy: input.routingPolicy
        )

        return BASAppleProviderRuntimeStatusOutput(
            preferredProviderID: summary.preferredProviderID,
            activeProviderID: summary.activeProviderID,
            fallbackProviderID: summary.fallbackProviderID,
            detail: summary.detail,
            orderedProviderIDs: summary.orderedProviderIDs
        )
    }

    public static func hostVisibleRuntimeStatus(
        from input: BASAppleHostVisibleRuntimeStatusInput
    ) -> BASAppleProviderRuntimeStatusOutput {
        let summary = runtimeStatus(
            from: BASAppleProviderRuntimeStatusInput(
                preferredProviderID: input.effectiveProviderID,
                allowFallbacks: input.allowFallbacks,
                runtimeEnabled: input.runtimeEnabled,
                statusesByID: input.statusesByID,
                suspendedProviderIDs: input.suspendedProviderIDs,
                routingPolicy: input.routingPolicy,
                routingRegistryVersion: input.routingRegistryVersion,
                testingOverrideEnabled: input.testingOverrideEnabled,
                testingOverrideTitle: input.testingOverrideTitle
            )
        )

        var fallbackProviderID = summary.fallbackProviderID
        var detail = summary.detail
        let requestedProviderID = input.requestedProviderID

        if summary.activeProviderID == BASReferenceProviderRuntime.templateProviderID ||
            input.effectiveProviderID != requestedProviderID {
            if summary.activeProviderID == BASReferenceProviderRuntime.templateProviderID &&
                requestedProviderID != BASReferenceProviderRuntime.templateProviderID {
                fallbackProviderID = BASReferenceProviderRuntime.templateProviderID
            } else if summary.activeProviderID != requestedProviderID {
                fallbackProviderID = summary.activeProviderID
            }
            detail = input.profileDetail
        }

        return BASAppleProviderRuntimeStatusOutput(
            preferredProviderID: requestedProviderID,
            activeProviderID: summary.activeProviderID,
            fallbackProviderID: fallbackProviderID,
            detail: detail,
            orderedProviderIDs: summary.orderedProviderIDs
        )
    }
}
