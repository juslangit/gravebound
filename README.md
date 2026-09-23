# Gravebound

A local 2D isometric modern-fantasy ranger prototype, built in Godot 4.7.2.

## Play

Open `build/Gravebound.app`, or import `project.godot` into Godot and press Play.

| Input | Action |
|---|---|
| Left click ground | Move to that point |
| Left click a dummy | Draw and fire one arrow at it |
| Shift + left click | Stand and fire one arrow toward the cursor |
| Right click | Stand and fire five arrows in a fan |
| Escape | Pause / resume |
| R | Restore dummies and clear statistics |
| M | Toggle sound |

The ranger stops to draw, launches at the release frame, and recovers before the next attack. One press triggers one attack. Ammunition is unlimited. Dummies reset 2.5 seconds after depletion. This is a movement and bow prototype; it has no enemies, loot or progression.

## Where things live

- `scripts/game.gd`: movement, projection, bow timing, hit detection, courtyard and UI.
- `assets/characters/`: painted sprite atlases, measured crop/anchor data and generation prompts.
- `tests/combat.gd`: input and combat behavior checks.
- `tests/capture.gd`: actual gameplay captures.
- `tests/capture_animation.gd`: all directional frames rendered by the same sprite code as gameplay.
- `tools/build.sh`: export a Mac app and sign it with the shared stable local certificate.
- `tools/docs/build_docs.py --publish`: rebuild the project record and collect it locally.

## Checks

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/combat.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/capture.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/capture_animation.gd
```

The painted artwork uses generated raster frames. Mirrored directions share art; idle uses a breathing motion. The single shot and five-arrow fan share the draw/release sequence. These are prototype animations, not hand-keyed production animation.
