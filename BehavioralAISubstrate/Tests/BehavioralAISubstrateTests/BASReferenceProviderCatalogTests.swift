import Testing
@testable import BASRuntimeCore

struct BASReferenceProviderCatalogTests {
    @Test
    func exposesDefaultDescriptorsForBuiltInProviders() {
        let descriptors = BASReferenceProviderCatalog.defaultDescriptorsByID()

        #expect(descriptors[BASReferenceProviderRuntime.gemmaE4BProviderID]?.track == .builtInOpenModel)
        #expect(descriptors[BASReferenceProviderRuntime.foundationModelsProviderID]?.track == .builtInSystem)
        #expect(descriptors[BASReferenceProviderRuntime.openModelProviderID]?.openModel?.stableID == "substrate/open-model-slot")
        #expect(descriptors[BASReferenceProviderRuntime.gemmaE4BProviderID]?.capabilityProfile.modelID == "google/gemma-4-e4b-it")
        #expect(descriptors[BASReferenceProviderRuntime.foundationModelsProviderID]?.affinity(for: .primary) == 100)
    }

    @Test
    func exposesReferenceTaskAffinitiesForRuntimeSlots() {
        let templateAffinities = BASReferenceProviderCatalog.defaultTaskAffinities(
            providerID: BASReferenceProviderRuntime.templateProviderID
        )
        let stubAffinities = BASReferenceProviderCatalog.defaultTaskAffinities(
            providerID: BASReferenceProviderRuntime.testingStubProviderID
        )

        #expect(templateAffinities[.reflective] == 0)
        #expect(stubAffinities[.comparative] == 100)
    }
}
