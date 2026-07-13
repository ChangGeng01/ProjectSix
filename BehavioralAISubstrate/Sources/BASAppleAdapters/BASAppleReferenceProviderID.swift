import Foundation
import BASRuntimeCore

// deep-audit sweep 2026-07-13 — model-family provider-ID literal, adapter-side.
//
// `gemmaE4BProviderID` used to live in `BASReferenceProviderRuntime` inside the model-NEUTRAL
// BASRuntimeCore, even though its every consumer is in this adapter module (ProviderCatalogCore /
// ProviderRoutingFixtures / AppleExecutionProfileAdapterCore). A specific model-family name has
// no place in the neutral core (the four siblings there are neutral categories). Declaring it in
// an `extension BASReferenceProviderRuntime` HERE keeps every call site textually identical
// (`BASReferenceProviderRuntime.gemmaE4BProviderID`) — the same "only test imports change" pattern
// ProviderRoutingFixtures established — while the core stays free of model-family literals
// (pinned by BASModelBoundaryPinTests). The STRING value "gemmaE4B" is an on-wire routing key, so
// it is unchanged.
public extension BASReferenceProviderRuntime {
    static let gemmaE4BProviderID = "gemmaE4B"
}
