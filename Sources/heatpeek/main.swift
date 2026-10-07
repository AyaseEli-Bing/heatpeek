import Cocoa
import HeatPeekCore

enum CLI {
    static let version = "0.1.0"

    static let help = """
        heatpeek \(version) — menu-bar readout of SoC temperature, GPU utilization and GPU power.

        Usage: heatpeek [options]
          (no options)   run the menu bar item
          --once         print one reading and exit
          --json         machine-readable output (with --once)
          --version      print the version
          --help (-h)    show this help

        Exit status is 0 even when a source is unavailable; the reason is reported per source.
        """
}

struct Options {
    var once = false
    var json = false
}

func parseOptions(_ arguments: [String]) -> Options? {
    var options = Options()
    for argument in arguments.dropFirst() {
        switch argument {
        case "--once": options.once = true
        case "--json": options.json = true
        default: return nil
        }
    }
    return options
}

let arguments = CommandLine.arguments

if arguments.contains("--help") || arguments.contains("-h") {
    print(CLI.help)
    exit(0)
}
if arguments.contains("--version") {
    print(CLI.version)
    exit(0)
}

guard let options = parseOptions(arguments) else {
    FileHandle.standardError.write(Data("heatpeek: unknown argument\n\n\(CLI.help)\n".utf8))
    exit(64)
}

if options.once {
    let sampler = Sampler()
    let snapshot = await sampler.samplePair(firstDelay: 1)
    if options.json {
        do {
            print(try Formatting.json(snapshot))
        } catch {
            FileHandle.standardError.write(Data("heatpeek: encoding failed: \(error)\n".utf8))
            exit(1)
        }
    } else {
        let text = Formatting.plainText(snapshot)
        print(text.isEmpty ? "heatpeek: no sensor data available on this machine" : text)
    }
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
