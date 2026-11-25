extends GdUnitTestSuite
## M20 acceptance: Smarana, the surge and the Exhausted flow (gameplay/player/devotion.gd, DESIGN §2, §9 M20).

var _exhausted_count: int = 0
var _recovered_count: int = 0
var _smarana_seen: Array[float] = []


func _on_exhausted() -> void:
	_exhausted_count += 1


func _on_recovered() -> void:
	_recovered_count += 1


func _on_smarana(v: float) -> void:
	_smarana_seen.append(v)


func _state() -> Node:
	return auto_free((load("res://core/game_state.gd") as GDScript).new()) as Node


func _setup() -> Dictionary:
	var bus: Node = auto_free((load("res://core/event_bus.gd") as GDScript).new()) as Node
	var gs: Node = _state()
	var p: Player = auto_free(Player.new()) as Player
	p.read_input = false
	p.event_bus = bus
	var d: Devotion = Devotion.new()
	d.event_bus = bus
	d.game_state = gs
	p.add_child(d)
	add_child(p)
	_exhausted_count = 0
	_recovered_count = 0
	_smarana_seen = []
	bus.connect("player_exhausted", _on_exhausted)
	bus.connect("player_recovered", _on_recovered)
	bus.connect("smarana_changed", _on_smarana)
	return {"bus": bus, "gs": gs, "p": p, "d": d}


func test_gain_spend_refill_clamp() -> void:
	var s: Dictionary = _setup()
	var d: Devotion = s["d"] as Devotion
	d.gain(150.0, "test")
	assert_float(d.value).is_equal_approx(100.0, 0.001)
	assert_bool(d.spend(30.0)).is_true()
	assert_float(d.value).is_equal_approx(70.0, 0.001)
	assert_bool(d.spend(80.0)).is_false()
	assert_float(d.value).is_equal_approx(70.0, 0.001)
	d.value = 0.0
	d.refill()
	assert_float(d.value).is_equal_approx(100.0, 0.001)
	assert_bool(_smarana_seen.size() > 0).is_true()


func test_hit_gives_two() -> void:
	var s: Dictionary = _setup()
	var d: Devotion = s["d"] as Devotion
	d.on_hit_landed()
	d.on_hit_landed()
	assert_float(d.value).is_equal_approx(4.0, 0.001)


func test_surge_requires_full_and_unlock_and_resets() -> void:
	var s: Dictionary = _setup()
	var d: Devotion = s["d"] as Devotion
	var gs: Node = s["gs"] as Node
	d.value = 100.0
	assert_bool(d.surge()).is_false()  # not unlocked
	gs.call("unlock", &"surge")
	d.value = 99.0
	assert_bool(d.surge()).is_false()  # not full
	d.value = 100.0
	assert_bool(d.surge()).is_true()
	assert_float(d.value).is_equal_approx(0.0, 0.001)


func test_surge_dissolves_weak_enemies_in_range() -> void:
	var s: Dictionary = _setup()
	var d: Devotion = s["d"] as Devotion
	(s["gs"] as Node).call("unlock", &"surge")
	var weak: EnemyBase = auto_free(EnemyBase.new()) as EnemyBase
	weak.enemy_id = &"guard_spear"
	add_child(weak)
	weak.position = Vector3(3, 0, 0)
	var far: EnemyBase = auto_free(EnemyBase.new()) as EnemyBase
	far.enemy_id = &"guard_spear"
	add_child(far)
	far.position = Vector3(10, 0, 0)
	var tough: EnemyBase = auto_free(EnemyBase.new()) as EnemyBase
	tough.enemy_id = &"kinkara"
	add_child(tough)
	tough.position = Vector3(2, 0, 0)
	d.value = 100.0
	assert_bool(d.surge()).is_true()
	assert_int(weak.state).is_equal(EnemyBase.State.DISSOLVE)
	assert_int(far.state).is_not_equal(EnemyBase.State.DISSOLVE)
	assert_int(tough.state).is_not_equal(EnemyBase.State.DISSOLVE)


func test_depletion_leads_to_recovery_at_shrine_with_full_health() -> void:
	var s: Dictionary = _setup()
	var d: Devotion = s["d"] as Devotion
	var p: Player = s["p"] as Player
	(s["gs"] as Node).set("last_shrine", {"pos": Vector3(12, 0, -7)})
	d.value = 80.0
	p.take_damage(1000)
	assert_bool(d.is_exhausted()).is_true()
	assert_int(_exhausted_count).is_equal(1)
	assert_int(_recovered_count).is_equal(0)
	assert_bool(p.read_input).is_false()
	d.tick(0.75)
	assert_bool(d.is_exhausted()).is_true()
	d.tick(0.8)
	assert_bool(d.is_exhausted()).is_false()
	assert_int(_recovered_count).is_equal(1)
	assert_int(p.get_health().value).is_equal(p.get_health().max_value)
	assert_float(p.global_position.distance_to(Vector3(12, 0, -7))).is_less(0.01)
	assert_float(d.value).is_equal_approx(0.0, 0.001)


func test_exhausted_shows_saffron_fade_and_ignores_damage() -> void:
	var s: Dictionary = _setup()
	var d: Devotion = s["d"] as Devotion
	var p: Player = s["p"] as Player
	p.take_damage(1000)
	d.tick(0.75)
	var rects: Array[Node] = d.find_children("*", "ColorRect", true, false)
	assert_int(rects.size()).is_equal(1)
	var c: Color = (rects[0] as ColorRect).color
	assert_float(c.a).is_equal_approx(0.5, 0.01)
	assert_float(c.r).is_equal_approx(Palette.SAFFRON.r, 0.01)
	p.take_damage(10)
	assert_int(p.get_health().value).is_equal(0)


func test_no_game_over_anywhere() -> void:
	var bus: Node = auto_free((load("res://core/event_bus.gd") as GDScript).new()) as Node
	for sig: Dictionary in bus.get_signal_list():
		var n: String = str(sig["name"]).to_lower()
		assert_bool(n.contains("game_over") or n.contains("gameover") or n.contains("died")).is_false()
	assert_bool(FileAccess.file_exists("res://ui/game_over.tscn")).is_false()
	assert_bool(FileAccess.file_exists("res://ui/game_over.gd")).is_false()
	var s: Dictionary = _setup()
	assert_bool((s["d"] as Devotion).has_signal(&"game_over")).is_false()
