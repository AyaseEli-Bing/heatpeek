# heatpeek

A menu bar readout of what a Mac is *feeling*: SoC temperature, GPU utilization,
and GPU power.

```text
55°  38%  1.9W
```

Zero dependencies: no package manager, no bundled libraries, no build step
beyond `swift build`. Every figure comes from the kernel through IOKit, so
nothing shells out to `powermetrics` or `nettop`.

heatpeek deliberately does not report CPU load, memory pressure, disk or
network throughput — that is
[xnumeter](https://github.com/AyaseEli-Bing/xnumeter)'s job. This project only
covers the sensor side, which needs different (and partly private) APIs.

## Requirements

- macOS 13 or later on **Apple Silicon**. Everything here is measured on an
  M4 (Mac16,1) running macOS 27; Intel Macs expose different sensor keys and
  are untested.
- No root, no entitlements, no sandbox exception. All three sources are
  readable by an ordinary user process.

## Build

```bash
make app        # release build -> dist/HeatPeek.app (ad-hoc signed)
swift build     # debug build -> .build/debug/heatpeek
```

Because a free Apple ID cannot issue a Developer ID certificate, releases are
ad-hoc signed and cannot be notarized. The first launch of a downloaded build
may need:

```bash
xattr -dr com.apple.quarantine dist/HeatPeek.app
```

## Use

Run the app; it lives in the menu bar with no Dock icon. The three fields are
hottest sensor, GPU utilization, and GPU power. A source that is unavailable
renders as `--` and explains itself in the menu.

Click the item for the eight hottest sensors, GPU figures, the refresh
interval (1/2/5/10 s), and quit.

The same readings are available for scripts:

```bash
$ heatpeek --once
temperature  max 56.8°C  (PMU tdev2)
temperature  avg 46.7°C  (44 sensors)
gpu          utilization 80%
gpu          power 1.57W
```

```bash
$ heatpeek --once --json
{
  "gpuPowerWatts" : 1.6341884174007515,
  "gpuUtilizationPercent" : 67,
  "temperatures" : [ { "celsius" : 51.64, "sensor" : "PMU tdie14" } ],
  "timestamp" : "2026-10-04T15:20:41Z",
  "unavailable" : { }
}
```

`--once` exits 0 even when a source is missing, so a dashboard can tell
"unavailable" apart from "heatpeek crashed".

## What it reads

| Field | Source | Privilege |
| --- | --- | --- |
| Temperature | `IOHIDEventSystemClient*`, usage page `0xff00` / usage `0x0005`, event type 15 | user |
| GPU utilization | `IOAccelerator` registry property `PerformanceStatistics` | user |
| GPU power | `IOReport` group `Energy Model`, channel `GPU Energy` | user |

The HID and IOReport entry points have no public headers. heatpeek resolves
them with `dlopen`/`dlsym` rather than shipping a private bridging header, so
`swift build` works with a stock toolchain.

Temperature is reported as the hottest of the ~44 exposed sensors rather than
a single "CPU temperature", because Apple publishes no such thing on Apple
Silicon: the sensors are named `PMU tdie*` and `PMU tdev*`, and which one
tracks the load changes with workload.

## Known limits

- **No CPU power.** On M4 the `mJ` counters in `Energy Model` (`CPU Energy`,
  `ECPU*`, `PCPU*`, `ANE`, `DRAM`) stay a static snapshot when polled, while
  only the `nJ` `GPU Energy` channel advances. Getting the CPU figure needs a
  stream callback this project does not implement yet.
- **Fan speed is not shown.** `F0Ac` is readable, but on the test machine it
  reported 0 RPM even after a 10-thread load pushed the hottest sensor to
  77 °C, so it would read as a broken widget.
- **GPU utilization is not comparable with Activity Monitor.** The kernel
  counter includes window-server work, so an idle desktop can report 60–80 %.
  Treat it as a trend, not a percentage of "your" work.
- `ProcessInfo.processInfo.thermalState` stayed `nominal` throughout testing
  and is not used.
- No historical graphs, no per-process attribution, no automatic updates.
- If the menu bar is already full, macOS clips new items behind the overflow
  chevron and heatpeek will not be visible.

## Tests

```bash
make test           # unit tests + quick selftest
make selftest-full  # adds a 25 s load test that asserts temperatures rise
```

`scripts/selftest.sh` cross-checks GPU utilization against `ioreg` and skips
(rather than fails) hardware assertions on machines without sensors, so the
same script runs on a CI runner.

## License

MIT — see [LICENSE](LICENSE).
