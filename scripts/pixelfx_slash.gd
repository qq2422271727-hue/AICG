extends AnimatedSprite2D
## Visual-only adapter. No source actors, collision, damage, hit-stop or shake.
## AshPlayer supplies its actual attack clock; this sprite never calls play().

const ANIM: StringName = &"slash"
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

func configure(json_path: String = "res://assets/fx/sword-slash.json") -> Error:
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
	centered = false
	offset = -RIBBON_ROOT
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_frames = SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
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

func sync_attack(attack_time_remaining: float, facing: int, hero_frame := -1) -> void:
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
