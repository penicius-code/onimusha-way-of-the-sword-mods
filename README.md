# Onimusha: Way of the Sword mods

Small REFramework Lua scripts for Onimusha: Way of the Sword, plus a DualSense touchpad helper. Pick the ones you want; no game files are replaced. Single-player only.
Made in November 2026; the exact game build was not recorded. Every mod has its own README with install, rollback, compatibility, known issues and its real test status.

**Featured:** [Katana Stays Sheathed](https://github.com/penicius-code/onimusha-katana-stays-sheathed)

> Unofficial fan-made modification, not affiliated with or endorsed by CAPCOM Co., Ltd. No Capcom game files or assets are included; a legitimate copy of the game is required.

## Mods

The Status column gives the recorded test result. Details are in each mod's README.

<details>
<summary><strong>Gameplay and HUD</strong> (2)</summary>

| Mod | What it does | Requires | Status | Details |
|---|---|---|---|---|
| Katana Stays Sheathed ([Nexus Mods](https://www.nexusmods.com/onimushawayofthesword/mods/401)) | Keeps the katana in its sheath after using the bow and during wall runs. Lives in [its own repo](https://github.com/penicius-code/onimusha-katana-stays-sheathed). | REFramework | Wall run part confirmed working in game; bow part 3.0 worked in game, 3.1 not re-tested | [README](mods/katana-stays-sheathed/README.md) |
| Oni Vision Toggle and Pins ([Nexus Mods](https://www.nexusmods.com/onimushawayofthesword/mods/404)) | Oni Vision stays on until you press the key again; world pins only show while Oni Vision is active | REFramework | in use and published; no written play-test record | [README](mods/oni-vision-toggle-and-pins/README.md) |

</details>

<details>
<summary><strong>Fixes</strong> (2)</summary>

| Mod | What it does | Requires | Status | Details |
|---|---|---|---|---|
| Exposure Flash Fix | Removes the white flash after fast travel and menus with DLSS 5 (DLSS-NR through OptiScaler) | REFramework, DLSS-NR through OptiScaler | passes its offline test; tested in game per the earlier release page, no dated record | [README](mods/exposure-flash-fix/README.md) |
| IA Meditation Smoke Fix | Removes Oni eye smoke that Immersive Animations' meditation sometimes leaves on Musashi | REFramework, Immersive Animations | confirmed working in game (2026-11-16) | [README](mods/ia-meditation-smoke-fix/README.md) |

</details>

<details>
<summary><strong>Controller</strong> (1)</summary>

| Mod | What it does | Requires | Status | Details |
|---|---|---|---|---|
| DualSense Touchpad Controls | Touchpad swipes send Immersive Animations' keys; a touchpad press triggers Oni Vision, also while walking; optional unbinding of Options | REFramework, Python 3.11 for the helper, a DualSense | touchpad press and Oni Vision while walking worked in game (2026-11-14); in use | [README](mods/dualsense-touchpad-controls/README.md) |

</details>

## Install a mod (general steps)

1. Install the requirements listed for that mod (see [Common requirements](#common-requirements)).
2. Copy the contents of the mod's `package/` folder into the game folder (where `OnimushaWotS.exe` is), so that the folders line up with the game's own, for example `reframework\autorun\oni_vision_toggle.lua`.
3. Start the game and open the REFramework menu (Insert) > Script Generated UI: each script has its own entry. Scripts that log write to `re2_framework_log.txt` in the game folder.

## Common requirements

| Requirement | Version | Where to get it |
|---|---|---|
| REFramework | the build for this game current in November 2026; exact build not recorded | [praydog/REFramework](https://github.com/praydog/REFramework) |

It is not bundled in this repository. Install it from its own page. Mod-specific requirements are listed in each mod's README.

## Uninstall / roll back

Each mod README lists exactly which files it adds. Delete those files to remove the mod; settings files in `reframework\data\` can be deleted too. Saves are not affected. To return to an unmodified game, also remove REFramework as its own page describes, then let your launcher verify the game files (on Steam: Properties > Installed Files > Verify integrity of game files).

## Other authors' mods

I use several other authors' mods and changed my local copies of five of them. None of their code is here. [COMPATIBILITY.md](COMPATIBILITY.md) lists them in words.

## Repo layout

```text
mods/<mod>/README.md    per-mod documentation
mods/<mod>/package/     folder tree that mirrors the game install folder
mods/<mod>/tests/       offline test with a stub of the REFramework API (Exposure Flash Fix)
mods/<mod>/helper/      program that runs outside the game (DualSense Touchpad Controls)
COMPATIBILITY.md        local edits of other authors' mods, in words
```

## Licence and credits

Runs on REFramework by praydog, which is not included here.

My code is MIT-licensed, see [LICENSE](LICENSE). Game files, names and trademarks belong to their owners; none are included here.
Built with AI assistance (Claude); designed, tested and maintained by me.
