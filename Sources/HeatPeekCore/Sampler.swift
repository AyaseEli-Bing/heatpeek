import Foundation

public actor Sampler {
    private let temperature: TemperatureReader
    private let energy: EnergyReader
    private let fan: FanReader

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

        let readings = await temperature.read()
        if readings.isEmpty {
            unavailable["temperature"] = await temperature.reasonIfUnavailable() ?? "no HID temperature services"
        }

        let utilization = GPUReader.read()
        if utilization == nil {
            unavailable["gpu"] = "IOAccelerator PerformanceStatistics unavailable"
        }

        var watts: Double?
        switch await energy.read(now: now) {
        case let .watts(value): watts = value
        case let .unavailable(reason): unavailable["power"] = reason
        case .pending: break
        }

        let fans = await fan.read()
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
        Log.sampler.debug("sample — sensors=\(readings.count, privacy: .public) gpu=\(utilization?.percent ?? -1, privacy: .public) watts=\(watts ?? -1, privacy: .public)")
        return snapshot
    }

    /// Two consecutive samples, for callers that need power immediately (one-shot CLI mode).
    public func samplePair(firstDelay: TimeInterval = 1) async -> Snapshot {
        _ = await sample()
        try? await Task.sleep(nanoseconds: UInt64(firstDelay * 1_000_000_000))
        return await sample()
    }
}
