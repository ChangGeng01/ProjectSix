import SwiftData

enum BASApplePersistenceTransactionError: Error, Equatable {
    case requiresSingleConfiguration(actual: Int)
}

protocol BASApplePersistenceIO {
    func fetch<Model: PersistentModel>(
        _ type: Model.Type,
        in context: ModelContext
    ) throws -> [Model]

    func save(_ context: ModelContext) throws
}

struct BASAppleLivePersistenceIO: BASApplePersistenceIO {
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

struct BASApplePersistenceTransactionOutcome<Value> {
    let value: Value
    let didSave: Bool
}

enum BASApplePersistenceTransaction {
    /// Executes against one package-owned context selected from the caller's
    /// committed store. Pending caller inserts, updates, and deletes do not
    /// participate. Custom/mixed stores and concurrent external writers are not
    /// qualified by this transaction boundary.
    static func perform<Result>(
        selectedBy caller: ModelContext,
        using io: some BASApplePersistenceIO,
        _ operation: (ModelContext) throws -> Result
    ) throws -> Result {
        try performReportingSave(
            selectedBy: caller,
            using: io,
            operation
        ).value
    }

    static func performReportingSave<Result>(
        selectedBy caller: ModelContext,
        using io: some BASApplePersistenceIO,
        _ operation: (ModelContext) throws -> Result
    ) throws -> BASApplePersistenceTransactionOutcome<Result> {
        let configurationCount = caller.container.configurations.count
        guard configurationCount == 1 else {
            throw BASApplePersistenceTransactionError
                .requiresSingleConfiguration(actual: configurationCount)
        }

        let owned = ModelContext(caller.container)
        owned.autosaveEnabled = false
        do {
            let result = try operation(owned)
            let didSave: Bool
            if owned.hasChanges {
                try io.save(owned)
                didSave = true
            } else {
                didSave = false
            }
            return BASApplePersistenceTransactionOutcome(
                value: result,
                didSave: didSave
            )
        } catch {
            owned.rollback()
            throw error
        }
    }
}
