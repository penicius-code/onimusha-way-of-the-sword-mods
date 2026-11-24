# IA Meditation Smoke Fix

A compatibility fix for Immersive Animations (by MaroKit): removes the Oni eye smoke that the meditation sometimes leaves on Musashi. Single-player only.
Version 1.0 | Status: confirmed working in game on 2026-11-16

## What and why

Immersive Animations' meditation borrows the Oni Vision look while it refills health and the blue gauge: glowing eyes and the game's Oni eye smoke effect. Sometimes the smoke is left behind: the glow goes off, but the smoke stays on Musashi's eyes for good.

What was found in game: one meditation request left three unfinished smoke effects on the player, and Immersive Animations only stops the one its request hands back. This script removes the leftovers the same way the game ends an effect. It does this:

- when the refill is over while still seated (Immersive Animations switches the eye glow back off): 0.5 s later,
- when you stand up from meditation or sword inspection: 0.3 s and 2 s later,
- once after loading, and when you press the menu button.

It never acts while the game's own Oni Vision runs or in Oni mode, and it never touches the game's own Oni Vision eye effect. Immersive Animations itself is not changed; this script only reads its public "sitting" flag.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Onimusha: Way of the Sword | the PC version current in November 2026; exact build not recorded | |
| REFramework | the build for this game current in November 2026; exact build not recorded | [praydog/REFramework](https://github.com/praydog/REFramework) |
| Immersive Animations by MaroKit | 0.19.1 (the version it was tested with) | [Nexus Mods](https://www.nexusmods.com/onimushawayofthesword/mods/300) |

None of these are bundled. Install them first from their own pages.

## Install

1. Install REFramework and Immersive Animations.
2. Copy the contents of `package/` into the game folder, so that `reframework\autorun\ia_meditation_smoke_fix.lua` exists.
3. Start the game. Open the REFramework menu (Insert) > Script Generated UI > "IA Meditation Smoke Fix".

## Uninstall / roll back

1. Close the game.
2. Delete `reframework\autorun\ia_meditation_smoke_fix.lua`.
3. Optional: delete `reframework\data\ia_meditation_smoke_fix.json`.
4. Saves are not affected. REFramework and Immersive Animations are left alone.

## Configuration

| Option | Default | Meaning |
|---|---|---|
| Remove leftover Oni eye smoke after Immersive Animations' meditation | on | |
| Remove leftover eye smoke now | button | Does nothing while Oni Vision or Oni mode is active |

The menu also shows how many sweeps ran and how many smoke effects were removed. Removals are written to `re2_framework_log.txt` with the prefix `[IAMeditationSmokeFix]`.

## Compatibility

| Item | Status | Notes |
|---|---|---|
| Oni Vision Toggle (this repo) | works | While Oni Vision is held on, the script does not act, and a timed sweep that falls in that time is skipped. Use the menu button afterwards if smoke is left. |

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-11-16 | First version. |

Credits: Immersive Animations is MaroKit's work; this is a small add-on fix for it.

Back to the [mod list](../../README.md).
