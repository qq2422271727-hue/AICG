# Run gait correction — v0.5.1

Only `assets/hero/run_sheet.png` is replaced. The original courier skin, palette,
mask, sword, frame size (128x96), twelve-cell layout, foot pivot (46,77), import
settings and all other hero PNGs are retained. No movement/collision/combat or
animation-sampler code changes are needed.

## Cause and corrected motion

The v0.5 run pose used the same sine sign to select both horizontal foot position
and lift. During each grounded half-cycle the foot travelled from the body to the
front and back to the body. That is forward sliding, not a running stance.
The arm-driven torso yaw also let the IK pelvis settle to different heights on
the two half-strides (the old atlas's head-top rows ranged from 24 to 27).

The new near-foot track has contact samples 0-3, recovery/forward swing 4-11,
and wraps to the next contact. The far foot is six frames out of phase. Frames
4,5,10,11 are intentional flight poses, not ground-anchor errors. Grounded boot
bottoms remain at y=77; flight boot bottoms are y=72 and y=74. Contact-to-contact
root spacing is still 41 world pixels, i.e. the existing 82-pixel full stride.
Every consecutive stance sample moves the boot backwards by 82/12 = 6.833333
source pixels, cancelling the corresponding world displacement at sample
boundaries. Integer rasterization leaves at most one source pixel of drift;
held frames still have the normal discrete animation stepping.

Fixed torso yaw and a small symmetric pelvis curve make the head-top pixel rows
`27,27,26,26,26,27` repeat exactly in both halves. The physical head-point excursion
is 1.242 pixels, while the rasterized head-top excursion is one pixel. The IK
bone-length residual is below 6e-15 and the blade remains at least 7.10 pixels
above the floor. These measurements are build checks, not phone-playtest claims.

## Rebuild without modifying the original proof

The original source is the owner's local `experiments/hero_proof/render.mjs`,
SHA256 `86099037e242efb9600b669adbc821376e32bcfdbef1e51312683ead6786f1eb`,
plus its existing `vendor/` helpers. The original proof and its outputs remain
unchanged. `run_gait_v051.patch` records the small pose-only change and run-only
export entrypoint; no new npm, Python or game-runtime dependency is introduced.

Copy that original script and its vendor directory into a new temporary working
directory. In that copy only, apply `docs/run_gait_v051.patch` with `patch -p1`.
Then run `ASHWAKE_HERO_OUT=/absolute/new/output node render.mjs --run-only`.
The command writes only `run_sheet.png` and a joint/foot validation JSON into the
chosen output folder, then exits before any other pose, manifest or proof export.
Copy only the new run PNG into `assets/hero/`; do not copy the proof manifest.

Expected generated PNG SHA256:
`0d0135ea93b7c8f712009ef6d148b62ebecd3cc8d0e46ac39102d5883e1271a9`.

After Godot reimport, `tests/gait_test.gd` checks the actual imported atlas's
contact/flight pattern, backward stance travel, <=1px contact drift, symmetric
head heights, frame order, both facings and loop closure. Keep the existing
visual, smoke and combat regression suites as well. No physical Android device
or emulator acceptance is implied by these checks.
