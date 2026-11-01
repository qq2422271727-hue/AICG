extends SceneTree

## Focused v0.6 check: shared weapon frames, real hit events, FX and resets.
## Not a visual-quality or Android-performance claim.
var checks := 0
var failures: Array[String] = []
var impacts: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func verify(condition: bool, description: String) -> void:
	checks += 1
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		failures.append(description)

func release_impact(game: Node2D) -> void:
	game.hit_stop = 0.0
	game.frame_time_scale = 1.0
	Engine.time_scale = 1.0

func on_surface(point: Vector2, target: Rect2) -> bool:
	var inside := point.x >= target.position.x - .001 and point.x <= target.end.x + .001 and point.y >= target.position.y - .001 and point.y <= target.end.y + .001
	return inside and (is_equal_approx(point.x, target.position.x) or is_equal_approx(point.x, target.end.x) or is_equal_approx(point.y, target.position.y) or is_equal_approx(point.y, target.end.y))

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var player: AshPlayer = game.player
	var target: AshSentry = game.enemies[0]
	player.set_physics_process(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	game.combat_impact.connect(func(context: Dictionary): impacts.append(context))
	var visual = player.visual
	for clip: StringName in [&"attack", &"attack_b"]:
		var matching := true
		var mirrored := true
		var query_only := true
		var elapsed := 0.0
		for frame_index in range(15):
			visual.sample_clip(clip, elapsed + .00001, 1)
			var before_frame: int = visual.frame
			var right: Dictionary = visual.sample_weapon(clip, elapsed + .00001, 1)
			var left: Dictionary = visual.sample_weapon(clip, elapsed + .00001, -1)
			matching = matching and bool(right.valid) and int(right.frame) == before_frame
			mirrored = mirrored and left.root.is_equal_approx(Vector2(-right.root.x, right.root.y)) and left.tip.is_equal_approx(Vector2(-right.tip.x, right.tip.y))
			query_only = query_only and visual.frame == before_frame and visual.scale == Vector2.ONE
			elapsed = float(visual.clip_ends[clip][frame_index])
		verify(matching and query_only, "%s: socket queries match all 15 hero frames without changing the sprite" % clip)
		verify(mirrored, "%s: root and tip mirror about the fixed player pivot" % clip)

	player.position = Vector2(605, 449)
	player.velocity = Vector2.ZERO
	player.facing = 1
	target.position = Vector2(660, 449)
	player.combo.press_attack()
	player._advance_combat(.060)
	player._update_visual(0.0)
	verify(target.health == 2 and impacts.size() == 1, "Real A contact damages once and publishes one presentation event")
	verify(player.slash.visible and player.slash.animation == &"attack_a" and player.slash.frame == visual.frame, "A blade trail uses the exact sampled actor frame")
	verify(impacts[0].stage == &"attack_a" and on_surface(impacts[0].point, target.hurtbox()), "A spark point is on the target surface, not its centre")
	var a_pose = target._sample_pose()
	var a_pelvis_y: float = a_pose.pelvis.y
	var a_torso_scale: Vector2 = a_pose.torso_scale
	verify(target.velocity == Vector2(220, -70), "A retains the original physical knockback")
	var frozen_time: float = player.combo.elapsed
	var frozen_frame: int = visual.frame
	player.combo.press_attack(true)
	player._advance_combat(.20)
	player._update_visual(.20)
	verify(is_equal_approx(player.combo.elapsed, frozen_time) and visual.frame == frozen_frame and player.slash.frame == frozen_frame, "Existing world hit-stop holds attack, hero and trail together")
	release_impact(game)
	player._advance_combat(.168 - frozen_time)
	verify(player.combo.current_attack == &"attack_b", "Buffered hit-confirm still chains A to B at the original boundary")
	player._advance_combat(.080)
	player._update_visual(0.0)
	verify(target.health == 1 and impacts.size() == 2 and impacts[0].serial != impacts[1].serial, "B damages the same target once with a fresh stage serial")
	verify(player.slash.visible and player.slash.animation == &"attack_b" and player.slash.frame == visual.frame, "B has its own rising trail, sampled from the same frame")
	verify(impacts[1].stage == &"attack_b" and on_surface(impacts[1].point, target.hurtbox()), "B passes its stage and surface contact to presentation")
	var b_pose = target._sample_pose()
	verify(b_pose.pelvis.y < a_pelvis_y and not b_pose.torso_scale.is_equal_approx(a_torso_scale), "A compression and B upward recoil are distinct visual poses")
	verify(target.velocity == Vector2(220, -70), "B reaction does not change knockback or combo reach")
	verify(game.effects.sparks.size() > 0 and game.effects.particles.is_empty(), "Confirmed sword hits use directional sparks without a duplicate generic burst")
	var spark_life: float = game.effects.sparks[0].life
	paused = true
	await process_frame
	await process_frame
	verify(is_equal_approx(float(game.effects.sparks[0].life), spark_life), "Pause holds existing FX instead of clearing or advancing them")
	paused = false
	player._interrupt_attack(&"test_cancel")
	verify(player.combo.current_attack.is_empty() and not player.slash.visible, "Interrupt immediately clears attack and trail")
	game.effects.dash_start(Vector2(600, 469), 1, true)
	var dash_dust: int = game.effects.dust.size()
	game.effects.landing(Vector2(600, 469), 380.0, 1)
	verify(dash_dust > 0 and game.effects.dust.size() > dash_dust, "Ground dash and landing create their small foot-level dust cues")
	target.respawn()
	release_impact(game)
	var events_before := impacts.size()
	target.take_hit(1, -1)
	verify(target.health == 2 and target.velocity == Vector2(-220, -70) and impacts.size() == events_before, "Legacy two-argument enemy hit stays compatible")
	game.restart_run()
	verify(game.effects.sparks.is_empty() and game.effects.dust.is_empty() and game.effects.particles.is_empty() and game.effects.ghosts.is_empty(), "Restart clears every FX collection")
	verify(target.hit_stage.is_empty() and not target.dead and player.combo.current_attack.is_empty() and not player.slash.visible, "Restart clears enemy reaction and player action state")
	verify(is_equal_approx(game.camera.zoom.x, 1.24) and game.camera.offset == Vector2.ZERO, "Restart retains the 1.24 camera and clears residual shake")
	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	print("FEEDBACK RESULT: ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)
