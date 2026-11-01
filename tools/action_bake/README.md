# Deterministic native action atlases

Run from any directory with Node.js 18+ (no packages or network required):

```sh
node tools/action_bake/bake.mjs
```

Use `node tools/action_bake/bake.mjs --check` to deterministically rebuild in
memory and compare all five shipped outputs byte-for-byte without rewriting
runtime assets. This also records their SHA-256 values in the review report.

This updates **only** `assets/hero/{attack_sheet.png,attack_b_sheet.png,
action_tracks.json}` and `assets/fx/{attack_a_trail.png,attack_b_trail.png}`.
It reads, validates and never rewrites the manifest's existing 15 dwell times.
Both clips remain 0.300 s with the same startup/active/recovery boundaries.
The other animation atlases are never rewritten. Review output and numerical
checks go to the ignored `tools/action_bake/review/` directory.

`hero_skin.mjs` computes sockets from the exact blade-base and clipped-tip
vertices it draws. JSON positions are **untrimmed atlas pixels**. At runtime
`player_visual.sample_weapon()` uses the existing manifest frame sampler, then
subtracts (46,77), mirrors X for the requested facing, and adds (0,20). It does
not advance or change the live visual. No separate timing array is shipped
with the socket track. A frame 8 and B frame 0 have identical pixels/sockets;
A frame 11 remains close for the later whiff-chain window. The actual instant
hit-confirm cancel displays A7 then B0: their blade-base/tip differences are
3.365/4.826 px, with a 3.438-degree downward continuation into the low guard;
the bake checks this real boundary in addition to the identical A8/B0 poses.

Both trail atlases are 15 × 128 by 96, transparent and untrimmed. Their narrow
outer-tip ribbons derive from sub-frame samples of the same source poses;
the newest ribbon section is about 4 px wide, tapering to a translucent point;
the thin blade edge terminates exactly on the current exported tip. Startup
is empty; first-active frames are fully bright; recovery fades immediately
and frame 11 onward is empty. No filled crescent obscures the courier.

These are authoring tools only. The Godot project consumes native PNG/JSON
assets and does not start Node, load these modules, or use a 3D runtime.
See `NOTICE.md` for source lineage and MIT attribution.
