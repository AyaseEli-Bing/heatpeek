# Changelog

All notable changes to this project are documented here.

## 0.1.0

Initial release.

- Menu bar readout of three Apple Silicon sensor sources: SoC temperature, GPU utilization,
  GPU power.
- Click-to-open menu listing the eight hottest sensors, GPU figures, refresh interval, and quit.
- `--once` and `--json` one-shot modes for scripting and CI.
- `scripts/selftest.sh` validates the CLI contract, JSON structure, plausibility, agreement with
  `ioreg`, and — with `--full` — that temperatures actually rise under load.
