# v0.5 candidate validation

Engine actually executed: `Godot 4.7.2.stable.official.ed1daf0bf`, Linux standard,
headless/dummy renderer. Project renderer configuration remains GL Compatibility.
All checks below were run from the assembled candidate, not merely inferred
from prior proof results. Logs are provided in `test_logs/`.

| Log | Executed result |
|---|---:|
| import.log | Editor import exit 0 |
| main_scene.log | Main scene, 180 fixed-60 render frames, exit 0 |
| smoke.log | 24/24 |
| touch.log | 17/17 |
| visual.log | 62/62 |
| camera_30.log / camera_60.log / camera_120.log | 25/25 each |
| combo.log | 78/78 |
| map_30.log / map_60.log / map_120.log | 362/362 each |
| independent/final-independent_combo_edges.log | 369/369 |
| independent/final-independent_live_qa.log | 719/719 |
| independent/final-independent_hitstop.log | 9/9 |

Project assertions: **1342/1342** (178 unchanged legacy + 78 combo + 362×3 map).
Independent additions: **1097/1097**, for **2439/2439 combined suite assertions**.
The four original regression script files are byte-for-byte copies of v0.4.
Camera checks are repeated assertions at three simulated render cadences, not
75 unique camera scenarios or a real-device FPS benchmark.

Combo tests retain proof boundary checks, timed input buffer, cancel routing,
freeze, lockout, mirrored hit rectangles, 30/60/120Hz logic checks and B atlas
pixel/timeline checks. They additionally instantiate the actual main scene and
exercise the actual player input loop, real sentry damage/de-duplication, native
touch ATK plus movement, airborne chain, dodge/hurt/death/respawn and the explicit
legacy clock compatibility adapter. The core damage case freezes AI movement
to isolate hit counting; separate independent live-enemy tests exercise actual
AI/knockback at 35/50/55/60/70/85px starting distances, static and moving forward.
Static 35–60px permits both hits; 70/85px only A; forward input permits both hits
at all tested distances. B has shorter horizontal reach by design.

Map tests retain all 256 raw terrain neighborhoods and 47 canonical-mask checks.
They additionally assert exact original platform rectangles, complete nonoverlap
visual coverage, native physics top AND underside collision rays, empty gaps
beside non-grid edges, unscaled cropped edges, one camera, original collider
count, exclusive static drawing ownership and actual native parallax movement.
Independent tests reconstruct actual native drawables rather than trusting only
the adapter's geometry metadata. Independent hit-stop tests observed three frozen
render frames at 60Hz with attack elapsed/atlas frame/input lifetime preserved.

The test-development failures were not ignored: a copied lab-only preload path
was replaced with the production visual adapter before the final run; real
hit-stop assertions exposed the same-frame delta/scale bug, which was fixed and
the entire matrix rerun. The final logs represent the corrected candidate.

Environment-only import warnings: a prohibited local TCP debugger listener
(`_sock == -1` / `ERR_CANT_CREATE`) and unavailable local Android build-tools
directory. There are no final script parse errors or failing assertions.

## Not established by this run

- Actual Android launch, multitouch latency/feel, emulator or physical-device
  behavior, power use, frame time or GPU/VRAM allocation.
- Rendered pixel appearance, shimmer during fractional camera scrolling,
  readable contrast against all backgrounds, or actual display aspect ratios.
- A newly installed APK. Any exported APK must be separately identified and
  its signing/package/integrity checks recorded outside these source results.
- GitHub publication, a source commit, or automatic changes to phone projects.

Original enemy/touch/effects/visual implementations remain preserved. The camera
update/snap functions, collision rectangles and checkpoint/win flow remain
unchanged; the world timing fix is explicitly listed in CHANGELOG.md.
