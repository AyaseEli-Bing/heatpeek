# Changelog

All notable changes to this project are documented here.

## Unreleased

- The usage text now advertises `-h` beside `--help`. The alias already worked and
  was documented in the README, but `--help` never mentioned it, so a user could
  only discover it by reading the README.

## 0.1.0

Initial release.

- Menu bar readout of four Apple Silicon sensor sources: SoC temperature, GPU
  utilization, GPU power, and fan speed.
- The temperature field turns red at a configurable threshold (85 °C by
  default; 80/85/90/95/100 °C or never).
- Click-to-open menu listing the eight hottest sensors, GPU figures, per-fan
  RPM, the refresh interval, and quit.
- `--once` and `--json` one-shot modes for scripting and CI.
- `--version` prints the version; `--help` (or `-h`) prints the usage text. Both
  exit 0 without taking a reading.
- An unknown argument writes `heatpeek: unknown argument` and the usage text to
  stderr and exits 64 (`EX_USAGE`), rather than falling back to the menu bar item.
- `scripts/selftest.sh` validates the CLI contract, JSON structure, plausibility,
  agreement with `ioreg`, and — with `--full` — that temperatures actually rise
  under load.
