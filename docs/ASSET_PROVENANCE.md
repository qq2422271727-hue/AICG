# Asset provenance

All paths below refer to the same local ASHWAKE workspace; no remote asset pack
was downloaded for this integration.

- Frozen baseline: `pixel_action_poc/` (v0.4). All original hero atlases, original
  frame metadata, effects and exact pixelfx MIT notices were copied.
- v0.5.1 run-only correction: `assets/hero/run_sheet.png` is rebaked from a
  temporary copy of the original `experiments/hero_proof/render.mjs` skin/IK
  pipeline. Only the running foot/hip/arm pose curves change; no new character,
  palette or third-party artwork is introduced. The original proof is preserved.
  See `RUN_GAIT_V051.md` and `run_gait_v051.patch` for reproducible construction,
  exact output hash, grounding checks and limits. Other hero PNGs are unchanged.
- New B: `experiments/combo_proof/assets/hero/attack_b_sheet.png`. 15 frames at
  128×96; low-coil/rising-cut poses generated from original ASHWAKE skin using the
  existing MIT fixed-bone helper offline. All 15 frames differ from all A frames;
  13 distinct B images, intentionally retaining authored holds/recovery poses.
- Environment: `experiments/world_art_proof/assets/`. Original deterministic
  pixel artwork; copied atlas/TileSet, sky, city, aqueduct, props and ledge.
  The proof's hero-scale reference and offline composite previews are not game
  resources in this candidate.
- The imported TileSet's only content change is its PNG path from
  `res://assets/ash_masonry_47.png` to `res://assets/world/ash_masonry_47.png`.
- No Autotiler or Blobsmith source/assets, commercial sprites, third-party font
  file, music or sound effect is incorporated. Those tools were researched in
  the prior proof, not installed or embedded here.

The exact incorporated third-party MIT license is `licenses/LICENSE.pixelfx`.
The combo proof's license/notice are additionally retained under `licenses/`.
Original ASHWAKE content belongs to the project owner; this integration makes
no new blanket licensing or redistribution policy for the owner's game.

`SOURCE_MANIFEST.sha256` in the delivered source archive hashes the complete
candidate file payload. Original PNG copies can be independently compared with
the above proofs, except the explicitly documented run-only v0.5.1 replacement;
import sidecars/resource paths may also differ.
