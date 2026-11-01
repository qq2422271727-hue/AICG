extends SceneTree

var checks := 0
var failed: Array[String] = []
const OFFSETS := [Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1)]
const BITS := [TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_LEFT_SIDE, TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER]

func _initialize() -> void:
	_run.call_deferred()

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed.append(label)
		printerr("FAIL: ", label)

func frames(count: int = 2) -> void:
	for i in range(count):
		await process_frame

func canonical(mask: int) -> int:
	for triple in [[1,0,2],[3,2,4],[5,4,6],[7,6,0]]:
		if not ((mask & (1 << triple[1])) and (mask & (1 << triple[2]))):
			mask &= ~(1 << triple[0])
	return mask

func read_mask(data: TileData) -> int:
	var result := 0
	for i in range(8):
		if data.get_terrain_peering_bit(BITS[i]) == 0:
			result |= 1 << i
	return result

func _run() -> void:
	var proof: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(proof)
	proof.player.set_physics_process(false)
	for enemy in proof.enemies:
		enemy.set_physics_process(false)
	var art: Node2D = proof.world_art
	await frames(3)
	var tiles: TileSet = art.ground_layers[0].tile_set
	verify(tiles.tile_size == Vector2i(32,32), "32px cells")
	verify(tiles.get_source_count() == 1, "one shared atlas")
	verify(tiles.get_terrain_set_mode(0) == TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES, "corners plus sides")
	verify(tiles.get_physics_layers_count() == 0, "no replacement collision shapes")
	for layer: TileMapLayer in art.ground_layers:
		verify(not layer.collision_enabled and not layer.navigation_enabled and not layer.occlusion_enabled, "visual-only TileMap " + layer.name)
	var source := tiles.get_source(0) as TileSetAtlasSource
	verify(source.get_tiles_count() == 47, "47 canonical masks")
	verify(source.use_texture_padding, "engine atlas padding enabled")
	var known: Dictionary = {}
	for i in range(source.get_tiles_count()):
		var data := source.get_tile_data(source.get_tile_id(i),0)
		var mask := read_mask(data)
		verify(not known.has(mask) and canonical(mask) == mask, "unique canonical mask %d" % mask)
		known[mask] = true
	var painter := TileMapLayer.new()
	painter.tile_set = tiles
	painter.collision_enabled = false
	painter.visible = false
	root.add_child(painter)
	# Exhaust all 256 raw neighbor arrangements through the actual Godot solver.
	for raw in range(256):
		painter.clear()
		var cells: Array[Vector2i] = [Vector2i.ZERO]
		for i in range(8):
			if raw & (1 << i):
				cells.append(OFFSETS[i])
		painter.set_cells_terrain_connect(cells,0,0,false)
		painter.update_internals()
		var data := painter.get_cell_tile_data(Vector2i.ZERO)
		verify(data != null and read_mask(data) == canonical(raw), "terrain paint raw %d" % raw)
	var frozen_cells: Array[PackedByteArray] = []
	for layer: TileMapLayer in art.ground_layers:
		frozen_cells.append(layer.tile_map_data.duplicate())
	var camera: Camera2D = proof.camera
	verify(camera.get_screen_center_position().is_equal_approx(Vector2(480,270)), "initial actual center")
	var far_start: Vector2 = art.far_layer.position
	var mid_start: Vector2 = art.mid_layer.position
	var stable := true
	for i in range(80):
		proof.player.position = Vector2(540 if i%2==0 else 420,300 if i%2==0 else 470)
		proof.player.facing = 1 if i%2==0 else -1
		await frames(1)
		stable = stable and camera.get_screen_center_position().is_equal_approx(Vector2(480,270))
		stable = stable and art.far_layer.position.is_equal_approx(far_start) and art.mid_layer.position.is_equal_approx(mid_start)
	verify(stable,"80 alternating directions/jumps leave actual camera and both parallax layers still")
	proof.player.position.x = 1200
	await frames(4)
	var center := camera.get_screen_center_position()
	verify(center.x > 480 and center.x < camera.position.x,"camera follows smoothly")
	verify(is_equal_approx(center.y,270),"vertical camera fixed")
	# Parallax local displacement must follow displayed scroll, not unsmoothed target.
	var scroll := center.x - 480.0
	verify(absf((art.far_layer.position.x-far_start.x)-scroll*0.76)<0.1,"far layer follows actual camera at 0.24 relative speed")
	verify(absf((art.mid_layer.position.x-mid_start.x)-scroll*0.48)<0.1,"mid layer follows actual camera at 0.52 relative speed")
	paused = true
	var pause_far: Vector2 = art.far_layer.position
	await frames(12)
	verify(camera.get_screen_center_position().is_equal_approx(center) and art.far_layer.position.is_equal_approx(pause_far),"pause freezes camera and parallax")
	paused = false
	proof.player.position.x=430
	proof._snap_camera_to_player()
	await frames(2)
	verify(camera.get_screen_center_position().is_equal_approx(Vector2(480,270)),"reset snaps actual camera")
	verify(art.far_layer.position.is_equal_approx(far_start) and art.mid_layer.position.is_equal_approx(mid_start),"reset restores parallax without residual offset")
	var cell_count := 0
	for i in range(art.ground_layers.size()):
		var layer: TileMapLayer = art.ground_layers[i]
		verify(layer.tile_map_data == frozen_cells[i], "no per-frame terrain edits " + layer.name)
		cell_count += layer.get_used_cells().size()
	verify(cell_count == 558 and art.edge_sprites.size() == 129, "558 full tiles plus 114 ground crops and 15 thin-platform slices")
	var expected: Array[Rect2] = [Rect2(-80, 470, 1010, 220), Rect2(1070, 470, 820, 220), Rect2(2030, 470, 1210, 220), Rect2(320, 383, 135, 18), Rect2(1120, 380, 135, 18), Rect2(1740, 382, 126, 18), Rect2(2100, 375, 134, 18), Rect2(2695, 379, 132, 18)]
	verify(proof.platforms == expected and art.platform_rects == expected, "All eight original collider Rect2s are preserved exactly, no grid rounding")
	for index in range(expected.size()):
		var rect := expected[index]
		var area := 0.0
		var within := true
		var no_overlap := true
		var regions: Array[Rect2] = []
		for record: Dictionary in art.surface_regions:
			if record.platform == index:
				var part: Rect2 = record.rect
				within = within and rect.encloses(part)
				area += part.get_area()
				for previous: Rect2 in regions:
					no_overlap = no_overlap and not previous.intersects(part)
				regions.append(part)
		verify(within and is_equal_approx(area, rect.get_area()) and no_overlap, "Platform %d visual coverage exactly equals collision with no gap/overhang" % index)
		# Check actual unchanged physics using downward and upward ray queries.
		var query := PhysicsRayQueryParameters2D.create(Vector2(rect.get_center().x, rect.position.y - 4), Vector2(rect.get_center().x, rect.position.y + 4), 2)
		var hit: Dictionary = root.world_2d.direct_space_state.intersect_ray(query)
		verify(not hit.is_empty() and is_equal_approx(hit.position.y, rect.position.y), "Platform %d actual top collision remains at original height" % index)
		query = PhysicsRayQueryParameters2D.create(Vector2(rect.get_center().x, rect.end.y + 4), Vector2(rect.get_center().x, rect.end.y - 4), 2)
		hit = root.world_2d.direct_space_state.intersect_ray(query)
		verify(not hit.is_empty() and is_equal_approx(hit.position.y, rect.end.y), "Platform %d remains solid from below, not one-way" % index)
	var all_crop_unscaled := true
	for sprite: Sprite2D in art.edge_sprites:
		var crop := sprite.texture as AtlasTexture
		all_crop_unscaled = all_crop_unscaled and sprite.scale == Vector2.ONE and crop != null and crop.filter_clip
	verify(all_crop_unscaled, "Fractional right/bottom edges and 18px ledges are cropped, never texture-scaled")
	var static_bodies := 0
	var camera_count := 0
	for node in proof.find_children("*", "StaticBody2D", true, false):
		static_bodies += 1
	for node in proof.find_children("*", "Camera2D", true, false):
		camera_count += 1
	verify(static_bodies == 10 and camera_count == 1, "Only the original eight platforms/two walls and one Camera2D exist")
	var world_source := FileAccess.get_file_as_string("res://scripts/world.gd")
	verify(not world_source.contains("var view_x") and not world_source.contains("draw_circle") and not world_source.contains("Foreground masonry"), "Legacy procedural backdrop/parallax drawing is removed, not double-composited")
	verify(world_source.contains("for x in [930, 1890]") and world_source.contains("for index in range(3)") and world_source.contains("Final relay"), "Original hazard, checkpoint and final relay drawings remain")
	verify(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "Compatibility renderer remains the production default")
	var sky: TextureRect = art.get_node("Sky").get_child(0)
	verify(sky.get_rect().size == Vector2(960, 540), "Sky covers the full logical viewport, not an undersized sprite")
	# Actual gaps stay empty even immediately beside fractional tile caps.
	for gap_x in [931.0, 1000.0, 1069.0, 1891.0, 1960.0, 2029.0]:
		var query := PhysicsRayQueryParameters2D.create(Vector2(gap_x, 465), Vector2(gap_x, 480), 2)
		verify(root.world_2d.direct_space_state.intersect_ray(query).is_empty(), "No false floor / collider in real gap x=%s" % gap_x)
	proof.queue_free()
	painter.queue_free()
	await frames()
	print("V05 MAP VERIFY: ", checks-failed.size(), "/",checks," passed; failures=",failed)
	quit(0 if failed.is_empty() else 1)
