# Night Market — Release Prep (P10 drafts)

Drafted by the build agent. App Store Connect entry, signing, pricing,
and submission are maintainer items.

## App Store metadata draft

- **Name:** Night Market
- **Subtitle:** A cozy street-food crowd puzzle
- **Category:** Games → Puzzle (secondary: Simulation)
- **Keywords (100 chars):** night market, food stall, crowd, cozy, puzzle, city, lantern, strategy, relaxing, taiwan, street food
- **Description:**
  > Open your stalls at dusk and keep the crowds moving until dawn.
  > Pave walkways, hang lanterns, hire buskers, and set seats so hungry
  > visitors find their favorite stall before the queues overflow. Six
  > night markets — Taipei, Seoul, Bangkok, Marrakesh, Istanbul, and
  > Oaxaca — each with its own rhythm, palette, and schedule. Daily and
  > weekly challenges give every player the same market and the same
  > twist; the per-map leaderboards decide who runs the best night.
  > - Draw walkways with a finger or Apple Pencil — hover previews, squeeze erases
  > - Watch steam, rain, and neon shift through a real-time night cycle
  > - A soundtrack that follows the crowd, synthesized live (no assets)
  > - Assist mode lengthens the overflow grace for a calmer night
  > - High-contrast mode and VoiceOver queue summaries
  > - No ads, no data collection, no network required
- **Promotional text:** "Tonight's challenge is the same for everyone. How far can you push one market?"
- **What's New:** first release.

## Privacy nutrition label

**Target: Data Not Collected.** The app has no analytics, no ads, no
network calls beyond the platform frameworks the player opts into
(Game Center posts and the iCloud key-value profile sync, both standard
Apple services under the player's own account). The in-game stats export
(P9) writes a file to Documents that the player shares themselves; it is
off unless the player opts in.

## Age rating questionnaire draft

- Cartoon/lantasy violence: none. Mature themes: none. Gambling: none.
- Unrestricted web access: none. Age rating target: **4+**.

## Accessibility notes (for the accessibility nutrition labels)

- VoiceOver: HUD controls labeled; a live queue summary element updates
  as stalls fill; results and launcher are fully labeled.
- Visual: high-contrast mode (thicker outlines, max-saturation accents);
  six stall identities also encoded as glyphs and canopy shapes; the
  palette passes a Machado-2009 color-blind simulation review (ΔE ≥ 12).
- Motor: all build actions are single-finger drags or taps; hover
  preview and squeeze-to-erase for Apple Pencil; assist mode adds time,
  not dexterity demands.

## Press kit

- **One-liner:** "Run a night market: pave the paths, light the lanterns, keep the queues moving until dawn."
- **Short:** Night Market is a cozy real-time crowd puzzle. Between the
  gates and six food stalls lies empty ground: draw the walkways, place
  the lanterns and seats, and keep customers flowing through a full
  night cycle of rain, neon, and steam. Deterministic simulation — the
  same seed always plays the same night — with daily challenges shared
  by every player and per-map leaderboards.
- **Asset list:** screenshots (generated on simulators, all sizes), an
  app preview video (`docs/release/preview.md`), and the app icon.
- **Fact sheet:** single purchase, universal (iOS/iPadOS/macOS), no
  in-app purchases, no ads, offline play, VoiceOver + high-contrast +
  assist mode, 6 maps, 3 schedules, 12 challenge modifiers, 20
  achievements.
