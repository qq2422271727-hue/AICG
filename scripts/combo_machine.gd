extends RefCounted
## v0.5 production attack authority, integrated from the isolated combo proof.
## AshPlayer owns collision contacts and the existing world hit-stop; this
## RefCounted machine owns one clock for attack state + sprite sampling.
signal attack_started(attack: StringName, serial: int)
signal attack_ended(attack: StringName, reason: StringName)
signal contact(attack: StringName, serial: int, target_id: int)

const INPUT_BUFFER_SECONDS := 0.14 # Existing v0.4 value is 140 ms, NOT 14%.
const EPS := 0.0000001
const ATTACKS := {
	&"attack_a": {"startup": 0.050, "active_end": 0.167, "total": 0.300, "damage": 1, "hitbox": Rect2(7, -28, 70, 53)},
	&"attack_b": {"startup": 0.067, "active_end": 0.167, "total": 0.300, "damage": 1, "hitbox": Rect2(6, -52, 62, 76)}
}
## Explicit allowed edges, not attack-name arithmetic or implicit animation links.
## Hit confirm unlocks the follow-up 66 ms before the whiff route.
const CANCEL_ROUTES := [
	{"from": &"attack_a", "to": &"attack_b", "input": &"attack", "open": 0.167, "close": 0.280, "require_hit": true},
	{"from": &"attack_a", "to": &"attack_b", "input": &"attack", "open": 0.233, "close": 0.280, "require_hit": false}
]

var current_attack: StringName = &""
var elapsed := 0.0
var buffer_left := 0.0
var attack_serial := 0
var hit_confirmed := false
var hit_targets: Dictionary = {}
var blocked := false
var last_end_reason: StringName = &""
var started_this_tick := false

func press_attack(frozen := false) -> void:
	if blocked:
		return
	buffer_left = INPUT_BUFFER_SECONDS
	if frozen:
		return
	if current_attack.is_empty():
		_start(&"attack_a")
	else:
		resolve_cancel()

func advance(delta: float, frozen := false) -> void:
	assert(delta >= 0.0)
	started_this_tick = false
	# Hit-stop freezes BOTH sampling and input lifetime; fresh presses may buffer.
	if frozen or blocked:
		return
	var remaining := delta
	# Split at buffer expiry, route boundaries and end; no frame-rate gate drift.
	while remaining > EPS:
		if current_attack.is_empty():
			if buffer_left > EPS:
				_start(&"attack_a")
			else:
				return
		resolve_cancel()
		var total: float = ATTACKS[current_attack].total
		var step := minf(remaining, total - elapsed)
		if buffer_left > EPS:
			step = minf(step, buffer_left)
		for route: Dictionary in CANCEL_ROUTES:
			if route.from == current_attack and float(route.open) > elapsed + EPS:
				step = minf(step, float(route.open) - elapsed)
		if step <= EPS:
			step = minf(remaining, EPS * 2.0)
		elapsed += step
		buffer_left = maxf(0.0, buffer_left - step)
		remaining -= step
		resolve_cancel()
		if elapsed >= float(ATTACKS[current_attack].total) - EPS:
			var has_buffer := buffer_left > EPS
			_finish(&"complete")
			if has_buffer:
				_start(&"attack_a")

func resolve_cancel() -> bool:
	if blocked or buffer_left <= EPS:
		return false
	for route: Dictionary in CANCEL_ROUTES:
		if route.from != current_attack:
			continue
		if elapsed + EPS < float(route.open) or elapsed >= float(route.close) - EPS:
			continue
		if bool(route.require_hit) and not hit_confirmed:
			continue
		_finish(&"combo_cancel")
		_start(route.to)
		return true
	return false

func phase() -> StringName:
	if current_attack.is_empty():
		return &"idle"
	var data: Dictionary = ATTACKS[current_attack]
	if elapsed + EPS < float(data.startup):
		return &"startup"
	if elapsed < float(data.active_end) - EPS:
		return &"active"
	return &"recovery"

func can_hit() -> bool:
	return not blocked and phase() == &"active"

func register_hit(target_id: int) -> bool:
	if target_id <= 0 or not can_hit() or hit_targets.has(target_id):
		return false
	hit_targets[target_id] = true
	hit_confirmed = true
	contact.emit(current_attack, attack_serial, target_id)
	return true

func hitbox(origin: Vector2, facing: int) -> Rect2:
	if current_attack.is_empty():
		return Rect2()
	var area: Rect2 = ATTACKS[current_attack].hitbox
	if facing < 0:
		area.position.x = -area.position.x - area.size.x
	area.position += origin
	return area

func cancel_status() -> String:
	if current_attack != &"attack_a":
		return "NO ROUTE" if current_attack == &"attack_b" else "READY"
	for route: Dictionary in CANCEL_ROUTES:
		if elapsed + EPS >= float(route.open) and elapsed < float(route.close) - EPS and (not bool(route.require_hit) or hit_confirmed):
			return "A > B OPEN / " + ("HIT" if hit_confirmed else "WHIFF")
	return "CLOSED / " + ("HIT CONFIRMED" if hit_confirmed else "NO HIT")

func interrupt(reason: StringName, lock_input := false) -> void:
	_finish(reason)
	buffer_left = 0.0
	hit_targets.clear()
	hit_confirmed = false
	blocked = lock_input

func reset() -> void:
	interrupt(&"reset")
	attack_serial = 0
	started_this_tick = false

func _start(attack: StringName) -> void:
	assert(ATTACKS.has(attack))
	current_attack = attack
	elapsed = 0.0
	buffer_left = 0.0
	attack_serial += 1
	hit_targets.clear()
	hit_confirmed = false
	started_this_tick = true
	attack_started.emit(attack, attack_serial)

func _finish(reason: StringName) -> void:
	var previous := current_attack
	current_attack = &""
	elapsed = 0.0
	last_end_reason = reason
	if not previous.is_empty():
		attack_ended.emit(previous, reason)
