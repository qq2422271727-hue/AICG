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

# Presentation has its own small envelope, driven by the same pausable physics
# clock as combat. It never rotates/scales the CharacterBody2D or its collider.
const HIT_POSE_SECONDS := 0.30
const DEATH_POSE_SECONDS := 0.48
const BLADE_LENGTH := 34.0
const TORSO_OUTLINE := [Vector2(-14, -19), Vector2(12, -19), Vector2(14, -10), Vector2(10, 3), Vector2(-10, 3), Vector2(-14, -9)]
const TORSO_ARMOR := [Vector2(-12, -17), Vector2(10, -17), Vector2(12, -9), Vector2(8, 1), Vector2(-9, 1), Vector2(-12, -8)]
# Packed-array construction is not a constant expression in GDScript. Bake
# these immutable draw buffers once at script load, not once per instance/frame.
static var _torso_outline := PackedVector2Array(TORSO_OUTLINE)
static var _torso_armor := PackedVector2Array(TORSO_ARMOR)
var hit_pose_time := HIT_POSE_SECONDS
var hit_stage: StringName = &""
var hit_direction := 1.0
var hit_normal := Vector2.RIGHT
var hit_contact := Vector2.ZERO
var hit_serial := -1
var death_pose_time := 0.0
var death_facing := 1
var death_direction := 1.0
var death_from_b := false

class SentryPose:
	var pelvis := Vector2(0, 7)
	var torso_angle := 0.0
	var torso_scale := Vector2.ONE
	var head_angle := 0.0
	var twist := 0.0
	var rear_foot := Vector2(-7, 21)
	var front_foot := Vector2(7, 21)
	var rear_elbow := Vector2(-16, -1)
	var rear_hand := Vector2(-13, 7)
	var front_elbow := Vector2(16, -1)
	var front_hand := Vector2(20, -7)
	var weapon_angle := 0.85

	func reset() -> void:
		pelvis = Vector2(0, 7)
		torso_angle = 0.0
		torso_scale = Vector2.ONE
		head_angle = 0.0
		twist = 0.0
		rear_foot = Vector2(-7, 21)
		front_foot = Vector2(7, 21)
		rear_elbow = Vector2(-16, -1)
		rear_hand = Vector2(-13, 7)
		front_elbow = Vector2(16, -1)
		front_hand = Vector2(20, -7)
		weapon_angle = 0.85

# Per-instance scratch data: drawing and pose sampling do not allocate new
# RefCounted poses or construct temporary polygon arrays every frame.
var _pose := SentryPose.new()
var _shade_points := PackedVector2Array([Vector2(-12, -17), Vector2(-6, -15), Vector2(-5, -1), Vector2(-9, 1), Vector2(-12, -8)])
var _blade_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

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
	# Sample before advancing so the step that reaches the final pose (or ends
	# the hit flash) still redraws once. The settled corpse then stays cached.
	var corpse_changed := dead and (death_pose_time < DEATH_POSE_SECONDS or flash > 0)
	anim_time += delta
	flash = maxf(0, flash - delta)
	hit_pose_time = minf(HIT_POSE_SECONDS, hit_pose_time + delta)
	if dead:
		death_pose_time = minf(DEATH_POSE_SECONDS, death_pose_time + delta)
	state_time -= delta
	if dead:
		if corpse_changed:
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

func take_hit(amount: int, direction: int, context: Dictionary = {}) -> void:
	if dead:
		return
	# Contact data belongs to presentation only. Old two-argument callers still
	# get the horizontal reaction and the same gameplay knockback as before.
	hit_stage = StringName(context.get("stage", &"attack_a"))
	hit_direction = 1.0 if direction >= 0 else -1.0
	hit_normal = context.get("normal", Vector2(hit_direction, 0))
	if hit_normal.is_zero_approx():
		hit_normal = Vector2(hit_direction, 0)
	hit_normal = hit_normal.normalized()
	hit_contact = to_local(context.get("point", global_position))
	hit_serial = int(context.get("serial", -1))
	hit_pose_time = 0.0
	health -= amount
	flash = 0.12
	state = State.HURT
	state_time = 0.24
	velocity = Vector2(direction * 220, -70)
	world.impact(position, Color("ffd084"), 0.045, 3.0, context)
	if health <= 0:
		dead = true
		state = State.DEAD
		death_pose_time = 0.0
		death_facing = facing
		death_direction = hit_direction
		death_from_b = hit_stage == &"attack_b"
		world.spawn_burst(position, Color("ffb373"), 23, 180.0)
		world.sentry_defeated(seal_index)
	queue_redraw()

func clear_combat_visuals() -> void:
	flash = 0.0
	hit_pose_time = HIT_POSE_SECONDS
	hit_stage = &""
	hit_direction = 1.0
	hit_normal = Vector2.RIGHT
	hit_contact = Vector2.ZERO
	hit_serial = -1
	death_pose_time = DEATH_POSE_SECONDS if dead else 0.0
	if not dead:
		death_facing = facing
		death_direction = 1.0
	death_from_b = false
	queue_redraw()

func respawn() -> void:
	position = home
	velocity = Vector2.ZERO
	health = 3
	dead = false
	state = State.PATROL
	state_time = 0
	anim_time = 0
	already_hit = false
	clear_combat_visuals()
	queue_redraw()

func _draw() -> void:
	# A stable ground shadow makes recoil readable without moving the hurtbox.
	draw_rect(Rect2(-18, 18, 36, 5), Color(0, 0, 0, 0.25))
	if dead:
		_draw_fall()
		return
	if state == State.TELEGRAPH:
		var range_rect := attack_rect()
		range_rect.position -= position
		draw_rect(range_rect, Color(1, 0.42, 0.26, 0.10))
	_draw_sentry(_sample_pose(), facing)
	if state == State.TELEGRAPH:
		var pulse := 0.55 + sin(anim_time * 30) * 0.2
		draw_rect(Rect2(-4, -53, 8, 14), Color(1, 0.7, 0.37, pulse))
		draw_rect(Rect2(-4, -35, 8, 4), Color("ffe2a1"))
	if state == State.STRIKE:
		draw_arc(Vector2(facing * 13, -2), 61, -0.8 if facing > 0 else PI - 0.8, 0.8 if facing > 0 else PI + 0.8, 8, Color("ff9b6b"), 7)
	# Health pips appear only once engaged or wounded.
	if state != State.PATROL or health < 3:
		for i in range(3):
			draw_rect(Rect2(-15 + i * 11, -61, 8, 3), Color("f1b27a") if i < health else Color("423b4b"))

func _sample_pose() -> SentryPose:
	var pose := _pose
	pose.reset()
	var gait := sin(anim_time * 13)
	var walking := state == State.PATROL or state == State.CHASE
	if walking and absf(velocity.x) > 10:
		pose.pelvis.y -= absf(gait) * 1.7
		pose.front_foot += Vector2(gait * 4.5, -maxf(0, gait) * 2.5)
		pose.rear_foot += Vector2(-gait * 4.5, -maxf(0, -gait) * 2.5)
		pose.rear_hand.x -= gait * 2.0
		pose.front_hand.x += gait * 1.4
		pose.torso_angle = 0.11 if state == State.CHASE else 0.035
	else:
		pose.torso_angle = sin(anim_time * 2.2) * 0.018
	match state:
		State.TELEGRAPH:
			var wind := smoothstep(0.0, 1.0, 1.0 - state_time / 0.55)
			pose.pelvis += Vector2(-3, 2) * wind
			pose.torso_angle = -0.17 * wind
			pose.head_angle = 0.10 * wind
			pose.rear_foot.x = -10
			pose.front_foot.x = 10
			pose.front_elbow = Vector2(16, -10).lerp(Vector2(19, -17), wind)
			pose.front_hand = Vector2(20, -7).lerp(Vector2(16, -21), wind)
			pose.rear_elbow = Vector2(-17, -3)
			pose.rear_hand = Vector2(-13, 2)
			pose.weapon_angle = lerpf(0.85, -1.55, wind)
		State.STRIKE:
			var thrust := smoothstep(0.0, 0.45, 1.0 - state_time / 0.15)
			pose.pelvis += Vector2(4, 1)
			pose.torso_angle = 0.28
			pose.head_angle = -0.12
			pose.front_foot = Vector2(14, 21)
			pose.rear_foot = Vector2(-10, 20)
			pose.front_elbow = Vector2(27, -11)
			pose.front_hand = Vector2(34, -13).lerp(Vector2(43, -12), thrust)
			pose.rear_elbow = Vector2(-17, -6)
			pose.rear_hand = Vector2(-23, -4)
			pose.weapon_angle = -0.03
		State.RECOVER:
			var recover := smoothstep(0.0, 1.0, 1.0 - state_time / 0.60)
			pose.pelvis += Vector2(4, 1) * (1.0 - recover)
			pose.torso_angle = lerpf(0.28, 0.0, recover)
			pose.head_angle = -0.12 * (1.0 - recover)
			pose.front_foot.x = lerpf(14, 7, recover)
			pose.rear_foot.x = lerpf(-10, -7, recover)
			pose.front_elbow = Vector2(27, -11).lerp(Vector2(16, -1), recover)
			pose.front_hand = Vector2(43, -12).lerp(Vector2(20, -7), recover)
			pose.weapon_angle = lerpf(-0.03, 0.85, recover)
	if hit_pose_time < HIT_POSE_SECONDS:
		_apply_hit_pose(pose)
	# Keep the fixed-length blade above the floor even in a forward A recoil.
	# This is a wrist correction only; collision and reach remain untouched.
	_keep_blade_above_floor(pose)
	return pose

func _keep_blade_above_floor(pose: SentryPose, body_transform: Transform2D = Transform2D.IDENTITY) -> void:
	var grip := body_transform * pose.front_hand
	var direction := body_transform.basis_xform(Vector2.from_angle(pose.weapon_angle))
	var max_downward := clampf((20.0 - grip.y) / (BLADE_LENGTH + 2.0), -1, 1)
	if direction.y > max_downward:
		var side := 1.0 if direction.x >= 0 else -1.0
		var corrected := Vector2(side * sqrt(maxf(0, 1.0 - max_downward * max_downward)), max_downward)
		pose.weapon_angle = body_transform.affine_inverse().basis_xform(corrected).angle()

func _apply_hit_pose(pose: SentryPose) -> void:
	var progress := clampf(hit_pose_time / HIT_POSE_SECONDS, 0, 1)
	# Impact starts at full compression, so world-owned hit-stop holds the
	# contact pose immediately. One damped recoil then returns to the live pose.
	var force := pow(1.0 - progress, 2.0)
	var recoil := sin(progress * PI) * (1.0 - progress)
	var push := hit_direction * facing
	var high_contact := clampf(-hit_contact.y / 21.0, -1, 1)
	if hit_stage == &"attack_b":
		var upward := clampf(-hit_normal.y, 0, 1)
		pose.pelvis += Vector2(push * 2.0 * force, -lerpf(4.0, 6.0, upward) * force)
		pose.torso_angle += push * (0.46 * force + 0.18 * recoil)
		pose.torso_scale = Vector2(1.0 - 0.09 * force, 1.0 + 0.12 * force)
		pose.twist = push * lerpf(4.0, 6.0, upward) * force
		pose.head_angle -= push * 0.30 * force
		pose.rear_elbow += Vector2(-push * 5, -7) * force
		pose.rear_hand += Vector2(-push * 8, -11) * force
		pose.front_elbow += Vector2(push * 7, -4) * force
		pose.front_hand += Vector2(push * 7, -10) * force
		pose.weapon_angle -= push * 0.42 * force
	else:
		pose.pelvis += Vector2(push * 4.0 * force, 2.0 * force)
		pose.torso_angle += push * (0.34 * force - 0.10 * recoil)
		pose.torso_scale = Vector2(1.0 - 0.23 * force, 1.0 + 0.035 * force)
		pose.head_angle -= push * (0.16 + high_contact * 0.09) * force
		pose.rear_elbow += Vector2(push * 3, 3) * force
		pose.rear_hand += Vector2(-push * 4, 2) * force
		pose.front_elbow += Vector2(push * 5, 2) * force
		pose.front_hand += Vector2(push * 8, -1) * force
		pose.weapon_angle += push * 0.25 * force

func _draw_sentry(pose: SentryPose, mirror: int, root: Vector2 = Vector2.ZERO, root_angle: float = 0.0) -> void:
	var ink := Color("282939")
	var armor := Color("fff3c6") if flash > 0 else Color("8c6870")
	var shade := Color("ac967f") if flash > 0 else Color("594853")
	var edge := Color("fff0bd") if flash > 0 else Color("c39983")
	var transform := Transform2D(root_angle, Vector2(mirror, 1), 0.0, root)
	draw_set_transform_matrix(transform)
	var rear_hip := pose.pelvis + Vector2(-5, 0)
	var front_hip := pose.pelvis + Vector2(5, 0)
	_draw_jointed_limb(rear_hip, rear_hip.lerp(pose.rear_foot, 0.52) + Vector2(-3, 0), pose.rear_foot, Color("453e55"), 7)
	_draw_jointed_limb(front_hip, front_hip.lerp(pose.front_foot, 0.52) + Vector2(3, 0), pose.front_foot, Color("665364"), 7)
	draw_rect(Rect2(pose.rear_foot + Vector2(-5, -3), Vector2(12, 4)), ink)
	draw_rect(Rect2(pose.front_foot + Vector2(-4, -3), Vector2(13, 4)), ink)
	var rear_shoulder := pose.pelvis + (Vector2(-10, -14) * pose.torso_scale).rotated(pose.torso_angle)
	var front_shoulder := pose.pelvis + (Vector2(10 - pose.twist, -14) * pose.torso_scale).rotated(pose.torso_angle)
	_draw_jointed_limb(rear_shoulder, pose.rear_elbow, pose.rear_hand, shade, 6)
	var torso := Transform2D(pose.torso_angle, pose.torso_scale, 0.0, pose.pelvis)
	draw_set_transform_matrix(transform * torso)
	draw_colored_polygon(_torso_outline, ink)
	draw_colored_polygon(_torso_armor, armor)
	_shade_points[1] = Vector2(-6 + pose.twist * 0.5, -15)
	_shade_points[2] = Vector2(-5 + pose.twist, -1)
	draw_colored_polygon(_shade_points, shade)
	draw_line(Vector2(-9, -16), Vector2(8, -16), edge, 2)
	draw_rect(Rect2(-9 + pose.twist * 0.5, -10, 16, 3), shade)
	draw_rect(Rect2(-3 + pose.twist, -13, 4, 8), Color("d7a56b"))
	draw_rect(Rect2(-12, 0, 24, 4), ink)
	draw_rect(Rect2(-10, 0, 20, 2), Color("d7a56b"))
	# Head lags the chest instead of rotating as a single cardboard rectangle.
	var head := Transform2D(pose.head_angle, Vector2(0, -20))
	draw_set_transform_matrix(transform * torso * head)
	draw_rect(Rect2(-11, -12, 23, 16), ink)
	draw_rect(Rect2(-9, -11, 19, 14), armor)
	draw_rect(Rect2(-9, -10, 5, 12), shade)
	draw_rect(Rect2(-13, -13, 27, 5), edge)
	draw_rect(Rect2(-11, -8, 24, 2), ink)
	draw_rect(Rect2(1, -6, 10, 4), Color("ffc77b"))
	draw_rect(Rect2(7, -6, 3, 2), Color("fff0bc"))
	draw_set_transform_matrix(transform)
	_draw_jointed_limb(front_shoulder, pose.front_elbow, pose.front_hand, armor, 7)
	draw_rect(Rect2(front_shoulder - Vector2(5, 4), Vector2(10, 7)), edge)
	_draw_weapon(pose.front_hand, pose.weapon_angle)
	draw_set_transform(Vector2.ZERO)

func _draw_jointed_limb(start: Vector2, joint: Vector2, end: Vector2, color: Color, width: float) -> void:
	var ink := Color("282939")
	draw_line(start, joint, ink, width + 3)
	draw_line(joint, end, ink, width + 2)
	draw_line(start, joint, color, width)
	draw_line(joint, end, color.darkened(0.12), width - 1)
	draw_rect(Rect2(joint - Vector2(2, 2), Vector2(4, 4)), Color("b38b7e"))

func _draw_weapon(grip: Vector2, angle: float) -> void:
	var direction := Vector2.from_angle(angle)
	var across := direction.orthogonal()
	var tip := grip + direction * BLADE_LENGTH
	var base := grip + direction * 5
	var blade := Color("ffb17d") if state == State.TELEGRAPH else Color("d3b79b")
	if state == State.STRIKE:
		blade = Color("ffe7ba")
	draw_line(grip - direction * 6, base, Color("282939"), 5)
	_blade_points[0] = base - across * 3
	_blade_points[1] = tip - direction * 3 - across * 3
	_blade_points[2] = tip + direction * 2
	_blade_points[3] = tip - direction * 3 + across * 3
	_blade_points[4] = base + across * 3
	draw_colored_polygon(_blade_points, blade)
	draw_line(base + across * 2, tip, Color("fff0ce"), 1)
	draw_line(base - across * 6, base + across * 6, Color("8f6a62"), 3)
	draw_rect(Rect2(grip - Vector2(3, 3), Vector2(6, 6)), Color("b58c7b"))

func _draw_fall() -> void:
	# The body freezes physically on defeat as before; only this drawing falls.
	# Clamp, never loop: the terminal ground pose remains until the run resets.
	var progress := clampf(death_pose_time / DEATH_POSE_SECONDS, 0, 1)
	var turn := smoothstep(0.0, 0.84, progress)
	var collapse := smoothstep(0.18, 0.92, progress)
	var push := death_direction * death_facing
	var pose := _pose
	pose.reset()
	pose.pelvis = Vector2(0, 6)
	pose.torso_angle = push * lerpf(0.34, 0.12, turn)
	pose.head_angle = -push * lerpf(0.2, 0.08, turn)
	pose.twist = push * 4.0 * (1.0 - turn) if death_from_b else 0.0
	pose.rear_foot = Vector2(-9, 18).lerp(Vector2(-11, 11), collapse)
	pose.front_foot = Vector2(10, 21).lerp(Vector2(7, 12), collapse)
	pose.rear_elbow = Vector2(-15, -4).lerp(Vector2(-12, -2), collapse)
	pose.rear_hand = Vector2(-15, 6).lerp(Vector2(-7, 7), collapse)
	pose.front_elbow = Vector2(16, -4).lerp(Vector2(12 * push, -2), collapse)
	pose.front_hand = Vector2(20, -7).lerp(Vector2(9 * push, 9), collapse)
	# Counter-rotate the dropped blade so its terminal edge lies along the
	# ground rather than rotating through the floor with the torso.
	pose.weapon_angle = lerpf(0.85, -1.48 * push, turn)
	var lift := sin(progress * PI) * (6.0 if death_from_b else 1.5)
	var settle := sin(clampf((progress - 0.82) / 0.18, 0, 1) * PI) * 1.2
	var root := Vector2(death_direction * 5.0 * turn, 6.0 * collapse - lift - settle)
	var root_angle := death_direction * 1.48 * turn
	_keep_blade_above_floor(pose, Transform2D(root_angle, Vector2(death_facing, 1), 0.0, root))
	_draw_sentry(pose, death_facing, root, root_angle)
