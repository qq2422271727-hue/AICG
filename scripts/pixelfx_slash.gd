extends AnimatedSprite2D
## Visual-only adapter. No source actors, collision, damage, hit-stop or shake.
## AshPlayer supplies its actual attack clock; this sprite never calls play().

const ANIM: StringName = &"slash"
const ATTACK_SECONDS := 0.30
const STARTUP_SECONDS := 0.05
const VFX_SECONDS := ATTACK_SECONDS - STARTUP_SECONDS

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
	offset = -pivot
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
	for i in range(frame_ends.size()):
		frame_ends[i] = frame_ends[i] / source_total_seconds * VFX_SECONDS
	sprite_frames.set_animation_speed(ANIM, relative_total / VFX_SECONDS)
	animation = ANIM
	pause()
	visible = false
	return OK

func sync_attack(attack_time_remaining: float, facing: int) -> void:
	scale = Vector2(-1.0 if facing < 0 else 1.0, 1.0)
	var elapsed := ATTACK_SECONDS - attack_time_remaining
	if attack_time_remaining <= 0.0 or elapsed + 0.000001 < STARTUP_SECONDS:
		visible = false
		return
	visible = true
	var vfx_time := maxf(0.0, elapsed - STARTUP_SECONDS)
	for i in range(frame_ends.size()):
		if vfx_time < frame_ends[i] or i == frame_ends.size() - 1:
			var previous := 0.0 if i == 0 else frame_ends[i - 1]
			set_frame_and_progress(i, clampf((vfx_time - previous) / (frame_ends[i] - previous), 0.0, 1.0))
			return
