extends SceneTree

## Run: godot --headless --path . --script res://tests/smoke_test.gd
## This is a gameplay regression test, not a substitute for a human feel test.
var game: Node2D
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func verify(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		printerr("FAIL: ", description)

func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func tap(action: String) -> void:
	Input.action_press(action)
	await ticks(2)
	Input.action_release(action)
	await ticks(1)

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	await ticks(8)
	var player: AshPlayer = game.player
	verify(player.is_on_floor(), "Player spawns on collision terrain")
	verify(player.health == 5, "Player starts with five health")
	var start_x := player.position.x
	Input.action_press("move_right")
	await ticks(24)
	Input.action_release("move_right")
	verify(player.position.x > start_x + 60, "Horizontal acceleration produces movement")
	await tap("jump")
	verify(player.position.y < 445 and player.velocity.y < 0, "Ground jump rises")
	await ticks(5)
	await tap("jump")
	verify(not player.air_jump and player.velocity.y < 0, "Second jump consumes air jump")
	await ticks(70)
	verify(player.is_on_floor(), "Player lands on terrain")
	await tap("dodge")
	verify(player.dodge_time > 0 and player.invulnerable > 0, "Dodge starts with invulnerability")
	var prior_health := player.health
	verify(not player.take_hit(1, -1) and player.health == prior_health, "Dodge rejects incoming damage")
	await ticks(55)
	verify(player.take_hit(1, -1) and player.health == prior_health - 1, "Damage applies outside invulnerability")
	await ticks(65)
	var enemy: AshSentry = game.enemies[0]
	player.position = Vector2(600, 449)
	player.velocity = Vector2.ZERO
	player.facing = 1
	enemy.position = Vector2(660, 449)
	await ticks(3)
	await tap("attack")
	await ticks(16)
	verify(enemy.health == 2, "One melee swing damages a target exactly once")
	await ticks(10)
	for i in range(2):
		await tap("attack")
		await ticks(29)
	verify(enemy.dead and game.seals.has(0), "Three hits kill a sentry and recover its seal")
	enemy.respawn()
	verify(not enemy.dead and enemy.health == 3 and enemy.position == enemy.home, "Enemy respawn restores health and patrol position")
	# Re-kill the collected enemy so checkpoint persistence is tested honestly.
	enemy.take_hit(3, 1)
	game.checkpoint = Vector2(1120, 448)
	game.checkpoint_index = 1
	player.invulnerable = 0
	player.take_hit(99, -1)
	verify(player.dead, "Lethal damage enters player death state")
	await ticks(130)
	verify(not player.dead and player.health == 5, "Player automatically respawns with full health")
	verify(absf(player.position.x - 1120) < 2 and game.seals.has(0), "Checkpoint respawn preserves recovered seals")
	verify(enemy.dead, "Collected sentry stays defeated after player death")
	game.seals.assign([0, 1, 2])
	player.position = Vector2(2960, 449)
	await tap("interact")
	verify(game.won, "Three seals and beacon interaction complete the run")
	game.restart_run()
	verify(not game.won and game.seals.is_empty() and game.deaths == 0, "Full restart clears run progression")
	verify(not enemy.dead and enemy.health == 3, "Full restart respawns all sentries")
	enemy.set_physics_process(true)
	var patrol_start := enemy.position.x
	await ticks(8)
	verify(enemy.state == AshSentry.State.PATROL and enemy.position.x < patrol_start, "Unengaged enemy patrols")
	player.position = Vector2(600, 449)
	player.velocity = Vector2.ZERO
	player.invulnerable = 0
	enemy.position = Vector2(660, 449)
	await ticks(5)
	verify(enemy.state == AshSentry.State.TELEGRAPH, "Nearby player causes chase and readable wind-up")
	await ticks(47)
	verify(player.health == 4, "Enemy strike damages the player once")
	verify(enemy.state == AshSentry.State.RECOVER, "Enemy exposes a recovery window after striking")
	enemy.take_hit(1, 1)
	verify(enemy.state == AshSentry.State.HURT, "Melee hit interrupts enemy with a hurt reaction")
	game.queue_free()
	await process_frame
	print("RESULT: ", checks - failures.size(), "/", checks, " checks passed")
	quit(0 if failures.is_empty() else 1)
