import XCTest
@testable import HeatPeekCore

final class ThresholdTests: XCTestCase {
    private func snapshot(celsius: Double, rpm: Double? = 2500) -> Snapshot {
        Snapshot(
            timestamp: .now,
            temperatures: [TemperatureReading(sensor: "PMU tdie1", celsius: celsius)],
            gpuUtilizationPercent: 40,
            gpuPowerWatts: 3,
            fans: rpm.map { [FanReader.Fan(name: "Fan 1", rpm: $0)] } ?? [],
            unavailable: [:]
        )
    }

    func testTemperatureWarnsAtOrAboveThreshold() {
        XCTAssertFalse(Formatting.titleSegments(snapshot(celsius: 84.9), warnCelsius: 85)[0].isWarning)
        XCTAssertTrue(Formatting.titleSegments(snapshot(celsius: 85), warnCelsius: 85)[0].isWarning)
        XCTAssertTrue(Formatting.titleSegments(snapshot(celsius: 99), warnCelsius: 85)[0].isWarning)
    }

    func testNilThresholdNeverWarns() {
        XCTAssertFalse(Formatting.titleSegments(snapshot(celsius: 109), warnCelsius: nil)[0].isWarning)
    }

    func testOnlyTheTemperatureFieldCarriesTheWarning() {
        let segments = Formatting.titleSegments(snapshot(celsius: 95), warnCelsius: 85)
        XCTAssertEqual(segments.map(\.isWarning), [true, false, false, false])
    }

    func testMissingTemperatureCannotWarn() {
        let empty = Snapshot(
            timestamp: .now,
            temperatures: [],
            gpuUtilizationPercent: nil,
            gpuPowerWatts: nil,
            fans: [],
            unavailable: [:]
        )
        let segments = Formatting.titleSegments(empty, warnCelsius: 85)
        XCTAssertEqual(segments.map(\.text), ["--", "--", "--", "--"])
        XCTAssertFalse(segments.contains(where: \.isWarning))
    }

    func testFanIsTheFourthField() {
        let segments = Formatting.titleSegments(snapshot(celsius: 60, rpm: 2506.2))
        XCTAssertEqual(segments.count, 4)
        XCTAssertEqual(segments[3].text, "2506r")
        XCTAssertEqual(Formatting.titleSegments(snapshot(celsius: 60, rpm: nil))[3].text, "--")
    }

    func testMenuBarTitleJoinsWithDoubleSpace() {
        XCTAssertEqual(
            Formatting.menuBarTitle(snapshot(celsius: 88), warnCelsius: 85),
            "88°  40%  3.0W  2500r"
        )
    }
}
