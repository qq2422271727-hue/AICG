extends Node2D

## Transient pixel particles and dodge silhouettes, shared by both combatants.
var particles: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []

func burst(at: Vector2, color: Color, count: int, speed: float) -> void:
	for i in range(count):
		var angle := randf_range(-PI, PI)
		particles.append({"p": at, "v": Vector2.from_angle(angle) * randf_range(speed * 0.25, speed), "life": randf_range(0.18, 0.45), "color": color, "size": randi_range(2, 5)})

func ghost(at: Vector2, direction: int) -> void:
	ghosts.append({"p": at, "life": 0.18, "facing": direction})

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
	for ghost_item in ghosts:
		var p: Vector2 = ghost_item.p
		draw_rect(Rect2(p - Vector2(11, 20), Vector2(22, 40)), Color(0.4, 0.9, 0.8, ghost_item.life / 0.18 * 0.35))
	for item in particles:
		var color: Color = item.color
		color.a = minf(1, item.life * 5)
		draw_rect(Rect2(item.p, Vector2.ONE * item.size), color)
