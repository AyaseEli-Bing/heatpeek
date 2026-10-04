import Foundation

/// Reuses a value for up to `cadence` seconds.
///
/// Each HID temperature sensor costs about a millisecond of IPC, so sampling all ~44 of them on
/// every menu bar tick dominated the app's CPU time. Heat moves far slower than that anyway.
public struct SampleCache<Value: Sendable & Equatable>: Sendable, Equatable {
    public let cadence: TimeInterval
    private var stored: Value?
    private var storedAt: Date?

    public init(cadence: TimeInterval) {
        self.cadence = cadence
    }

    public func cached(at now: Date) -> Value? {
        guard let stored, let storedAt, now.timeIntervalSince(storedAt) < cadence else { return nil }
        return stored
    }

    public mutating func store(_ value: Value, at now: Date) {
        stored = value
        storedAt = now
    }
}
