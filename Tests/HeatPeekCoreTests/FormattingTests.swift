import XCTest
@testable import HeatPeekCore

final class FormattingTests: XCTestCase {
    private func snapshot(
        temperature: Double? = 73.4,
        gpu: Double? = 68,
        watts: Double? = 3.42
    ) -> Snapshot {
        Snapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            temperatures: temperature.map { [TemperatureReading(sensor: "PMU tdie1", celsius: $0)] } ?? [],
            gpuUtilizationPercent: gpu,
            gpuPowerWatts: watts,
            unavailable: [:]
        )
    }

    func testMenuBarTitleKeepsThreeFields() {
        XCTAssertEqual(Formatting.menuBarTitle(snapshot()), "73°  68%  3.4W")
    }

    func testMenuBarTitlePlaceholdersForMissingSources() {
        let partial = Snapshot(
            timestamp: .now,
            temperatures: [],
            gpuUtilizationPercent: 12,
            gpuPowerWatts: nil,
            unavailable: ["temperature": "no HID temperature services"]
        )
        XCTAssertEqual(Formatting.menuBarTitle(partial), "--  12%  --")
    }

    func testWattsSwitchesPrecisionAtTen() {
        XCTAssertEqual(Formatting.watts(9.94), "9.9W")
        XCTAssertEqual(Formatting.watts(9.96), "10.0W")
        XCTAssertEqual(Formatting.watts(42.6), "43W")
    }

    func testMaxTemperaturePicksHottestSensor() throws {
        let reading = try XCTUnwrap(snapshot(temperature: 88.2).maxTemperature)
        XCTAssertEqual(reading.sensor, "PMU tdie1")
        XCTAssertEqual(reading.celsius, 88.2, accuracy: 0.001)
    }

    func testAverageTemperatureIsNilWithoutSensors() {
        XCTAssertNil(snapshot(temperature: nil).averageTemperature)
    }

    func testJSONRoundTripsAndIsStable() throws {
        let first = try Formatting.json(snapshot())
        let second = try Formatting.json(snapshot())
        XCTAssertEqual(first, second, "sorted keys must make output deterministic")
        XCTAssertTrue(first.contains("\"gpuPowerWatts\" : 3.42"))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Snapshot.self, from: Data(first.utf8))
        XCTAssertEqual(decoded, snapshot())
    }

    func testPlainTextListsUnavailableSources() {
        let partial = Snapshot(
            timestamp: .now,
            temperatures: [],
            gpuUtilizationPercent: nil,
            gpuPowerWatts: nil,
            unavailable: ["power": "no GPU Energy channel"]
        )
        XCTAssertEqual(Formatting.plainText(partial), "power        unavailable: no GPU Energy channel")
    }
}
