# Changelog

All notable changes to this project are documented here.

## 0.1.0

Initial release.

- Menu bar readout of four Apple Silicon sensor sources: SoC temperature, GPU
  utilization, GPU power, and fan speed.
- The temperature field turns red at a configurable threshold (85 °C by
  default; 80/85/90/95/100 °C or never).
- Click-to-open menu listing the eight hottest sensors, GPU figures, per-fan
  RPM, the refresh interval, and quit.
- `--once` and `--json` one-shot modes for scripting and CI.
- `scripts/selftest.sh` validates the CLI contract, JSON structure, plausibility,
  agreement with `ioreg`, and — with `--full` — that temperatures actually rise
  under load.
