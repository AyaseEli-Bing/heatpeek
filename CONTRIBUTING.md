# Contributing

Short version: **open an issue, or leave a comment claiming an existing one, before sending a
PR.** It stops two people from doing the same task, and it lets the maintainer redirect a wrong
approach before you spend an evening on it.

## What you need

- macOS 13 or later with the Xcode Command Line Tools. A Swift 6.x toolchain is enough — the
  build is driven by `Package.swift`, there is no Xcode project and no GUI session needed.
- No root, no entitlements, no `sudo`. The app reads its sensors as an ordinary user.
- A real Apple Silicon Mac only if your change touches the sensor readers. `scripts/selftest.sh`
  **skips** (rather than fails) hardware assertions on a machine with no sensors, so most tasks
  are verifiable on any Mac and on the CI runner.

## Build and verify

```sh
make build   # release binary -> .build/release/heatpeek
make app     # also bundles dist/HeatPeek.app (ad-hoc signed)
make test    # swift test + scripts/selftest.sh — the acceptance gate
```

CI (`.github/workflows/build.yml`) runs `make build`, `swift test`, `make app`, the selftest,
markdownlint over the top-level `*.md` files, and `bash -n` on both scripts. Doc-only changes
still have to pass markdownlint: `MD013` (line length) is disabled in `.markdownlint.json`, the
rest of the default rules are on.

## Where the logic belongs

- **New behaviour goes in `HeatPeekCore`, not in the executable target.** `Sources/heatpeek` is an
  `executableTarget` and a test target cannot import one, so anything you want covered by
  `swift test` has to live in the library. This is why the menu bar string and the warning
  decision sit in `Sources/HeatPeekCore/Formatting.swift`: `TitleSegment.isWarning` carries the
  decision, and `StatusItemController` only maps it to a colour.
- `--json` has a hardware-independent key set on purpose. `Snapshot.encode(to:)` writes every
  documented key and emits `null` for an absent source, because synthesized encoding would drop
  the key and change the shape per machine. If you add a field, update `encode(to:)`, the
  documented-key check in `scripts/selftest.sh`, and the README example in the same commit.
- Hardware claims are dated. README and CHANGELOG say what was measured on which machine (an
  M4 / Mac16,1). When you change a sensor path, name the hardware and macOS version you verified
  against.

## Conventions

- **Commit messages**: capitalized imperative, no `type:` prefix — match `git log`, e.g.
  `Sample temperature at most every 5s`.
- **Comments** explain why, not what: the constraint behind a constant, the private API that has
  no public header, the endianness trap a decoder avoids. Keep them short.
- Prefer the stock toolchain and the standard library. Private entry points are resolved with
  `dlopen`/`dlsym` rather than a bridging header, so `swift build` keeps working without extra
  setup; do not add a dependency to get what one syscall already gives you.

## Pull requests

- One change per PR. Keep refactors separate from behaviour changes.
- For a bug fix, write the failing check first: run it against unmodified code, confirm it fails
  for the reported reason, then fix. A test that passes either way proves nothing.
- Paste the tail of `make test` in the PR description — `passed=N failed=0` and how many
  assertions were skipped, so the reviewer knows what was actually exercised.

## License

By submitting a PR you agree your contribution is licensed under the MIT license in `LICENSE`.
