# ASHWAKE — The Last Relay · v0.5

**A complete playable Godot project, not the isolated combat/map proof.**
The ceramic-masked courier must recover three seals from ruined sentries,
cross two gaps and activate the eastern relay. Version 0.5 integrates a
second attack and original aqueduct pixel artwork into the existing game.

Status: source validated with **Godot 4.7.2.stable.official.ed1daf0bf**,
Compatibility renderer. The v0.5 integration was prepared independently of
the frozen v0.4 source. Once v0.5 is merged into the public repository's
`main` branch, GitSync users can obtain it through the update workflow below.
No physical Android device, emulator or real-GPU visual playtest was performed
by the integration task. Automated success does not establish mobile frame
rate, touch feel or rendered pixel quality.

## Open and play

1. Import this folder's `project.godot` in Godot **4.7.2 standard**, then press F5.
2. On the Android Editor, choose one source workflow:
   - **GitHub / GitSync:** follow `ANDROID_SYNC_GUIDE.md` to clone the public
     repository's `main` branch into `Documents/AICG`, or safely pull updates
     into your existing clean clone after v0.5 has been merged into `main`.
   - **Standalone source ZIP:** extract the supplied v0.5 source ZIP, or a
     source ZIP downloaded from GitHub, into a new folder and import its root
     `project.godot`. GitHub ZIP filenames and top-level folders can vary.
     A ZIP extraction is not a Git clone and does not receive GitSync pulls.
   Do not overwrite a phone project with local edits. This is source, not an APK.
3. Move right, defeat all three sentries, cross the gaps and press **E / USE**
   at the final relay. The original health, death, checkpoints and restart loop
   remain playable. Ground and upper platforms remain solid from both sides.

```sh
godot --path /absolute/path/to/AICG
```

GitSync pulls the selected branch, not a standalone ZIP or an unmerged branch.
After v0.5 is merged into `main`, pull `main` and reopen the same
`Documents/AICG/project.godot`; do not switch to an older ZIP copy.
Until that merge, pulling `main` still retrieves the previous main-branch code.
Keep ZIP projects separate from the GitSync-managed folder.
An independently installed APK never updates when source is changed.

## Controls

| Action | Desktop | Android touch |
|---|---|---|
| Move | A/D or left/right | Left joystick |
| Jump / air jump | Space, W or up | JUMP |
| Attack A, then chain B | Tap J/X, then tap again | Tap ATK, then tap again |
| Dodge / cancel attack | Shift or K | DASH |
| Activate relay | E | USE |
| Pause | Esc | II |
| Full restart | R | RST |

The same `attack` action drives both attacks and both input methods. There is
no B button. Holding ATK/J does not repeat or automatically chain. The original
multi-touch implementation still permits movement plus attack/jump/dodge.

## Two-strike combat

A is the existing forward cut; B uses **15 new low-windup, rising-cut frames**,
not a speed/color variation of A. The original 11 animation clips are preserved.
B has the same fixed 128×96 canvas and (46,77) foot pivot. Only the visual child
flips; collider, movement speed, gravity and jump values are unchanged.

| Stage | Startup | Active interval | Recovery | Full un-cancelled duration |
|---|---:|---|---:|---:|
| A | 50 ms | [50,167) ms | 133 ms | 300 ms |
| B | 67 ms | [67,167) ms | 133 ms | 300 ms |

Input buffer: **140 ms**, not 14%. Hit-confirmed A can enter B from 167 ms;
whiffed A can enter B from 233 ms. Both windows close before 280 ms. Too-early
taps expire; taps after the close queue a fresh A after A's full recovery,
not a stale B. B never early-cancels back to A. A live late buffer may start a
new A only after B's 300 ms finishes. Landing is not required to chain.

Each stage has its own serial and hit-target set: one damage per target per
stage. A retains its 70×53 forward hitbox; B uses a 62×76 higher hitbox. B is
shorter horizontally, so a tip-range A that knocks a sentry away can whiff B;
start closer or keep moving toward the target. Independent real-enemy tests
confirmed A+B at static starting distances of 35–60px, A-only at 70/85px, and
A+B at all six tested distances while holding movement toward the enemy.
B does not add root-motion slide. A's end is now explicitly half-open at 167ms;
the former inclusive endpoint no longer permits damage on that exact boundary.

Dodge, hurt, death and respawn atomically clear old attack/buffer/hit state.
The existing world's impact timer drives freeze; no second local hit-stop or
camera shake is layered on top. Attack pose and buffered input stop together.
The v0.4 hit-stop timer's same-frame time-scale bug is corrected (see changelog).
A keeps its licensed slash VFX; B deliberately shows its authored blade/body
motion without reusing A's horizontal slash in the wrong direction.

## World-art integration

- One original 47-tile atlas, **3 visual-only TileMapLayer nodes**, 558 full
  32px cells, 114 cropped ground-edge pieces, and 15 thin-platform slices.
- Three original floor Rect2s remain `(-80,470,1010,220)`,
  `(1070,470,820,220)`, `(2030,470,1210,220)`. Five 18px-high upper platforms
  keep their original positions and widths of 135/135/126/134/132px.
- Fractional edges are source-cropped, never stretched or snapped to 32px.
  Both edges and the underside of thin ledges are preserved by three-piece
  slicing. No art tile creates physics, navigation or occlusion shapes.
- Two native Parallax2D layers use the **existing Camera2D's displayed scroll**
  at 0.24 and 0.52 relative speed, with 1536px repeats. The sky fills the viewport.
- The old opaque background and manual parallax drawing were removed entirely;
  they would otherwise hide/compete with the negative-z native layers.
  Hazard marks, active checkpoints, relay, dust and all gameplay remain.
- The 120px horizontal camera margins, smoothing, fixed vertical framing,
  respawn snap, pause and shake cleanup remain unchanged.

All PNGs use lossless import, nearest sampling and no mipmaps. Runtime is native
Godot only: no Node, Python, web service, runtime terrain plugin or 3D renderer.
Nearest filtering does not guarantee uniform pixels at non-integer window scales.
See `docs/ASSET_PROVENANCE.md` and `THIRD_PARTY_NOTICES.md` for asset provenance.

## Tests actually run

```sh
GODOT_BIN=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64 bash verify.sh
```

| Check | Result |
|---|---:|
| Editor import + 180-frame main-scene run | Exit 0 |
| Unmodified v0.4 gameplay | 24/24 |
| Unmodified v0.4 touch | 17/17 |
| Unmodified v0.4 native animation | 62/62 |
| Unmodified camera at 30 / 60 / 120 simulated render FPS | 25/25 each |
| v0.5 combo logic, native B assets and real main-scene input | 78/78 |
| v0.5 map at 30 / 60 / 120 simulated render FPS | 362/362 each |
| **Project regression total** | **1342/1342** |
| Independent combo boundary / scheduling equivalence | 369/369 |
| Independent actual drawable geometry + live-enemy physics | 719/719 |
| Independent cross-frame hit-stop | 9/9 |
| **Combined distinct suite assertions executed** | **2439/2439** |

Logs are in `test_logs/`; detailed scope and known limits are in
`docs/VALIDATION.md`. Independent scripts are under `tests/independent/`.
The map tests exhaust all 256 raw neighbor arrangements, check exact
visual/collider coverage, actual top/bottom collision rays, gap emptiness,
native parallax and lack of per-frame tile changes. Combo tests exercise actual
main-scene keyboard/touch, airborne chain, global hit-stop, held-input suppression,
interruption and respawn, in addition to the unchanged legacy compatibility seek.

The editor emitted the environment's blocked local debugger listener and
unavailable local Android build-tools warning; resource import and tests still
exited 0. Source validation is not a claim that an APK was exported or a phone
was tested. Any separately supplied APK has its own export/validation record.

## Project layout / remaining work

`scripts/player.gd` remains the movement controller; `combo_machine.gd` is its
single attack authority. `world.gd` remains the level/checkpoint/camera owner;
`world_art.gd` is visual-only. `player_visual.gd`, enemy and touch scripts retain
the original contracts. `docs/README_v04.md` is the historical v0.4 documentation.

Still one short authored lane and one enemy archetype: no save system, audio,
procedural generation, roguelite progression, controller remapping or weapon
tree. The second/third combat zones share repeatable scenery rather than unique
bespoke landmarks. Enemies and dynamic markers remain code-drawn. Android
launch/feel, rapid-reversal pixel shimmer, fill-rate and screenshot acceptance
remain unverified; publishing the source does not establish Android readiness.
During the original candidate integration, the separate v0.4 project and both
proofs were left untouched, and that integration step made no Git commit or push.
This is historical context, not the current publication status.
