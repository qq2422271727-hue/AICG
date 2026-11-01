extends Control
class_name AshTouchControls

## Multi-touch controls for the Android build. The left finger owns a virtual
## horizontal stick; other fingers can hold jump/attack/dodge simultaneously.
## TouchScreenButton emits the same InputMap actions as the desktop keyboard.

# Visual sizes are independent of touch targets: compact artwork must not
# require pixel-perfect thumbs. All measurements use the 960x540 canvas.
const STICK_RADIUS := 47.0
const STICK_CAPTURE_RADIUS := 104.0
const STICK_DEADZONE := 12.0
const THUMB_TRAVEL := 28.0
const THUMB_RADIUS := 21.0

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
		# action, label, color, visible radius, unchanged touch radius
		["attack", "ATK", Color("df9a74"), 32.0, 49.0],
		["jump", "JUMP", Color("71cdb4"), 30.0, 46.0],
		["dodge", "DASH", Color("7aabdf"), 29.0, 44.0],
		["interact", "USE", Color("d8c178"), 23.0, 35.0],
		["pause", "II", Color("7c91a4"), 18.0, 28.0],
		["restart", "RST", Color("7c91a4"), 17.0, 26.0]
	]:
		var control := TouchScreenButton.new()
		control.name = String(entry[0]).capitalize() + "Button"
		control.action = String(entry[0])
		var hit_shape := CircleShape2D.new()
		hit_shape.radius = float(entry[4])
		control.shape = hit_shape
		control.passby_press = true
		control.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
		add_child(control)
		action_buttons[String(entry[0])] = {
			"node": control, "label": String(entry[1]),
			"color": entry[2], "radius": float(entry[3]),
			"hit_radius": float(entry[4])
		}
	resized.connect(_layout_buttons)
	_layout_buttons()
	# Always create the controls for deterministic testing, but only render and
	# accept them on actual touch devices unless an explicit desktop test asks.
	visible = show_on_desktop or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

func _layout_buttons() -> void:
	if action_buttons.is_empty():
		return
	var safe := _safe_control_rect()
	var w := safe.end.x
	var h := safe.end.y
	var positions := {
		# A staggered two-column thumb cluster. Even the larger, invisible
		# hit circles have gaps, preventing one contact from firing two actions.
		"attack": Vector2(w - 76, h - 96),
		"jump": Vector2(w - 179, h - 63),
		"dodge": Vector2(w - 174, h - 163),
		"interact": Vector2(w - 72, h - 193),
		"pause": Vector2(w - 42, safe.position.y + 40),
		"restart": Vector2(w - 114, safe.position.y + 40)
	}
	for key in action_buttons:
		action_buttons[key]["node"].position = positions[key]
	queue_redraw()

func _safe_control_rect() -> Rect2:
	var bounds := Rect2(Vector2.ZERO, size)
	if OS.has_feature("mobile"):
		var screen_safe := Rect2(DisplayServer.get_display_safe_area())
		if screen_safe.has_area():
			# The OS reports physical screen pixels; drawing and input use
			# canvas coordinates after stretch/letterboxing. Never use raw insets.
			var local_safe := get_screen_transform().affine_inverse() * screen_safe
			var clipped := bounds.intersection(local_safe)
			if clipped.has_area():
				return clipped
	return bounds

func _stick_center() -> Vector2:
	var safe := _safe_control_rect()
	return Vector2(safe.position.x + 104, safe.end.y - 104)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed and stick_finger == -1 and event.position.distance_to(_stick_center()) <= STICK_CAPTURE_RADIUS:
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
	draw_arc(center, STICK_RADIUS, 0, TAU, 48, Color(0.48, 0.76, 0.76, 0.65), 2.0)
	draw_circle(center + stick_displacement, THUMB_RADIUS, Color(0.37, 0.72, 0.70, 0.62))
	draw_arc(center + stick_displacement, THUMB_RADIUS, 0, TAU, 28, Color(0.76, 0.97, 0.90, 0.72), 1.5)
	draw_string(ThemeDB.fallback_font, center + Vector2(-33, 5), "L", HORIZONTAL_ALIGNMENT_CENTER, 16, 14, Color(0.82, 0.94, 0.90, 0.65))
	draw_string(ThemeDB.fallback_font, center + Vector2(17, 5), "R", HORIZONTAL_ALIGNMENT_CENTER, 16, 14, Color(0.82, 0.94, 0.90, 0.65))
	for key in action_buttons:
		var item: Dictionary = action_buttons[key]
		var position: Vector2 = item["node"].position
		var radius: float = item["radius"]
		var tone: Color = item["color"]
		draw_circle(position, radius, Color(tone.r * 0.30, tone.g * 0.30, tone.b * 0.30, 0.52))
		draw_arc(position, radius, 0, TAU, 40, Color(tone.r, tone.g, tone.b, 0.82), 2.0)
		var caption := String(item["label"])
		draw_string(ThemeDB.fallback_font, position + Vector2(-radius, 5), caption, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 12 if radius < 24 else 14, Color(1, 1, 1, 0.90))
