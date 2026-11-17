# Murmuration — Known Issues

- **Host CoreSimulator stack degraded** (shared with Night Market, tracked as
  [issue #10](https://github.com/Zyniker13/Geist/issues/10)): SpringBoard/UI rendering
  on the iPad simulator froze across the Night Market P10 attempt; `simctl io
  screenshot` produces no image even though the simulator daemon responds. Needs a Mac
  host reboot. Local iPad app-launch evidence and UI-test runs are blocked until then;
  the macOS app launch is unaffected and CI (which boots its own simulators) is
  unaffected.
- No game-internal known issues yet.
