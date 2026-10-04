import Foundation

public actor Sampler {
    private static let temperatureCadence: TimeInterval = 5

    private let temperature: TemperatureReader
    private let energy: EnergyReader
    private let fan: FanReader
    private var temperatureCache = SampleCache<[TemperatureReading]>(cadence: temperatureCadence)

    public init(
        temperature: TemperatureReader = .init(),
        energy: EnergyReader = .init(),
        fan: FanReader = .init()
    ) {
        self.temperature = temperature
        self.energy = energy
        self.fan = fan
    }

    public func sample(now: Date = .now) async -> Snapshot {
        var unavailable: [String: String] = [:]
        var elapsed: [String: Double] = [:]
        let started = ContinuousClock.now

        let readings: [TemperatureReading]
        if let cached = temperatureCache.cached(at: now) {
            readings = cached
            elapsed["temp"] = 0
        } else {
            readings = await temperature.read()
            temperatureCache.store(readings, at: now)
            elapsed["temp"] = milliseconds(since: started)
        }
        if readings.isEmpty {
            unavailable["temperature"] = await temperature.reasonIfUnavailable() ?? "no HID temperature services"
        }

        var mark = ContinuousClock.now
        let utilization = GPUReader.read()
        elapsed["gpu"] = milliseconds(since: mark)
        if utilization == nil {
            unavailable["gpu"] = "IOAccelerator PerformanceStatistics unavailable"
        }

        mark = ContinuousClock.now
        var watts: Double?
        switch await energy.read(now: now) {
        case let .watts(value): watts = value
        case let .unavailable(reason): unavailable["power"] = reason
        case .pending: break
        }
        elapsed["power"] = milliseconds(since: mark)

        mark = ContinuousClock.now
        let fans = await fan.read()
        elapsed["fan"] = milliseconds(since: mark)
        if fans.isEmpty {
            unavailable["fan"] = await fan.reasonIfUnavailable() ?? "no SMC fan keys"
        }

        let snapshot = Snapshot(
            timestamp: now,
            temperatures: readings,
            gpuUtilizationPercent: utilization?.percent,
            gpuPowerWatts: watts,
            fans: fans,
            unavailable: unavailable
        )
        Log.sampler.debug("sample — sensors=\(readings.count, privacy: .public) total=\(String(format: "%.1f", self.milliseconds(since: started)), privacy: .public)ms temp=\(String(format: "%.1f", elapsed["temp"] ?? 0), privacy: .public) gpu=\(String(format: "%.1f", elapsed["gpu"] ?? 0), privacy: .public) power=\(String(format: "%.1f", elapsed["power"] ?? 0), privacy: .public) fan=\(String(format: "%.1f", elapsed["fan"] ?? 0), privacy: .public)")
        return snapshot
    }

    private func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: .now)
        return Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
    }

    /// Two consecutive samples, for callers that need power immediately (one-shot CLI mode).
    public func samplePair(firstDelay: TimeInterval = 1) async -> Snapshot {
        _ = await sample()
        try? await Task.sleep(nanoseconds: UInt64(firstDelay * 1_000_000_000))
        return await sample()
    }
}
