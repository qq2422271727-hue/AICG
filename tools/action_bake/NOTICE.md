# ASHWAKE native action bake

The ceramic courier skin, palette, relay blade, action choreography, pixel
silhouette and narrow blade-tip trail design are original ASHWAKE work belonging
to the project owner. This notice does not grant a blanket license to the
project or its original art. No third-party character art is rendered.

Source lineage (existing original project proof sources, preserved unchanged):

- `experiments/hero_proof/render.mjs`: original ASHWAKE skin and Attack A proof.
- `experiments/combo_proof/art/hero_skin.mjs`: extracted original skin copied
  here, extended only to export the same blade vertices used for rasterization.
- `experiments/combo_proof/art/render_combo.mjs`: earlier B study; choreography
  is replaced here by the authored low-guard, compression, upward-drive sequence.
- `experiments/combo_proof/art/vendor/pixelfx/rig.js`: MIT fixed-bone IK from
  `patch-gg/pixelfx`. `vendor/pixelfx/skeleton.mjs` retains its solver and joint
  extraction, with unrelated dummy rendering/weapons omitted. Fixed side-view
  poses are explicit; runtime mirroring belongs to Godot, not this solver.
- `experiments/combo_proof/art/vendor/pixelfx/png.mjs`: unmodified MIT encoder.

The exact upstream license is retained at `vendor/pixelfx/LICENSE`, including
copyright notices for Patch and Hugo Duprez. That MIT license applies to the
identified vendor helper code, not to all ASHWAKE assets or project code.

These proof paths identify the existing sibling authoring experiments. They
are provenance only: this checked-in bake is self-contained and does not
import or write those experiments.
