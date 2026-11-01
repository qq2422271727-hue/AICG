extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func verify(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures.append(label)
func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var player = game.player
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	player.position = Vector2(605,449)
	player.velocity = Vector2.ZERO
	player.facing = 1
	for i in range(4):
		await physics_frame
	Input.action_press("attack")
	var samples := 0
	var clock := -1.0
	var frame := -1
	var buffer := -1.0
	var unchanged := true
	for i in range(50):
		await process_frame
		if game.enemies[0].health == 2 and game.hit_stop > 0:
			if samples == 0:
				clock = player.combo.elapsed
				frame = player.visual.frame
				player.combo.press_attack(true)
				buffer = player.combo.buffer_left
			samples += 1
			unchanged = unchanged and is_equal_approx(clock,player.combo.elapsed) and frame == player.visual.frame and is_equal_approx(buffer,player.combo.buffer_left)
		elif samples > 0:
			break
	Input.action_release("attack")
	verify(samples >= 2, "Real contact hit-stop survives at least two 60Hz rendered-frame observations")
	verify(unchanged, "Attack elapsed, native sprite frame and full input buffer remain unchanged throughout real hit-stop")
	verify(Engine.time_scale == 1.0, "Real hit-stop exits without stuck global slow motion")
	verify(player.combo.current_attack == &"attack_a", "Hit-stop release does not skip A directly to B")
	for i in range(45):
		await physics_frame
		await process_frame
	verify(game.enemies[0].health == 1 and player.attack_id == 2, "Input buffered during real freeze produces exactly B after resume")
	game.set_process(false)
	player.set_physics_process(false)
	game.restart_run()
	player.set_physics_process(false)
	# Deterministic reproduction of the old mixed-scale-frame bug.
	game.impact(Vector2(100,100),Color.WHITE,.045,3)
	game._process(1.0/60.0)
	verify(absf(game.hit_stop-(.045-1.0/60.0)) < .000001 and Engine.time_scale == .12, "Physics-triggered scale change does not erase 45ms freeze in contact frame")
	game._process(.12/60.0)
	verify(absf(game.hit_stop-(.045-2.0/60.0)) < .000001 and Engine.time_scale == .12, "Following scaled frame consumes one real 60Hz step, not one slow step")
	game._process(.12/60.0)
	verify(game.hit_stop <= 0 and Engine.time_scale == 1.0, "Three real 60Hz steps finish the 45ms freeze")
	game.impact(Vector2.ZERO,Color.WHITE,.045,3)
	game.restart_run()
	verify(game.hit_stop == 0 and game.frame_time_scale == 1.0 and Engine.time_scale == 1.0 and game.shake == 0, "Restart atomically clears freeze, scale bookkeeping and shake")
	game.queue_free()
	await process_frame
	print("INDEPENDENT_HITSTOP_QA: %s/%s passed; actual frozen frame samples=%s" % [checks-failures.size(),checks,samples])
	quit(0 if failures.is_empty() else 1)
