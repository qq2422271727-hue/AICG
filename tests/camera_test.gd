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
	var min_x: float = game.CAMERA_MIN_X
	var max_x: float = game.CAMERA_MAX_X
	var fixed_y: float = game.CAMERA_FIXED_Y
	var start_center := Vector2(min_x, fixed_y)
	await frames()
	verify(camera.zoom.is_equal_approx(Vector2(1.24, 1.24)), "World camera enlarges characters, enemies and ruins together by 24 percent")
	var idle_image: Image = game.player.visual.sprite_frames.get_frame_texture(&"idle", 0).get_image()
	var hero_screen_height: float = idle_image.get_used_rect().size.y * camera.zoom.y
	verify(roundi(hero_screen_height) >= 60 and roundi(hero_screen_height) <= 68, "Standing hero rounds to 60-68 logical screen pixels tall")
	var ui: CanvasLayer = game.get_node("TouchHUD")
	verify(not ui.follow_viewport_enabled and ui.transform.is_equal_approx(Transform2D.IDENTITY), "Touch HUD stays unscaled and independent of world camera zoom")
	verify(is_equal_approx(min_x, 480.0 / 1.24) and is_equal_approx(max_x, 3160.0 - min_x), "Horizontal bounds use the zoomed viewport half-width")
	verify(is_equal_approx(camera.position.x, min_x), "Camera begins at the level's left boundary")
	verify(camera.get_screen_center_position().is_equal_approx(start_center), "First view is snapped immediately without a startup slide")
	var ground_screen_y := 270.0 + (470.0 - fixed_y) * camera.zoom.y
	verify(ground_screen_y >= 380 and ground_screen_y <= 389, "Walking surface stays above the bottom joystick artwork")
	var view_top := fixed_y - 270.0 / camera.zoom.y
	var double_jump_rise: float = 2.0 * pow(game.player.JUMP_SPEED, 2) / (2.0 * game.player.GRAVITY)
	verify(375.0 - double_jump_rise - 55.0 > view_top + 24.0, "Highest optional platform double jump keeps the hero's head in view")
	game.player.facing = -1
	await frames()
	verify(is_equal_approx(camera.position.x, min_x), "Turning in place never shifts the background")
	game.player.position.x = min_x + 60.0
	game.player.facing = 1
	await frames()
	verify(is_equal_approx(camera.position.x, min_x), "Small movement inside the quiet zone keeps scenery fixed")
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
	verify(is_equal_approx(camera.position.y, fixed_y), "Jumping does not bob the whole scene vertically")
	game.player.position.x = 3000.0
	await frames()
	verify(is_equal_approx(camera.position.x, max_x), "Camera clamps at the far edge of the map")
	game.restart_run()
	await frames()
	verify(is_equal_approx(camera.position.x, min_x), "Restart snaps the camera back to the start")
	game.player.set_physics_process(false)
	verify(camera.get_screen_center_position().is_equal_approx(start_center), "Restart resets the displayed center, not only its target")
	var quiet_zone_stable := true
	for i in range(60):
		game.player.facing = 1 if i % 2 == 0 else -1
		game.player.position = Vector2(min_x + 60 if i % 2 == 0 else min_x - 60, 300 if i % 2 == 0 else 449)
		await frames(1)
		quiet_zone_stable = quiet_zone_stable and camera.get_screen_center_position().is_equal_approx(start_center)
	verify(quiet_zone_stable, "Repeated rapid reversals and jumps leave the displayed scenery still")
	game.player.position = Vector2(1200, 449)
	await frames(4)
	var moving_center := camera.get_screen_center_position()
	verify(moving_center.x > min_x and moving_center.x < camera.position.x, "Actual camera scroll is smoothed instead of snapping to the target")
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
	verify(camera.get_screen_center_position().is_equal_approx(Vector2(1120, fixed_y)), "Checkpoint snap immediately places the displayed center at the respawn point")
	game.checkpoint = Vector2(2090, 448)
	game.player.dead = true
	game.respawn_time = 0
	await frames()
	verify(not game.player.dead and game.player.position.is_equal_approx(game.checkpoint), "Automatic checkpoint respawn restores the player")
	verify(camera.get_screen_center_position().is_equal_approx(Vector2(2090, fixed_y)), "Automatic checkpoint respawn resets the displayed center")
	game.player.position = Vector2(-1000, -500)
	game._snap_camera_to_player()
	verify(camera.get_screen_center_position().is_equal_approx(start_center), "Teleport beyond the left edge stays inside the map")
	game.player.position = Vector2(5000, 1500)
	game._snap_camera_to_player()
	verify(camera.get_screen_center_position().is_equal_approx(Vector2(max_x, fixed_y)), "Teleport beyond the right edge stays inside the map")
	game.player.position.x = max_x + game.CAMERA_DEAD_ZONE
	game._update_camera()
	verify(is_equal_approx(camera.position.x, max_x), "Movement at the exact right dead-zone margin does not change the target")
	game.player.position.x = max_x - game.CAMERA_DEAD_ZONE
	game._update_camera()
	verify(is_equal_approx(camera.position.x, max_x), "Movement at the exact left dead-zone margin does not change the target")
	for gap_left in [930.0, 1890.0]:
		game.player.position = Vector2(gap_left - 30.0, 449)
		game.camera_anchor_x = min_x
		game._update_camera()
		# Include the expected speed/smoothing-rate lag during sustained running.
		var running_view_right: float = camera.position.x - game.player.RUN_SPEED / camera.position_smoothing_speed + min_x
		verify(running_view_right > gap_left + 140.0 + 50.0, "Gap at %d and at least 50px of landing remain visible before takeoff" % int(gap_left))
	var original_size := root.size
	root.size = Vector2i(2400, 1080)
	await frames()
	game.player.position = Vector2(1120, 448)
	game._snap_camera_to_player()
	verify(camera.get_screen_center_position().is_equal_approx(Vector2(1120, fixed_y)), "Wide landscape phone framing preserves the logical camera center")
	root.size = Vector2i(1280, 960)
	await frames()
	game.player.position = Vector2(120, 448)
	game._snap_camera_to_player()
	verify(camera.get_screen_center_position().is_equal_approx(start_center), "Tablet framing preserves the level-edge camera clamp")
	root.size = original_size
	game.queue_free()
	await frames()
	print("RESULT: ", checks - failures.size(), "/", checks, " camera checks passed")
	quit(0 if failures.is_empty() else 1)
