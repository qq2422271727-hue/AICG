extends SceneTree
## Focused geometric regression. No damage changes or GPU/device claims.
const Slash = preload("res://scripts/pixelfx_slash.gd")
const Visual = preload("res://scripts/player_visual.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func verify(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + label)

func _run() -> void:
	var fx := Slash.new()
	var hero := Visual.new()
	root.add_child(fx)
	root.add_child(hero)
	verify(fx.configure() == OK and hero.configure() == OK, "Native resources configure")
	var max_root_error := 0.0
	var max_tip_error := 0.0
	var max_mirror_error := 0.0
	for elapsed: float in [0.05, 0.088, 0.089, 0.127, 0.128, 0.166, 0.167, 0.185, 0.186, 0.204, 0.205, 0.223]:
		var right_root := Vector2.ZERO
		var right_tip := Vector2.ZERO
		for facing: int in [1, -1]:
			hero.sample_clip(&"attack", elapsed, facing)
			fx.sync_attack(0.30 - elapsed, facing, hero.frame)
			var points: Array = Slash.BLADE_POSES[hero.frame]
			var expected_root: Vector2 = hero.transform * (points[0] + hero.offset)
			var expected_tip: Vector2 = hero.transform * (points[1] + hero.offset)
			var actual_root: Vector2 = fx.transform * (Slash.RIBBON_ROOT + fx.offset)
			var actual_tip: Vector2 = fx.transform * (Slash.RIBBON_TIP + fx.offset)
			max_root_error = maxf(max_root_error, actual_root.distance_to(expected_root))
			max_tip_error = maxf(max_tip_error, actual_tip.distance_to(expected_tip))
			verify(fx.visible and fx.frame > 0, "%.0f ms facing %d: correct socket pose %d / forward FX" % [elapsed * 1000, facing, hero.frame])
			if facing == 1:
				right_root = actual_root
				right_tip = actual_tip
			else:
				max_mirror_error = maxf(max_mirror_error, actual_root.distance_to(Vector2(-right_root.x, right_root.y)))
				max_mirror_error = maxf(max_mirror_error, actual_tip.distance_to(Vector2(-right_tip.x, right_tip.y)))
	verify(max_root_error < 0.001 and max_tip_error < 0.001, "FX root and tip attach to measured sword sockets within 0.001 world pixel")
	verify(max_mirror_error < 0.001, "Left/right transforms mirror both endpoints without double flip")
	fx.sync_attack(0.25, 1, 5)
	verify(fx.frame == 1, "First active sample skips rear-facing source disc")
	fx.sync_attack(0.134, 1, 7)
	verify(fx.frame == 8, "Last active sample still uses the final dense ribbon frame")
	fx.sync_attack(0.133, 1, 8)
	verify(fx.frame == 9, "Recovery starts on sparse trail, not a second bright slash")
	fx.sync_attack(0.10, -1, 9)
	var frozen := fx.transform
	var frame := fx.frame
	var alpha := fx.modulate.a
	for i in range(20):
		fx.sync_attack(0.10, -1, 9)
	verify(fx.transform == frozen and fx.frame == frame and fx.modulate.a == alpha, "Hit-stop freezes socket, source frame and fade together")
	fx.sync_attack(0.076, 1, 11)
	verify(not fx.visible, "Blade return after 224 ms cannot drag old particles behind the actor")
	fx.sync_attack(0.251, 1, 4)
	verify(not fx.visible, "Startup remains FX-free")
	fx.sync_attack(0.0, -1)
	verify(not fx.visible, "Interrupt hides FX immediately")
	print("MAX_SOCKET_ERROR_PX: ", max_root_error, " MAX_TIP_ERROR_PX: ", max_tip_error, " MAX_MIRROR_ERROR_PX: ", max_mirror_error)
	print("RESULT: ", checks - failures, "/", checks, " slash alignment checks passed")
	fx.queue_free()
	hero.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
