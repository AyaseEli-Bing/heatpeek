import Foundation

public struct TemperatureReading: Codable, Sendable, Equatable {
    public let sensor: String
    public let celsius: Double

    public init(sensor: String, celsius: Double) {
        self.sensor = sensor
        self.celsius = celsius
    }
}

public struct Snapshot: Codable, Sendable, Equatable {
    public let timestamp: Date
    public let temperatures: [TemperatureReading]
    public let gpuUtilizationPercent: Double?
    public let gpuPowerWatts: Double?
    public let fans: [FanReader.Fan]
    public let unavailable: [String: String]

    public init(
        timestamp: Date,
        temperatures: [TemperatureReading],
        gpuUtilizationPercent: Double?,
        gpuPowerWatts: Double?,
        fans: [FanReader.Fan] = [],
        unavailable: [String: String]
    ) {
        self.timestamp = timestamp
        self.temperatures = temperatures
        self.gpuUtilizationPercent = gpuUtilizationPercent
        self.gpuPowerWatts = gpuPowerWatts
        self.fans = fans
        self.unavailable = unavailable
    }

    public var maxTemperature: TemperatureReading? { temperatures.max(by: { $0.celsius < $1.celsius }) }

    public var maxFanRPM: Double? { fans.map(\.rpm).max() }

    public var averageTemperature: Double? {
        guard !temperatures.isEmpty else { return nil }
        return temperatures.map(\.celsius).reduce(0, +) / Double(temperatures.count)
    }

    public static let empty = Snapshot(
        timestamp: .init(),
        temperatures: [],
        gpuUtilizationPercent: nil,
        gpuPowerWatts: nil,
        fans: [],
        unavailable: [:]
    )

    private enum CodingKeys: String, CodingKey {
        case timestamp, temperatures, gpuUtilizationPercent, gpuPowerWatts, fans, unavailable
    }

    /// Synthesized encoding drops nil keys, which would make the `--json` shape depend on the
    /// hardware. Encoding explicitly keeps every documented key present, as null when absent.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(temperatures, forKey: .temperatures)
        try container.encode(gpuUtilizationPercent, forKey: .gpuUtilizationPercent)
        try container.encode(gpuPowerWatts, forKey: .gpuPowerWatts)
        try container.encode(fans, forKey: .fans)
        try container.encode(unavailable, forKey: .unavailable)
    }
}
