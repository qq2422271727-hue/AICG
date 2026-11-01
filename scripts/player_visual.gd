extends AnimatedSprite2D

## Original offline-baked pixel hero. Native atlas resources only at runtime.
## Never call play(): AshPlayer's physics clock is the single animation clock,
## so a hit-stop, pause, cancel or respawn cannot leave the drawing running ahead.
const MANIFEST_PATH := "res://assets/hero/manifest.json"
const FOOT_ANCHOR := Vector2(0, 20)

var pivot := Vector2.ZERO
var frame_size := Vector2.ZERO
var clip_ends: Dictionary = {}
var clip_lengths: Dictionary = {}
var clip_loops: Dictionary = {}
var manifest: Dictionary = {}

func configure(manifest_path: String = MANIFEST_PATH) -> Error:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary or not parsed.has("frame") or not parsed.has("animations"):
		return ERR_FILE_CORRUPT
	manifest = parsed
	frame_size = Vector2(float(manifest.frame.width), float(manifest.frame.height))
	pivot = Vector2(float(manifest.frame.pivot[0]), float(manifest.frame.pivot[1]))
	if frame_size.x <= 0 or frame_size.y <= 0:
		return ERR_FILE_CORRUPT
	centered = false
	offset = -pivot
	position = FOOT_ANCHOR
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_frames = SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	clip_ends.clear()
	clip_lengths.clear()
	clip_loops.clear()
	for key: String in manifest.animations:
		var record: Dictionary = manifest.animations[key]
		var clip := StringName(key)
		var count := int(record.frames)
		var texture := load(manifest_path.get_base_dir().path_join(record.get("file", key + "_sheet.png"))) as Texture2D
		if texture == null:
			return ERR_CANT_OPEN
		if count <= 0 or texture.get_size() != Vector2(frame_size.x * count, frame_size.y):
			return ERR_FILE_CORRUPT
		var seconds: Array = record.get("frame_durations_seconds", [])
		if seconds.size() != count:
			return ERR_FILE_CORRUPT
		var ends: Array[float] = []
		var length := 0.0
		sprite_frames.add_animation(clip)
		# Relative duration in SpriteFrames: fps=1 makes each weight seconds.
		sprite_frames.set_animation_speed(clip, 1.0)
		var looping := bool(record.get("loop", false))
		sprite_frames.set_animation_loop(clip, looping)
		for i in range(count):
			var duration := float(seconds[i])
			if duration <= 0:
				return ERR_FILE_CORRUPT
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(i * frame_size.x, 0), frame_size)
			atlas.filter_clip = true
			sprite_frames.add_frame(clip, atlas, duration)
			length += duration
			ends.append(length)
		clip_ends[clip] = ends
		clip_lengths[clip] = length
		clip_loops[clip] = looping
	if not sprite_frames.has_animation(&"idle"):
		return ERR_FILE_CORRUPT
	animation = &"idle"
	pause()
	sample_clip(&"idle", 0.0, 1)
	return OK

func sample_clip(clip: StringName, elapsed: float, facing: int) -> void:
	if not clip_ends.has(clip):
		push_error("Missing hero animation: %s" % clip)
		return
	# Flip this visual child around the fixed foot pivot, never CharacterBody2D.
	scale = Vector2(-1.0 if facing < 0 else 1.0, 1.0)
	animation = clip
	var ends: Array[float] = clip_ends[clip]
	var duration: float = clip_lengths[clip]
	var sample := maxf(0.0, elapsed)
	if clip_loops[clip]:
		sample = fposmod(sample, duration)
	else:
		sample = minf(sample, duration)
	for i in range(ends.size()):
		if sample < ends[i] - 0.000001 or i == ends.size() - 1:
			var previous := 0.0 if i == 0 else ends[i - 1]
			set_frame_and_progress(i, clampf((sample - previous) / (ends[i] - previous), 0, 1))
			return

func snapshot() -> Dictionary:
	# AtlasTexture is immutable after configure; share it rather than copying pixels.
	return {
		"texture": sprite_frames.get_frame_texture(animation, frame),
		"offset": offset, "anchor": position, "facing": -1 if scale.x < 0 else 1,
		"clip": animation, "frame": frame
	}
