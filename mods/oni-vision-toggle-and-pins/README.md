# Oni Vision Toggle and Pins

Two REFramework scripts: Oni Vision becomes a toggle, and world pins only show while Oni Vision is active. Single-player only.
Oni Vision Toggle 1.1 | Oni Vision Pins 1.0 | Status: in use and published on Nexus Mods; the game behaviour they rely on was checked in game on 2026-11-15, but there is no written play-test record

Published on Nexus Mods as "Oni Vision Toggle and Pins": <https://www.nexusmods.com/onimushawayofthesword/mods/404>

## What and why

**Oni Vision Toggle** (`oni_vision_toggle.lua`). In the unmodified game Oni Vision is a short pulse: the wave goes out, things glow for a few seconds and fade. With this script, pressing the Oni Vision key starts it as usual and it then stays on. The glow on objects and the item icons stay lit. Pressing the key again switches it off, with a 0.3 s fade instead of the game's 2 s. Extra presses right after a switch are ignored for 0.6 s, so a quick double tap does not start it again. Optional: an automatic new pulse (normal wave and sound) after you walk a set distance, so things you walk up to are revealed too. This is off by default.

**Oni Vision Pins** (`oni_vision_pins.lua`). World pins and distance markers are hidden and only show while Oni Vision is active, then for as long as Oni Vision's own item icons stay (12 s in the game, unless a mod changes it). Loot and interact prompts are never hidden. While Oni Vision Toggle holds Oni Vision on, the pins stay visible too.

How they work, in short:
- The toggle hooks the game's Oni Vision press check. While Oni Vision is held on, a new press switches it off and the press itself is not passed on, so no new pulse starts. Each frame it keeps the wave's fade timer at zero, the item icon counters full and the glow timers of found objects lit.
- The pins script hides only the "far" part (pin, distance, arrow) of each of the 20 pin panels of the pin HUD, using a "force invisible" flag the game never sets itself. The game's own visibility logic is left alone.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Onimusha: Way of the Sword | the PC version current in November 2026; exact build not recorded | |
| REFramework | the build for this game current in November 2026; exact build not recorded | [praydog/REFramework](https://github.com/praydog/REFramework) |

The two scripts work alone or together. REFramework is not bundled. Install it first from its own page.

## Install

1. Install REFramework for the game.
2. Copy the contents of `package/` into the game folder, so that `reframework\autorun\oni_vision_toggle.lua` exists. Copy only one of the two scripts if you want only one.
3. Start the game. Open the REFramework menu (Insert) and look under "Script Generated UI" for "Oni Vision Toggle" and "Oni Vision Pins".

## Uninstall / roll back

1. Close the game.
2. Delete `reframework\autorun\oni_vision_toggle.lua` and `reframework\autorun\oni_vision_pins.lua`.
3. Optional: delete the settings files `reframework\data\oni_vision_toggle.json` and `reframework\data\oni_vision_pins.json`.
4. Saves are not affected. REFramework is left alone.

## Configuration

REFramework menu > Script Generated UI. Changes are saved at once.

Oni Vision Toggle:

| Option | Default | Meaning |
|---|---|---|
| Oni Vision stays on until you press V again | on | Off = the game's normal pulse |
| Auto re-scan after walking (m) | 0 | 0 = off, up to 60 m |
| Switch-off fade (s) | 0.3 | 0 to 2 s |
| Switch off now | button | |
| Debug log (re2_framework_log.txt) | off | Lines start with `[OniVisionToggle]` |

Oni Vision Pins:

| Option | Default | Meaning |
|---|---|---|
| World pins only while Oni Vision is active | on | Off = the game's normal pins |
| Keep them as long as the Oni Vision item icons | on | Off shows a slider "Seconds after pressing V" (0 to 60 s, default 12) |

## Compatibility

| Item | Status | Notes |
|---|---|---|
| [Enhanced Oni Vision](https://www.nexusmods.com/onimushawayofthesword/mods/67) | no conflict seen | Played together. If a mod changes how long the item icons last, the pins follow it. |
| [Onimusha HUD Controller](https://www.nexusmods.com/onimushawayofthesword/mods/225) | see note | The pins menu shows the line "HUD Controller: leave 'Hide' for World Markers unticked". That option exists only in a locally edited copy of HUD Controller (see [COMPATIBILITY.md](../../COMPATIBILITY.md)); the published HUD Controller has no such entry, so with it there is nothing to change. |

## Known issues

- The toggle works through the game's own Oni Vision press, so the key or button you use for Oni Vision is the one that toggles it. During an action in which the game would not accept Oni Vision, only the keyboard key (V) switches it off; on a controller, press again a moment later.

## Changelog

| Version | Date | Change |
|---|---|---|
| Oni Vision Toggle 1.1 | 2026-11-15 | Switching off is quick: wave, glow and icons fade in 0.3 s (slider) instead of the game's 2 s. |
| Oni Vision Toggle 1.0 | 2026-11-15 | First version. |
| Oni Vision Pins 1.0 | 2026-11-15 | First version. |

Back to the [mod list](../../README.md).
