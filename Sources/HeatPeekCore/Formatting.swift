import Foundation

/// One field of the menu bar readout. The warning flag lives here, not in the UI, so the
/// threshold decision is testable without AppKit.
public struct TitleSegment: Sendable, Equatable {
    public let text: String
    public let isWarning: Bool

    public init(text: String, isWarning: Bool = false) {
        self.text = text
        self.isWarning = isWarning
    }
}

public enum Formatting {
    /// Non-colour warning cue. Red alone fails for red-green colour deficiency and under
    /// macOS "Differentiate without colour", so the text carries a second channel and the
    /// colour stays as the redundant one. U+25B2, not an emoji: it has glyphs in the menu
    /// bar font, so nothing falls back to a colour emoji and undoes the point.
    public static let warningMarker = "\u{25B2}"

    public static func celsius(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }

    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    public static func watts(_ value: Double) -> String {
        value >= 10 ? "\(Int(value.rounded()))W" : "\(String(format: "%.1f", value))W"
    }

    public static func rpm(_ value: Double) -> String {
        "\(Int(value.rounded()))r"
    }

    /// A missing source renders as `--` so the readout keeps a stable shape.
    public static func titleSegments(_ snapshot: Snapshot, warnCelsius: Double? = nil) -> [TitleSegment] {
        let temperature = snapshot.maxTemperature
        let hot = warnCelsius.flatMap { threshold in
            temperature.map { $0.celsius >= threshold }
        } ?? false
        // Only the temperature can warn, so only the temperature takes the marker. The other
        // three fields have no threshold of their own and a marker there would read as noise.
        let reading = temperature.map { celsius($0.celsius) } ?? "--"
        return [
            TitleSegment(text: hot ? warningMarker + reading : reading, isWarning: hot),
            TitleSegment(text: snapshot.gpuUtilizationPercent.map(percent) ?? "--"),
            TitleSegment(text: snapshot.gpuPowerWatts.map(watts) ?? "--"),
            TitleSegment(text: snapshot.maxFanRPM.map(rpm) ?? "--"),
        ]
    }

    public static func menuBarTitle(_ snapshot: Snapshot, warnCelsius: Double? = nil) -> String {
        titleSegments(snapshot, warnCelsius: warnCelsius).map(\.text).joined(separator: "  ")
    }

    public static func json(_ snapshot: Snapshot) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(snapshot), as: UTF8.self)
    }

    public static func plainText(_ snapshot: Snapshot) -> String {
        var lines: [String] = []
        if let max = snapshot.maxTemperature {
            lines.append(row("temperature", "max \(String(format: "%.1f", max.celsius))°C  (\(max.sensor))"))
        }
        if let avg = snapshot.averageTemperature {
            lines.append(row("temperature", "avg \(String(format: "%.1f", avg))°C  (\(snapshot.temperatures.count) sensors)"))
        }
        if let gpu = snapshot.gpuUtilizationPercent {
            lines.append(row("gpu", "utilization \(String(format: "%.0f", gpu))%"))
        }
        if let power = snapshot.gpuPowerWatts {
            lines.append(row("gpu", "power \(String(format: "%.2f", power))W"))
        }
        for fan in snapshot.fans {
            lines.append(row("fan", "\(fan.name) \(String(format: "%.0f", fan.rpm)) RPM"))
        }
        for (source, reason) in snapshot.unavailable.sorted(by: { $0.key < $1.key }) {
            lines.append(row(source, "unavailable: \(reason)"))
        }
        return lines.joined(separator: "\n")
    }

    private static func row(_ source: String, _ detail: String) -> String {
        "\(source.padding(toLength: 13, withPad: " ", startingAt: 0))\(detail)"
    }
}
