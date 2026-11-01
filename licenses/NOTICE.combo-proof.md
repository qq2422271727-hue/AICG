# Sources and scope

`art/hero_skin.mjs` is a self-contained extraction of the original ASHWAKE
`experiments/hero_proof/render.mjs` polygon skin. `art/render_combo.mjs` authors
new low-to-high B poses; the runtime state machine, training room and tests are
new ASHWAKE work. Original A and idle atlases are unchanged local copies of
the ASHWAKE hero-proof output. `scripts/hero_visual.gd` is an unchanged local
copy of the ASHWAKE v0.4 native-atlas sampler. Project-original material is MIT
licensed as in the supplied project `LICENSE`.

`art/vendor/pixelfx/` preserves the existing unmodified upstream MIT files from
the hero proof. Only `skeleton()` and the PNG encoder are used. The upstream
dummy artist/weapon renderer is not used for these images. Its exact license
is in `art/vendor/pixelfx/LICENSE`.

No Rakugaki Rumble source implementation or restricted sprite was copied; the
general idea of enumerated cancel routes is independently implemented here.
No Dead Cells asset, animation, character, sound, logo or game code is included.
The review scripts use an installed system DejaVu Sans Mono font without
redistributing the font file.
