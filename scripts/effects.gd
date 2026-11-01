extends Node2D

## Pixel debris and frozen native sprite afterimages. No actor animation clocks.
const MAX_PARTICLES := 128
const MAX_GHOSTS := 12
const MAX_SPARKS := 64
const MAX_DUST := 32
const GHOST_SECONDS := 0.18
const DUST_COLOR := Color(0.53, 0.60, 0.61, 0.34)
const AIR_TRACE_COLOR := Color(0.51, 0.84, 0.81, 0.25)

var particles: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var dust: Array[Dictionary] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The world itself may keep processing its pause menu. FX must retain their
	# exact current state while paused, rather than draining or clearing lists.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var host := get_parent()
	if host != null and host.has_signal(&"combat_impact"):
		var callback := Callable(self, "_on_combat_impact")
		if not host.is_connected(&"combat_impact", callback):
			host.connect(&"combat_impact", callback)

func burst(at: Vector2, color: Color, count: int, speed: float) -> void:
	var amount := clampi(count, 0, MAX_PARTICLES)
	_reserve(particles, amount, MAX_PARTICLES)
	for i in range(amount):
		var angle := randf_range(-PI, PI)
		particles.append({"p": at, "v": Vector2.from_angle(angle) * randf_range(speed * 0.25, speed), "life": randf_range(0.18, 0.45), "color": color, "size": randi_range(2, 5)})

func ghost_sprite(at: Vector2, snapshot: Dictionary) -> void:
	if snapshot.is_empty() or not snapshot.get("texture") is Texture2D:
		return
	# Copy the values but retain the same immutable frame texture. No readback,
	# image allocation, changing AnimationPlayer or rectangular body stand-in.
	var frozen := snapshot.duplicate()
	frozen["p"] = at
	frozen["life"] = GHOST_SECONDS
	_reserve(ghosts, 1, MAX_GHOSTS)
	ghosts.append(frozen)

func _on_combat_impact(context: Dictionary) -> void:
	# A real contact point is required. Never substitute an enemy centre or
	# actor origin when collision geometry could not establish contact.
	if not context.get("point") is Vector2:
		return
	var world_point: Vector2 = context.point
	var direction: Vector2 = context.get("normal", Vector2.ZERO)
	if direction.is_zero_approx() and context.get("weapon_root") is Vector2 and context.get("weapon_tip") is Vector2:
		direction = context.weapon_tip - context.weapon_root
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var stage := StringName(context.get("stage", &""))
	if stage == &"attack_b":
		# normal is the authored swing direction, not the hurtbox surface normal.
		# The small extra lift distinguishes B without creating a second slash.
		direction = (direction + Vector2(0, -0.35)).normalized()
	var at := to_local(world_point)
	var color: Color = context.get("color", Color(0.50, 0.95, 0.88))
	var amount := 9 if stage == &"attack_b" else 7
	_reserve(sparks, amount + 1, MAX_SPARKS)
	# A five-pixel contact core is brief enough not to obscure a telegraph.
	sparks.append({"p": at, "v": Vector2.ZERO, "life": 0.045, "ttl": 0.045, "color": color.lerp(Color(1.0, 0.96, 0.81), 0.75), "length": 2.0, "flash": true})
	for i in range(amount):
		var spread := lerpf(-0.65, 0.65, float(i) / float(maxi(1, amount - 1))) + randf_range(-0.08, 0.08)
		var world_velocity := direction.rotated(spread) * randf_range(75.0, 165.0)
		var velocity := to_local(world_point + world_velocity) - at
		var lifetime := randf_range(0.11, 0.19)
		var tint := color.lerp(Color(1.0, 0.94, 0.75), 0.55 if i % 3 == 0 else 0.15)
		sparks.append({"p": at, "v": velocity, "life": lifetime, "ttl": lifetime, "color": tint, "length": randf_range(3.0, 7.0), "flash": false})
	queue_redraw()

func dash_start(at: Vector2, facing: int, grounded: bool) -> void:
	# at is already the WORLD foot point; adding a body anchor here would
	# bury the dust in the ground. Air dodges get only two faint wind marks.
	var direction := -1.0 if facing < 0 else 1.0
	var amount := 4 if grounded else 2
	_reserve(dust, amount, MAX_DUST)
	for i in range(amount):
		var world_point := at + Vector2(-direction * randf_range(1.0, 7.0), -1.0 if grounded else -12.0 + float(i) * 5.0)
		var world_velocity := Vector2(-direction * randf_range(28.0, 60.0), randf_range(-22.0, -8.0)) if grounded else Vector2(-direction * randf_range(100.0, 145.0), 0.0)
		var local_point := to_local(world_point)
		var lifetime := randf_range(0.16, 0.23) if grounded else 0.11
		dust.append({"p": local_point, "v": to_local(world_point + world_velocity) - local_point, "life": lifetime, "ttl": lifetime, "color": DUST_COLOR if grounded else AIR_TRACE_COLOR, "size": Vector2(randi_range(2, 3), 2), "floor_y": to_local(at).y - 1.0, "streak": not grounded, "length": 5.0 + float(i) * 2.0})
	queue_redraw()

func landing(at: Vector2, impact_speed: float, facing: int) -> void:
	# Small steps do not emit a full cloud. Ordinary jumps make only 3-5 low,
	# translucent flecks, with a modest speed response instead of screen fill.
	if not is_finite(impact_speed) or impact_speed < 70.0:
		return
	var strength := clampf(impact_speed / 700.0, 0.15, 1.0)
	var amount := clampi(3 + int(strength * 2.0), 3, 5)
	var facing_sign := -1.0 if facing < 0 else 1.0
	_reserve(dust, amount, MAX_DUST)
	for i in range(amount):
		var side := (-1.0 if i % 2 == 0 else 1.0) * facing_sign
		var world_point := at + Vector2(side * randf_range(2.0, 5.0), -1.0)
		var world_velocity := Vector2(side * randf_range(22.0, 45.0) * (0.7 + strength), -randf_range(12.0, 24.0) * (0.7 + strength))
		var local_point := to_local(world_point)
		var lifetime := randf_range(0.20, 0.29)
		dust.append({"p": local_point, "v": to_local(world_point + world_velocity) - local_point, "life": lifetime, "ttl": lifetime, "color": DUST_COLOR, "size": Vector2(randi_range(2, 3), randi_range(1, 2)), "floor_y": to_local(at).y - 1.0, "streak": false, "length": 0.0})
	queue_redraw()

func clear_all() -> void:
	particles.clear()
	ghosts.clear()
	sparks.clear()
	dust.clear()
	queue_redraw()

func _reserve(items: Array[Dictionary], incoming: int, limit: int) -> void:
	# Bounded, short-lived pools prevent rapid multi-target impacts or repeated
	# dash input from accumulating unbounded draw calls. Keep the newest burst.
	while items.size() + incoming > limit and not items.is_empty():
		items.pop_front()

func _process(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var item: Dictionary = particles[i]
		item.life -= delta
		item.v.y += 420 * delta
		item.p += item.v * delta
		if item.life <= 0:
			particles.remove_at(i)
	for i in range(ghosts.size() - 1, -1, -1):
		ghosts[i].life -= delta
		if ghosts[i].life <= 0:
			ghosts.remove_at(i)
	for i in range(sparks.size() - 1, -1, -1):
		var item: Dictionary = sparks[i]
		item.life -= delta
		if not item.flash:
			item.v.y += 145.0 * delta
			item.p += item.v * delta
		if item.life <= 0.0:
			sparks.remove_at(i)
	for i in range(dust.size() - 1, -1, -1):
		var item: Dictionary = dust[i]
		item.life -= delta
		if not item.streak:
			item.v.x = move_toward(float(item.v.x), 0.0, 95.0 * delta)
			item.v.y += 105.0 * delta
		item.p += item.v * delta
		if not item.streak and item.p.y > item.floor_y:
			item.p.y = item.floor_y
			item.v.y = 0.0
		if item.life <= 0.0:
			dust.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for item in ghosts:
		draw_set_transform(item.p + item.anchor, 0, Vector2(item.facing, 1))
		draw_texture(item.texture, item.offset, Color(0.5, 1.1, 0.95, item.life / GHOST_SECONDS * 0.30))
	draw_set_transform(Vector2.ZERO)
	for item in dust:
		var color: Color = item.color
		var fade := clampf(float(item.life) / float(item.ttl), 0.0, 1.0)
		color.a *= fade * fade
		var point: Vector2 = item.p
		if item.streak:
			var velocity: Vector2 = item.v
			draw_line((point - velocity.normalized() * float(item.length)).round(), point.round(), color, 1.0, false)
		else:
			draw_rect(Rect2(point.round(), item.size), color)
	for item in particles:
		var color: Color = item.color
		color.a = minf(1, item.life * 5)
		draw_rect(Rect2(item.p, Vector2.ONE * item.size), color)
	for item in sparks:
		var color: Color = item.color
		var fade := clampf(float(item.life) / float(item.ttl), 0.0, 1.0)
		color.a *= fade
		var point: Vector2 = item.p
		if item.flash:
			draw_rect(Rect2(point.round() - Vector2(2, 0), Vector2(5, 1)), color)
			draw_rect(Rect2(point.round() - Vector2(0, 2), Vector2(1, 5)), color)
		else:
			var velocity: Vector2 = item.v
			var tail := point - velocity.normalized() * float(item.length) * (0.45 + fade * 0.55)
			draw_line(tail.round(), point.round(), color, 1.0, false)
