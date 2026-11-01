extends Control

var world: Node2D
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func label_at(at: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.player):
		return
	var w := get_viewport_rect().size.x
	var h := get_viewport_rect().size.y
	draw_rect(Rect2(18, 16, 254, 79), Color(0.035, 0.06, 0.10, 0.9))
	draw_rect(Rect2(18, 16, 3, 79), Color("83d9c5"))
	label_at(Vector2(33, 38), "ASHWAKE / THE LAST RELAY", 14, Color("d8e8db"))
	for i in range(world.player.MAX_HEALTH):
		draw_rect(Rect2(33 + i * 26, 49, 20, 9), Color("87ddc3") if i < world.player.health else Color("2c3a47"))
	label_at(Vector2(33, 80), "DODGE", 10, Color("99adb7"))
	draw_rect(Rect2(82, 72, 99, 5), Color("293b49"))
	draw_rect(Rect2(82, 72, 99 * (1.0 - world.player.dodge_cooldown / 0.62), 5), Color("e4ad71"))
	# Same attack action on keyboard and touch; B is a timed second tap.
	var combo = world.player.combo
	var combo_label := "TAP ATK AGAIN TO CHAIN A > B"
	if not combo.current_attack.is_empty():
		combo_label = ("B / RISING CUT" if combo.current_attack == &"attack_b" else "A / FORWARD CUT") + "  /  " + String(combo.phase()).to_upper()
	label_at(Vector2(33, 105), combo_label, 10, Color("c8cfa9"))
	label_at(Vector2(w - 249, 35), "RELAY SEALS  %d / 3" % world.seals.size(), 16, Color("ead8b5"))
	label_at(Vector2(w - 249, 55), "Reach the eastern relay  >", 12, Color("9bb1b9"))
	var seconds := int(world.elapsed)
	label_at(Vector2(w - 96, 79), "%02d:%02d" % [seconds / 60, seconds % 60], 13, Color("9bb1b9"))
	if not world.won:
		draw_rect(Rect2(18, h - 42, w - 36, 26), Color(0.03, 0.05, 0.085, 0.87))
		label_at(Vector2(31, h - 24), "A/D  MOVE    SPACE  JUMP x2    J / X  TAP A > B    SHIFT / K  DODGE    E  RELAY    R  RESTART", 12, Color("b4c8c6"))
	if world.message_time > 0 and not world.won:
		var text: String = world.message
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_rect(Rect2(w * 0.5 - width * 0.5 - 18, 111, width + 36, 35), Color(0.035, 0.055, 0.09, 0.9))
		label_at(Vector2((w - width) * 0.5, 134), text, 16, Color("f3d7a5"))
	if world.player.dead:
		var death_fade := clampf((world.player.death_time - 0.15) / 0.30, 0, 1)
		draw_rect(Rect2(0, 0, w, h), Color(0.025, 0.04, 0.07, 0.65 * death_fade))
		label_at(Vector2(w / 2 - 121, h / 2), "THE SIGNAL FALTERS", 23, Color("e6ba92"))
		label_at(Vector2(w / 2 - 127, h / 2 + 31), "Returning to the last relay marker…", 14, Color("b4c8c6"))
	if world.won:
		draw_rect(Rect2(0, 0, w, h), Color(0.025, 0.04, 0.065, 0.80))
		draw_rect(Rect2(w / 2 - 229, h / 2 - 101, 458, 215), Color("132b35"))
		draw_rect(Rect2(w / 2 - 229, h / 2 - 101, 458, 3), Color("87ddc3"))
		label_at(Vector2(w / 2 - 168, h / 2 - 46), "THE RELAY LIVES AGAIN", 26, Color("bff3d6"))
		label_at(Vector2(w / 2 - 160, h / 2 - 9), "Three broken sentries. One surviving signal.", 15, Color("a6bfc1"))
		label_at(Vector2(w / 2 - 94, h / 2 + 31), "TIME  %02d:%02d  /  FALLS  %d" % [seconds / 60, seconds % 60, world.deaths], 14, Color("efc996"))
		label_at(Vector2(w / 2 - 78, h / 2 + 80), "Press R to run again", 17, Color("e9e8d4"))
	if get_tree().paused:
		draw_rect(Rect2(0, 0, w, h), Color(0.025, 0.04, 0.07, 0.8))
		label_at(Vector2(w / 2 - 79, h / 2), "PAUSED / ESC", 22, Color("bff3d6"))
