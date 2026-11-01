extends SceneTree

## Authored gait geometry/timeline regression, not a device or GPU playtest.
const Visual = preload("res://scripts/player_visual.gd")
const CONTACTS := [true, true, true, true, false, false, true, true, true, true, false, false]
var checks := 0
var failures: Array[String] = []

func verify(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var visual := Visual.new()
	root.add_child(visual)
	verify(visual.configure() == OK, "hero resources load")
	var atlas := visual.sprite_frames.get_frame_texture(&"run", 0) as AtlasTexture
	var img := atlas.atlas.get_image()
	verify(img.get_size() == Vector2i(1536, 96), "run retains twelve 128x96 cells")
	verify(visual.pivot == Vector2(46, 77), "run retains the fixed foot pivot")
	var tops: Array[int] = []
	var planted_x: Array[float] = []
	for i in range(12):
		var cell := img.get_region(Rect2i(i * 128, 0, 128, 96))
		var bounds := cell.get_used_rect()
		tops.append(bounds.position.y)
		var row_x := 0.0
		var row_count := 0
		for x in range(128):
			if cell.get_pixel(x, 77).a > 0:
				row_x += x
				row_count += 1
		verify((row_count > 0) == CONTACTS[i], "ground contact pattern frame %s" % i)
		verify(bounds.end.y <= 78, "no pixels below ground frame %s" % i)
		planted_x.append(row_x / row_count if row_count > 0 else -1.0)
		for facing in [-1, 1]:
			visual.sample_clip(&"run", (i + 0.5) * 0.0625, facing)
			verify(visual.frame == i and visual.scale == Vector2(facing, 1), "ordered sample and visual-only mirror frame %s facing %s" % [i, facing])
	for i in range(6):
		verify(tops[i] == tops[i + 6], "same head height in both half-strides %s" % i)
	verify(tops.max() - tops.min() <= 1, "whole-cycle head bob is at most one pixel")
	for start in [0, 6]:
		var foot_world: float = planted_x[start] + start * 82.0 / 12.0
		for i in range(start + 1, start + 4):
			verify(planted_x[i] < planted_x[i - 1], "planted foot moves monotonically backwards frame %s" % i)
			verify(absf(planted_x[i] + i * 82.0 / 12.0 - foot_world) <= 1.0, "planted foot world drift is within one source pixel frame %s" % i)
	visual.sample_clip(&"run", 0.75, 1)
	verify(visual.frame == 0 and not visual.is_playing(), "run wraps on the physics clock without a duplicate end pose")
	visual.queue_free()
	await process_frame
	print("GAIT: ", checks - failures.size(), "/", checks, " passed; head rows=", tops, "; boot rows=", planted_x)
	print("LIMITATION: native atlas and timeline checks, no Android/GPU gait acceptance")
	quit(0 if failures.is_empty() else 1)
