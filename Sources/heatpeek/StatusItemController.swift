import Cocoa
import HeatPeekCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private static let intervalDefaultsKey = "heatpeek.intervalSeconds"
    private static let allowedIntervals: [TimeInterval] = [1, 2, 5, 10]

    private let sampler = Sampler()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    private var timer: Timer?
    private var snapshot = Snapshot.empty
    private var renderedTitle = ""
    private var isFetching = false

    var interval: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: Self.intervalDefaultsKey)
            return Self.allowedIntervals.contains(stored) ? stored : 2
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.intervalDefaultsKey)
            startTimer()
            refresh()
        }
    }

    override init() {
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)
        statusItem.button?.toolTip = "heatpeek"
        set(title: "…")
    }

    func start() {
        startTimer()
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        guard !isFetching else { return }
        isFetching = true
        Task { @MainActor in
            let next = await sampler.sample()
            self.snapshot = next
            self.apply(next)
            self.isFetching = false
        }
    }

    private func apply(_ snapshot: Snapshot) {
        set(title: Formatting.menuBarTitle(snapshot))
    }

    private func set(title: String) {
        guard title != renderedTitle else { return }
        renderedTitle = title
        statusItem.button?.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.foregroundColor: NSColor.labelColor]
        )
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if let max = snapshot.maxTemperature {
            menu.addItem(header("max \(Formatting.celsius(max.celsius))  \(max.sensor)"))
            if let average = snapshot.averageTemperature {
                menu.addItem(header("avg \(Formatting.celsius(average))  ·  \(snapshot.temperatures.count) sensors"))
            }
            menu.addItem(.separator())
            for reading in snapshot.temperatures.sorted(by: { $0.celsius > $1.celsius }).prefix(8) {
                menu.addItem(row(reading.sensor, value: String(format: "%.1f°C", reading.celsius)))
            }
        } else {
            menu.addItem(header("no temperature data"))
        }

        menu.addItem(.separator())
        menu.addItem(row("GPU utilization", value: snapshot.gpuUtilizationPercent.map(Formatting.percent) ?? reason("gpu")))
        menu.addItem(row("GPU power", value: snapshot.gpuPowerWatts.map(Formatting.watts) ?? reason("power")))

        menu.addItem(.separator())
        let intervals = NSMenuItem(title: "Interval", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for value in Self.allowedIntervals {
            let option = NSMenuItem(title: "\(Int(value))s", action: #selector(selectInterval(_:)), keyEquivalent: "")
            option.target = self
            option.representedObject = value
            option.state = value == interval ? .on : .off
            submenu.addItem(option)
        }
        intervals.submenu = submenu
        menu.addItem(intervals)

        let refresh = NSMenuItem(title: "Refresh now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let quit = NSMenuItem(title: "Quit heatpeek", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func header(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: text,
            attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.boldSystemFont(ofSize: 11)]
        )
        return item
    }

    private func row(_ title: String, value: String) -> NSMenuItem {
        let item = NSMenuItem(title: "\(title)  \(value)", action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func reason(_ source: String) -> String {
        snapshot.unavailable[source] ?? "n/a"
    }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? TimeInterval else { return }
        interval = value
    }

    @objc private func refreshNow() { refresh() }

    @objc private func quit() { NSApp.terminate(nil) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = StatusItemController()
        self.controller = controller
        controller.start()
        Log.ui.info("status item started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}
