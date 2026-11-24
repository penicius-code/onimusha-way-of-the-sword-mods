# Exposure Flash Fix

Removes the white flash after fast travel and after leaving the menu when the game runs with DLSS 5 (DLSS-NR through OptiScaler). Single-player only.
Version 1.0 | Status: passes its offline test; the earlier release page says it was tested in game with an OptiScaler DLSS-NR build (v0.2.0-patch1); no dated in-game test record

## What and why

After fast travel and when you leave the menu, the game resets its automatic exposure: the value jumps from about 0.002 to about 560 and comes back down. Without DLSS 5 this is not visible. DLSS-NR takes its white point from the game's exposure, so it shows a blown-out white picture for about 1.5 seconds.

The script blocks that one reset (the game method `ace.PostEffect.cExposureController.clearHistogram`, the only reset path seen firing in game). The exposure simply carries on. Side effect: after a transition the exposure adapts gradually instead of snapping, like stepping out of a dark room. Not needed without DLSS 5.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Onimusha: Way of the Sword | the PC version current in November 2026; exact build not recorded | |
| REFramework | the build for this game current in November 2026; exact build not recorded | [praydog/REFramework](https://github.com/praydog/REFramework) |
| DLSS 5 (DLSS-NR) through OptiScaler | with its default white point source (game exposure) | |

None of these are bundled. Install them first from their own pages.

## Install

1. Install REFramework for the game.
2. Copy the contents of `package/` into the game folder, so that `reframework\autorun\exposure_flash_fix.lua` exists.
3. Start the game. Open the REFramework menu (Insert) > Script Generated UI > "Exposure Flash Fix". It should read "Hook active".

## Uninstall / roll back

1. Close the game.
2. Delete `reframework\autorun\exposure_flash_fix.lua`.
3. Optional: delete `reframework\data\exposure_flash_fix.json` (only written after you change the setting).
4. Saves are not affected. REFramework and OptiScaler are left alone.

## Configuration

One checkbox, "Block the exposure reset (DLSS 5 white flash)", on by default, and two counters: resets blocked and resets let through. Switching it off takes effect at the next fast travel or menu exit.

## Compatibility

| Item | Status | Notes |
|---|---|---|
| OptiScaler and its ini | not touched | Alternative without this script: `WhitePointSource=0` in `OptiScaler.ini` (fixed paper white) also removes the flash, but the normal exposure differs about 25 times between places, so one fixed white point looks wrong in many of them. |

## Tests

`tests/run_exposure_flash_fix_test.lua` replaces the REFramework API with a stub and checks six things: the hook is installed, the reset is blocked while enabled, unticking saves the setting, the reset is let through while disabled, the counters, and ticking again blocks again. Run it with Lua 5.4:

```text
lua tests/run_exposure_flash_fix_test.lua package/reframework/autorun/exposure_flash_fix.lua
```

It runs in CI on every push.

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-11-15 | One hook on the exposure reset only. |
| 0.1, 0.2 | 2026-11-15 | Earlier builds with several hooks; not included. |

Back to the [mod list](../../README.md).
