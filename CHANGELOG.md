# Changelog

## 0.5.1 — mobile playtest visual refinement

- Refined the 12-frame run gait to address sliding/limping feedback.
- Realigned A's slash effect to the actual sword animation, without changing hit logic.
- Enlarged the playable world via Camera2D zoom while retaining camera smoothing.
- Reduced the visible mobile controls while preserving usable multitouch targets.
- Focused regression checks only; final Android phone feel awaits the next user playtest.

## 0.5-combo-world-candidate — 2026-11-01 task

Originally prepared as an unpublished candidate from frozen v0.4 plus two
isolated proofs; v0.5 was subsequently published to GitHub. Existing installed
APKs are not modified by source updates.

### Playable integration

- Integrated ComboMachine into the actual AshPlayer rather than shipping the
  stationary lab as a replacement game. Preserved original movement, collider,
  jump/double-jump, dodge cooldown/invulnerability, checkpoint/seal and win loop.
- Added the 15-frame original B rising cut to the complete production manifest.
  Preserved all original 11 clips and A's 300ms timing. B is also 300ms.
- Retained 140ms buffering; implemented explicit hit/whiff A→B cancel windows,
  half-open damage windows, per-stage target de-duplication, held-edge suppression,
  and atomic dodge/hurt/death/respawn cancellation. Keyboard and touch share ATK.
- `attack_time` is now a compatibility view/seek into ComboMachine, not a second
  ticking clock. Original animation regression tests remain unchanged.
- Fixed the original world's same-frame hit-stop bug: process delta is scaled
  before physics contacts can change Engine.time_scale. Dividing by the new
  scale could expire 45ms immediately. A remembered frame scale now reconstructs
  the correct delta. The attack clock/buffer freeze on the existing timer;
  no separate impact timer, extra shake or duplicate hit effect is introduced.
- Kept A's horizontal slash VFX; intentionally hide it for B rather than visually
  contradict B's rising trajectory. Added a compact stage/phase HUD hint.

### World

- Added original masonry/sky/city/aqueduct/props/ledge assets from world_art_proof.
- Added a visual-only world-art adapter: 558 full native cells + 114 unscaled
  fractional ground crops + 15 thin-ledge slices. Exact original 8 platform
  rectangles and 2 boundary colliders remain unchanged.
- Added two native Parallax2D layers driven by the original smoothed Camera2D.
  Removed the old opaque background/manual parallax/brick draw commands entirely;
  preserved hazards, checkpoint lamps, final relay, particles and gameplay art.
- Kept Compatibility rendering, lossless nearest PNG imports and no mipmaps.
  No runtime Node/Python/plugin dependencies; no terrain writes per frame.

### Verification / limits

- Godot 4.7.2 editor import and 180 headless main-scene frames completed.
- Unchanged v0.4 regression: 178/178. Added combo: 78/78. Added map: 362/362 at
  each of 30, 60 and 120 simulated render FPS. Project matrix: 1342/1342.
- Independent QA: 369 boundary + 719 draw/live-enemy + 9 hit-stop checks =
  1097/1097; combined suite assertions 2439/2439 (not a device benchmark).
- Preserved original third-party license notices and added provenance for B and
  environment assets. No original directory or experiment was edited.
- No physical Android/emulator test, rendered-GPU screenshot/feel validation or
  phone performance claim. Shorter B reach can miss after tip-range A knockback.
  Native tests are not a substitute for those remaining acceptance checks.
