# Murmuration — Known Issues

- **Host CoreSimulator stack degraded** (shared with Night Market, tracked as
  [issue #10](https://github.com/Zyniker13/Geist/issues/10)): SpringBoard/UI rendering
  on the iPad simulator froze across the Night Market P10 attempt; `simctl io
  screenshot` produces no image even though the simulator daemon responds. Needs a Mac
  host reboot. Local iPad app-launch evidence and UI-test runs are blocked until then;
  the macOS app launch is unaffected and CI (which boots its own simulators) is
  unaffected. Update 2026-11-17: the iPad simulator now boots and screenshots
  (boot splash captured), so the stack is at least partially recovered; still
  verify a real app UI renders before relying on it.
- Resolved (was P0 spike SIGTRAP at 4000 birds / ticks ≥ 223, seed-dependent):
  root-caused to the broken velocity rescale driving speeds to the Int32 clamp and
  overflowing the Int64 `speed2`; fixed by the exact-direction rescale (ADR-0005).
  4000×300 now completes deterministically (finalHash 028729a269626600).
- Resolved: committed tree could not build tests at the P0 scaffold commit
  (9ec2408) — `Package.swift` declared the `GoldenReplays` test resource but the
  folder was never committed. Fixed by committing
  `Tests/MUCoreTests/GoldenReplays/trivial-golden-1.json`.
- No open game-internal known issues.
