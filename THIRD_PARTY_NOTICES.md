# ASHWAKE v0.5 candidate asset and runtime notices

The ceramic-masked relay courier design, armor/cloth/mask pixel skin, palette,
weapon and authored poses are original ASHWAKE work. The baked hero sheets in
`assets/hero` use a fixed-length 3D IK skeleton from `patch-gg/pixelfx` as an
offline construction aid. They are a depth-sorted 2.5D pixel skin, not a finished
skinned 3D model, and do not include any commercial game's character artwork.

The sword-slash effect in `assets/fx` derives from `patch-gg/pixelfx`, including
Sprite Fusion / Hugo Duprez's MIT-licensed pixel VFX. Its PNG export was corrected
to preserve straight-alpha RGB; six wholly transparent tail frames were removed.
The original fixed frame dimensions and pivot are preserved. The GDScript adapter
retimes the 18 retained frames from the game's attack clock and does not execute
the upstream actor simulation, damage, hit-stop or camera shake.

The exact upstream MIT license is in `licenses/LICENSE.pixelfx`. The upstream
notice is retained verbatim in `licenses/NOTICE.pixelfx.md`; its mentions of other
upstream components do not mean those components are present in this game.
No `gallery/fonts` files, Patch Pixel font, Hollow Crown actors, JavaScript
runtime, npm package, network service or upstream dummy character is shipped.

Source: https://github.com/patch-gg/pixelfx

The new `attack_b_sheet.png` is original ASHWAKE authored rising-cut art using
the same offline fixed-bone construction aid. The isolated combo proof's exact
MIT license and notice are preserved in `licenses/LICENSE.combo-proof` and
`licenses/NOTICE.combo-proof.md`; paths mentioned inside that upstream notice
refer to the isolated proof, not to runtime dependencies in this game.

`assets/world` contains original ASHWAKE atlas, sky, city, aqueduct, props and
ledge pixels copied from the local world-art proof. No Autotiler/Blobsmith demo
art, commercial game sprites, fonts, sound packs or remote asset package was
imported. `scripts/world_art.gd` is an original adapter; it does not redistribute
those tools. The sentry, dynamic markers and HUD remain original code-drawn
ASHWAKE artwork. See `docs/ASSET_PROVENANCE.md` for source paths and hashes.

This integration does not impose a new blanket license on the owner's existing
game. Third-party notices govern their respective incorporated material.
