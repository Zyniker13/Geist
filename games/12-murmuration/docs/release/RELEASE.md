# Murmuration — Release Prep (P10 drafts)

Drafted by the build agent. App Store Connect entry, signing, pricing,
and submission are maintainer items.

## App Store metadata draft

- **Name:** Murmuration
- **Subtitle:** Herd a starling flock across the sky
- **Category:** Games → Strategy (secondary: Simulation)
- **Keywords (100 chars):** flock, starling, birds, murmuration, strategy, herding, cozy, nature, flight, roost, falcon, split
- **Description:**
  > One flock, ten skies, endless decisions. Steer your starlings
  > through meadows, marshes, and mountain air — split the flock to
  > feed across scattered fields, beat rival flocks to the contested
  > roosts, and slip past falcons hunting the careless edge.
  > Every region plays differently: wind, field layout, and rival
  > tactics shift the math, and a ten-day campaign ties the regions
  > together. Daily challenges give every player the same sky and the
  > same twist; per-region leaderboards decide whose flock fed best.
  > - Steer with a finger or Apple Pencil — the leader point shows exactly where the flock aims
  > - Split and rejoin the flock; birds forage, rivals plan, falcons stoop
  > - Three AI difficulty tiers and a gentle per-region curve
  > - Deterministic simulation — the same seed always plays the same day
  > - Falcon assist for a calmer first flight, high-contrast rival colors
  > - No ads, no data collection, no network required
- **Promotional text:** "Today's challenge is the same for everyone. How far can one flock fly?"
- **What's New:** first release.

## Privacy nutrition label

**Target: Data Not Collected.** The app has no analytics, no ads, no
network calls beyond the platform frameworks the player opts into (Game
Center leaderboard posts and the iCloud key-value profile sync, both
standard Apple services under the player's own account). The in-game
stats export (P9) writes a file to Documents that the player shares
themselves; it is off unless the player opts in.

## Age rating questionnaire draft

- Cartoon/fantasy violence: none. Mature themes: none. Gambling: none.
- Unrestricted web access: none. Age rating target: **4+**.

## Accessibility notes (for the accessibility nutrition labels)

- VoiceOver: menu and results fully labeled; the HUD reads roost and
  field state; assist steering lowers steering precision demands.
- Visual: high-contrast rival mode (max-saturation rival tint); bird
  density is also encoded by the leader ring shape; the palette passes
  a Machado-2009 color-blind simulation review.
- Motor: all steering is a single touch drag; Reduce Motion supported;
  falcon assist removes reaction-time pressure without changing rules.

## Press kit

- **One-liner:** "Steer a starling flock: split it to feed, win the roosts, outfly the falcons."
- **Short:** Murmuration is a real-time flock-herding strategy game.
  Ten regions of meadow, marsh, and mountain: steer thousands of birds
  with one touch, split the flock so every field feeds before dusk, and
  contest the roosts against planning rivals — while falcons stoop on
  the careless edge. A deterministic simulation — the same seed always
  plays the same day — with daily challenges shared by every player and
  per-region leaderboards.
- **Asset list (all generated, on `zGeist_bot-iPad-Pro-13`, committed in
  this repo):**
  - Screenshots: `docs/release/screenshots/01-menu.png` (main menu),
    `02-flock.png` (mid-day flock steering), `03-high-contrast.png`
    (high-contrast rival mode), `04-assist.png` (falcon assist prompt) —
    2064×2752 iPad portrait, verified non-blank.
  - App preview: `docs/release/preview.mp4` (53 s, 2064×2752, H.264,
    19 MB) with capture facts and trim plan in
    `docs/release/preview.md`.
  - App icon: generated at upload time in App Store Connect —
    maintainer item (see `docs/STATUS.md` G10).
- **Fact sheet:** single purchase, universal (iOS/iPadOS/macOS), no
  in-app purchases, no ads, offline play, VoiceOver + high-contrast +
  falcon assist, 10 regions, 3 AI tiers, 30-day dailies, campaign mode.
