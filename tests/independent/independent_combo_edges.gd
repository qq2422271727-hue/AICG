extends SceneTree

var checks := 0
var failures: Array[String] = []
var Combo = load("res://scripts/combo_machine.gd")

func _initialize() -> void:
	_run.call_deferred()

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func fresh():
	var c = Combo.new()
	c.press_attack()
	return c

func signature(c) -> Array:
	return [c.current_attack, c.attack_serial, c.hit_confirmed, c.hit_targets.size(), c.phase()]

func _run() -> void:
	# Independent partition-invariance checks around cancel/buffer/end boundaries.
	for hit in [false, true]:
		for input_at in [.0, .02, .0269, .027, .0271, .049, .05, .0929, .093, .0931, .1, .1669, .167, .2329, .233, .2799, .28, .2999]:
			for duration in [.0001, .02, .066, .117, .14, .3, .8]:
				var bulk = fresh()
				var split = fresh()
				for c in [bulk, split]:
					c.advance(input_at)
					# Explicit condition injection isolates scheduler boundaries, not enemy physics.
					c.hit_confirmed = hit
					c.press_attack()
				bulk.advance(duration)
				for i in range(101):
					split.advance(duration / 101.0)
				verify(signature(bulk) == signature(split) and absf(bulk.elapsed - split.elapsed) < .000001 and absf(bulk.buffer_left - split.buffer_left) < .000001, "partition invariant hit=%s press=%s advance=%s" % [hit,input_at,duration])
	for elapsed in [.0,.049,.05,.166,.167,.233,.279,.28,.299]:
		var c = fresh()
		c.advance(elapsed)
		c.press_attack(true)
		var before := signature(c)
		var clock: float = c.elapsed
		var buffer: float = c.buffer_left
		for i in range(100):
			c.advance(.013, true)
		verify(signature(c) == before and c.elapsed == clock and c.buffer_left == buffer, "freeze exact across 100 steps at %s" % elapsed)
	for hit in [false,true]:
		var c = fresh()
		c.advance(.1)
		c.hit_confirmed = hit
		c.press_attack()
		c.interrupt(&"death", true)
		for i in range(50):
			c.press_attack(i%2 == 0)
			c.advance(.02)
		verify(c.current_attack.is_empty() and c.buffer_left == 0 and c.hit_targets.is_empty(), "dead locked press spam leaves no stale intent hit=%s" % hit)
		c.reset()
		c.advance(1)
		verify(c.current_attack.is_empty() and c.attack_serial == 0 and not c.blocked, "reset does not auto attack from dead input")
	for attack in [&"attack_a", &"attack_b"]:
		var c = fresh()
		c.current_attack = attack
		c.elapsed = .1
		var right: Rect2 = c.hitbox(Vector2(0,100),1)
		var left: Rect2 = c.hitbox(Vector2(0,100),-1)
		verify(right.size == left.size and is_equal_approx(right.position.x,-left.end.x) and right.position.y == left.position.y, "%s exact mirrored horizontal edges" % attack)
		verify(not c.register_hit(0) and not c.register_hit(-1), "%s invalid target ids ignored" % attack)
		for target in range(1,51):
			verify(c.register_hit(target) and not c.register_hit(target), "%s unique target %s accepted exactly once" % [attack,target])
	print("INDEPENDENT_COMBO_QA: %d/%d passed" % [checks-failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
