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
        // Threshold above the reading, so this case stays about the separator. The warning
        // state changes the first token and has its own cases below.
        XCTAssertEqual(
            Formatting.menuBarTitle(snapshot(celsius: 88), warnCelsius: 100),
            "88°  40%  3.0W  2500r"
        )
    }

    // MARK: - Non-colour warning cue

    func testWarningPrefixesTheTemperatureWithTheMarker() {
        let segments = Formatting.titleSegments(snapshot(celsius: 95), warnCelsius: 85)
        XCTAssertEqual(segments[0].text, "▲95°")
        XCTAssertTrue(segments[0].text.hasPrefix("▲"), "marker must lead, not trail")
    }

    func testMarkerAppearsExactlyAtTheThreshold() {
        let below = Formatting.titleSegments(snapshot(celsius: 84.9), warnCelsius: 85)[0]
        let at = Formatting.titleSegments(snapshot(celsius: 85), warnCelsius: 85)[0]
        XCTAssertFalse(below.text.hasPrefix("▲"), "below threshold must stay unmarked")
        XCTAssertEqual(at.text, "▲85°", "the threshold itself is inclusive")
    }

    func testNoMarkerBelowThresholdOrWithoutOne() {
        XCTAssertFalse(Formatting.titleSegments(snapshot(celsius: 40), warnCelsius: 85)[0].text.hasPrefix("▲"))
        XCTAssertFalse(Formatting.titleSegments(snapshot(celsius: 109), warnCelsius: nil)[0].text.hasPrefix("▲"))
    }

    func testMarkerStaysOnTheTemperatureFieldOnly() {
        let segments = Formatting.titleSegments(snapshot(celsius: 95), warnCelsius: 85)
        XCTAssertEqual(segments.count, 4)
        XCTAssertTrue(segments[0].text.hasPrefix("▲"))
        for segment in segments.dropFirst() {
            XCTAssertFalse(segment.text.contains("▲"), "unexpected marker on \(segment.text)")
        }
        XCTAssertEqual(segments.map(\.text), ["▲95°", "40%", "3.0W", "2500r"])
    }

    func testMarkerKeepsTheColourChannelAlive() {
        let segment = Formatting.titleSegments(snapshot(celsius: 95), warnCelsius: 85)[0]
        XCTAssertTrue(segment.isWarning, "StatusItemController still paints on this flag")
    }

    func testMissingTemperatureStaysUnmarked() {
        let empty = Snapshot(
            timestamp: .now,
            temperatures: [],
            gpuUtilizationPercent: nil,
            gpuPowerWatts: nil,
            fans: [],
            unavailable: [:]
        )
        XCTAssertEqual(Formatting.titleSegments(empty, warnCelsius: 85)[0].text, "--")
    }

    func testMarkerStaysOutOfJSON() throws {
        let json = try Formatting.json(snapshot(celsius: 95))
        XCTAssertFalse(json.contains("▲"), "the cue is a menu bar concern, not a data field")
        for key in ["timestamp", "temperatures", "gpuUtilizationPercent", "gpuPowerWatts", "fans", "unavailable"] {
            XCTAssertTrue(json.contains("\"\(key)\""), "missing key \(key)")
        }
        XCTAssertTrue(json.contains("\"celsius\" : 95"), "the reading itself is unchanged:\n\(json)")
    }

    func testMenuBarTitleInheritsTheMarker() {
        XCTAssertEqual(
            Formatting.menuBarTitle(snapshot(celsius: 88), warnCelsius: 85),
            "▲88°  40%  3.0W  2500r"
        )
    }
}
