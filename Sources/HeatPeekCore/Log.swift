import Foundation
import os

private let subsystem = "local.heatpeek"

public enum Log {
    public static let sampler = Logger(subsystem: subsystem, category: "sampler")
    public static let sensor = Logger(subsystem: subsystem, category: "sensor")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
}
