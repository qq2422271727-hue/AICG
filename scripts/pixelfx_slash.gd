extends AnimatedSprite2D
## Visual-only adapter. No source actors, collision, damage, hit-stop or shake.
## AshPlayer supplies its actual attack clock; this sprite never calls play().

const ANIM: StringName = &"slash"
const HERO_MANIFEST := "res://assets/hero/manifest.json"
const TRAIL_FRAME_SIZE := Vector2(128, 96)
const TRAIL_FRAME_COUNT := 15
const TRAIL_TEXTURES := {
	&"attack_a": "res://assets/fx/attack_a_trail.png",
	&"attack_b": "res://assets/fx/attack_b_trail.png"
}
const HERO_CLIPS := {&"attack_a": "attack", &"attack_b": "attack_b"}
const ATTACK_SECONDS := 0.30
const STARTUP_SECONDS := 0.05
const ACTIVE_END_SECONDS := 0.167
const END_SECONDS := 0.224
const VFX_SECONDS := END_SECONDS - STARTUP_SECONDS
# The source crescent belongs to a different actor's downward cut. Its foot
# pivot (44,92) is NOT a weapon socket for our forward cut. Reproject its energy
# onto a narrow ribbon along the actual blade instead of drawing a body-sized orb.
const HERO_PIVOT := Vector2(46, 77)
const FOOT_ANCHOR := Vector2(0, 20)
const RIBBON_ROOT := Vector2(20, 65)
const RIBBON_TIP := Vector2(100, 65)
const RIBBON_THICKNESS := 0.14
# Pixel centres measured on the untrimmed A atlas: guard centre, blade tip.
# Frames 5-7 hold the same contact pose; 8-10 lower the blade during recovery.
const BLADE_POSES := {
	5: [Vector2(74, 45), Vector2(102, 38)],
	6: [Vector2(74, 45), Vector2(102, 38)],
	7: [Vector2(74, 45), Vector2(102, 38)],
	8: [Vector2(71, 49), Vector2(100, 49)],
	9: [Vector2(68, 53), Vector2(96, 59)],
	10: [Vector2(65, 57), Vector2(90, 69)]
}

var frame_ends: Array[float] = []
var source_total_seconds := 0.0
var pivot := Vector2.ZERO
# Keep missing/malformed original assets observable even while the legacy
# MIT adapter remains usable by old callers. Reconfigure after adding assets;
# never retry disk loading from the attack sampler or invent a replacement B.
var legacy_status: Error = ERR_UNCONFIGURED
var stage_load_errors: Dictionary = {}
var stage_lengths: Dictionary = {}

func configure(json_path: String = "res://assets/fx/sword-slash.json") -> Error:
	visible = false
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_frames = SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	frame_ends.clear()
	stage_load_errors.clear()
	stage_lengths.clear()
	source_total_seconds = 0.0
	legacy_status = _configure_legacy(json_path)
	var original_status := _configure_original_trails()
	if legacy_status == OK:
		animation = ANIM
		offset = -RIBBON_ROOT
	pause()
	# Production requires both authored A/B atlases. A non-OK result does not
	# discard a valid legacy resource, but cannot claim original trails loaded.
	return original_status if original_status != OK else legacy_status

func _configure_original_trails() -> Error:
	if not FileAccess.file_exists(HERO_MANIFEST):
		return _all_stages_failed(ERR_FILE_NOT_FOUND)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(HERO_MANIFEST))
	if not parsed is Dictionary or not parsed.get("animations") is Dictionary or not parsed.get("frame") is Dictionary:
		return _all_stages_failed(ERR_FILE_CORRUPT)
	var info: Dictionary = parsed
	var canvas: Dictionary = info.frame
	var hero_pivot: Array = canvas.get("pivot", [])
	if Vector2(float(canvas.get("width", 0)), float(canvas.get("height", 0))) != TRAIL_FRAME_SIZE or hero_pivot.size() != 2:
		return _all_stages_failed(ERR_FILE_CORRUPT)
	if Vector2(float(hero_pivot[0]), float(hero_pivot[1])) != HERO_PIVOT:
		return _all_stages_failed(ERR_FILE_CORRUPT)
	var result: Error = OK
	for stage: StringName in TRAIL_TEXTURES:
		var status := _configure_stage(stage, info.animations)
		stage_load_errors[stage] = status
		if status != OK and result == OK:
			result = status
	return result

func _all_stages_failed(status: Error) -> Error:
	for stage: StringName in TRAIL_TEXTURES:
		stage_load_errors[stage] = status
	return status

func _configure_stage(stage: StringName, animations: Dictionary) -> Error:
	var record: Dictionary = animations.get(HERO_CLIPS[stage], {})
	var seconds: Array = record.get("frame_durations_seconds", [])
	if int(record.get("frames", 0)) != TRAIL_FRAME_COUNT or seconds.size() != TRAIL_FRAME_COUNT:
		return ERR_FILE_CORRUPT
	var total := 0.0
	for value in seconds:
		var duration := float(value)
		if not is_finite(duration) or duration <= 0.0:
			return ERR_FILE_CORRUPT
		total += duration
	if not is_equal_approx(total, ATTACK_SECONDS):
		return ERR_FILE_CORRUPT
	var path: String = TRAIL_TEXTURES[stage]
	if not ResourceLoader.exists(path):
		return ERR_FILE_NOT_FOUND
	var texture := load(path) as Texture2D
	if texture == null:
		return ERR_CANT_OPEN
	if texture.get_size() != Vector2(TRAIL_FRAME_SIZE.x * TRAIL_FRAME_COUNT, TRAIL_FRAME_SIZE.y):
		return ERR_FILE_CORRUPT
	sprite_frames.add_animation(stage)
	sprite_frames.set_animation_loop(stage, false)
	# Metadata mirrors the actor's exact dwell times for inspection only.
	# Neither this adapter nor AnimatedSprite2D advances the stage animation.
	sprite_frames.set_animation_speed(stage, 1.0)
	for i in range(TRAIL_FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(i * TRAIL_FRAME_SIZE.x, 0), TRAIL_FRAME_SIZE)
		atlas.filter_clip = true
		sprite_frames.add_frame(stage, atlas, float(seconds[i]))
	stage_lengths[stage] = total
	return OK

func _configure_legacy(json_path: String) -> Error:
	if not FileAccess.file_exists(json_path):
		return ERR_FILE_NOT_FOUND
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not parsed is Dictionary or not parsed.has("frames") or not parsed.has("meta"):
		return ERR_FILE_CORRUPT
	var info: Dictionary = parsed
	var texture := load(json_path.get_base_dir().path_join(info.meta.image)) as Texture2D
	if texture == null:
		return ERR_CANT_OPEN
	var records: Array = info.frames
	if records.is_empty():
		return ERR_FILE_CORRUPT
	pivot = Vector2(float(info.meta.pixelfx.pivot[0]), float(info.meta.pixelfx.pivot[1]))
	sprite_frames.add_animation(ANIM)
	sprite_frames.set_animation_loop(ANIM, false)
	frame_ends.clear()
	source_total_seconds = 0.0
	var base_ms := float(records[0].duration)
	if base_ms <= 0:
		return ERR_FILE_CORRUPT
	var relative_total := 0.0
	for record: Dictionary in records:
		if record.get("rotated", false) or record.get("trimmed", false):
			return ERR_UNAVAILABLE
		var rect: Dictionary = record.frame
		var region := Rect2(float(rect.x), float(rect.y), float(rect.w), float(rect.h))
		if not Rect2(Vector2.ZERO, texture.get_size()).encloses(region):
			return ERR_FILE_CORRUPT
		var ms := float(record.duration)
		if ms <= 0:
			return ERR_FILE_CORRUPT
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		atlas.filter_clip = true
		var relative := ms / base_ms
		sprite_frames.add_frame(ANIM, atlas, relative)
		relative_total += relative
		source_total_seconds += ms / 1000.0
		frame_ends.append(source_total_seconds)
	if frame_ends.size() != 18:
		return ERR_FILE_CORRUPT
	# Source frame 0 is a rear-facing half-disc, not a forward blade flash.
	# Keep it in the immutable atlas but skip it when sampling. Strong frames
	# 1-8 belong to active contact; only the sparse 9-17 trail enters recovery.
	frame_ends[0] = 0.0
	for i in range(1, 9):
		frame_ends[i] = float(i) / 8.0 * (ACTIVE_END_SECONDS - STARTUP_SECONDS)
	for i in range(9, 18):
		frame_ends[i] = ACTIVE_END_SECONDS - STARTUP_SECONDS + float(i - 8) / 9.0 * (END_SECONDS - ACTIVE_END_SECONDS)
	sprite_frames.set_animation_speed(ANIM, relative_total / VFX_SECONDS)
	animation = ANIM
	pause()
	visible = false
	return OK

func sync_stage(stage: StringName, elapsed: float, facing: int, weapon_pose: Dictionary) -> void:
	# The authoritative actor has already sampled its current stage. A frame
	# supplied here is not resampled from elapsed and cannot drift in hit-stop.
	if stage.is_empty() or not stage_lengths.has(stage) or not bool(weapon_pose.get("valid", false)):
		visible = false
		return
	var sampled_frame := int(weapon_pose.get("frame", -1))
	if not is_finite(elapsed) or elapsed < 0.0 or elapsed >= float(stage_lengths[stage]) or sampled_frame < 0 or sampled_frame >= TRAIL_FRAME_COUNT:
		visible = false
		return
	animation = stage
	position = FOOT_ANCHOR
	offset = -HERO_PIVOT
	rotation = 0.0
	scale = Vector2(-1.0 if facing < 0 else 1.0, 1.0)
	flip_h = false
	flip_v = false
	modulate.a = 1.0
	set_frame_and_progress(sampled_frame, 0.0)
	pause()
	visible = true

func sync_attack(attack_time_remaining: float, facing: int, hero_frame := -1) -> void:
	if legacy_status != OK:
		visible = false
		return
	var elapsed := ATTACK_SECONDS - attack_time_remaining
	if attack_time_remaining <= 0.0 or elapsed + 0.000001 < STARTUP_SECONDS or elapsed >= END_SECONDS - 0.000001:
		visible = false
		return
	# Optional fallback keeps old callers valid. Production passes the already
	# sampled hero frame, so held/hit-stop poses and the weapon socket agree.
	if hero_frame < 0:
		if elapsed < ACTIVE_END_SECONDS - 0.000001:
			hero_frame = 5 + mini(2, int(maxf(0.0, elapsed - STARTUP_SECONDS + 0.000001) / 0.039))
		else:
			hero_frame = 8 + int(maxf(0.0, elapsed - ACTIVE_END_SECONDS + 0.000001) / 0.019)
	if not BLADE_POSES.has(hero_frame):
		visible = false
		return
	animation = ANIM
	offset = -RIBBON_ROOT
	flip_h = false
	flip_v = false
	pause()
	var hand: Vector2 = BLADE_POSES[hero_frame][0] - HERO_PIVOT
	var blade: Vector2 = BLADE_POSES[hero_frame][1] - BLADE_POSES[hero_frame][0]
	var direction := -1.0 if facing < 0 else 1.0
	position = FOOT_ANCHOR + Vector2(hand.x * direction, hand.y)
	rotation = blade.angle() * direction
	scale = Vector2(direction * blade.length() / RIBBON_ROOT.distance_to(RIBBON_TIP), RIBBON_THICKNESS)
	modulate.a = 0.65 * clampf((END_SECONDS - elapsed) / (END_SECONDS - ACTIVE_END_SECONDS), 0.0, 1.0)
	visible = true
	var vfx_time := maxf(0.0, elapsed - STARTUP_SECONDS)
	for i in range(1, frame_ends.size()):
		if vfx_time < frame_ends[i] - 0.000001 or i == frame_ends.size() - 1:
			var previous := 0.0 if i == 0 else frame_ends[i - 1]
			set_frame_and_progress(i, clampf((vfx_time - previous) / (frame_ends[i] - previous), 0.0, 1.0))
			return
