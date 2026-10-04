import Foundation

public enum Formatting {
    public static func celsius(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }

    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    public static func watts(_ value: Double) -> String {
        value >= 10 ? "\(Int(value.rounded()))W" : "\(String(format: "%.1f", value))W"
    }

    /// A missing source is rendered as `--` so the menu bar title keeps a stable shape.
    public static func menuBarTitle(_ snapshot: Snapshot) -> String {
        let temp = snapshot.maxTemperature.map { celsius($0.celsius) } ?? "--"
        let gpu = snapshot.gpuUtilizationPercent.map(percent) ?? "--"
        let power = snapshot.gpuPowerWatts.map(watts) ?? "--"
        return "\(temp)  \(gpu)  \(power)"
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
        for (source, reason) in snapshot.unavailable.sorted(by: { $0.key < $1.key }) {
            lines.append(row(source, "unavailable: \(reason)"))
        }
        return lines.joined(separator: "\n")
    }

    private static func row(_ source: String, _ detail: String) -> String {
        "\(source.padding(toLength: 13, withPad: " ", startingAt: 0))\(detail)"
    }
}
