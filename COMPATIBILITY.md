# Local edits of other authors' mods

Besides the scripts in this repo, I changed my local copies of five mods by other authors for my own game. None of their code is in this repository, and none of these edits is published. This page lists them in words so that anyone comparing my setup with theirs knows what differed. The scripts in this repo do not need any of these edits.

| Mod (author) | Kind | What my local copy changes | Effect on the scripts in this repo |
|---|---|---|---|
| [Immersive Animations](https://www.nexusmods.com/onimushawayofthesword/mods/300) (MaroKit) | compatibility | Sets and clears a shared flag while its meditation pose holds the camera (two added lines), so that Onimusha FOV can tell when the camera is temporarily overridden. | None. IA Meditation Smoke Fix reads a flag that the unmodified mod already has. Bow Keeps Sheathed and Wall Run Keeps Sheathed were tested only next to this edited copy; the edit adds no hook. |
| [Onimusha FOV](https://www.nexusmods.com/onimushawayofthesword/mods/35) (Zaid / Mozaid) | compatibility | Ignores its own readings of the rendered field of view and camera position while that flag is set, so its blends do not start from the meditation view. Side effect: its FOV readout is blank while meditating. | None. |
| [Run Speed Multiplier](https://www.nexusmods.com/onimushawayofthesword/mods/64) (Sleepy3812) | feature | A local patch made katana-drawn walk, run and dash as fast as the sheathed ones. Removed on 2026-11-16: the installed copy is the unmodified original again. | None. |
| [Fast Interact](https://www.nexusmods.com/onimushawayofthesword/mods/96) (xyzkljl1) | feature | Adds separate speed sliders per interaction type. | None. |
| [Onimusha HUD Controller](https://www.nexusmods.com/onimushawayofthesword/mods/225) (author not recorded) | UI | Adds five more HUD elements to its list: world pins, marker arrow, direction arrow, interact icons and the "destination reached" message. | Oni Vision Pins works with or without it. Its menu mentions the added "World Markers" option, which exists only in this edited copy. |

Back to the [mod list](README.md).
