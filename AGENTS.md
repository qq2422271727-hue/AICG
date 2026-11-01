# ASHWAKE contributor and Codex notes

This repository is the canonical source for **ASHWAKE — The Last Relay**, an
original side-scrolling 2D action prototype. Treat it as a playable game, not a
template to regenerate from scratch.

## Technical baseline

- Godot **4.7.2**, GDScript, Compatibility renderer, no C#/.NET requirement.
- Android-first, landscape orientation, with desktop keyboard controls too.
- `project.godot` and `scenes/main.tscn` are at the repository root.
- `scripts/world.gd` assembles the level and owns checkpoints, camera and reset.
- `scripts/player.gd` owns movement, attack, dodge, damage and jumping.
- `scripts/enemy.gd` owns enemy states and combat responses.
- `scripts/touch_controls.gd` owns the multitouch joystick and action buttons.
- `tests/` contains headless gameplay, touch and camera regression checks.

## Preserve existing behavior

- Multi-touch: allow movement at the same time as jump, attack or dodge.
- Camera v0.3: rapid alternating left/right input must not jerk the background.
  Keep the horizontal dead zone and smooth follow; do not introduce vertical
  jitter on jumps or residual shake after restart/respawn.
- Checkpoints must preserve collected seals across deaths, but full restart
  resets the run. Preserve dodge invulnerability and enemy telegraphs.
- Keep all gameplay and visuals original. Do not import copyrighted characters,
  art, music or third-party assets without authorization and attribution.

## Editing and validation

1. Read `README.md` and `ANDROID_SYNC_GUIDE.md` before changing workflow.
2. Make focused, reviewable changes. Do not overwrite unrelated user edits.
3. Keep `*.gd.uid`, `.import` sidecars and `export_presets.cfg` under version control.
   Never commit `.godot/`, APKs, Android signing keys, secrets, or local SDK files.
4. When Godot 4.7.2 is available, run these headless commands from repo root:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/touch_test.gd
godot --headless --path . --fixed-fps 30 --script res://tests/camera_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/camera_test.gd
godot --headless --path . --fixed-fps 120 --script res://tests/camera_test.gd
```

5. Report exactly which tests were actually executed. Do not claim Android
   device testing unless a device/emulator was used. Do not replace a verified
   APK merely because the source tests passed.
6. Commit and push to the intended GitHub repository only after inspecting the
   diff; use a PR or review branch for large changes. Include the commit SHA
   and remaining limitations in the handoff.

## Collaboration

- The owner prefers **GPT-6 Astra** for core gameplay development when offered.
- The user plays and edits on the Android Godot 4.7 editor. The GitHub repository
  is the source of truth; a standalone installed APK does not auto-update.
- Preserve a simple phone sync workflow and avoid requiring an APK re-download
  for ordinary GDScript changes.
