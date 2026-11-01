extends SceneTree
var game: Node2D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func ticks(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await ticks(3)
	var art = game.world_art
	# Rebuild coverage from actual drawable nodes, NOT author-maintained metadata.
	var drawn: Array[Rect2] = []
	for layer: TileMapLayer in art.ground_layers:
		for cell in layer.get_used_cells():
			drawn.append(Rect2(layer.to_global(layer.map_to_local(cell) - Vector2(16,16)), Vector2(32,32)))
	for sprite: Sprite2D in art.edge_sprites:
		drawn.append(Rect2(sprite.to_global(sprite.get_rect().position), sprite.get_rect().size))
	for index in range(game.platforms.size()):
		var expected: Rect2 = game.platforms[index]
		var area := 0.0
		var overlap := false
		var pieces: Array[Rect2] = []
		for rect in drawn:
			if expected.encloses(rect):
				area += rect.get_area()
				for prior in pieces:
					overlap = overlap or prior.intersects(rect)
				pieces.append(rect)
		verify(not overlap and is_equal_approx(area,expected.get_area()), "Actual draw geometry equals platform %s, not metadata-only" % index)
	for rect in drawn:
		var belongs := false
		for expected: Rect2 in game.platforms:
			belongs = belongs or expected.encloses(rect)
		verify(belongs, "Actual drawable contained in a real platform")
	# The real enemy AI, knockback, hurt timing, collision and player motion run.
	for moving in [false,true]:
		for gap in [35.0,50.0,55.0,60.0,70.0,85.0]:
			game.restart_run()
			var player = game.player
			var enemy = game.enemies[0]
			for other in game.enemies:
				other.set_physics_process(other == enemy)
			player.position = Vector2(600,449)
			player.velocity = Vector2.ZERO
			player.facing = 1
			enemy.position = Vector2(600+gap,449)
			enemy.velocity = Vector2.ZERO
			enemy.state = enemy.State.TELEGRAPH
			enemy.state_time = .55
			await ticks(2)
			var start_serial: int = player.attack_id
			if moving:
				Input.action_press("move_right")
			Input.action_press("attack")
			await ticks(2)
			Input.action_release("attack")
			for i in range(60):
				if player.combo.current_attack == &"attack_a" and player.combo.elapsed >= .09:
					break
				await ticks(1)
			Input.action_press("attack")
			await ticks(2)
			Input.action_release("attack")
			var b_enter_gap := -1.0
			var b_active_gap := -1.0
			for i in range(55):
				if player.combo.current_attack == &"attack_b":
					if b_enter_gap < 0:
						b_enter_gap = enemy.position.x-player.position.x
					if player.combo.can_hit() and b_active_gap < 0:
						b_active_gap = enemy.position.x-player.position.x
				await ticks(1)
			Input.action_release("move_right")
			verify(player.attack_id == start_serial + 2, "Real enemy case starts exactly A/B gap=%s moving=%s" % [gap,moving])
			verify(enemy.health >= 1, "A/B never damages more than once per stage gap=%s moving=%s" % [gap,moving])
			print("LIVE_REACH: initial_gap=%s moving=%s hits=%s b_enter_gap=%.2f b_active_gap=%.2f" % [gap,moving,3-enemy.health,b_enter_gap,b_active_gap])
	game.queue_free()
	await process_frame
	print("INDEPENDENT_LIVE_QA: %d/%d passed" % [checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)
