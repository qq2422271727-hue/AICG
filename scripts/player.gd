extends CharacterBody2D
class_name AshPlayer

## Input buffering, coyote time and early jump release keep the movement responsive.
signal health_changed(current: int, maximum: int)
signal died

const RUN_SPEED := 236.0
const ACCELERATION := 1950.0
const GRAVITY := 1150.0
const JUMP_SPEED := -388.0
const DODGE_SPEED := 490.0
const MAX_HEALTH := 5
const Visual = preload("res://scripts/player_visual.gd")
const SlashVisual = preload("res://scripts/pixelfx_slash.gd")
const ComboMachine = preload("res://scripts/combo_machine.gd")

# This machine is the ONLY attack clock. The legacy properties below are
# deliberate compatibility adapters for v0.4 callers / unchanged regressions.
var combo := ComboMachine.new()

var world: Node2D
var health := MAX_HEALTH
var facing := 1
var dead := false
var coyote := 0.0
var jump_buffer := 0.0
var attack_buffer: float:
	get:
		return combo.buffer_left
	set(value):
		combo.buffer_left = maxf(0.0, value)
var air_jump := true
var dodge_time := 0.0
var dodge_cooldown := 0.0
var invulnerable := 0.0
var attack_time: float:
	get:
		return 0.0 if combo.current_attack.is_empty() else maxf(0.0, 0.30 - combo.elapsed)
	set(value):
		if value <= 0:
			_interrupt_attack(&"legacy_clear")
		else:
			combo.interrupt(&"legacy_seek")
			combo.press_attack()
			combo.elapsed = clampf(0.30 - value, 0.0, 0.30)
var attack_id: int:
	get:
		return combo.attack_serial
var stagger := 0.0
var anim_time := 0.0
var trail_clock := 0.0
var visual_state: StringName = &"idle"
var visual: AnimatedSprite2D
var slash: AnimatedSprite2D
var visual_clock := 0.0
var gait_clock := 0.0
var takeoff_time := 0.0
var landing_time := 0.0
var death_time := 0.0
var dodge_grounded := true

func _ready() -> void:
	name = "Player"
	collision_layer = 1
	collision_mask = 2
	var body := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 40)
	body.shape = shape
	add_child(body)
	add_to_group("player")
	combo.attack_started.connect(_on_attack_started)
	visual = Visual.new()
	visual.name = "HeroSprite"
	add_child(visual)
	var hero_error: Error = visual.configure()
	assert(hero_error == OK, "Failed to load original hero atlas: %s" % error_string(hero_error))
	slash = SlashVisual.new()
	slash.name = "SwordSlash"
	slash.position = Visual.FOOT_ANCHOR
	slash.z_index = 1
	add_child(slash)
	var slash_error: Error = slash.configure()
	assert(slash_error == OK, "Failed to load sword slash atlas: %s" % error_string(slash_error))
	health_changed.emit(health, MAX_HEALTH)
	_update_visual(0.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	anim_time += delta
	if dead:
		death_time += delta
		_update_visual(delta)
		queue_redraw()
		return
	var was_grounded := is_on_floor()
	var emit_ghost := false
	takeoff_time = maxf(0, takeoff_time - delta)
	landing_time = maxf(0, landing_time - delta)
	coyote = maxf(0, coyote - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	invulnerable = maxf(0, invulnerable - delta)
	stagger = maxf(0, stagger - delta)
	if is_on_floor():
		coyote = 0.11
		air_jump = true
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.13
	if Input.is_action_just_pressed("attack"):
		# Queue now; resolve only on the combat simulation clock below. This also
		# captures a tap during global hit-stop without changing the held pose.
		combo.press_attack(true)
	var direction := Input.get_axis("move_left", "move_right")
	if absf(direction) > 0.1 and dodge_time <= 0 and attack_time <= 0 and stagger <= 0:
		facing = 1 if direction > 0 else -1
	if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0 and stagger <= 0:
		dodge_grounded = is_on_floor()
		dodge_time = 0.22
		dodge_cooldown = 0.62
		invulnerable = maxf(invulnerable, 0.19)
		_interrupt_attack(&"dodge")
		world.spawn_burst(position, Color("8cfff0"), 5, 70.0)
	if dodge_time > 0:
		dodge_time = maxf(0, dodge_time - delta)
		velocity = Vector2(facing * DODGE_SPEED, 0)
		trail_clock -= delta
		if trail_clock <= 0:
			trail_clock = 0.035
			emit_ghost = true
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, 850)
		if stagger <= 0:
			var desired := direction * RUN_SPEED
			if attack_time > 0:
				desired *= 0.45
			velocity.x = move_toward(velocity.x, desired, ACCELERATION * delta)
			if jump_buffer > 0 and (coyote > 0 or air_jump):
				takeoff_time = 0.05
				landing_time = 0
				if coyote <= 0:
					air_jump = false
					world.spawn_burst(position + Vector2(0, 17), Color("88dfd0"), 9, 90.0)
				velocity.y = JUMP_SPEED
				jump_buffer = 0
				coyote = 0
			if Input.is_action_just_released("jump") and velocity.y < -150:
				velocity.y = -150
	if dodge_time <= 0 and stagger <= 0:
		_advance_combat(delta)
	elif world.hit_stop <= 0:
		# Late taps during dodge/hurt may buffer, but interrupts never leak old B.
		combo.buffer_left = maxf(0.0, combo.buffer_left - delta)
	move_and_slide()
	if not was_grounded and is_on_floor():
		landing_time = 0.083
		world.spawn_burst(position + Vector2(0, 18), Color("7eaaa0"), 4, 35.0)
	if position.y > 740:
		health = 0
		health_changed.emit(health, MAX_HEALTH)
		_die()
	_update_visual(delta)
	if emit_ghost and not dead:
		world.effects.ghost_sprite(position, visual.snapshot())
	queue_redraw()

func hurtbox() -> Rect2:
	return Rect2(position - Vector2(11, 20), Vector2(22, 40))

func _on_attack_started(attack: StringName, _serial: int) -> void:
	# A retains the original lunge; B is an upward body extension, not a slide.
	if attack == &"attack_a":
		velocity.x += facing * 65.0

func _interrupt_attack(reason: StringName, lock_input := false) -> void:
	combo.interrupt(reason, lock_input)
	if is_instance_valid(slash):
		slash.sync_attack(0.0, facing)

func _advance_combat(delta: float) -> void:
	# Keep the existing world's global impact timer, not a second local freeze.
	# Unlike the slowed environment, attack clock + input lifetime freeze exactly.
	if world.hit_stop > 0:
		return
	var remaining := delta
	while remaining > ComboMachine.EPS:
		var step := minf(remaining, 1.0 / 120.0)
		combo.advance(step)
		remaining -= step
		if combo.can_hit():
			var hitbox: Rect2 = combo.hitbox(position, facing)
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not enemy.dead and hitbox.intersects(enemy.hurtbox()) and combo.register_hit(enemy.get_instance_id()):
					enemy.take_hit(int(ComboMachine.ATTACKS[combo.current_attack].damage), facing)
		# Contact can start hit-stop in this substep: never advance/cancel to B
		# in leftover time from the same tick. No duplicate pause or camera shake.
		if world.hit_stop > 0:
			break

func take_hit(amount: int, direction: int) -> bool:
	if dead or invulnerable > 0:
		return false
	health = maxi(0, health - amount)
	invulnerable = 0.8
	stagger = 0.16
	_interrupt_attack(&"hurt")
	velocity = Vector2(direction * 250, -125)
	_update_visual(0.0)
	world.impact(position, Color("ffae96"), 0.045, 5.0)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		_die()
	return true

func _die() -> void:
	if dead:
		return
	dead = true
	death_time = 0
	_interrupt_attack(&"death", true)
	dodge_time = 0
	_update_visual(0.0)
	queue_redraw()
	world.spawn_burst(position, Color("a9fff0"), 24, 190.0)
	died.emit()

func respawn(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	health = MAX_HEALTH
	dead = false
	visible = true
	invulnerable = 1.0
	dodge_time = 0
	dodge_cooldown = 0
	_interrupt_attack(&"respawn")
	stagger = 0
	jump_buffer = 0
	attack_buffer = 0
	air_jump = true
	coyote = 0
	death_time = 0
	takeoff_time = 0
	landing_time = 0
	trail_clock = 0
	gait_clock = 0
	visual_clock = 0
	anim_time = 0
	dodge_grounded = true
	visual_state = &"idle"
	# Reset immediately, without waiting one physics tick with a stale death frame.
	visual.sample_clip(&"idle", 0.0, facing)
	visual.modulate = Color.WHITE
	slash.sync_attack(0.0, facing)
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()

func _update_visual(delta: float) -> void:
	var next: StringName = &"idle"
	if dead:
		next = &"death"
	elif stagger > 0:
		next = &"hurt"
	elif dodge_time > 0:
		next = &"ground_dodge" if dodge_grounded else &"air_dodge"
	elif attack_time > 0:
		next = &"attack_b" if combo.current_attack == &"attack_b" else &"attack"
	elif takeoff_time > 0:
		next = &"takeoff"
	elif not is_on_floor():
		next = &"rise" if velocity.y < -35 else &"fall"
	elif absf(velocity.x) > 25:
		next = &"run"
	elif landing_time > 0:
		next = &"land"
	if next != visual_state:
		visual_clock = 0
	else:
		visual_clock += delta
	visual_state = next
	var sample_time := visual_clock
	if next == &"run":
		# One authored stride per 82 world pixels, driven by travelled speed.
		# Sampling never accelerates while blocked against a wall.
		gait_clock += absf(get_position_delta().x) / 82.0 * float(visual.clip_lengths[&"run"])
		sample_time = gait_clock
	elif next == &"attack" or next == &"attack_b":
		sample_time = combo.elapsed
	elif next == &"ground_dodge" or next == &"air_dodge":
		sample_time = 0.22 - dodge_time
	elif next == &"takeoff":
		sample_time = 0.05 - takeoff_time
	elif next == &"land":
		sample_time = 0.083 - landing_time
	elif next == &"hurt":
		# Fit the authored recoil to the existing 160 ms stagger, not vice versa.
		sample_time = (0.16 - stagger) / 0.16 * float(visual.clip_lengths[&"hurt"])
	elif next == &"death":
		sample_time = death_time
	visual.sample_clip(next, sample_time, facing)
	var opacity := clampf(1.0 - maxf(0, death_time - 0.7) * 1.2, 0.2, 1) if dead else 1.0
	if invulnerable > 0 and dodge_time <= 0 and not dead:
		opacity = 0.5 if int(anim_time * 18) % 2 == 0 else 1.0
	visual.modulate = Color(1.5, 1.25, 1.1, opacity) if stagger > 0.09 else Color(1, 1, 1, opacity)
	# Retain A's licensed effect. Do NOT reuse its horizontal slash for rising B;
	# B's original blade/body animation remains visible without an incorrect FX.
	slash.sync_attack(attack_time if next == &"attack" else 0.0, facing)

func _draw() -> void:
	if is_on_floor() and not dead:
		draw_rect(Rect2(-13, 19, 27, 3), Color(0, 0, 0, 0.25))
