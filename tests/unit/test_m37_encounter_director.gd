extends GdUnitTestSuite
## M37 acceptance tests: world/encounter_director.gd (DESIGN §9 M37).
## Spawns come from a level root's "Spawns" markers carrying meta wave (int) and chapter (int). start(chapter) begins
## wave 0. When every enemy of a wave is defeated (EventBus.enemy_defeated), the director waits 2 s, then starts the next
## wave. Boss kinds ("boss_*") emit boss_started / boss_finished. waves_completed fires when the last wave ends.
## Enemies are fake Node3D stand-ins made by an injected factory, and the bus is a real EventBus instance.

const DirectorScript: GDScript = preload("res://world/encounter_director.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")

const GAP: float = 2.0
const EPS: float = 0.001

var _made_kinds: Array[String] = []
var _boss_started: Array[Node3D] = []
var _boss_finished: Array[Node3D] = []
var _completed_count: int = 0


func before_test() -> void:
	_made_kinds.clear()
	_boss_started.clear()
	_boss_finished.clear()
	_completed_count = 0


func _make_enemy(kind: String) -> Node3D:
	_made_kinds.append(kind)
	var node: Node3D = Node3D.new()
	node.set_meta("kind", kind)
	return node


func _on_boss_started(enemy: Node3D) -> void:
	_boss_started.append(enemy)


func _on_boss_finished(enemy: Node3D) -> void:
	_boss_finished.append(enemy)


func _on_completed() -> void:
	_completed_count += 1


## Builds a level root with a "Spawns" group. Each entry: {kind, wave, chapter, pos}.
func _make_level(entries: Array[Dictionary]) -> Node3D:
	var root: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(root)
	var spawns: Node3D = Node3D.new()
	spawns.name = "Spawns"
	root.add_child(spawns)
	for i: int in range(entries.size()):
		var entry: Dictionary = entries[i]
		var marker: Marker3D = Marker3D.new()
		marker.name = "m%d" % i
		marker.position = entry.get("pos", Vector3.ZERO) as Vector3
		marker.set_meta("kind", str(entry.get("kind", "guard_spear")))
		marker.set_meta("wave", (entry.get("wave", 0) as int))
		marker.set_meta("chapter", (entry.get("chapter", 1) as int))
		spawns.add_child(marker)
	return root


func _make_director(level: Node3D, bus: Node) -> EncounterDirector:
	var director: EncounterDirector = DirectorScript.new() as EncounterDirector
	add_child(director)
	auto_free(director)
	director.boss_started.connect(Callable(self, "_on_boss_started"))
	director.boss_finished.connect(Callable(self, "_on_boss_finished"))
	director.waves_completed.connect(Callable(self, "_on_completed"))
	director.configure(level, Callable(self, "_make_enemy"))
	director.connect_to(bus)
	return director


func _make_bus() -> Node:
	var bus: Node = auto_free(BusScript.new()) as Node
	return bus


func _defeat(bus: Node, kind: String) -> void:
	bus.emit_signal("enemy_defeated", StringName(kind), Vector3.ZERO)


func _two_wave_chapter() -> Array[Dictionary]:
	return [
		{"kind": "guard_spear", "wave": 0, "chapter": 4, "pos": Vector3(1, 0, 2)},
		{"kind": "guard_archer", "wave": 0, "chapter": 4, "pos": Vector3(3, 0, 4)},
		{"kind": "kinkara", "wave": 1, "chapter": 4, "pos": Vector3(5, 0, 6)},
	]


func test_start_spawns_only_wave_zero_of_the_chapter() -> void:
	var entries: Array[Dictionary] = _two_wave_chapter()
	entries.append({"kind": "guard_spear", "wave": 0, "chapter": 5})
	var level: Node3D = _make_level(entries)
	var bus: Node = _make_bus()
	var director: EncounterDirector = _make_director(level, bus)
	director.start(4)
	assert_array(_made_kinds).has_size(2)
	assert_str(_made_kinds[0]).is_equal("guard_spear")
	assert_str(_made_kinds[1]).is_equal("guard_archer")
	assert_int(director.current_wave()).is_equal(0)
	assert_int(director.living_count()).is_equal(2)


func test_spawned_enemies_sit_at_marker_positions() -> void:
	var level: Node3D = _make_level(_two_wave_chapter())
	var bus: Node = _make_bus()
	var director: EncounterDirector = _make_director(level, bus)
	director.start(4)
	var found: int = 0
	for child: Node in level.get_children():
		if child is Node3D and child.has_meta("kind"):
			found += 1
	assert_int(found).is_equal(2)
	var spear: Node3D = null
	for child: Node in level.get_children():
		if child.has_meta("kind") and str(child.get_meta("kind")) == "guard_spear":
			spear = child as Node3D
	assert_object(spear).is_not_null()
	assert_float((spear as Node3D).position.x).is_equal_approx(1.0, EPS)
	assert_float((spear as Node3D).position.z).is_equal_approx(2.0, EPS)


func test_next_wave_waits_two_seconds_after_last_enemy_defeated() -> void:
	var level: Node3D = _make_level(_two_wave_chapter())
	var bus: Node = _make_bus()
	var director: EncounterDirector = _make_director(level, bus)
	director.start(4)
	_defeat(bus, "guard_spear")
	_defeat(bus, "guard_archer")
	director.advance(1.9)
	assert_int(director.current_wave()).is_equal(0)
	assert_array(_made_kinds).has_size(2)
	director.advance(0.2)
	assert_int(director.current_wave()).is_equal(1)
	assert_array(_made_kinds).has_size(3)
	assert_str(_made_kinds[2]).is_equal("kinkara")


func test_wave_does_not_end_while_an_enemy_is_alive() -> void:
	var level: Node3D = _make_level(_two_wave_chapter())
	var bus: Node = _make_bus()
	var director: EncounterDirector = _make_director(level, bus)
	director.start(4)
	_defeat(bus, "guard_spear")
	director.advance(10.0)
	assert_int(director.current_wave()).is_equal(0)
	assert_int(director.living_count()).is_equal(1)
	assert_array(_made_kinds).has_size(2)


func test_defeat_of_unrelated_kind_is_ignored() -> void:
	var level: Node3D = _make_level(_two_wave_chapter())
	var bus: Node = _make_bus()
	var director: EncounterDirector = _make_director(level, bus)
	director.start(4)
	_defeat(bus, "kinkara")
	_defeat(bus, "guard_spear")
	_defeat(bus, "guard_spear")
	director.advance(10.0)
	assert_int(director.living_count()).is_equal(1)
	assert_int(director.current_wave()).is_equal(0)


func test_waves_completed_fires_once_when_last_wave_ends() -> void:
	var level: Node3D = _make_level(_two_wave_chapter())
	var bus: Node = _make_bus()
	var director: EncounterDirector = _make_director(level, bus)
	director.start(4)
	_defeat(bus, "guard_spear")
	_defeat(bus, "guard_archer")
	director.advance(GAP)
	assert_int(_completed_count).is_equal(0)
	_defeat(bus, "kinkara")
	assert_int(_completed_count).is_equal(1)
	assert_bool(director.is_finished()).is_true()
	director.advance(10.0)
	_defeat(bus, "kinkara")
	assert_int(_completed_count).is_equal(1)


func test_chapter_without_spawns_completes_immediately() -> void:
	var level: Node3D = _make_level(_two_wave_chapter())
	var bus: Node = _make_bus()
	var director: EncounterDirector = _make_director(level, bus)
	director.start(9)
	assert_int(_completed_count).is_equal(1)
	assert_array(_made_kinds).is_empty()


func test_boss_wave_emits_boss_started_and_boss_finished() -> void:
	var entries: Array[Dictionary] = [
		{"kind": "guard_spear", "wave": 0, "chapter": 5},
		{"kind": "boss_akshaya", "wave": 1, "chapter": 5, "pos": Vector3(7, 0, 8)},
	]
	var level: Node3D = _make_level(entries)
	var bus: Node = _make_bus()
	var director: EncounterDirector = _make_director(level, bus)
	director.start(5)
	_defeat(bus, "guard_spear")
	director.advance(GAP)
	assert_int(_boss_started.size()).is_equal(1)
	assert_object(_boss_started[0]).is_not_null()
	assert_str(str(_boss_started[0].get_meta("kind"))).is_equal("boss_akshaya")
	assert_int(_boss_finished.size()).is_equal(0)
	_defeat(bus, "boss_akshaya")
	assert_int(_boss_finished.size()).is_equal(1)
	assert_object(_boss_finished[0]).is_same(_boss_started[0])
	assert_int(_completed_count).is_equal(1)


func test_non_boss_kinds_emit_no_boss_signals() -> void:
	var level: Node3D = _make_level(_two_wave_chapter())
	var bus: Node = _make_bus()
	var director: EncounterDirector = _make_director(level, bus)
	director.start(4)
	_defeat(bus, "guard_spear")
	_defeat(bus, "guard_archer")
	director.advance(GAP)
	_defeat(bus, "kinkara")
	assert_int(_boss_started.size()).is_equal(0)
	assert_int(_boss_finished.size()).is_equal(0)


func test_timing_is_independent_of_how_delta_is_split() -> void:
	var level_a: Node3D = _make_level(_two_wave_chapter())
	var bus_a: Node = _make_bus()
	var director_a: EncounterDirector = _make_director(level_a, bus_a)
	director_a.start(4)
	_defeat(bus_a, "guard_spear")
	_defeat(bus_a, "guard_archer")
	for _i: int in range(25):
		director_a.advance(0.1)
	assert_int(director_a.current_wave()).is_equal(1)
	assert_int(director_a.living_count()).is_equal(1)
