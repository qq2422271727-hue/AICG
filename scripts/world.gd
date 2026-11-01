extends Node2D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const EffectsScript = preload("res://scripts/effects.gd")
const HudScript = preload("res://scripts/hud.gd")
const TouchControlsScript = preload("res://scripts/touch_controls.gd")
const WorldArtScript = preload("res://scripts/world_art.gd")

const CAMERA_ZOOM := 1.24
const CAMERA_VIEWPORT_SIZE := Vector2(960, 540)
const CAMERA_WORLD_RIGHT := 3160.0
const CAMERA_DEAD_ZONE := 120.0
const CAMERA_MIN_X := CAMERA_VIEWPORT_SIZE.x * 0.5 / CAMERA_ZOOM
const CAMERA_MAX_X := CAMERA_WORLD_RIGHT - CAMERA_MIN_X
# At 1.24x, the y=470 walking surface appears at screen y=386.56, above
# the bottom thumb controls. Keep this fixed: jumps must not bob the ruins.
# The top of the view is y=158.26, retaining even an upper-platform double jump.
const CAMERA_FIXED_Y := 376.0

var player: AshPlayer
var enemies: Array[AshSentry] = []
var effects: Node2D
var camera: Camera2D
var camera_anchor_x := CAMERA_MIN_X
var platforms: Array[Rect2] = []
var seals: Array[int] = []
var checkpoint := Vector2(120, 448)
var checkpoint_index := 0
var respawn_time := -1.0
var elapsed := 0.0
var deaths := 0
var won := false
var message := "Recover three seals. Wake the eastern relay."
var message_time := 5.0
var hit_stop := 0.0
var frame_time_scale := 1.0
var shake := 0.0
var ambient_time := 0.0
var world_art: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_build_level()
	world_art = WorldArtScript.new()
	add_child(world_art)
	world_art.build(platforms)
	effects = EffectsScript.new()
	effects.z_index = 6
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(effects)
	player = PlayerScript.new()
	player.world = self
	player.position = checkpoint
	player.z_index = 5
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.died.connect(_on_player_died)
	camera = Camera2D.new()
	# The world must receive pause/restart input while paused, but the camera
	# must not inherit that mode and keep sliding behind the pause overlay.
	camera.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Only the world is enlarged. TouchHUD remains an unscaled CanvasLayer.
	camera.zoom = Vector2.ONE * CAMERA_ZOOM
	camera.position = Vector2(camera_anchor_x, CAMERA_FIXED_Y)
	camera.limit_left = 0
	camera.limit_right = int(CAMERA_WORLD_RIGHT)
	camera.limit_top = 0
	camera.limit_bottom = 620
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6
	add_child(camera)
	_snap_camera_to_player()
	_spawn_enemy(Vector2(660, 449), Vector2(500, 800), 0)
	_spawn_enemy(Vector2(1490, 449), Vector2(1280, 1660), 1)
	_spawn_enemy(Vector2(2420, 449), Vector2(2250, 2580), 2)
	var ui := CanvasLayer.new()
	ui.name = "TouchHUD"
	add_child(ui)
	var hud := HudScript.new()
	hud.world = self
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.add_child(hud)
	var touch_controls := TouchControlsScript.new()
	ui.add_child(touch_controls)

func _setup_input() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP], "attack": [KEY_J, KEY_X],
		"dodge": [KEY_SHIFT, KEY_K], "interact": [KEY_E],
		"restart": [KEY_R], "pause": [KEY_ESCAPE]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _build_level() -> void:
	# Three safe arenas, two forgiving traversal gaps, optional upper platforms.
	for rect in [Rect2(-80, 470, 1010, 220), Rect2(1070, 470, 820, 220), Rect2(2030, 470, 1210, 220), Rect2(320, 383, 135, 18), Rect2(1120, 380, 135, 18), Rect2(1740, 382, 126, 18), Rect2(2100, 375, 134, 18), Rect2(2695, 379, 132, 18)]:
		platforms.append(rect)
		var body := StaticBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collider.shape = shape
		collider.position = rect.get_center()
		body.add_child(collider)
		add_child(body)
	# Side boundaries keep every run in the designed space.
	for x in [-45, 3220]:
		var wall := StaticBody2D.new()
		wall.collision_layer = 2
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(40, 1600)
		collider.shape = shape
		collider.position = Vector2(x, 0)
		wall.add_child(collider)
		add_child(wall)

func _spawn_enemy(at: Vector2, bounds: Vector2, index: int) -> void:
	var enemy := EnemyScript.new()
	enemy.world = self
	enemy.player = player
	enemy.position = at
	enemy.home = at
	enemy.patrol_bounds = bounds
	enemy.seal_index = index
	enemy.z_index = 4
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(enemy)
	enemies.append(enemy)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") and not won:
		get_tree().paused = not get_tree().paused
	if Input.is_action_just_pressed("restart"):
		restart_run()
	if get_tree().paused:
		return
	# delta was scaled at the START of this frame. A physics contact may already
	# have changed Engine.time_scale; dividing by that new .12 erased a 45ms
	# impact in the contact frame itself. Use the scale that produced this delta.
	var real_delta := delta / maxf(frame_time_scale, 0.01)
	if hit_stop > 0:
		hit_stop -= real_delta
		if hit_stop <= 0:
			Engine.time_scale = 1.0
	ambient_time += delta
	message_time = maxf(0, message_time - delta)
	shake = move_toward(shake, 0, 35 * real_delta)
	if not won:
		elapsed += delta
	_update_camera()
	camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)).round()
	if respawn_time >= 0:
		respawn_time -= delta
		if respawn_time <= 0:
			respawn_time = -1
			player.respawn(checkpoint)
			_snap_camera_to_player()
			for enemy in enemies:
				if not seals.has(enemy.seal_index):
					enemy.respawn()
	if not player.dead and not won:
		if player.position.x > 1120 and checkpoint_index == 0 and player.is_on_floor():
			checkpoint_index = 1
			checkpoint = Vector2(1120, 448)
			show_message("Relay marker lit. Your return point is secured.")
		if player.position.x > 2090 and checkpoint_index == 1 and player.is_on_floor():
			checkpoint_index = 2
			checkpoint = Vector2(2090, 448)
			show_message("Final relay marker lit. One last stretch.")
		if absf(player.position.x - 2960) < 80 and Input.is_action_just_pressed("interact"):
			if seals.size() == 3:
				won = true
				player.set_physics_process(false)
				spawn_burst(Vector2(2960, 375), Color("bcffd7"), 65, 220.0)
			else:
				show_message("The relay needs all three seals. Defeat the remaining sentries.")
	frame_time_scale = Engine.time_scale
	queue_redraw()

func _update_camera() -> void:
	# A 240-pixel-wide quiet zone keeps the scenery still during short left/right
	# corrections. Changing facing no longer moves the camera by itself.
	if player.position.x > camera_anchor_x + CAMERA_DEAD_ZONE:
		camera_anchor_x = player.position.x - CAMERA_DEAD_ZONE
	elif player.position.x < camera_anchor_x - CAMERA_DEAD_ZONE:
		camera_anchor_x = player.position.x + CAMERA_DEAD_ZONE
	camera_anchor_x = clampf(camera_anchor_x, CAMERA_MIN_X, CAMERA_MAX_X)
	camera.position = Vector2(camera_anchor_x, CAMERA_FIXED_Y)

func _snap_camera_to_player() -> void:
	# Teleporting to a checkpoint must not leave the camera behind off-screen.
	shake = 0.0
	camera.offset = Vector2.ZERO
	camera_anchor_x = clampf(player.position.x, CAMERA_MIN_X, CAMERA_MAX_X)
	camera.position = Vector2(camera_anchor_x, CAMERA_FIXED_Y)
	camera.reset_smoothing()
	camera.force_update_scroll()

func restart_run() -> void:
	get_tree().paused = false
	Engine.time_scale = 1
	frame_time_scale = 1.0
	hit_stop = 0
	shake = 0
	won = false
	elapsed = 0
	deaths = 0
	seals.clear()
	checkpoint = Vector2(120, 448)
	checkpoint_index = 0
	respawn_time = -1
	player.set_physics_process(true)
	player.respawn(checkpoint)
	_snap_camera_to_player()
	for enemy in enemies:
		enemy.respawn()
	effects.particles.clear()
	effects.ghosts.clear()
	show_message("Recover three seals. Wake the eastern relay.", 5)

func _on_player_died() -> void:
	deaths += 1
	respawn_time = 1.3

func sentry_defeated(index: int) -> void:
	if not seals.has(index):
		seals.append(index)
		show_message("Seal recovered  %d / 3%s" % [seals.size(), "  —  Wake the eastern relay with E." if seals.size() == 3 else ""])

func show_message(text: String, duration: float = 3.5) -> void:
	message = text
	message_time = duration

func spawn_burst(at: Vector2, color: Color, count: int, speed: float) -> void:
	effects.burst(at, color, count, speed)

func impact(at: Vector2, color: Color, pause_time: float, strength: float) -> void:
	spawn_burst(at, color, 12, 140)
	hit_stop = maxf(hit_stop, pause_time)
	Engine.time_scale = 0.12
	shake = maxf(shake, strength)

func _exit_tree() -> void:
	Engine.time_scale = 1

func _draw() -> void:
	# Static backdrop/masonry now belong EXCLUSIVELY to WorldArt. The old opaque
	# rectangle would cover negative-z Parallax2D layers; the old view_x math
	# would apply a second camera transform. Keep only dynamic gameplay markers.
	for x in [930, 1890]:
		draw_rect(Rect2(x, 609, 140, 90), Color("301f30"))
		for i in range(8):
			var px: int = x + i * 18
			draw_colored_polygon(PackedVector2Array([Vector2(px, 637), Vector2(px + 8, 613), Vector2(px + 16, 637)]), Color("b16559"))
	for index in range(3):
		var x: int = [145, 1120, 2090][index]
		var active := index <= checkpoint_index
		draw_rect(Rect2(x - 4, 415, 8, 55), Color("38505a"))
		draw_rect(Rect2(x - 10, 416, 20, 16), Color("87ddc3") if active else Color("637c7c"))
		if active:
			draw_rect(Rect2(x - 18, 409, 36, 30), Color(0.5, 0.9, 0.75, 0.08))
	# Final relay is deliberately readable as a distinct destination.
	draw_rect(Rect2(2915, 450, 90, 20), Color("637d77"))
	draw_rect(Rect2(2930, 360, 60, 90), Color("294650"))
	draw_rect(Rect2(2924, 352, 72, 12), Color("7fa397"))
	var relay_color := Color("aeffcc") if seals.size() == 3 else Color("c3996b")
	draw_rect(Rect2(2950, 374, 20, 52), relay_color)
	draw_rect(Rect2(2944, 380, 32, 40), Color(relay_color, 0.16))
	for i in range(3):
		draw_rect(Rect2(2936 + i * 18, 438, 12, 5), Color("a6efd0") if seals.has(i) else Color("172e3b"))
	if won:
		draw_rect(Rect2(2956, -100, 8, 475), Color("d2ffe0"))
		draw_rect(Rect2(2945, -100, 30, 475), Color(0.6, 1, 0.7, 0.16))
	# Sparse windblown motes add life without obscuring collision surfaces.
	for i in range(48):
		var x := fposmod(i * 71.3 + ambient_time * (6 + i % 3), 3300)
		var y := 115 + i * 41 % 320 + sin(ambient_time + i) * 8
		draw_rect(Rect2(x, y, 2, 2), Color(0.6, 0.8, 0.7, 0.3))
