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

var world: Node2D
var health := MAX_HEALTH
var facing := 1
var dead := false
var coyote := 0.0
var jump_buffer := 0.0
var attack_buffer := 0.0
var air_jump := true
var dodge_time := 0.0
var dodge_cooldown := 0.0
var invulnerable := 0.0
var attack_time := 0.0
var attack_id := 0
var hit_targets: Array[Node] = []
var stagger := 0.0
var anim_time := 0.0
var trail_clock := 0.0

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
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()

func _physics_process(delta: float) -> void:
	anim_time += delta
	if dead:
		return
	coyote = maxf(0, coyote - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	attack_buffer = maxf(0, attack_buffer - delta)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	invulnerable = maxf(0, invulnerable - delta)
	stagger = maxf(0, stagger - delta)
	if is_on_floor():
		coyote = 0.11
		air_jump = true
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.13
	if Input.is_action_just_pressed("attack"):
		attack_buffer = 0.14
	var direction := Input.get_axis("move_left", "move_right")
	if absf(direction) > 0.1 and dodge_time <= 0 and attack_time <= 0 and stagger <= 0:
		facing = 1 if direction > 0 else -1
	if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0 and stagger <= 0:
		dodge_time = 0.22
		dodge_cooldown = 0.62
		invulnerable = maxf(invulnerable, 0.19)
		attack_time = 0
		world.spawn_burst(position, Color("8cfff0"), 5, 70.0)
	if dodge_time > 0:
		dodge_time = maxf(0, dodge_time - delta)
		velocity = Vector2(facing * DODGE_SPEED, 0)
		trail_clock -= delta
		if trail_clock <= 0:
			trail_clock = 0.035
			world.spawn_ghost(position, facing)
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, 850)
		if stagger <= 0:
			var desired := direction * RUN_SPEED
			if attack_time > 0:
				desired *= 0.45
			velocity.x = move_toward(velocity.x, desired, ACCELERATION * delta)
			if jump_buffer > 0 and (coyote > 0 or air_jump):
				if coyote <= 0:
					air_jump = false
					world.spawn_burst(position + Vector2(0, 17), Color("88dfd0"), 9, 90.0)
				velocity.y = JUMP_SPEED
				jump_buffer = 0
				coyote = 0
			if Input.is_action_just_released("jump") and velocity.y < -150:
				velocity.y = -150
		if attack_buffer > 0 and attack_time <= 0 and stagger <= 0:
			attack_time = 0.30
			attack_buffer = 0
			attack_id += 1
			hit_targets.clear()
			velocity.x += facing * 65
	if attack_time > 0:
		attack_time = maxf(0, attack_time - delta)
		# 50 ms startup, 117 ms active frames, then a recoverable finish.
		if attack_time <= 0.25 and attack_time >= 0.133:
			var hitbox := Rect2(position + Vector2(7 if facing > 0 else -77, -28), Vector2(70, 53))
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not enemy.dead and not hit_targets.has(enemy) and hitbox.intersects(enemy.hurtbox()):
					hit_targets.append(enemy)
					enemy.take_hit(1, facing)
	move_and_slide()
	if position.y > 740:
		health = 0
		health_changed.emit(health, MAX_HEALTH)
		_die()
	queue_redraw()

func hurtbox() -> Rect2:
	return Rect2(position - Vector2(11, 20), Vector2(22, 40))

func take_hit(amount: int, direction: int) -> bool:
	if dead or invulnerable > 0:
		return false
	health = maxi(0, health - amount)
	invulnerable = 0.8
	stagger = 0.16
	attack_time = 0
	velocity = Vector2(direction * 250, -125)
	world.impact(position, Color("ffae96"), 0.045, 5.0)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		_die()
	return true

func _die() -> void:
	if dead:
		return
	dead = true
	visible = false
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
	attack_time = 0
	stagger = 0
	jump_buffer = 0
	attack_buffer = 0
	air_jump = true
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()

func _draw() -> void:
	if invulnerable > 0 and dodge_time <= 0 and int(anim_time * 24) % 2 == 0:
		return
	var stride := sin(anim_time * 19) * 4 if absf(velocity.x) > 25 and is_on_floor() else 0.0
	var lean := 7.0 if dodge_time > 0 else 0.0
	# The relay runner: teal ceramic mask, copper scarf, dark wrapped limbs.
	draw_rect(Rect2(-12, 17, 25, 5), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-8 + stride, 8, 6, 12), Color("23394e"))
	draw_rect(Rect2(2 - stride, 8, 6, 12), Color("23394e"))
	draw_rect(Rect2(-10 + stride, 17, 9, 3), Color("99cfca"))
	draw_rect(Rect2(1 - stride, 17, 9, 3), Color("99cfca"))
	draw_rect(Rect2(-10 + lean * facing, -8, 20, 20), Color("283e50"))
	draw_rect(Rect2(-8 + lean * facing, -8, 4, 18), Color("4f827d"))
	draw_rect(Rect2(-11 + lean * facing, -21, 22, 16), Color("75cfbf"))
	draw_rect(Rect2(-7 + lean * facing, -21, 15, 3), Color("bcf6da"))
	draw_rect(Rect2((3 if facing > 0 else -10) + lean * facing, -16, 7, 4), Color("101d2b"))
	draw_rect(Rect2(-11 + lean * facing, -7, 22, 5), Color("e79460"))
	draw_rect(Rect2(-25 if facing > 0 else 10, -5 + sin(anim_time * 12) * 2, 16, 5), Color("b85a49"))
	if attack_time > 0 and attack_time <= 0.25 and attack_time >= 0.10:
		var progress := (0.25 - attack_time) / 0.15
		var center := Vector2(facing * 13, -2)
		var base := 0.0 if facing > 0 else PI
		draw_arc(center, 55, base - 1.15 + progress * 0.5, base + 0.9 + progress * 0.5, 10, Color("e4ffce"), 6)
		draw_arc(center, 62, base - 0.85, base + 0.75, 8, Color("70d8b6"), 2)
	else:
		draw_rect(Rect2(12 if facing > 0 else -17, -2, 5, 26), Color("c1d8cd"))
		draw_rect(Rect2(10 if facing > 0 else -19, -3, 9, 4), Color("e7ac62"))
