# Murmuration — Performance Notes

## MU-P0.1 spike (P0)

Measured on the build host, Release build, `make spike` (`Tools/spike/spike`):

- 4,000 fixed-point boids, 30 Hz tick, spatial hash rebuild + full boid step per tick.
- Gate check: **boid tick ≤ 4 ms for 4,000 birds on Mac Release** — see
  [`STATUS.md`](STATUS.md) for the recorded numbers from the run used for G0.
- Metal instanced rendering: 4,000 instanced quads via `Tools/spike/metalprobe`
  (MTKView at 120 fps preferred rate); recorded in `STATUS.md` with the host's real
  frame count.

Note: the spike's bird spawn uses tool-side `Double` trig; Core itself is
integer-only. P1 replaces spawn with integer-deterministic seeding before golden
replays go cross-device (see ADR-0002).
