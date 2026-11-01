extends CharacterBody2D
class_name AshSentry

## One enemy archetype. Every attack has a 0.55 second, visible wind-up.
enum State { PATROL, CHASE, TELEGRAPH, STRIKE, RECOVER, HURT, DEAD }

var world: Node2D
var player: AshPlayer
var state := State.PATROL
var state_time := 0.0
var home := Vector2.ZERO
var patrol_bounds := Vector2.ZERO
var facing := -1
var health := 3
var dead := false
var flash := 0.0
var anim_time := 0.0
var already_hit := false
var seal_index := 0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	var body := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 42)
	body.shape = shape
	add_child(body)
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	anim_time += delta
	flash = maxf(0, flash - delta)
	state_time -= delta
	if dead:
		queue_redraw()
		return
	velocity.y = minf(velocity.y + 1150 * delta, 850)
	var gap := player.position - position
	var can_see := not player.dead and absf(gap.x) < 260 and absf(gap.y) < 95
	match state:
		State.PATROL:
			if position.x <= patrol_bounds.x:
				facing = 1
			elif position.x >= patrol_bounds.y:
				facing = -1
			velocity.x = facing * 40.0
			if can_see:
				state = State.CHASE
		State.CHASE:
			facing = 1 if gap.x >= 0 else -1
			velocity.x = facing * 92.0
			if not can_see:
				state = State.PATROL
			elif absf(gap.x) < 74 and absf(gap.y) < 58:
				state = State.TELEGRAPH
				state_time = 0.55
				velocity.x = 0
		State.TELEGRAPH:
			velocity.x = 0
			if state_time <= 0:
				state = State.STRIKE
				state_time = 0.15
				already_hit = false
		State.STRIKE:
			velocity.x = facing * 160.0
			if not already_hit and attack_rect().intersects(player.hurtbox()):
				already_hit = player.take_hit(1, facing)
			if state_time <= 0:
				state = State.RECOVER
				state_time = 0.60
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0, 1600 * delta)
			if state_time <= 0:
				state = State.CHASE
		State.HURT:
			velocity.x = move_toward(velocity.x, 0, 950 * delta)
			if state_time <= 0:
				state = State.CHASE
	# Never chase into a gap: each sentry owns a bounded floor segment.
	if position.x < patrol_bounds.x - 55 and velocity.x < 0:
		velocity.x = 0
	if position.x > patrol_bounds.y + 55 and velocity.x > 0:
		velocity.x = 0
	move_and_slide()
	queue_redraw()

func hurtbox() -> Rect2:
	return Rect2(position - Vector2(14, 21), Vector2(28, 42))

func attack_rect() -> Rect2:
	return Rect2(position + Vector2(6 if facing > 0 else -83, -22), Vector2(77, 43))

func take_hit(amount: int, direction: int) -> void:
	if dead:
		return
	health -= amount
	flash = 0.12
	state = State.HURT
	state_time = 0.24
	velocity = Vector2(direction * 220, -70)
	world.impact(position, Color("ffd084"), 0.045, 3.0)
	if health <= 0:
		dead = true
		state = State.DEAD
		world.spawn_burst(position, Color("ffb373"), 23, 180.0)
		world.sentry_defeated(seal_index)

func respawn() -> void:
	position = home
	velocity = Vector2.ZERO
	health = 3
	dead = false
	state = State.PATROL
	state_time = 0
	flash = 0
	queue_redraw()

func _draw() -> void:
	if dead:
		draw_rect(Rect2(-16, 13, 32, 8), Color("424456"))
		draw_rect(Rect2(-9, 9, 11, 6), Color("795d62"))
		return
	var body_color := Color("fff3c6") if flash > 0 else Color("8c6870")
	var stride := sin(anim_time * 13) * 3 if absf(velocity.x) > 10 else 0.0
	draw_rect(Rect2(-17, 18, 34, 5), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-10 + stride, 7, 8, 14), Color("453e55"))
	draw_rect(Rect2(3 - stride, 7, 8, 14), Color("453e55"))
	draw_rect(Rect2(-15, -10, 30, 22), body_color)
	draw_rect(Rect2(-15, -10, 5, 20), Color("594853"))
	draw_rect(Rect2(-11, -25, 23, 17), body_color)
	draw_rect(Rect2(-14, -27, 28, 6), Color("b48a7c"))
	draw_rect(Rect2(2 if facing > 0 else -10, -20, 9, 4), Color("ffc77b"))
	draw_rect(Rect2(-15, 6, 30, 5), Color("d7a56b"))
	var sword_x := 22 if facing > 0 else -28
	if state == State.TELEGRAPH:
		draw_rect(Rect2(sword_x, -38, 6, 39), Color("ff9766"))
		var pulse := 0.55 + sin(anim_time * 30) * 0.2
		draw_rect(Rect2(-4, -51, 8, 14), Color(1, 0.7, 0.37, pulse))
		draw_rect(Rect2(-4, -33, 8, 4), Color("ffe2a1"))
		var range_rect := attack_rect()
		range_rect.position -= position
		draw_rect(range_rect, Color(1, 0.42, 0.26, 0.10))
	elif state == State.STRIKE:
		draw_rect(Rect2(14 if facing > 0 else -80, -13, 66, 7), Color("ffe7ba"))
		draw_arc(Vector2(facing * 13, -2), 61, -0.8 if facing > 0 else PI - 0.8, 0.8 if facing > 0 else PI + 0.8, 8, Color("ff9b6b"), 7)
	else:
		draw_rect(Rect2(sword_x, -3, 6, 30), Color("d3b79b"))
	# Health pips appear only once engaged or wounded.
	if state != State.PATROL or health < 3:
		for i in range(3):
			draw_rect(Rect2(-15 + i * 11, -61, 8, 3), Color("f1b27a") if i < health else Color("423b4b"))
