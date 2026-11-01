extends SceneTree

## Headless verification of on-screen controls and multi-finger input.
## Run with: godot --headless --path . --script res://tests/touch_test.gd

var failures: Array[String] = []
var total := 0

func _initialize() -> void:
	_run.call_deferred()

func verify(ok: bool, description: String) -> void:
	total += 1
	if ok:
		print("PASS: ", description)
	else:
		failures.append(description)
		printerr("FAIL: ", description)

func touch_event(finger: int, pressed: bool, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.pressed = pressed
	event.position = at
	root.push_input(event, true)

func drag_event(finger: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = at
	root.push_input(event, true)

func verify_layout(controls: AshTouchControls, viewport_size: Vector2) -> void:
	controls.size = viewport_size
	controls._layout_buttons()
	var actions: Array = controls.action_buttons.values()
	var separated := true
	var inside := true
	for i in range(actions.size()):
		var position: Vector2 = actions[i]["node"].position
		var radius: float = actions[i]["hit_radius"]
		inside = inside and position.x - radius >= 0 and position.x + radius <= viewport_size.x
		inside = inside and position.y - radius >= 0 and position.y + radius <= viewport_size.y
		separated = separated and position.distance_to(controls._stick_center()) > radius + controls.STICK_CAPTURE_RADIUS
		for j in range(i + 1, actions.size()):
			separated = separated and position.distance_to(actions[j]["node"].position) > radius + float(actions[j]["hit_radius"])
	verify(inside and separated, "Full touch targets fit without overlap at " + str(viewport_size))

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var controls: AshTouchControls = game.get_node("TouchHUD/MobileControls")
	controls.visible = true
	await process_frame
	verify(controls.size.x > 900 and controls.size.y > 500, "Touch overlay fills the landscape viewport")
	var original_size := controls.size
	verify_layout(controls, Vector2(960, 540))
	verify_layout(controls, Vector2(1200, 540))
	controls.size = original_size
	controls._layout_buttons()
	verify(controls.STICK_RADIUS == 47.0 and controls.action_buttons["attack"]["radius"] == 32.0, "Visible controls are approximately 35 percent smaller")
	var center := controls._stick_center()
	touch_event(0, true, center + Vector2(90, 0))
	await process_frame
	verify(controls.stick_finger == 0 and Input.is_action_pressed("move_right"), "Stick retains forgiving capture outside the smaller visible ring")
	touch_event(0, false, center)
	touch_event(0, true, center)
	drag_event(0, center + Vector2(45, 0))
	await process_frame
	verify(Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left"), "Stick drag right presses movement")
	drag_event(0, center + Vector2(-45, 0))
	await process_frame
	verify(Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "Stick drag left switches movement")
	drag_event(0, center + Vector2(0, -30))
	await process_frame
	verify(not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "Stick horizontal dead zone releases movement")
	# Finger 0 holds the stick while finger 1 simultaneously attacks.
	drag_event(0, center + Vector2(45, 0))
	var attack_at: Vector2 = controls.action_buttons["attack"]["node"].position
	# Press outside the new 32px artwork but inside the unchanged 49px target.
	var forgiving_attack_at := attack_at + Vector2(43, 0)
	touch_event(1, true, forgiving_attack_at)
	await process_frame
	verify(Input.is_action_pressed("move_right") and Input.is_action_pressed("attack"), "Second finger attacks in invisible target margin while first holds movement")
	touch_event(3, true, controls.action_buttons["jump"]["node"].position)
	await process_frame
	verify(Input.is_action_pressed("move_right") and Input.is_action_pressed("attack") and Input.is_action_pressed("jump"), "Three fingers can hold movement, attack and jump together")
	touch_event(3, false, controls.action_buttons["jump"]["node"].position)
	touch_event(1, false, forgiving_attack_at)
	await process_frame
	verify(not Input.is_action_pressed("attack") and Input.is_action_pressed("move_right"), "Releasing attack leaves movement held")
	touch_event(0, false, center)
	await process_frame
	verify(not Input.is_action_pressed("move_right") and controls.stick_finger == -1, "Lifting stick finger releases movement")
	for action in ["jump", "dodge", "interact", "pause", "restart"]:
		var at: Vector2 = controls.action_buttons[action]["node"].position
		touch_event(2, true, at)
		await process_frame
		verify(Input.is_action_pressed(action), "Touch button presses " + action)
		touch_event(2, false, at)
		await process_frame
		verify(not Input.is_action_pressed(action), "Touch button releases " + action)
	game.queue_free()
	await process_frame
	print("RESULT: ", total - failures.size(), "/", total, " touch checks passed")
	quit(0 if failures.is_empty() else 1)
