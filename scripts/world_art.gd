extends Node2D
## Visual-only adapter. The original eight physics Rect2s are authoritative.
## Full 32px cells use one native TileSet; fractional edges are source-cropped,
## never stretched or rounded onto a grid. No new collision or camera exists.
const MASONRY := preload("res://assets/world/ash_masonry_47.tres")
const ATLAS := preload("res://assets/world/ash_masonry_47.png")
const LEDGE := preload("res://assets/world/ledge_135x18.png")
const MASKS := [0, 1, 4, 5, 7, 16, 17, 20, 21, 23, 28, 29, 31, 64, 65, 68, 69, 71, 80, 81, 84, 85, 87, 92, 93, 95, 112, 113, 116, 117, 119, 124, 125, 127, 193, 197, 199, 209, 213, 215, 221, 223, 241, 245, 247, 253, 255]
const NEIGHBORS := [Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1)]

var far_layer: Parallax2D
var mid_layer: Parallax2D
var ground_layers: Array[TileMapLayer] = []
var platform_rects: Array[Rect2] = []
var surface_regions: Array[Dictionary] = []
var edge_sprites: Array[Sprite2D] = []

func build(rects: Array[Rect2]) -> void:
	name = "WorldArt"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	platform_rects.assign(rects)
	var sky_canvas := CanvasLayer.new()
	sky_canvas.name = "Sky"
	sky_canvas.layer = -20
	add_child(sky_canvas)
	var sky := TextureRect.new()
	sky.texture = preload("res://assets/world/sky.png")
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_canvas.add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	far_layer = _parallax("DistantCity", "distant_city.png", 0.24, -15, 160.0)
	mid_layer = _parallax("Aqueduct", "aqueduct.png", 0.52, -10, 240.0)
	var props := Sprite2D.new()
	props.name = "RuinProps"
	props.texture = preload("res://assets/world/ruin_props.png")
	props.centered = false
	props.position = Vector2(0, 270)
	props.z_index = -3
	add_child(props)
	for index in range(rects.size()):
		if rects[index].size.y >= 32:
			_masonry(rects[index], index)
		else:
			_ledge(rects[index], index)

func _parallax(title: String, file: String, speed: float, depth: int, y: float) -> Parallax2D:
	var layer := Parallax2D.new()
	layer.name = title
	layer.scroll_scale = Vector2(speed, 1.0)
	layer.repeat_size = Vector2(1536, 0)
	layer.repeat_times = 1
	layer.z_index = depth
	add_child(layer)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/world/" + file)
	sprite.centered = false
	sprite.position.y = y
	layer.add_child(sprite)
	return layer

func _masonry(rect: Rect2, platform_index: int) -> void:
	var layer := TileMapLayer.new()
	layer.name = "Masonry%d" % platform_index
	layer.tile_set = MASONRY
	layer.position = rect.position
	layer.z_index = -1
	layer.collision_enabled = false
	layer.navigation_enabled = false
	layer.occlusion_enabled = false
	add_child(layer)
	ground_layers.append(layer)
	var columns := ceili(rect.size.x / 32.0)
	var rows := ceili(rect.size.y / 32.0)
	for y in range(rows):
		for x in range(columns):
			var size := Vector2(minf(32, rect.size.x - x * 32), minf(32, rect.size.y - y * 32))
			var origin := rect.position + Vector2(x, y) * 32.0
			var mask := 0
			for bit in range(8):
				var n: Vector2i = Vector2i(x, y) + NEIGHBORS[bit]
				if n.x >= 0 and n.x < columns and n.y >= 0 and n.y < rows:
					mask |= 1 << bit
			var atlas_index := MASKS.find(mask)
			assert(atlas_index >= 0)
			var atlas_coords := Vector2i(atlas_index % 8, atlas_index / 8)
			if size == Vector2(32, 32):
				layer.set_cell(Vector2i(x, y), 0, atlas_coords)
			else:
				# Keep the far edge of an edge tile so its border lands at the
				# real collider end, including the 18/20/26px ground end caps.
				var crop_offset := Vector2(32, 32) - size
				_crop(ATLAS, Rect2(Vector2(atlas_coords) * 32.0 + crop_offset, size), origin)
			surface_regions.append({"platform": platform_index, "rect": Rect2(origin, size)})
	layer.update_internals()

func _ledge(rect: Rect2, platform_index: int) -> void:
	# All five original upper platforms are exactly 18px tall. Three unscaled
	# pieces preserve the authored top and underside and BOTH 16px end caps.
	assert(is_equal_approx(rect.size.y, 18.0) and rect.size.x >= 32.0 and rect.size.x <= 135.0)
	var center_width := rect.size.x - 32.0
	var regions := [Rect2(0, 0, 16, 18), Rect2(16, 0, center_width, 18), Rect2(119, 0, 16, 18)]
	var offsets := [0.0, 16.0, rect.size.x - 16.0]
	for part in range(3):
		var at := rect.position + Vector2(offsets[part], 0)
		_crop(LEDGE, regions[part], at)
		surface_regions.append({"platform": platform_index, "rect": Rect2(at, regions[part].size)})

func _crop(texture: Texture2D, region: Rect2, at: Vector2) -> void:
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = region
	cropped.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.texture = cropped
	sprite.centered = false
	sprite.position = at
	sprite.z_index = -1
	add_child(sprite)
	edge_sprites.append(sprite)
