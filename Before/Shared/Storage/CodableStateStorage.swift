import Foundation

struct CodableStateStorage: @unchecked Sendable {
    private let loadValueBlock: ((any Decodable.Type, String) -> Any?)?
    private let loadDataBlock: (String) -> Data?
    private let saveDataBlock: (Data, String) -> Void
    private let clearBlock: (String) -> Void

    init(
        loadValue: ((any Decodable.Type, String) -> Any?)? = nil,
        loadData: @escaping (String) -> Data?,
        saveData: @escaping (Data, String) -> Void,
        clear: @escaping (String) -> Void
    ) {
        self.loadValueBlock = loadValue
        self.loadDataBlock = loadData
        self.saveDataBlock = saveData
        self.clearBlock = clear
    }

    func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        if let loadValueBlock {
            return loadValueBlock(type, key) as? Value
        }

        guard
            let data = loadDataBlock(key),
            let value = try? JSONDecoder().decode(type, from: data)
        else {
            return nil
        }

        return value
    }

    func loadData(key: String) -> Data? {
        loadDataBlock(key)
    }

    func save<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        saveDataBlock(data, key)
    }

    func saveData(_ data: Data, key: String) {
        saveDataBlock(data, key)
    }

    func clear(key: String) {
        clearBlock(key)
    }

    static let protectedLocal = CodableStateStorage(
        loadValue: { type, key in ProtectedLocalStateStore.load(type, key: key) },
        loadData: { ProtectedLocalStateStore.loadData(key: $0) },
        saveData: { ProtectedLocalStateStore.saveData($0, key: $1) },
        clear: { ProtectedLocalStateStore.clear(key: $0) }
    )

    static let sharedProtected = CodableStateStorage(
        loadValue: { type, key in SharedProtectedStateStore.load(type, key: key) },
        loadData: { SharedProtectedStateStore.loadData(key: $0) },
        saveData: { SharedProtectedStateStore.saveData($0, key: $1) },
        clear: { SharedProtectedStateStore.clear(key: $0) }
    )

    static let sharedPublic = CodableStateStorage(
        loadValue: { type, key in SharedPublicStateStore.load(type, key: key) },
        loadData: { SharedPublicStateStore.loadData(key: $0) },
        saveData: { SharedPublicStateStore.saveData($0, key: $1) },
        clear: { SharedPublicStateStore.clear(key: $0) }
    )

    static func userDefaults(_ defaults: UserDefaults) -> CodableStateStorage {
        CodableStateStorage(
            loadData: { defaults.data(forKey: $0) },
            saveData: { defaults.set($0, forKey: $1) },
            clear: { defaults.removeObject(forKey: $0) }
        )
    }
}
