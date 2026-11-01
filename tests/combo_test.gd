extends SceneTree
const Combo = preload("res://scripts/combo_machine.gd")
const Visual = preload("res://scripts/player_visual.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func verify(condition: bool, message: String) -> void:
	checks += 1
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures.append(message)

func machine():
	var c := Combo.new()
	c.press_attack()
	return c

func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func touch(finger: int, down: bool, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.pressed = down
	event.position = at
	root.push_input(event, true)

func _run() -> void:
	var c = machine()
	verify(c.current_attack == &"attack_a" and c.attack_serial == 1, "One attack press starts A once")
	verify(is_equal_approx(Combo.INPUT_BUFFER_SECONDS, .14), "Existing 140 ms input buffer retained, not reinterpreted as percent")
	verify(c.phase() == &"startup" and not c.can_hit(), "A starts in non-damaging startup")
	c.advance(.049)
	verify(c.phase() == &"startup" and not c.register_hit(1), "49 ms cannot damage")
	c.advance(.001)
	verify(c.phase() == &"active" and c.can_hit(), "A active begins at exactly 50 ms")
	verify(c.register_hit(1) and not c.register_hit(1), "First A contact damages once, repeated target rejects")
	verify(c.register_hit(2) and c.hit_targets.size() == 2, "A can hit distinct targets; de-duplication is not global")
	verify(c.hit_confirmed, "Contact exposes hit-confirmed state")
	c.advance(.116)
	verify(c.phase() == &"active", "A remains active at 166 ms")
	c.advance(.001)
	verify(c.phase() == &"recovery" and not c.register_hit(3), "A active end 167 ms is half-open and cannot damage")
	c.advance(.133)
	verify(c.current_attack.is_empty() and c.last_end_reason == &"complete", "Unbuffered A completes at exactly 300 ms")
	c.advance(1)
	verify(c.attack_serial == 1, "Holding/no new edge never repeats attacks")

	c = machine()
	c.advance(.05)
	c.register_hit(8)
	c.press_attack()
	c.advance(.116)
	verify(c.current_attack == &"attack_a", "Hit-confirmed second input does not cancel A active frames")
	c.advance(.001)
	verify(c.current_attack == &"attack_b" and is_zero_approx(c.elapsed), "Buffered hit-confirm A > B enters at exactly 167 ms")
	verify(c.attack_serial == 2 and not c.hit_confirmed and c.hit_targets.is_empty(), "B gets new serial, empty hit set and reset hit-confirm state")
	verify(c.phase() == &"startup" and not c.register_hit(8), "B startup is distinct and cannot deal inherited contact damage")
	c.advance(.066)
	verify(c.phase() == &"startup", "B startup lasts 67 ms, not A's 50 ms")
	c.advance(.001)
	verify(c.phase() == &"active" and c.register_hit(8) and not c.register_hit(8), "B can damage the same target once under its new serial")
	c.advance(.100)
	verify(c.phase() == &"recovery", "B active range ends exactly at 167 ms")
	c.press_attack()
	c.advance(.132)
	verify(c.current_attack == &"attack_b", "No B > A cancel route: B recovery cannot be skipped")
	c.advance(.001)
	verify(c.current_attack == &"attack_a" and c.attack_serial == 3, "Valid late B buffer starts fresh A only after full 300 ms B")

	c = machine()
	c.advance(.10)
	c.press_attack()
	c.advance(.067)
	verify(c.current_attack == &"attack_a", "Whiff cannot take hit-only 167 ms cancel route")
	c.advance(.066)
	verify(c.current_attack == &"attack_b" and is_zero_approx(c.elapsed), "Whiff A > B only opens at 233 ms")
	c = machine()
	c.advance(.02)
	c.press_attack()
	c.advance(.03)
	c.register_hit(1)
	c.advance(.117)
	verify(c.current_attack == &"attack_a" and is_zero_approx(c.buffer_left), "Too-early second tap expires after 140 ms; it does not become permanent intent")
	c = machine()
	c.advance(.05)
	c.register_hit(1)
	c.advance(.23)
	c.press_attack()
	verify(c.current_attack == &"attack_a", "Cancel close at exactly 280 ms is exclusive")
	c.advance(.02)
	verify(c.current_attack == &"attack_a" and c.attack_serial == 2, "Late closed-window input queues fresh A at full recovery, never stale B")

	c = machine()
	c.advance(.05)
	c.register_hit(7)
	c.advance(.117)
	var before: float = c.elapsed
	c.press_attack(true)
	c.advance(.8, true)
	verify(c.current_attack == &"attack_a" and is_equal_approx(c.elapsed, before), "Hit-stop freezes state/clock even when the cancel window is open")
	verify(is_equal_approx(c.buffer_left, .14), "Hit-stop preserves a fresh buffered tap's full lifetime")
	c.advance(.001)
	verify(c.current_attack == &"attack_b" and is_equal_approx(c.elapsed, .001), "Buffered B begins only on hit-stop release; remaining time advances once")

	for reason: StringName in [&"dodge", &"hurt", &"death", &"respawn"]:
		c = machine()
		c.advance(.05)
		c.register_hit(1)
		c.press_attack()
		c.interrupt(reason, reason == &"death")
		verify(c.current_attack.is_empty() and is_zero_approx(c.buffer_left) and not c.hit_confirmed and c.hit_targets.is_empty(), "%s atomically clears attack, pending combo and hit state" % reason)
		c.advance(.4)
		verify(c.current_attack.is_empty(), "%s cannot leak buffered B after interrupt" % reason)
	c.press_attack()
	# The loop's final respawn is intentionally unlocked.
	verify(c.current_attack == &"attack_a", "Respawn unlocks fresh attack input")
	c.interrupt(&"death", true)
	c.press_attack()
	verify(c.current_attack.is_empty() and c.buffer_left == 0, "Locked dead state ignores attacks rather than accumulating input")
	c.reset()
	verify(not c.blocked and c.attack_serial == 0, "Reset clears death lock and serial for reproducible tests")
	c.press_attack()
	c.advance(.05)
	var right: Rect2 = c.hitbox(Vector2(100, 200), 1)
	var left: Rect2 = c.hitbox(Vector2(100, 200), -1)
	verify(right == Rect2(107, 172, 70, 53) and left == Rect2(23, 172, 70, 53), "A hitbox stays exactly v0.4-sized and mirrors around the body")

	for fps: int in [30, 60, 120]:
		c = machine()
		var contacts := 0
		var pressed_second := false
		for i in range(fps):
			if not pressed_second and c.current_attack == &"attack_a" and c.elapsed >= .09:
				c.press_attack()
				pressed_second = true
			c.advance(1.0 / fps)
			if c.can_hit() and c.register_hit(10):
				contacts += 1
			c.resolve_cancel()
		verify(contacts == 2 and c.attack_serial == 2 and c.current_attack.is_empty(), "%d Hz: exactly two attacks/two hits; no duplicate damage or repeated hold" % fps)

	var visual := Visual.new()
	root.add_child(visual)
	verify(visual.configure() == OK, "Standalone native A/B/idle PNG resources load")
	verify(visual.frame_size == Vector2(128,96) and visual.pivot == Vector2(46,77), "All clips preserve fixed 128x96 frame and (46,77) pivot")
	verify(is_equal_approx(visual.clip_lengths[&"attack"], .3) and is_equal_approx(visual.clip_lengths[&"attack_b"], .3), "Production A and B each total 300 ms in native animation metadata")
	visual.sample_clip(&"attack_b", .0, 1)
	verify(visual.frame == 0, "B starts from its own low preload frame")
	visual.sample_clip(&"attack_b", .067, 1)
	verify(visual.frame == 4, "B contact frame 4 aligns to its 67 ms active boundary")
	visual.sample_clip(&"attack_b", .167, -1)
	verify(visual.frame == 8 and visual.scale == Vector2(-1,1), "B recovery frame 8 aligns to 167 ms and mirrors around fixed pivot")
	for i in range(20):
		visual.sample_clip(&"attack_b", .167, -1)
	verify(visual.frame == 8 and not visual.is_playing(), "B atlas never runs ahead of frozen physics clock")
	var a := load("res://assets/hero/attack_sheet.png") as Texture2D
	var b := load("res://assets/hero/attack_b_sheet.png") as Texture2D
	verify(a.get_image().get_data() != b.get_image().get_data(), "B is a distinct authored atlas, not A replayed faster")
	var a_image := a.get_image()
	var b_image := b.get_image()
	var seen_b: Array[PackedByteArray] = []
	var binary_alpha := true
	var edge_clearance := true
	var all_frames_grounded := true
	var novel_frames := 0
	for frame in range(15):
		var cell := b_image.get_region(Rect2i(frame * 128, 0, 128, 96))
		var bytes := cell.get_data()
		if not seen_b.has(bytes):
			seen_b.append(bytes)
		var novel := true
		for old_frame in range(15):
			if bytes == a_image.get_region(Rect2i(old_frame * 128, 0, 128, 96)).get_data():
				novel = false
		if novel:
			novel_frames += 1
		var has_foot := false
		for y in range(96):
			for x in range(128):
				var alpha := cell.get_pixel(x,y).a
				binary_alpha = binary_alpha and (alpha == 0.0 or alpha == 1.0)
				if alpha > 0:
					edge_clearance = edge_clearance and x > 0 and x < 127 and y > 0 and y <= 77
					if y == 77:
						has_foot = true
		all_frames_grounded = all_frames_grounded and has_foot
	verify(binary_alpha and edge_clearance, "All B pixels use binary alpha and clear the untrimmed canvas borders")
	verify(all_frames_grounded, "All 15 B frames keep boots on the same y=77 floor")
	verify(seen_b.size() >= 12 and novel_frames >= 13, "B has at least 12 distinct poses / 13 frames not found anywhere in A")
	print("B_POSE_COUNTS: distinct=", seen_b.size(), " novel_vs_all_A=", novel_frames)
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.size = Vector2i(960, 540)
	root.add_child(game)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	await ticks(8)
	var player: AshPlayer = game.player
	var target: AshSentry = game.enemies[0]
	var controls: AshTouchControls = game.get_node("TouchHUD/MobileControls")
	controls.visible = true
	verify(controls.action_buttons["attack"]["node"].action == &"attack", "Production touch and keyboard share the one attack action")
	verify(player.visual.sprite_frames.get_animation_names().size() == 12, "Production preserves all 11 v0.4 clips and adds only B")
	player.position = Vector2(605, 449)
	player.velocity = Vector2.ZERO
	player.facing = 1
	Input.action_press("attack")
	await ticks(2)
	Input.action_release("attack")
	await ticks(2)
	verify(player.combo.current_attack == &"attack_a" and target.health == 2, "Real main-scene attack input starts A and damages a real sentry once")
	verify(game.hit_stop > 0, "Real sentry contact uses the existing world impact timer")
	var frozen_elapsed: float = player.combo.elapsed
	player.combo.press_attack(true)
	var frozen_buffer: float = player.combo.buffer_left
	player._advance_combat(.12)
	verify(is_equal_approx(player.combo.elapsed, frozen_elapsed) and is_equal_approx(player.combo.buffer_left, frozen_buffer), "Global hit-stop freezes production attack time AND buffered input")
	verify(player.combo.current_attack == &"attack_a", "Contact cannot advance to B during the same hit-stop")
	await ticks(22)
	verify(player.combo.attack_serial == 2 and target.health == 1, "Production A > B hits the same sentry exactly once per stage")
	verify(player.visual_state == &"attack_b" and not player.slash.visible, "Real B selects its rising atlas and does not reuse A's horizontal slash FX")
	await ticks(30)
	verify(player.combo.current_attack.is_empty() and target.health == 1, "B recovery completes without repeated damage")
	game.restart_run()
	player.position = Vector2(120, 449)
	player.invulnerable = 0
	var before_serial: int = player.attack_id
	Input.action_press("attack")
	await ticks(60)
	verify(player.attack_id == before_serial + 1 and player.combo.current_attack.is_empty(), "Held keyboard attack produces one A, never automatic B or repeat")
	Input.action_release("attack")
	await ticks(2)
	Input.action_press("jump")
	await ticks(2)
	Input.action_release("jump")
	Input.action_press("attack")
	await ticks(2)
	Input.action_release("attack")
	verify(not player.is_on_floor() and player.combo.current_attack == &"attack_a", "Production airborne A retains jump physics")
	await ticks(5)
	Input.action_press("attack")
	await ticks(2)
	Input.action_release("attack")
	await ticks(8)
	verify(player.combo.current_attack == &"attack_b", "Production airborne input chains into B without root-motion teleport")
	player.combo.buffer_left = .14
	Input.action_press("dodge")
	await ticks(2)
	Input.action_release("dodge")
	verify(player.dodge_time > 0 and player.combo.current_attack.is_empty() and player.attack_buffer == 0 and not player.combo.hit_confirmed, "Actual dodge input cancels B and clears pending attack/hit state")
	await ticks(25)
	verify(player.combo.current_attack.is_empty(), "Cancelled B does not reappear after dodge")
	player.combo.press_attack()
	player.combo.buffer_left = .14
	player.invulnerable = 0
	player.take_hit(1, -1)
	verify(player.combo.current_attack.is_empty() and player.attack_buffer == 0 and player.visual_state == &"hurt", "Actual hurt cancels state, buffer, pose and FX atomically")
	player.invulnerable = 0
	player.take_hit(99, 1)
	player.combo.press_attack()
	verify(player.dead and player.combo.blocked and player.attack_buffer == 0, "Death locks attack input rather than storing a stale combo")
	player.respawn(Vector2(120, 448))
	verify(not player.combo.blocked and player.combo.current_attack.is_empty() and player.visual.frame == 0, "Respawn clears death lock and immediately resets native pose")
	game.restart_run()
	await ticks(3)
	# Native touch event path, with movement held on another finger throughout.
	var attack_at: Vector2 = controls.action_buttons["attack"]["node"].position
	var center: Vector2 = controls._stick_center()
	touch(0, true, center)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = center + Vector2(45, 0)
	root.push_input(drag, true)
	before_serial = player.attack_id
	var start_x: float = player.position.x
	touch(1, true, attack_at)
	await ticks(6)
	verify(player.combo.current_attack == &"attack_a" and Input.is_action_pressed("move_right"), "Touch A executes while a second finger holds the movement stick")
	touch(1, false, attack_at)
	await ticks(1)
	touch(1, true, attack_at)
	await ticks(10)
	verify(player.combo.current_attack == &"attack_b" and player.position.x > start_x, "Same native touch button chains B while player keeps moving")
	await ticks(45)
	verify(player.attack_id == before_serial + 2 and player.combo.current_attack.is_empty(), "Holding the second touch does not auto-repeat beyond A > B")
	touch(1, false, attack_at)
	touch(0, false, center)
	await ticks(2)
	verify(not Input.is_action_pressed("attack") and not Input.is_action_pressed("move_right"), "Touch release leaves no sticky movement or attack action")
	# Legacy read/write API is an explicit view/seek into the same machine.
	player.attack_time = .19
	verify(player.combo.current_attack == &"attack_a" and is_equal_approx(player.combo.elapsed, .11), "Legacy attack_time seek reconstructs A in the single machine, not a shadow clock")
	player.attack_time = 0
	verify(player.combo.current_attack.is_empty() and player.combo.buffer_left == 0, "Legacy zero clock atomically clears the same machine")
	game.queue_free()
	visual.queue_free()
	await process_frame
	print("LIMITATION: headless logic/native atlas/input routing only; no physical Android or GPU playtest")
	print("RESULT: %d/%d checks passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
