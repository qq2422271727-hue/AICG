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
var weapon_tracks: Dictionary = {}

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
	_load_weapon_tracks(manifest_path.get_base_dir().path_join(manifest.get("action_tracks", "action_tracks.json")))
	if manifest.has("action_tracks") and (not weapon_tracks.has(&"attack") or not weapon_tracks.has(&"attack_b")):
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
	var sample := _clip_sample_time(clip, elapsed)
	var index := _clip_frame(clip, sample)
	var previous := 0.0 if index == 0 else ends[index - 1]
	set_frame_and_progress(index, clampf((sample - previous) / (ends[index] - previous), 0, 1))

func _clip_sample_time(clip: StringName, elapsed: float) -> float:
	var duration: float = clip_lengths[clip]
	var sample := maxf(0.0, elapsed)
	if clip_loops[clip]:
		return fposmod(sample, duration)
	return minf(sample, duration)

func _clip_frame(clip: StringName, sample: float) -> int:
	var ends: Array[float] = clip_ends[clip]
	for i in range(ends.size()):
		if sample < ends[i] - 0.000001 or i == ends.size() - 1:
			return i
	return -1

func sample_weapon(clip: StringName, elapsed: float, facing: int) -> Dictionary:
	# A pure query: use the visual's manifest clock without touching its current
	# animation, frame, progress, transform or playback state. Track coordinates
	# are the actual offline-rendered blade base and clipped tip in atlas pixels.
	if not weapon_tracks.has(clip) or not clip_ends.has(clip) or not is_finite(elapsed):
		return {"valid": false}
	var index := _clip_frame(clip, _clip_sample_time(clip, elapsed))
	var socket: Dictionary = weapon_tracks[clip][index]
	var mirror := Vector2(-1.0 if facing < 0 else 1.0, 1.0)
	var root_pixel := Vector2(float(socket.root[0]), float(socket.root[1]))
	var tip_pixel := Vector2(float(socket.tip[0]), float(socket.tip[1]))
	return {
		"valid": true,
		"root": (root_pixel - pivot) * mirror + FOOT_ANCHOR,
		"tip": (tip_pixel - pivot) * mirror + FOOT_ANCHOR,
		"frame": index
	}

func _load_weapon_tracks(path: String) -> void:
	# Validate before exposing sockets. configure() rejects a declared track if
	# either attack is missing/corrupt. Old manifests without action_tracks may
	# still load without sockets; selecting legacy FX is the caller's decision.
	weapon_tracks.clear()
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema_version", 0) != 1:
		return
	var track_frame = parsed.get("frame", {})
	var clips = parsed.get("clips", {})
	if not track_frame is Dictionary or not clips is Dictionary:
		return
	var track_pivot = track_frame.get("pivot", [])
	if not track_pivot is Array or track_pivot.size() != 2:
		return
	if track_frame.get("width", 0) != frame_size.x or track_frame.get("height", 0) != frame_size.y:
		return
	if not _valid_socket_point(track_pivot) or Vector2(float(track_pivot[0]), float(track_pivot[1])) != pivot:
		return
	for clip: StringName in [&"attack", &"attack_b"]:
		if not clip_ends.has(clip):
			continue
		var record = clips.get(String(clip), {})
		if not record is Dictionary:
			continue
		var sockets = record.get("sockets", [])
		if not sockets is Array or sockets.size() != clip_ends[clip].size():
			continue
		var valid := true
		for socket in sockets:
			if not socket is Dictionary or not _valid_socket_point(socket.get("root", [])) or not _valid_socket_point(socket.get("tip", [])):
				valid = false
				break
		if valid:
			weapon_tracks[clip] = sockets

func _valid_socket_point(point: Variant) -> bool:
	if not point is Array or point.size() != 2:
		return false
	for value in point:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	return float(point[0]) >= 0 and float(point[0]) < frame_size.x and float(point[1]) >= 0 and float(point[1]) < frame_size.y

func snapshot() -> Dictionary:
	# AtlasTexture is immutable after configure; share it rather than copying pixels.
	return {
		"texture": sprite_frames.get_frame_texture(animation, frame),
		"offset": offset, "anchor": position, "facing": -1 if scale.x < 0 else 1,
		"clip": animation, "frame": frame
	}
