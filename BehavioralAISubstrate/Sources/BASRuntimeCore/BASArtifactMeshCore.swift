import Crypto
import Foundation

public enum BASArtifactIDStorageScalarError:
    Error, Sendable, Equatable
{
    case invalidBase64OrLength
    case nonCanonicalBase64
    case malformedLengthPrefix
    case invalidFieldCount
    case unsupportedVersion
    case invalidAlgorithm
    case invalidEpoch
    case invalidCommitment
}

public struct BASArtifactID: Codable, Sendable, Hashable {
    public let integrityAlgorithm: String
    public let commitmentKeyEpoch: UInt64
    public let commitmentHex: String

    public init(
        integrityAlgorithm: String,
        commitmentKeyEpoch: UInt64,
        commitmentHex: String
    ) {
        self.integrityAlgorithm = integrityAlgorithm
        self.commitmentKeyEpoch = commitmentKeyEpoch
        self.commitmentHex = commitmentHex
    }

    public var storageScalar: String {
        get throws {
            try validateStorageFields()
            let bytes = BASSovereignCanonicalBytes.lengthPrefixed([
                "bas-artifact-id-storage-v1",
                integrityAlgorithm,
                String(commitmentKeyEpoch),
                commitmentHex,
            ])
            return bytes.base64EncodedString()
        }
    }

    public init(storageScalar: String) throws {
        guard !storageScalar.isEmpty,
              storageScalar.utf8.count <= 4_096,
              let bytes = Data(base64Encoded: storageScalar),
              bytes.count <= 3_072
        else {
            throw BASArtifactIDStorageScalarError
                .invalidBase64OrLength
        }
        guard bytes.base64EncodedString() == storageScalar else {
            throw BASArtifactIDStorageScalarError.nonCanonicalBase64
        }
        let fields = try Self.decodeBoundedLengthPrefixedFields(bytes)
        guard fields.count == 4 else {
            throw BASArtifactIDStorageScalarError.invalidFieldCount
        }
        guard fields[0] == "bas-artifact-id-storage-v1" else {
            throw BASArtifactIDStorageScalarError.unsupportedVersion
        }
        guard !fields[2].isEmpty,
              let epoch = UInt64(fields[2]),
              fields[2] == String(epoch)
        else {
            throw BASArtifactIDStorageScalarError.invalidEpoch
        }
        self.integrityAlgorithm = fields[1]
        self.commitmentKeyEpoch = epoch
        self.commitmentHex = fields[3]
        try validateStorageFields()
    }

    private enum CodingKeys: String, CodingKey {
        case integrityAlgorithm
        case commitmentKeyEpoch
        case commitmentHex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.integrityAlgorithm = try container.decode(
            String.self, forKey: .integrityAlgorithm)
        self.commitmentKeyEpoch = try container.decode(
            UInt64.self, forKey: .commitmentKeyEpoch)
        self.commitmentHex = try container.decode(
            String.self, forKey: .commitmentHex)
        try validateStorageFields()
    }

    private func validateStorageFields() throws {
        let algorithmBytes = Array(integrityAlgorithm.utf8)
        guard (1...64).contains(algorithmBytes.count),
              algorithmBytes.allSatisfy({ byte in
                  (byte >= 97 && byte <= 122)
                      || (byte >= 48 && byte <= 57)
                      || byte == 45
              })
        else {
            throw BASArtifactIDStorageScalarError.invalidAlgorithm
        }
        let commitmentBytes = Array(commitmentHex.utf8)
        guard (2...512).contains(commitmentBytes.count),
              commitmentBytes.count.isMultiple(of: 2),
              commitmentBytes.allSatisfy({ byte in
                  (byte >= 48 && byte <= 57)
                      || (byte >= 97 && byte <= 102)
              })
        else {
            throw BASArtifactIDStorageScalarError.invalidCommitment
        }
    }

    private static func decodeBoundedLengthPrefixedFields(
        _ bytes: Data
    ) throws -> [String] {
        let input = Array(bytes)
        var fields: [String] = []
        var index = 0
        while index < input.count {
            let digitStart = index
            var length = 0
            while index < input.count,
                  input[index] >= 48,
                  input[index] <= 57
            {
                guard index - digitStart < 4 else {
                    throw BASArtifactIDStorageScalarError
                        .malformedLengthPrefix
                }
                if index > digitStart, input[digitStart] == 48 {
                    throw BASArtifactIDStorageScalarError
                        .malformedLengthPrefix
                }
                length = length * 10 + Int(input[index] - 48)
                index += 1
            }
            guard index > digitStart,
                  index < input.count,
                  input[index] == 58,
                  length <= 1_024
            else {
                throw BASArtifactIDStorageScalarError
                    .malformedLengthPrefix
            }
            index += 1
            guard length <= input.count - index else {
                throw BASArtifactIDStorageScalarError
                    .malformedLengthPrefix
            }
            let end = index + length
            guard let field = String(
                bytes: input[index..<end], encoding: .utf8)
            else {
                throw BASArtifactIDStorageScalarError
                    .malformedLengthPrefix
            }
            fields.append(field)
            guard fields.count <= 5 else {
                throw BASArtifactIDStorageScalarError.invalidFieldCount
            }
            index = end
        }
        return fields
    }
}

private struct BASArtifactCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        return nil
    }
}

public enum BASArtifactScopeBinding: Codable, Sendable, Hashable {
    case publicArtifact
    case workspaceAuthority(BASArtifactID)
    case attempt(BASArtifactID)
    case durableWarrant(BASArtifactID)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: BASArtifactCodingKey.self)
        let keys = Set(container.allKeys.map(\.stringValue))
        let tagKey = BASArtifactCodingKey("tag")
        let idKey = BASArtifactCodingKey("artifactID")
        let tag = try container.decode(String.self, forKey: tagKey)
        switch tag {
        case "public":
            guard keys == ["tag"] else {
                throw DecodingError.dataCorruptedError(
                    forKey: tagKey,
                    in: container,
                    debugDescription: "public scope carries no Artifact ID")
            }
            self = .publicArtifact
        case "workspace-authority", "attempt", "durable-warrant":
            guard keys == ["tag", "artifactID"] else {
                throw DecodingError.dataCorruptedError(
                    forKey: tagKey,
                    in: container,
                    debugDescription: "bound scope requires one Artifact ID")
            }
            let id = try container.decode(
                BASArtifactID.self, forKey: idKey)
            _ = try id.storageScalar
            if tag == "workspace-authority" {
                self = .workspaceAuthority(id)
            } else if tag == "attempt" {
                self = .attempt(id)
            } else {
                self = .durableWarrant(id)
            }
        default:
            throw DecodingError.dataCorruptedError(
                forKey: tagKey,
                in: container,
                debugDescription: "unsupported Artifact scope tag")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: BASArtifactCodingKey.self)
        let tagKey = BASArtifactCodingKey("tag")
        let idKey = BASArtifactCodingKey("artifactID")
        switch self {
        case .publicArtifact:
            try container.encode("public", forKey: tagKey)
        case .workspaceAuthority(let id):
            _ = try id.storageScalar
            try container.encode("workspace-authority", forKey: tagKey)
            try container.encode(id, forKey: idKey)
        case .attempt(let id):
            _ = try id.storageScalar
            try container.encode("attempt", forKey: tagKey)
            try container.encode(id, forKey: idKey)
        case .durableWarrant(let id):
            _ = try id.storageScalar
            try container.encode("durable-warrant", forKey: tagKey)
            try container.encode(id, forKey: idKey)
        }
    }
}

public struct BASArtifactIdentityCore: Codable, Sendable, Hashable {
    public let canonicalizationVersion: String
    public let schemaID: String
    public let schemaVersion: String
    public let kind: String
    public let parentArtifactIDs: [BASArtifactID]
    public let producerLayerID: BASSemanticLayerID
    public let scopeBinding: BASArtifactScopeBinding
    public let logicalEpoch: UInt64
    public let createdLogicalTime: UInt64
    public let canonicalPayloadBytes: Data
    public let payloadLength: UInt64
    public let confidentialityLabel: String
    public let provenanceArtifactIDs: [BASArtifactID]
    public let snapshotRootArtifactID: BASArtifactID?

    public init(
        canonicalizationVersion: String,
        schemaID: String,
        schemaVersion: String,
        kind: String,
        parentArtifactIDs: [BASArtifactID],
        producerLayerID: BASSemanticLayerID,
        scopeBinding: BASArtifactScopeBinding,
        logicalEpoch: UInt64,
        createdLogicalTime: UInt64,
        canonicalPayloadBytes: Data,
        payloadLength: UInt64,
        confidentialityLabel: String,
        provenanceArtifactIDs: [BASArtifactID],
        snapshotRootArtifactID: BASArtifactID?
    ) {
        self.canonicalizationVersion = canonicalizationVersion
        self.schemaID = schemaID
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.parentArtifactIDs = parentArtifactIDs
        self.producerLayerID = producerLayerID
        self.scopeBinding = scopeBinding
        self.logicalEpoch = logicalEpoch
        self.createdLogicalTime = createdLogicalTime
        self.canonicalPayloadBytes = canonicalPayloadBytes
        self.payloadLength = payloadLength
        self.confidentialityLabel = confidentialityLabel
        self.provenanceArtifactIDs = provenanceArtifactIDs
        self.snapshotRootArtifactID = snapshotRootArtifactID
    }
}

public struct BASArtifactStorageMetadataEntry:
    Codable, Sendable, Hashable
{
    public let key: String
    public let value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

public struct BASArtifactStorageEnvelope:
    Codable, Sendable, Hashable
{
    public let artifactID: BASArtifactID
    public let payloadRef: String
    public let storedLength: UInt64
    public let storageEncoding: String?
    public let compression: String?
    public let encryptionKeyID: String?
    public let encryptionMetadata: [BASArtifactStorageMetadataEntry]

    public init(
        artifactID: BASArtifactID,
        payloadRef: String,
        storedLength: UInt64,
        storageEncoding: String?,
        compression: String?,
        encryptionKeyID: String?,
        encryptionMetadata: [BASArtifactStorageMetadataEntry]
    ) {
        self.artifactID = artifactID
        self.payloadRef = payloadRef
        self.storedLength = storedLength
        self.storageEncoding = storageEncoding
        self.compression = compression
        self.encryptionKeyID = encryptionKeyID
        self.encryptionMetadata = encryptionMetadata
    }
}

public struct BASArtifactAttestationPayload:
    BASSchemaVersioned, Codable, Sendable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let targetArtifactID: BASArtifactID
    public let attestationPurpose: String
    public let producerReceiptArtifactID: BASArtifactID?
    public let usageReceiptArtifactIDs: [BASArtifactID]
    public let proofSuite: String
    public let keyID: String
    public let keyEpoch: UInt64
    public let custodyClass: String
    public let signedStatementDigest: String
    public let proofBytes: Data
    public let logicalTime: UInt64
    public let policyEpoch: UInt64

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        targetArtifactID: BASArtifactID,
        attestationPurpose: String,
        producerReceiptArtifactID: BASArtifactID?,
        usageReceiptArtifactIDs: [BASArtifactID],
        proofSuite: String,
        keyID: String,
        keyEpoch: UInt64,
        custodyClass: String,
        signedStatementDigest: String,
        proofBytes: Data,
        logicalTime: UInt64,
        policyEpoch: UInt64
    ) {
        self.schemaVersion = schemaVersion
        self.targetArtifactID = targetArtifactID
        self.attestationPurpose = attestationPurpose
        self.producerReceiptArtifactID = producerReceiptArtifactID
        self.usageReceiptArtifactIDs = usageReceiptArtifactIDs
        self.proofSuite = proofSuite
        self.keyID = keyID
        self.keyEpoch = keyEpoch
        self.custodyClass = custodyClass
        self.signedStatementDigest = signedStatementDigest
        self.proofBytes = proofBytes
        self.logicalTime = logicalTime
        self.policyEpoch = policyEpoch
    }
}

public struct BASArtifactMeshRecord:
    BASSchemaVersioned, Codable, Sendable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let artifactID: BASArtifactID
    public let identityCore: BASArtifactIdentityCore
    public let storage: BASArtifactStorageEnvelope

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        artifactID: BASArtifactID,
        identityCore: BASArtifactIdentityCore,
        storage: BASArtifactStorageEnvelope
    ) {
        self.schemaVersion = schemaVersion
        self.artifactID = artifactID
        self.identityCore = identityCore
        self.storage = storage
    }

    public var canonicalPayloadBytes: Data {
        identityCore.canonicalPayloadBytes
    }
}

public struct BASArtifactStoreReceiptBody:
    Codable, Sendable, Hashable
{
    public let artifactID: BASArtifactID
    public let storage: BASArtifactStorageEnvelope
    public let head: BASArtifactHead?

    public init(
        artifactID: BASArtifactID,
        storage: BASArtifactStorageEnvelope,
        head: BASArtifactHead?
    ) {
        self.artifactID = artifactID
        self.storage = storage
        self.head = head
    }
}

public typealias BASArtifactStoreReceipt = BASResult<BASArtifactStoreReceiptBody>

public enum BASArtifactMutableHeadScope:
    Codable, Sendable, Hashable
{
    case workspaceAuthority(BASArtifactID)
    case attempt(BASArtifactID)
}

public enum BASArtifactHeadPurpose:
    String, Codable, Sendable, Hashable
{
    case workspaceRoot
    case attemptRoot
    case semanticSnapshot
    case projectionCheckpoint
}

public enum BASArtifactHeadKeyLegacyProjectionError:
    Error, Sendable, Equatable
{
    case invalidBase64OrLength
    case nonCanonicalBase64
    case malformedFrame
    case unsupportedVersion
    case unsupportedScope
    case unsupportedPurpose
    case nonCanonicalProjection
}

public struct BASArtifactHeadKey: Codable, Sendable, Hashable {
    public let scope: BASArtifactMutableHeadScope
    public let purpose: BASArtifactHeadPurpose

    public init(
        scope: BASArtifactMutableHeadScope,
        purpose: BASArtifactHeadPurpose
    ) {
        self.scope = scope
        self.purpose = purpose
    }

    public func canonicalLegacyProjection() throws -> String {
        let scopeTag: String
        let scopeID: BASArtifactID
        switch scope {
        case .workspaceAuthority(let id):
            scopeTag = "workspace-authority"
            scopeID = id
        case .attempt(let id):
            scopeTag = "attempt"
            scopeID = id
        }
        let bytes = BASSovereignCanonicalBytes.lengthPrefixed([
            "bas-artifact-head-key-v1",
            scopeTag,
            try scopeID.storageScalar,
            purpose.rawValue,
        ])
        return bytes.base64EncodedString()
    }

    public init(
        validatingCanonicalLegacyProjection projection: String
    ) throws {
        guard !projection.isEmpty,
              projection.utf8.count <= 4_096,
              let bytes = Data(base64Encoded: projection),
              bytes.count <= 3_072
        else {
            throw BASArtifactHeadKeyLegacyProjectionError
                .invalidBase64OrLength
        }
        guard bytes.base64EncodedString() == projection else {
            throw BASArtifactHeadKeyLegacyProjectionError
                .nonCanonicalBase64
        }
        let fields = try Self.decodeLegacyFields(bytes)
        guard fields.count == 4 else {
            throw BASArtifactHeadKeyLegacyProjectionError.malformedFrame
        }
        guard fields[0] == "bas-artifact-head-key-v1" else {
            throw BASArtifactHeadKeyLegacyProjectionError.unsupportedVersion
        }
        let id = try BASArtifactID(storageScalar: fields[2])
        if fields[1] == "workspace-authority" {
            self.scope = .workspaceAuthority(id)
        } else if fields[1] == "attempt" {
            self.scope = .attempt(id)
        } else {
            throw BASArtifactHeadKeyLegacyProjectionError.unsupportedScope
        }
        guard let purpose = BASArtifactHeadPurpose(
            rawValue: fields[3])
        else {
            throw BASArtifactHeadKeyLegacyProjectionError.unsupportedPurpose
        }
        self.purpose = purpose
        guard try canonicalLegacyProjection() == projection else {
            throw BASArtifactHeadKeyLegacyProjectionError
                .nonCanonicalProjection
        }
    }

    private static func decodeLegacyFields(
        _ bytes: Data
    ) throws -> [String] {
        let input = Array(bytes)
        var fields: [String] = []
        var index = 0
        while index < input.count {
            let start = index
            var length = 0
            while index < input.count,
                  input[index] >= 48,
                  input[index] <= 57
            {
                guard index - start < 4,
                      !(index > start && input[start] == 48)
                else {
                    throw BASArtifactHeadKeyLegacyProjectionError
                        .malformedFrame
                }
                length = length * 10 + Int(input[index] - 48)
                index += 1
            }
            guard index > start,
                  index < input.count,
                  input[index] == 58,
                  length <= 1_024
            else {
                throw BASArtifactHeadKeyLegacyProjectionError
                    .malformedFrame
            }
            index += 1
            guard length <= input.count - index else {
                throw BASArtifactHeadKeyLegacyProjectionError
                    .malformedFrame
            }
            let end = index + length
            guard let field = String(
                bytes: input[index..<end], encoding: .utf8)
            else {
                throw BASArtifactHeadKeyLegacyProjectionError
                    .malformedFrame
            }
            fields.append(field)
            guard fields.count <= 5 else {
                throw BASArtifactHeadKeyLegacyProjectionError
                    .malformedFrame
            }
            index = end
        }
        return fields
    }
}

public struct BASArtifactHead: Codable, Sendable, Hashable {
    public let key: BASArtifactHeadKey
    public let artifactID: BASArtifactID
    public let revision: UInt64

    public init(
        key: BASArtifactHeadKey,
        artifactID: BASArtifactID,
        revision: UInt64
    ) {
        self.key = key
        self.artifactID = artifactID
        self.revision = revision
    }
}

public struct BASArtifactHeadCAS: Codable, Sendable, Hashable {
    public let key: BASArtifactHeadKey
    public let expected: BASArtifactHead?
    public let replacementArtifactID: BASArtifactID

    public init(
        key: BASArtifactHeadKey,
        expected: BASArtifactHead?,
        replacementArtifactID: BASArtifactID
    ) {
        self.key = key
        self.expected = expected
        self.replacementArtifactID = replacementArtifactID
    }
}

public protocol BASArtifactStorePort: AnyObject, Sendable {
    func put(
        identityCore: BASArtifactIdentityCore,
        headUpdate: BASArtifactHeadCAS?
    ) async throws -> BASArtifactStoreReceipt

    func read(
        _ artifactID: BASArtifactID
    ) async throws -> BASArtifactMeshRecord

    func head(
        _ key: BASArtifactHeadKey
    ) async throws -> BASArtifactHead?

    func attestationArtifactIDs(
        targeting artifactID: BASArtifactID
    ) async throws -> BASBundle<BASArtifactID>
}

public typealias BASArtifactCommitmentKeyResolver =
    @Sendable (UInt64) throws -> SymmetricKey

public enum BASGovernedArtifactPayloadCodecError:
    Error, Sendable, Equatable
{
    case nonCurrentWrite(
        typeName: String, found: String, expected: String)
    case unsupportedRead(
        typeName: String, found: String, expected: String)
}

public enum BASCanonicalPayloadValidationError:
    Error, Sendable, Equatable
{
    case emptyOrOversized(actualBytes: Int)
    case topLevelObjectRequired
    case missingSchemaVersion
    case nonCanonicalJSON
    case payloadSchemaMismatch(found: String, expected: String)
}

private struct BASCanonicalJSONKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private indirect enum BASCanonicalJSONValue: Codable {
    case object([String: Self])
    case array([Self])
    case string(String)
    case signed(Int64)
    case unsigned(UInt64)
    case floating(Double)
    case boolean(Bool)
    case null

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(
            keyedBy: BASCanonicalJSONKey.self)
        {
            var members: [String: Self] = [:]
            members.reserveCapacity(container.allKeys.count)
            for key in container.allKeys {
                members[key.stringValue] = try container.decode(
                    Self.self, forKey: key)
            }
            self = .object(members)
            return
        }
        if var container = try? decoder.unkeyedContainer() {
            var elements: [Self] = []
            if let count = container.count {
                elements.reserveCapacity(count)
            }
            while !container.isAtEnd {
                elements.append(try container.decode(Self.self))
            }
            self = .array(elements)
            return
        }
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .signed(value)
        } else if let value = try? container.decode(UInt64.self) {
            self = .unsigned(value)
        } else if let value = try? container.decode(Double.self) {
            self = .floating(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .object(let members):
            var container = encoder.container(
                keyedBy: BASCanonicalJSONKey.self)
            for (name, value) in members {
                guard let key = BASCanonicalJSONKey(
                    stringValue: name)
                else {
                    preconditionFailure("dynamic JSON key must be valid")
                }
                try container.encode(value, forKey: key)
            }
        case .array(let elements):
            var container = encoder.unkeyedContainer()
            for element in elements {
                try container.encode(element)
            }
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .signed(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .unsigned(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .floating(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .boolean(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

public enum BASCanonicalPayloadValidator {
    public static let maximumPayloadBytes = 16_777_216
    package static let maximumRecordBytes = 33_554_432
    public static let governedCanonicalizationVersion =
        "bas-governed-artifact-payload-v1"

    public static func canonicalBytes<T: Encodable>(
        for value: T
    ) throws -> Data {
        try canonicalBytes(
            for: value,
            maximumBytes: value is BASArtifactMeshRecord
                ? maximumRecordBytes
                : maximumPayloadBytes)
    }

    fileprivate static func canonicalBytes<T: Encodable>(
        for value: T,
        maximumBytes: Int
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys,
            .withoutEscapingSlashes,
        ]
        let bytes = try encoder.encode(value)
        try validateCanonicalJSON(
            bytes, maximumBytes: maximumBytes)
        return bytes
    }

    public static func validateCanonicalJSON(_ bytes: Data) throws {
        try validateCanonicalJSON(
            bytes, maximumBytes: maximumPayloadBytes)
    }

    fileprivate static func validateCanonicalJSON(
        _ bytes: Data,
        maximumBytes: Int
    ) throws {
        try validateSize(bytes, maximumBytes: maximumBytes)
        let value = try JSONDecoder().decode(
            BASCanonicalJSONValue.self, from: bytes)
        guard case .object = value else {
            throw BASCanonicalPayloadValidationError
                .topLevelObjectRequired
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys,
            .withoutEscapingSlashes,
        ]
        let normalized = try encoder.encode(value)
        guard normalized == bytes else {
            throw BASCanonicalPayloadValidationError.nonCanonicalJSON
        }
    }

    public static func schemaVersion(in bytes: Data) throws -> String? {
        try schemaVersion(
            in: bytes, maximumBytes: maximumPayloadBytes)
    }

    fileprivate static func schemaVersion(
        in bytes: Data,
        maximumBytes: Int
    ) throws -> String? {
        try validateSize(bytes, maximumBytes: maximumBytes)
        let object = try JSONSerialization.jsonObject(with: bytes)
        guard let dictionary = object as? [String: Any] else {
            throw BASCanonicalPayloadValidationError
                .topLevelObjectRequired
        }
        return dictionary["schemaVersion"] as? String
    }

    fileprivate static func validateSize(_ bytes: Data) throws {
        try validateSize(
            bytes, maximumBytes: maximumPayloadBytes)
    }

    fileprivate static func validateSize(
        _ bytes: Data,
        maximumBytes: Int
    ) throws {
        guard !bytes.isEmpty,
              bytes.count <= maximumBytes
        else {
            throw BASCanonicalPayloadValidationError
                .emptyOrOversized(actualBytes: bytes.count)
        }
    }
}

public enum BASGovernedArtifactPayloadCodec {
    public static func canonicalBytes<T: BASSchemaVersioned>(
        for value: T
    ) throws -> Data {
        guard value.schemaVersion == T.currentSchemaVersion else {
            throw BASGovernedArtifactPayloadCodecError.nonCurrentWrite(
                typeName: String(reflecting: T.self),
                found: value.schemaVersion,
                expected: T.currentSchemaVersion)
        }
        return try BASCanonicalPayloadValidator.canonicalBytes(
            for: value,
            maximumBytes: maximumWireBytes(for: T.self))
    }

    public static func decodeCurrent<T: BASSchemaVersioned>(
        _ type: T.Type,
        from canonicalBytes: Data
    ) throws -> T {
        let maximumBytes = maximumWireBytes(for: T.self)
        try BASCanonicalPayloadValidator.validateSize(
            canonicalBytes, maximumBytes: maximumBytes)
        let found = try BASCanonicalPayloadValidator
            .schemaVersion(
                in: canonicalBytes, maximumBytes: maximumBytes)
        guard let found,
              found == T.currentSchemaVersion
        else {
            throw BASGovernedArtifactPayloadCodecError.unsupportedRead(
                typeName: String(reflecting: T.self),
                found: found ?? "<missing>",
                expected: T.currentSchemaVersion)
        }
        let decoded = try JSONDecoder().decode(T.self, from: canonicalBytes)
        guard decoded.schemaVersion == T.currentSchemaVersion else {
            throw BASGovernedArtifactPayloadCodecError.unsupportedRead(
                typeName: String(reflecting: T.self),
                found: decoded.schemaVersion,
                expected: T.currentSchemaVersion)
        }
        let reencoded = try Self.canonicalBytes(for: decoded)
        guard reencoded == canonicalBytes else {
            throw BASCanonicalPayloadValidationError.nonCanonicalJSON
        }
        return decoded
    }

    private static func maximumWireBytes<T>(
        for type: T.Type
    ) -> Int {
        ObjectIdentifier(type)
            == ObjectIdentifier(BASArtifactMeshRecord.self)
            ? BASCanonicalPayloadValidator.maximumRecordBytes
            : BASCanonicalPayloadValidator.maximumPayloadBytes
    }
}

public enum BASArtifactMeshError: Error, Sendable, Equatable {
    case invalidIdentityField(String)
    case payloadLengthMismatch(expected: UInt64, actual: UInt64)
    case payloadSchemaMismatch(found: String, expected: String)
    case attemptPayloadContainsLegacyIdentity(String)
    case durableWarrantRequiresAuditArtifact
    case unsupportedIntegrityAlgorithm(String)
    case identityVerificationFailed
    case malformedRecord(String)
}

public enum BASArtifactMesh {
    public static let integrityAlgorithm = "hmac-sha256"

    public static func canonicalIdentityBytes(
        for identityCore: BASArtifactIdentityCore
    ) throws -> Data {
        try validateIdentity(identityCore)
        var fields = [
            "bas-artifact-identity-v1",
            identityCore.canonicalizationVersion,
            identityCore.schemaID,
            identityCore.schemaVersion,
            identityCore.kind,
            String(identityCore.parentArtifactIDs.count),
        ]
        for parent in identityCore.parentArtifactIDs {
            fields.append(try parent.storageScalar)
        }
        fields.append(identityCore.producerLayerID.rawValue)
        switch identityCore.scopeBinding {
        case .publicArtifact:
            fields.append("public")
        case .workspaceAuthority(let id):
            fields.append("workspace-authority")
            fields.append(try id.storageScalar)
        case .attempt(let id):
            fields.append("attempt")
            fields.append(try id.storageScalar)
        case .durableWarrant(let id):
            fields.append("durable-warrant")
            fields.append(try id.storageScalar)
        }
        fields.append(String(identityCore.logicalEpoch))
        fields.append(String(identityCore.createdLogicalTime))
        fields.append(
            identityCore.canonicalPayloadBytes.base64EncodedString())
        fields.append(String(identityCore.payloadLength))
        fields.append(identityCore.confidentialityLabel)
        fields.append(String(identityCore.provenanceArtifactIDs.count))
        for provenance in identityCore.provenanceArtifactIDs {
            fields.append(try provenance.storageScalar)
        }
        if let snapshot = identityCore.snapshotRootArtifactID {
            fields.append("1")
            fields.append(try snapshot.storageScalar)
        } else {
            fields.append("0")
        }
        return BASSovereignCanonicalBytes.lengthPrefixed(fields)
    }

    public static func artifactID(
        for identityCore: BASArtifactIdentityCore,
        commitmentKey: SymmetricKey,
        commitmentKeyEpoch: UInt64
    ) throws -> BASArtifactID {
        let bytes = try canonicalIdentityBytes(for: identityCore)
        let code = HMAC<SHA256>.authenticationCode(
            for: bytes, using: commitmentKey)
        return BASArtifactID(
            integrityAlgorithm: integrityAlgorithm,
            commitmentKeyEpoch: commitmentKeyEpoch,
            commitmentHex: code.map { String(format: "%02x", $0) }
                .joined())
    }

    public static func verify(
        _ artifactID: BASArtifactID,
        for identityCore: BASArtifactIdentityCore,
        commitmentKey: SymmetricKey
    ) throws {
        _ = try artifactID.storageScalar
        guard artifactID.integrityAlgorithm == integrityAlgorithm else {
            throw BASArtifactMeshError.unsupportedIntegrityAlgorithm(
                artifactID.integrityAlgorithm)
        }
        let bytes = try canonicalIdentityBytes(for: identityCore)
        guard let code = Data(lowercaseHex: artifactID.commitmentHex),
              HMAC<SHA256>.isValidAuthenticationCode(
                  code, authenticating: bytes, using: commitmentKey)
        else {
            throw BASArtifactMeshError.identityVerificationFailed
        }
    }

    public static func verify(
        _ record: BASArtifactMeshRecord,
        commitmentKey: SymmetricKey
    ) throws {
        guard record.schemaVersion
                == BASArtifactMeshRecord.currentSchemaVersion,
              record.artifactID == record.storage.artifactID,
              !record.storage.payloadRef.isEmpty
        else {
            throw BASArtifactMeshError.malformedRecord(
                "record and storage envelope disagree")
        }
        try verify(
            record.artifactID,
            for: record.identityCore,
            commitmentKey: commitmentKey)
    }

    private static func validateIdentity(
        _ core: BASArtifactIdentityCore
    ) throws {
        for (name, value, maximum) in [
            ("canonicalizationVersion", core.canonicalizationVersion, 128),
            ("schemaID", core.schemaID, 256),
            ("schemaVersion", core.schemaVersion, 64),
            ("kind", core.kind, 256),
            ("confidentialityLabel", core.confidentialityLabel, 256),
        ] {
            guard !value.isEmpty,
                  value.utf8.count <= maximum
            else {
                throw BASArtifactMeshError.invalidIdentityField(name)
            }
        }
        guard core.parentArtifactIDs.count <= 1_024,
              core.provenanceArtifactIDs.count <= 1_024
        else {
            throw BASArtifactMeshError.invalidIdentityField(
                "ordered Artifact ID vector")
        }
        guard let actualLength = UInt64(
            exactly: core.canonicalPayloadBytes.count),
              actualLength == core.payloadLength
        else {
            throw BASArtifactMeshError.payloadLengthMismatch(
                expected: core.payloadLength,
                actual: UInt64(core.canonicalPayloadBytes.count))
        }
        try BASCanonicalPayloadValidator.validateSize(
            core.canonicalPayloadBytes)
        try BASCanonicalPayloadValidator.validateCanonicalJSON(
            core.canonicalPayloadBytes)
        let found = try BASCanonicalPayloadValidator.schemaVersion(
            in: core.canonicalPayloadBytes)
        guard let found,
              found == core.schemaVersion
        else {
            throw BASArtifactMeshError.payloadSchemaMismatch(
                found: found ?? "<missing>",
                expected: core.schemaVersion)
        }
        if case .attempt = core.scopeBinding {
            let object = try? JSONSerialization.jsonObject(
                with: core.canonicalPayloadBytes)
            for forbidden in ["turnID", "branchID"] {
                if containsKey(forbidden, in: object) {
                    throw BASArtifactMeshError
                        .attemptPayloadContainsLegacyIdentity(forbidden)
                }
            }
        }
        if case .durableWarrant = core.scopeBinding {
            let kind = core.kind.lowercased()
            guard !kind.contains("executable"),
                  kind.contains("warrant")
                    || kind.contains("audit")
                    || kind.contains("attestation")
            else {
                throw BASArtifactMeshError
                    .durableWarrantRequiresAuditArtifact
            }
        }
        for id in core.parentArtifactIDs
            + core.provenanceArtifactIDs
            + [core.snapshotRootArtifactID].compactMap({ $0 })
        {
            _ = try id.storageScalar
        }
    }

    private static func containsKey(
        _ key: String,
        in object: Any?
    ) -> Bool {
        if let dictionary = object as? [String: Any] {
            if dictionary[key] != nil { return true }
            return dictionary.values.contains {
                containsKey(key, in: $0)
            }
        }
        if let array = object as? [Any] {
            return array.contains { containsKey(key, in: $0) }
        }
        return false
    }
}

private extension Data {
    init?(lowercaseHex: String) {
        let bytes = Array(lowercaseHex.utf8)
        guard bytes.count.isMultiple(of: 2) else { return nil }
        var output = Data(capacity: bytes.count / 2)
        var index = 0
        while index < bytes.count {
            func nibble(_ byte: UInt8) -> UInt8? {
                if byte >= 48, byte <= 57 { return byte - 48 }
                if byte >= 97, byte <= 102 { return byte - 87 }
                return nil
            }
            guard let high = nibble(bytes[index]),
                  let low = nibble(bytes[index + 1])
            else {
                return nil
            }
            output.append(high << 4 | low)
            index += 2
        }
        self = output
    }
}
