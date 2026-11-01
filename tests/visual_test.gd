extends SceneTree

## Native-resource/timeline regression, not GPU appearance or device acceptance.
const Visual = preload("res://scripts/player_visual.gd")
const Slash = preload("res://scripts/pixelfx_slash.gd")
const Effects = preload("res://scripts/effects.gd")
const CLIPS := [&"idle", &"run", &"attack", &"takeoff", &"rise", &"fall", &"land", &"ground_dodge", &"air_dodge", &"hurt", &"death"]

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func verify(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures.append(label)
		printerr("FAIL: ", label)

func _run() -> void:
	var visual := Visual.new()
	root.add_child(visual)
	var status: Error = visual.configure()
	verify(status == OK, "Original hero manifest and all native PNG resources load")
	if status != OK:
		quit(1)
		return
	verify(visual.pivot == Vector2(46, 77) and visual.frame_size == Vector2(128, 96), "Every hero frame uses the fixed 128x96 canvas / (46,77) pivot")
	verify(not visual.centered and visual.offset == -visual.pivot and visual.position == Vector2(0, 20), "Untrimmed foot pivot attaches at the unchanged collider's foot")
	verify(visual.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and not visual.is_playing(), "Hero uses nearest sampling and never runs an independent animation clock")
	var atlas_bytes := 0
	for clip in CLIPS:
		verify(visual.sprite_frames.has_animation(clip), "Required clip exists: %s" % clip)
		var frames: SpriteFrames = visual.sprite_frames
		var first := frames.get_frame_texture(clip, 0) as AtlasTexture
		var all_shared := true
		var all_regions := true
		var duration := 0.0
		for i in range(frames.get_frame_count(clip)):
			var frame := frames.get_frame_texture(clip, i) as AtlasTexture
			all_shared = all_shared and frame != null and frame.atlas == first.atlas
			all_regions = all_regions and frame.filter_clip and frame.region == Rect2(i * 128, 0, 128, 96)
			duration += frames.get_frame_duration(clip, i) / frames.get_animation_speed(clip)
		verify(all_shared and all_regions, "%s shares one atlas and preserves fixed untrimmed regions" % clip)
		verify(is_equal_approx(duration, float(visual.clip_lengths[clip])), "%s resource dwell weights match the physics sampler" % clip)
		atlas_bytes += int(first.atlas.get_width() * first.atlas.get_height() * 4)
	verify(atlas_bytes < 8 * 1024 * 1024, "Hero's decoded RGBA8 atlas payload stays below 8 MiB (no mipmaps)")
	verify(is_equal_approx(float(visual.clip_lengths[&"attack"]), 0.30), "Attack asset totals exactly 0.30 seconds, not the old 0.833-second study")
	visual.sample_clip(&"attack", 0.0, 1)
	var startup_frame := visual.frame
	visual.sample_clip(&"attack", 0.05, 1)
	var active_frame := visual.frame
	visual.sample_clip(&"attack", 0.167, 1)
	var recovery_frame := visual.frame
	verify(startup_frame == 0 and active_frame == 5 and recovery_frame == 8, "Attack contact frames 5-7 begin at .05s and recovery frame 8 at .167s")
	visual.sample_clip(&"attack", 0.11, -1)
	var frozen_frame := visual.frame
	for i in range(30):
		visual.sample_clip(&"attack", 0.11, -1)
	verify(visual.frame == frozen_frame and not visual.is_playing(), "A frozen attack clock freezes its exact atlas frame throughout hit-stop")
	verify(visual.scale == Vector2(-1, 1) and visual.offset == Vector2(-46, -77), "Left-facing mirrors around the same fixed foot pivot")
	visual.sample_clip(&"idle", float(visual.clip_lengths[&"idle"]) + 0.01, 1)
	verify(visual.frame == 0, "Idle wraps without accumulating an extra frame")
	visual.sample_clip(&"death", 99.0, 1)
	verify(visual.frame == visual.sprite_frames.get_frame_count(&"death") - 1, "Death holds its final pose instead of wrapping back upright")
	var fx := Slash.new()
	root.add_child(fx)
	verify(fx.configure() == OK, "Corrected straight-alpha sword slash loads")
	verify(fx.sprite_frames.get_frame_count(&"slash") == 18 and is_equal_approx(fx.frame_ends[-1], 0.174), "18 source FX frames are retained; aligned blade ribbon ends at 224 ms")
	fx.sync_attack(0.251, 1)
	verify(not fx.visible, "Slash is hidden during the 50 ms attack anticipation")
	fx.sync_attack(0.25, 1)
	verify(fx.visible and fx.frame == 1, "Slash starts on the first active boundary, skipping the rear-facing source disc")
	fx.sync_attack(0.10, -1)
	verify(fx.visible and fx.scale.x < 0 and is_equal_approx(fx.scale.y, Slash.RIBBON_THICKNESS), "Thin slash tail remains visual-only in early recovery and mirrors with the blade")
	var fx_frame := fx.frame
	var scale_before := Engine.time_scale
	for i in range(30):
		fx.sync_attack(0.10, -1)
	verify(fx.frame == fx_frame and Engine.time_scale == scale_before, "FX frozen-clock sampling cannot apply a second hit-stop")
	fx.sync_attack(0, 1)
	verify(not fx.visible, "Zero attack clock immediately cancels the slash")
	var fx_atlas := fx.sprite_frames.get_frame_texture(&"slash", 0) as AtlasTexture
	var corrected := fx_atlas.atlas.get_image().get_pixel(12, 54)
	verify(roundi(corrected.r * 255) == 102 and roundi(corrected.g * 255) == 208 and roundi(corrected.b * 255) == 255 and roundi(corrected.a * 255) == 60, "Imported slash retains corrected straight-alpha RGBA (102,208,255,60)")
	var effects := Effects.new()
	root.add_child(effects)
	visual.sample_clip(&"ground_dodge", 0.07, -1)
	var snapshot: Dictionary = visual.snapshot()
	var saved_texture: Texture2D = snapshot.texture
	effects.ghost_sprite(Vector2(100, 200), snapshot)
	snapshot["offset"] = Vector2.ZERO
	visual.sample_clip(&"idle", 0, 1)
	verify(effects.ghosts[0].texture == saved_texture and effects.ghosts[0].offset == Vector2(-46, -77) and effects.ghosts[0].facing == -1, "Dash ghost freezes atlas frame, pivot and facing independently of the live sprite")
	verify(effects.ghosts[0].p == Vector2(100, 200) and effects.ghosts[0].anchor == Vector2(0, 20), "Dash ghost preserves body position plus foot-anchor attachment")
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	var player: AshPlayer = game.player
	player.attack_time = 0.19
	player.facing = -1
	player._update_visual(0)
	verify(player.visual_state == &"attack" and player.visual.frame == frozen_frame and player.scale == Vector2.ONE, "Player attack samples the same physics clock without mirroring its collision body")
	verify(player.slash.visible and player.slash.scale.x < 0, "Hero and weapon-attached slash share facing without a double mirror")
	var body_shape := player.get_child(0) as CollisionShape2D
	verify(body_shape.shape.size == Vector2(22, 40) and player.hurtbox().size == Vector2(22, 40), "Sprite integration does not expand the collider or hurtbox")
	player.dodge_grounded = true
	player.dodge_time = 0.12
	player.attack_time = 0
	player._update_visual(0)
	verify(player.visual_state == &"ground_dodge" and not player.slash.visible, "Ground dodge selects its atlas and cancels attack FX")
	player.dodge_grounded = false
	player._update_visual(0)
	verify(player.visual_state == &"air_dodge", "Air dodge has a separate authored atlas")
	player.dodge_time = 0
	player.attack_time = 0.20
	player.invulnerable = 0
	player.take_hit(1, 1)
	verify(player.visual_state == &"hurt" and not player.slash.visible, "Damage synchronously cancels attack drawing/FX before the next physics tick")
	player.invulnerable = 0
	player.take_hit(99, 1)
	verify(player.visual_state == &"death" and not player.slash.visible and player.attack_time == 0, "Death clears attack state and selects the death atlas immediately")
	player.respawn(Vector2(120, 448))
	verify(player.visual.animation == &"idle" and player.visual.frame == 0 and not player.slash.visible, "Respawn resets drawing and FX with no stale death frame")
	game.queue_free()
	effects.queue_free()
	fx.queue_free()
	visual.queue_free()
	await process_frame
	print("HERO_RGBA8_PAYLOAD_BYTES: ", atlas_bytes)
	print("LIMITATION: headless resources/timing only; no GPU appearance or Android device validation")
	print("RESULT: ", checks - failures.size(), "/", checks, " animation checks passed")
	quit(0 if failures.is_empty() else 1)
