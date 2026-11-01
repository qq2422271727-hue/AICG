extends Node2D

## Pixel debris and frozen native sprite afterimages. No actor animation clocks.
var particles: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func burst(at: Vector2, color: Color, count: int, speed: float) -> void:
	for i in range(count):
		var angle := randf_range(-PI, PI)
		particles.append({"p": at, "v": Vector2.from_angle(angle) * randf_range(speed * 0.25, speed), "life": randf_range(0.18, 0.45), "color": color, "size": randi_range(2, 5)})

func ghost_sprite(at: Vector2, snapshot: Dictionary) -> void:
	if snapshot.is_empty() or not snapshot.get("texture") is Texture2D:
		return
	# Copy the values but retain the same immutable frame texture. No readback,
	# image allocation, changing AnimationPlayer or rectangular body stand-in.
	var frozen := snapshot.duplicate()
	frozen["p"] = at
	frozen["life"] = 0.18
	ghosts.append(frozen)

func _process(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var item: Dictionary = particles[i]
		item.life -= delta
		item.v.y += 420 * delta
		item.p += item.v * delta
		if item.life <= 0:
			particles.remove_at(i)
	for i in range(ghosts.size() - 1, -1, -1):
		ghosts[i].life -= delta
		if ghosts[i].life <= 0:
			ghosts.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for item in ghosts:
		draw_set_transform(item.p + item.anchor, 0, Vector2(item.facing, 1))
		draw_texture(item.texture, item.offset, Color(0.5, 1.1, 0.95, item.life / 0.18 * 0.30))
	draw_set_transform(Vector2.ZERO)
	for item in particles:
		var color: Color = item.color
		color.a = minf(1, item.life * 5)
		draw_rect(Rect2(item.p, Vector2.ONE * item.size), color)
