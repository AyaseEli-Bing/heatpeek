import Foundation
import IOKit

/// GPU utilization via the public `IOAccelerator` registry property.
public enum GPUReader {
    public struct Utilization: Sendable, Equatable {
        public let percent: Double
        public let deviceName: String
    }

    private static let preferredKeys = ["Device Utilization %", "Renderer Utilization %", "Tiler Utilization %"]

    public static func read() -> Utilization? {
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("IOAccelerator"),
              IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS
        else {
            Log.sensor.error("IOServiceGetMatchingServices(IOAccelerator) failed")
            return nil
        }
        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }

            if let stats = statistics(for: service) {
                for key in preferredKeys {
                    if let number = stats[key] as? NSNumber {
                        return Utilization(percent: number.doubleValue, deviceName: name(of: service))
                    }
                }
            }
        }
        return nil
    }

    private static func statistics(for service: io_service_t) -> [String: Any]? {
        guard let property = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? [String: Any]
        else {
            return nil
        }
        return property
    }

    private static func name(of service: io_service_t) -> String {
        guard let name = IORegistryEntryCreateCFProperty(service, "IOGLBundleName" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
        else {
            return "IOAccelerator"
        }
        return name
    }
}
