# DualSense Touchpad Controls

Three small REFramework scripts and a Python helper that put the DualSense touchpad to use: swipes for Immersive Animations' keys and a touchpad press for Oni Vision. Single-player only, Windows only.
Touchpad Oni Vision v4 | Unbind Touchpad Press v3 | Unbind Options | DS5 Swipe helper | Status: touchpad press and Oni Vision while walking worked in game on 2026-11-14; in use; no separate test record for the swipes or for Unbind Options

## What and why

Edits to the Steam Input layout never reached the game: no keys were sent, and the touchpad click kept its old behaviour. So the helper reads the controller's own reports directly and sends keyboard keys.

| Part | File | What it does |
|---|---|---|
| DS5 Swipe helper | `helper/ds5_swipe.py` | Reads the DualSense touchpad (USB or Bluetooth) and sends keys: swipe right = Numpad 1, left = Numpad 3, down = Numpad 2, up = Numpad 4 (Immersive Animations' draw / sheathe, meditation, cover cloak, inspect sword). A press on the right half of the touchpad holds F24 while pressed and taps V (Oni Vision) on release. Keys are sent only while the game window is in front. |
| Unbind Touchpad Press v3 | `unbind_touchpad_press.lua` | The game reads a touchpad press as a button: the left half like the pause-menu button, the right half like Options (map). The script clears the left-half button always and the right-half button while the helper holds F24, so the press reaches only the helper. |
| Touchpad Oni Vision v4 | `touchpad_oni_vision.lua` | The V key always reaches the game, but Oni Vision only reacts to it while the game thinks the last input device was the keyboard. Moving the stick keeps that on "pad", so V was ignored while walking. While V is down, the script sets the last input device to keyboard. Movement is not affected. |
| Unbind Options | `unbind_options.lua` | Clears the Options (DualSense) / Menu (Xbox) button from the game's pad input, so the game never sees it. Mods that read the controller directly still do. |

Each script can be installed on its own. The swipes only do something with Immersive Animations installed, because they send its keys.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Onimusha: Way of the Sword | the PC version current in November 2026; exact build not recorded | |
| REFramework | the build for this game current in November 2026; exact build not recorded | [praydog/REFramework](https://github.com/praydog/REFramework) |
| Python (for the helper) | 3.11, standard library only, nothing to install | [python.org](https://www.python.org/downloads/) |
| A DualSense or DualSense Edge controller | USB or Bluetooth | |
| Immersive Animations by MaroKit (for the swipes) | optional | [Nexus Mods](https://www.nexusmods.com/onimushawayofthesword/mods/300) |

None of these are bundled.

## Install

1. Install REFramework for the game.
2. Copy the contents of `package/` into the game folder, so that `reframework\autorun\unbind_touchpad_press.lua` exists. Leave out any script you do not want.
3. Put `helper/ds5_swipe.py` anywhere outside the game folder and start it with `pythonw -I ds5_swipe.py` (no window). It waits, checking every 5 seconds, until `OnimushaWotS.exe` runs. To start it at logon, create a Task Scheduler task that runs the same command.
4. Start the game. Each script has an entry under REFramework menu (Insert) > Script Generated UI.

## Uninstall / roll back

1. Close the game. End the `pythonw.exe` process that runs `ds5_swipe.py`, and delete the scheduled task if you made one.
2. Delete `reframework\autorun\touchpad_oni_vision.lua`, `reframework\autorun\unbind_touchpad_press.lua` and `reframework\autorun\unbind_options.lua`.
3. Optional: delete `reframework\data\TouchpadOniVision_log.txt` if you turned its log on.
4. Saves are not affected. REFramework is left alone. Steam Input settings are not touched.

## Configuration

- Helper: the settings are at the top of `ds5_swipe.py` (keys per swipe, minimum swipe distances, time limit, key hold time). Command-line switches: `--debug` prints every touch and lift, `--any-window` sends keys whatever window is in front, `--probe` prints the found controller and three reports.
- Scripts: each has an on/off box in the REFramework menu. The boxes are not saved; every script starts switched on. Touchpad Oni Vision also has an optional log to `reframework\data\TouchpadOniVision_log.txt`.

## Known issues

- With Unbind Touchpad Press, a touchpad press no longer opens the pause menu or the map. The Create button may share the left-half button code and is then blocked as well.
- With Unbind Options, the Options button no longer opens the map.
- The V key has to be sent on release: while the touchpad click is held, the game ignores the key.
- Button prompts may switch between keyboard and pad for one frame when V is pressed.

## Changelog

| Part | Date | Change |
|---|---|---|
| DS5 Swipe helper | 2026-11-13 | First version (swipes). The right-half press for Oni Vision is recorded as working on 2026-11-14. |
| Unbind Touchpad Press v3 | 2026-11-14 | Clears the button on the controller device itself before the game reads it, and again on the game's pad info afterwards. |
| Touchpad Oni Vision v4 | 2026-11-14 | Sets the last input device right after the game computes it, and once more each frame. |

Back to the [mod list](../../README.md).
