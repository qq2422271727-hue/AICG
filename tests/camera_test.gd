extends SceneTree

## Regression for camera shake caused by quick left/right input.
## Run with --fixed-fps 30, 60 or 120 to cover different render cadences.

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func verify(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures.append(label)
		printerr("FAIL: ", label)

func frames(count: int = 2) -> void:
	for i in range(count):
		await process_frame

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.player.set_physics_process(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	var camera: Camera2D = game.camera
	await frames()
	verify(is_equal_approx(camera.position.x, 480.0), "Camera begins at the level's left boundary")
	game.player.facing = -1
	await frames()
	verify(is_equal_approx(camera.position.x, 480.0), "Turning in place never shifts the background")
	game.player.position.x = 540.0
	game.player.facing = 1
	await frames()
	verify(is_equal_approx(camera.position.x, 480.0), "Small movement inside the quiet zone keeps scenery fixed")
	game.player.position.x = 800.0
	await frames()
	verify(is_equal_approx(camera.position.x, 680.0), "Camera starts tracking beyond the right margin")
	game.player.facing = -1
	await frames()
	verify(is_equal_approx(camera.position.x, 680.0), "Instant facing reversal does not flick camera position")
	game.player.position.x = 700.0
	await frames()
	verify(is_equal_approx(camera.position.x, 680.0), "Reversing within the quiet zone leaves scenery stable")
	game.player.position.x = 500.0
	await frames()
	verify(is_equal_approx(camera.position.x, 620.0), "Camera tracks after passing the left margin")
	game.player.position.y = 300.0
	await frames()
	verify(is_equal_approx(camera.position.y, 270.0), "Jumping does not bob the whole scene vertically")
	game.player.position.x = 3000.0
	await frames()
	verify(is_equal_approx(camera.position.x, 2680.0), "Camera clamps at the far edge of the map")
	game.restart_run()
	await frames()
	verify(is_equal_approx(camera.position.x, 480.0), "Restart snaps the camera back to the start")
	game.player.set_physics_process(false)
	verify(camera.get_screen_center_position().is_equal_approx(Vector2(480, 270)), "Restart resets the displayed center, not only its target")
	var quiet_zone_stable := true
	for i in range(60):
		game.player.facing = 1 if i % 2 == 0 else -1
		game.player.position = Vector2(540 if i % 2 == 0 else 420, 300 if i % 2 == 0 else 449)
		await frames(1)
		quiet_zone_stable = quiet_zone_stable and camera.get_screen_center_position().is_equal_approx(Vector2(480, 270))
	verify(quiet_zone_stable, "Repeated rapid reversals and jumps leave the displayed scenery still")
	game.player.position = Vector2(1200, 449)
	await frames(4)
	var moving_center := camera.get_screen_center_position()
	verify(moving_center.x > 480 and moving_center.x < camera.position.x, "Actual camera scroll is smoothed instead of snapping to the target")
	paused = true
	await frames(12)
	verify(camera.get_screen_center_position().is_equal_approx(moving_center), "Pausing freezes in-progress camera smoothing")
	paused = false
	await frames(4)
	verify(camera.get_screen_center_position().x > moving_center.x, "Camera smoothing resumes after unpausing")
	game.player.position = Vector2(1120, 448)
	camera.offset = Vector2(-4, 3)
	game.shake = 5
	game._snap_camera_to_player()
	verify(camera.offset == Vector2.ZERO and is_zero_approx(game.shake), "Checkpoint snap clears any residual combat shake")
	verify(camera.get_screen_center_position().is_equal_approx(Vector2(1120, 270)), "Checkpoint snap immediately places the displayed center at the respawn point")
	game.checkpoint = Vector2(2090, 448)
	game.player.dead = true
	game.respawn_time = 0
	await frames()
	verify(not game.player.dead and game.player.position.is_equal_approx(game.checkpoint), "Automatic checkpoint respawn restores the player")
	verify(camera.get_screen_center_position().is_equal_approx(Vector2(2090, 270)), "Automatic checkpoint respawn resets the displayed center")
	game.player.position = Vector2(-1000, -500)
	game._snap_camera_to_player()
	verify(camera.get_screen_center_position().is_equal_approx(Vector2(480, 270)), "Teleport beyond the left edge stays inside the map")
	game.player.position = Vector2(5000, 1500)
	game._snap_camera_to_player()
	verify(camera.get_screen_center_position().is_equal_approx(Vector2(2680, 270)), "Teleport beyond the right edge stays inside the map")
	game.player.position.x = 2800
	game._update_camera()
	verify(is_equal_approx(camera.position.x, 2680), "Movement at the exact right dead-zone margin does not change the target")
	game.player.position.x = 2560
	game._update_camera()
	verify(is_equal_approx(camera.position.x, 2680), "Movement at the exact left dead-zone margin does not change the target")
	var original_size := root.size
	root.size = Vector2i(2400, 1080)
	await frames()
	game.player.position = Vector2(1120, 448)
	game._snap_camera_to_player()
	verify(camera.get_screen_center_position().is_equal_approx(Vector2(1120, 270)), "Wide landscape phone framing preserves the logical camera center")
	root.size = Vector2i(1280, 960)
	await frames()
	game.player.position = Vector2(120, 448)
	game._snap_camera_to_player()
	verify(camera.get_screen_center_position().is_equal_approx(Vector2(480, 270)), "Tablet framing preserves the level-edge camera clamp")
	root.size = original_size
	game.queue_free()
	await frames()
	print("RESULT: ", checks - failures.size(), "/", checks, " camera checks passed")
	quit(0 if failures.is_empty() else 1)
