# ASHWAKE — The Last Relay

An original, small 2D action-game prototype. A ceramic-masked courier crosses a ruined aqueduct, takes three relay seals from broken sentries, and restores its final beacon. The hero, sentries, environment and story are original ASHWAKE work. The v0.4 hero is an offline-baked pixel character; the sword-slash effect uses MIT-licensed pixelfx / Sprite Fusion artwork with attribution in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## v0.4 source preview: a fully animated pixel courier

The previous geometric player is replaced by 69 baked frames across idle, run,
attack, takeoff, rise, fall, land, ground dodge, air dodge, hurt and death.
The ivory ceramic mask, asymmetric copper shoulder, short scarf and relay blade
are original character art. A fixed-bone 3D IK construction was baked offline into
a depth-sorted 2.5D pixel skin; this is not a finished skinned 3D character, and no
JavaScript or 3D renderer runs on the phone.

Godot's native `SpriteFrames` / `AtlasTexture` resources share one PNG per clip.
Every hero cell is 128 × 96 with the same (46, 77) foot pivot, nearest filtering,
lossless import and no mipmaps. Only the visual child flips; the 22 × 40 collider,
directional attack hitbox, movement and dodge values are unchanged. Dash echoes
freeze the current atlas frame, pivot and facing rather than drawing rectangles.

Attacks still last 0.30 seconds: 0.05 startup, 0.117 active, 0.133 recovery. The
hero's contact drawings are explicitly timed to that active window. The corrected
straight-alpha slash starts after startup and may trail through recovery; its
tail cannot deal damage. Both sprites sample the actual physics attack clock,
so pause, hit-stop, dodge cancellation, hurt, death and respawn remain in sync.
The existing combat system remains the sole source of hit-stop and camera shake.

The 12 PNG atlases total 127,809 bytes on disk. Their decoded RGBA8 pixel payload
is 4,523,008 bytes (about 4.31 MiB), not a measured total engine/GPU allocation.
The asymmetric armor is mirrored between facings, and ground/air attacks currently
share one swing clip. Foot-contact polish and real-phone visual/feel acceptance
remain to be done; headless tests cannot establish rendered appearance.

This is a source update, not a newly validated APK. The separately supplied v0.3
APK remains unchanged. Pull the source into the same phone Godot project using
the guide below; do not reinstall an APK to test ordinary source changes.

## Run in Godot

1. Install **Godot 4.7.2**, standard build (no .NET needed; this is the validated version).
2. Import `project.godot` and press **F6/F5**, or run:
   ```sh
   godot --path /absolute/path/to/pixel_action_poc
   ```
3. Run right, defeat all three sentries, and press **E** at the eastern beacon. A first run should take roughly 30–60 seconds, depending on combat and exploration.

### Open the source on a phone with Godot 4.7 Android Editor

For repeatable phone updates from the public [ASHWAKE source repository](https://github.com/qq2422271727-hue/AICG), follow the Chinese [Android sync guide](ANDROID_SYNC_GUIDE.md). The recommended phone workflow is **GitSync Client mode**, without Termux: try the public HTTPS clone URL without login if the installed version offers that option; otherwise use the documented GitHub OAuth flow. Choose **Nested clone** into **Documents**, then import **`Documents/AICG/project.godot`** in Godot. GitSync requests broad **All files access**, not access limited to the project; review that permission and any OAuth authorization before accepting. Do not create or share a personal access token for this workflow.

For later updates, save and close Godot, check that the phone has no local changes or commits, then manually choose **Pull Changes** in GitSync. Keep automatic sync disabled. Do not use **Force Pull**, **Force Push**, **Push Changes**, or **Sync All Changes** for this download-only workflow; stop and back up if local changes or conflicts appear. Reopen the same project in Godot after a successful pull. No game APK or source ZIP re-download is needed for ordinary source updates; an independently installed APK does not update with the source. This GitSync workflow has not been tested on an Android device in this environment. The guide retains Termux as an optional fallback; public Git cloning/pulling itself does not require login.

For a one-time import of the older v0.3 preview without Git, use the ZIP steps below. That archive does not contain the v0.4 hero update. Keep only one active project: the GitSync clone **or** the ZIP copy, not both.

1. Download `ASHWAKE_v0.3_Godot_Source.zip` to the phone's **Downloads** folder. This archive has `project.godot` at the ZIP root, ready for import.
2. Open the Godot Android Editor **Project Manager**, choose **Import**, and select that ZIP (or extract it and select its `project.godot`).
3. If the file is not visible, allow Godot access to device files in Android settings, then try again. Import the source archive, **not the APK**.
4. Open the imported project and tap the **Play** button to run. A Bluetooth mouse and keyboard can make editing scripts much easier on small phone screens.

The Android Editor is still an early-access editor, but this game uses GDScript and the Compatibility renderer, not C# or Forward+.

## Android APK preview

The separate `ASHWAKE_Android_Touch_v0.3.apk` build is a **debug-signed installable APK** generated with the official Godot 4.7.2 Android export template and Android SDK Build-Tools 36.0.0. It targets Android 36, supports Android 7.0 (API 24) and later, uses the `arm64-v8a` architecture, and requests no Android permissions. It is a prototype intended for manual installation, not a Play Store release.

To install on your own Android phone, download the APK, open it in a file manager, permit installation from that file-manager app if Android prompts you, then install and launch **ASHWAKE**. The orientation is landscape. Do not leave broad unknown-app installation permission enabled unnecessarily.

For a future v0.4 command-line export after configuring Godot's Android SDK, JDK 17 and export templates (not exported or device-validated in this update):

```sh
godot --headless --path /absolute/path/to/pixel_action_poc --export-debug Android /absolute/path/to/ASHWAKE_Android_Touch_v0.4.apk
```

The supplied debug signing key was generated in an isolated build environment and **is not included in the source ZIP**. A future release should use a persistent release keystore, a different package name, and proper device testing. Installing an independently re-signed debug build over this preview may require uninstalling the earlier one first.

## Controls

| Action | Keys |
| --- | --- |
| Move | A / D or Left / Right |
| Jump / air jump | Space, W or Up |
| Light melee attack | J or X |
| Dodge, including in air | Shift or K |
| Activate final relay | E |
| Restart entire run, including enemy respawns | R |
| Pause | Esc |

On an Android touchscreen, the game uses **landscape orientation** and an on-screen layout: drag the left joystick to run; on the right, use **JUMP**, **ATK**, **DASH**, and **USE**. The top-right controls are **II** (pause/resume) and **RST** (restart). Two or more fingers work simultaneously (for example, move while attacking or jumping). Touch buttons are hidden when playing on a desktop without a touchscreen.

**v0.3 camera:** rapid changes in movement direction no longer shift the whole background. The camera stays still while the player moves within a 120-pixel margin on either side of the tracked center, then smoothly follows for longer traversal. The camera is vertically stable during jumps, freezes when paused, and immediately resets on checkpoint respawns or full restarts without carrying over combat shake. Parallax backgrounds use the actual smoothed camera screen center instead of the unsmoothed target. Brief intentional impact shake remains during combat.

Jump height responds to release. Attacks can be buffered near the end of recovery; dodging cancels an attack. Dodge lasts 0.22 seconds, has 0.19 seconds of invulnerability and a 0.62 second cooldown. The orange enemy marker telegraphs an attack for 0.55 seconds. Dodge through the strike or punish its recovery.

Two checkpoints preserve recovered seals after death. Unbeaten sentries reset on player respawn; beaten sentries remain down until a full restart. Falling costs a life/run death, not progress on recovered seals. R resets everything and respawns every sentry.

## Structure

- `scenes/main.tscn`: tiny bootstrap scene.
- `scripts/world.gd`: input mapping, level assembly, checkpoints, camera, win/reset flow and environment art.
- `scripts/player.gd`: movement, coyote time, input buffers, double jump, dodge, light attack and health.
- `scripts/player_visual.gd`: native atlas loading and physics-clock hero frame sampling.
- `scripts/pixelfx_slash.gd`: visual-only slash atlas synchronized to the same attack clock.
- `assets/hero/`: original hero sheets and the explicit frame-duration/pivot manifest.
- `assets/fx/`: corrected straight-alpha MIT sword-slash sheet and metadata.
- `scripts/enemy.gd`: patrol/chase/telegraph/strike/recover/hurt/dead state machine.
- `scripts/effects.gd`: shared particles and dodge afterimages.
- `scripts/hud.gd`: health, dodge cooldown, objectives, controls and result screen.
- `scripts/touch_controls.gd`: responsive multi-touch virtual stick and six action buttons.

The fixed physics step is 60 Hz; rendering uses the lightweight compatibility renderer. Damage is evaluated with explicit directional hit rectangles; each light swing can damage each target only once. Player/enemy bodies collide with terrain but not each other, so invulnerable rolls can cross an enemy cleanly. Platforms are solid rather than one-way.

## Prototype boundaries

This is one hand-authored traversal/combat lane, one enemy archetype, one light attack, and a short completion loop. It is not a content-complete game: no controller/touch *remapping*, audio, save system, procedural maps, weapon tree or full production animation pipeline yet. The environment and enemies remain deliberately geometric; the protagonist now has a native pixel-atlas animation pipeline.

## Validation

For the **v0.4 source**, the official Godot 4.7.2 Linux engine completed editor
import, a 180-frame headless main-scene run, **62/62 native animation checks**,
**24/24 gameplay checks**, **17/17 mobile control checks**, and **25/25 camera
checks at each of 30, 60 and 120 simulated render FPS**. The animation checks
cover all eleven clips, shared atlas regions, the fixed pivot, contact-frame
timing, frozen attack clocks, slash cancellation/straight alpha, mirrored visuals
without mirrored collision, frozen dash echoes and immediate respawn reset.
The headless/dummy renderer does not validate actual rendered pixels or Android
performance. No connected Android device or emulator was used. Editor import
reported the environment's blocked local debugger listener and unavailable local
Android build-tools directory, but resource import and all tests exited 0.

The following paragraph describes the **previous v0.3 APK**, not a v0.4 export:

Verified with the official **Godot 4.7.2** Linux engine: editor import, **24/24 gameplay checks**, **17/17 mobile control checks**, and **25/25 camera stability checks at each of 30, 60, and 120 simulated render FPS** passed. The engine-driven gameplay test covers movement, jump/air jump, landing, dodge invulnerability, damage, melee single-hit behavior, enemy death/respawn, checkpoint persistence, win/restart flow, and enemy states. The touch test injects simulated screen-touch/drag events into the game viewport and checks joystick direction, multi-finger concurrent actions, and all six buttons. Camera tests check both the target and the actual displayed center: repeated rapid facing reversals, exact dead-zone margins, smoothing, stable vertical framing, pause/resume, checkpoint respawns, shake cleanup, out-of-bounds teleports, restarts, and 20:9/4:3 window framing. The Android debug APK was successfully exported and validated with `apksigner verify`, `aapt dump badging`, `zipalign`, and `unzip -t`. The APK is structurally installable, but **no Android emulator or physical Android device was connected to this environment**, so real-device launch and feel testing remain to be done. The editor's debugger socket and ADB daemon are unavailable in the restricted authoring environment; they do not prevent exporting the APK.

```sh
godot --headless --path /absolute/path/to/pixel_action_poc --editor --quit
godot --headless --path /absolute/path/to/pixel_action_poc --quit-after 180
godot --headless --path /absolute/path/to/pixel_action_poc --script res://tests/smoke_test.gd
godot --headless --path /absolute/path/to/pixel_action_poc --script res://tests/touch_test.gd
godot --headless --path /absolute/path/to/pixel_action_poc --script res://tests/visual_test.gd
godot --headless --path /absolute/path/to/pixel_action_poc --fixed-fps 60 --script res://tests/camera_test.gd
```

Repeat the camera test with `--fixed-fps 30` and `--fixed-fps 120` for the other simulated render cadences. These checks are not real-device performance benchmarks.
