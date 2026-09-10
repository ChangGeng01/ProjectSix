import SwiftData

enum BASAppleCurrentBrainPersistenceTransactionError: Error, Equatable {
    case requiresSingleConfiguration(actual: Int)
}

protocol BASAppleCurrentBrainPersistenceIO {
    func fetch<Model: PersistentModel>(
        _ type: Model.Type,
        in context: ModelContext
    ) throws -> [Model]

    func save(_ context: ModelContext) throws
}

struct BASAppleCurrentBrainLivePersistenceIO: BASAppleCurrentBrainPersistenceIO {
    func fetch<Model: PersistentModel>(
        _ type: Model.Type,
        in context: ModelContext
    ) throws -> [Model] {
        try context.fetch(FetchDescriptor<Model>())
    }

    func save(_ context: ModelContext) throws {
        try context.save()
    }
}

enum BASAppleCurrentBrainPersistenceTransaction {
    /// Executes against one package-owned context selected from the caller's
    /// committed store. Pending caller inserts, updates, and deletes do not
    /// participate. Custom/mixed stores and concurrent external writers are not
    /// qualified by this transaction boundary.
    static func perform<Result>(
        selectedBy caller: ModelContext,
        using io: some BASAppleCurrentBrainPersistenceIO,
        _ operation: (ModelContext) throws -> Result
    ) throws -> Result {
        let configurationCount = caller.container.configurations.count
        guard configurationCount == 1 else {
            throw BASAppleCurrentBrainPersistenceTransactionError
                .requiresSingleConfiguration(actual: configurationCount)
        }

        let owned = ModelContext(caller.container)
        owned.autosaveEnabled = false
        do {
            let result = try operation(owned)
            if owned.hasChanges {
                try io.save(owned)
            }
            return result
        } catch {
            owned.rollback()
            throw error
        }
    }
}
