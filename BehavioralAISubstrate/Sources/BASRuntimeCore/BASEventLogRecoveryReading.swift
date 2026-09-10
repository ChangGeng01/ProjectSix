import Foundation

/// Value-only budgets for one complete session recovery read.
///
/// Encoded-byte limits charge the UTF-8 length of every text value materialized
/// for an event plus the raw length of its payload blob: event/session identity,
/// kind, risk band, payload JSON and payload blob. UTF-8 databases use SQLite's
/// incremental-value metadata without reading content; legacy UTF-16 databases
/// are counted through fixed-size, budget-stopping incremental reads. When
/// recorded-chain verification is requested, its event/session identity and
/// hash/link text are charged to the same per-row and aggregate budgets. Fixed
/// SQLite/Swift object overhead and fixed-width integer columns are not charged.
public struct BASEventLogRecoveryReadLimits: Sendable, Equatable {
    public let maximumEventCount: Int
    public let maximumEncodedEventBytes: Int
    public let maximumTotalEncodedBytes: Int

    public init(
        maximumEventCount: Int,
        maximumEncodedEventBytes: Int,
        maximumTotalEncodedBytes: Int
    ) throws {
        guard maximumEventCount > 0,
              maximumEventCount < Int.max,
              maximumEncodedEventBytes > 0,
              maximumTotalEncodedBytes > 0
        else {
            throw BASEventLogRecoveryReadError.invalidLimits
        }
        self.maximumEventCount = maximumEventCount
        self.maximumEncodedEventBytes = maximumEncodedEventBytes
        self.maximumTotalEncodedBytes = maximumTotalEncodedBytes
    }
}

public enum BASEventLogRecoveryIntegrityRequirement: Sendable, Equatable {
    case none
    case recordedChain
}

public enum BASEventLogRecoveryReadError: Error, Sendable, Equatable {
    case invalidLimits
    case eventCountLimitExceeded
    case eventByteLimitExceeded
    case totalByteLimitExceeded
    case malformedRecord
    case unsupportedRecord
    case missingIntegrity
    case invalidIntegrity
}

public protocol BASEventLogRecoveryReading: Sendable {
    func recoveryEvents(
        forSession sessionID: String,
        limits: BASEventLogRecoveryReadLimits,
        integrity: BASEventLogRecoveryIntegrityRequirement
    ) async throws -> [BASEventLogEntry]
}
