extends Control
class_name AshTouchControls

## Multi-touch controls for the Android build. The left finger owns a virtual
## horizontal stick; other fingers can hold jump/attack/dodge simultaneously.
## TouchScreenButton emits the same InputMap actions as the desktop keyboard.

const STICK_RADIUS := 72.0
const STICK_DEADZONE := 19.0
const THUMB_TRAVEL := 46.0

var stick_finger := -1
var stick_displacement := Vector2.ZERO
var action_buttons: Dictionary = {}
var show_on_desktop := false

func _ready() -> void:
	name = "MobileControls"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for entry in [
		["attack", "ATK", Color("df9a74"), 49.0],
		["jump", "JUMP", Color("71cdb4"), 46.0],
		["dodge", "DASH", Color("7aabdf"), 44.0],
		["interact", "USE", Color("d8c178"), 35.0],
		["pause", "II", Color("7c91a4"), 28.0],
		["restart", "RST", Color("7c91a4"), 26.0]
	]:
		var control := TouchScreenButton.new()
		control.name = String(entry[0]).capitalize() + "Button"
		control.action = String(entry[0])
		var hit_shape := CircleShape2D.new()
		hit_shape.radius = float(entry[3])
		control.shape = hit_shape
		control.passby_press = true
		control.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
		add_child(control)
		action_buttons[String(entry[0])] = {
			"node": control, "label": String(entry[1]),
			"color": entry[2], "radius": float(entry[3])
		}
	resized.connect(_layout_buttons)
	_layout_buttons()
	# Always create the controls for deterministic testing, but only render and
	# accept them on actual touch devices unless an explicit desktop test asks.
	visible = show_on_desktop or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

func _layout_buttons() -> void:
	if action_buttons.is_empty():
		return
	var w := size.x
	var h := size.y
	var positions := {
		"attack": Vector2(w - 100, h - 120),
		"jump": Vector2(w - 210, h - 82),
		"dodge": Vector2(w - 310, h - 153),
		"interact": Vector2(w - 110, h - 245),
		"pause": Vector2(w - 42, 40),
		"restart": Vector2(w - 114, 40)
	}
	for key in action_buttons:
		action_buttons[key]["node"].position = positions[key]
	queue_redraw()

func _stick_center() -> Vector2:
	return Vector2(112, size.y - 113)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed and stick_finger == -1 and event.position.distance_to(_stick_center()) <= STICK_RADIUS * 1.45:
			stick_finger = event.index
			_move_stick(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == stick_finger:
			stick_finger = -1
			stick_displacement = Vector2.ZERO
			_set_horizontal(0.0)
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == stick_finger:
		_move_stick(event.position)
		get_viewport().set_input_as_handled()

func _move_stick(screen_position: Vector2) -> void:
	stick_displacement = (screen_position - _stick_center()).limit_length(THUMB_TRAVEL)
	_set_horizontal(stick_displacement.x)
	queue_redraw()

func _set_horizontal(amount: float) -> void:
	if amount < -STICK_DEADZONE:
		Input.action_press("move_left")
		Input.action_release("move_right")
	elif amount > STICK_DEADZONE:
		Input.action_press("move_right")
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

func _exit_tree() -> void:
	_set_horizontal(0.0)

func _draw() -> void:
	if not visible:
		return
	var center := _stick_center()
	draw_circle(center, STICK_RADIUS, Color(0.07, 0.14, 0.22, 0.46))
	draw_arc(center, STICK_RADIUS, 0, TAU, 48, Color(0.48, 0.76, 0.76, 0.65), 3.0)
	draw_circle(center + stick_displacement, 32, Color(0.37, 0.72, 0.70, 0.62))
	draw_arc(center + stick_displacement, 32, 0, TAU, 28, Color(0.76, 0.97, 0.90, 0.72), 2.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-42, 6), "L", HORIZONTAL_ALIGNMENT_CENTER, 24, 19, Color(0.82, 0.94, 0.90, 0.65))
	draw_string(ThemeDB.fallback_font, center + Vector2(19, 6), "R", HORIZONTAL_ALIGNMENT_CENTER, 24, 19, Color(0.82, 0.94, 0.90, 0.65))
	for key in action_buttons:
		var item: Dictionary = action_buttons[key]
		var position: Vector2 = item["node"].position
		var radius: float = item["radius"]
		var tone: Color = item["color"]
		draw_circle(position, radius, Color(tone.r * 0.30, tone.g * 0.30, tone.b * 0.30, 0.52))
		draw_arc(position, radius, 0, TAU, 40, Color(tone.r, tone.g, tone.b, 0.82), 3.0)
		var caption := String(item["label"])
		draw_string(ThemeDB.fallback_font, position + Vector2(-radius, 6), caption, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 17, Color(1, 1, 1, 0.90))
