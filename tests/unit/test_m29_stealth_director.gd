extends GdUnitTestSuite
## M29 acceptance tests: world/stealth_director.gd (DESIGN §9 M29, §3 Ch2).
## A guard entering ALERT on a player raises the alarm (0 calm, 1 suspicious, 2 alarm). Each sighting escalates by one
## level, up to 2. At level 2 guards within 15 m of the alarm position switch to chase it. The alarm decays to 0 after
## 12 s without sightings. Guards are fake Node3D stand-ins that record what the director asks of them.

const DirectorScript: GDScript = preload("res://world/stealth_director.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")

const IDLE: int = 0
const ALERT: int = 2
const CHASE: int = 3
const DISSOLVE: int = 6
const DECAY_TIME: float = 12.0
const DT: float = 0.1


class FakeGuard extends Node3D:
	var state: int = 0
	var target: Node3D = null
	var forced_state: int = -1
	var sees: bool = true

	func set_target(t: Node3D) -> void:
		target = t

	func force_state(s: int) -> void:
		state = s
		forced_state = s

	func can_see(_t: Node3D) -> bool:
		return sees


var _alarms: Array[Vector3] = []
var _levels: Array[int] = []


func before_test() -> void:
	_alarms.clear()
	_levels.clear()


func _on_alarm(pos: Vector3) -> void:
	_alarms.append(pos)


func _on_level(level: int) -> void:
	_levels.append(level)


func _make_director() -> StealthDirector:
	var director: StealthDirector = DirectorScript.new() as StealthDirector
	auto_free(director)
	add_child(director)
	var bus: Node = auto_free(BusScript.new()) as Node
	director.event_bus = bus
	bus.connect("alarm_raised", Callable(self, "_on_alarm"))
	director.alarm_changed.connect(Callable(self, "_on_level"))
	return director


func _make_guard(pos: Vector3, director: StealthDirector) -> FakeGuard:
	var g: FakeGuard = auto_free(FakeGuard.new()) as FakeGuard
	add_child(g)
	g.position = pos
	director.register_guard(g)
	return g


func _make_player(pos: Vector3) -> Node3D:
	var p: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(p)
	p.position = pos
	p.add_to_group(&"player")
	return p


## A sighting: the guard enters ALERT for one tick, then goes back to IDLE without a tick (zero delta).
func _sight(g: FakeGuard, director: StealthDirector, dt: float = DT) -> void:
	g.state = ALERT
	director.tick(dt)
	g.state = IDLE
	director.tick(0.0)


func test_starts_calm() -> void:
	var director: StealthDirector = _make_director()
	assert_int(director.alarm_level).is_equal(0)
	assert_int(director.guard_count()).is_equal(0)


func test_guard_alert_on_player_raises_suspicious_and_emits() -> void:
	var director: StealthDirector = _make_director()
	var g: FakeGuard = _make_guard(Vector3.ZERO, director)
	_make_player(Vector3(5, 0, 0))
	g.state = ALERT
	director.tick(DT)
	assert_int(director.alarm_level).is_equal(1)
	assert_int(_alarms.size()).is_equal(1)
	assert_float(_alarms[0].x).is_equal_approx(5.0, 0.001)
	assert_int(_levels.size()).is_equal(1)
	assert_int(_levels[0]).is_equal(1)


func test_alert_without_player_in_sight_is_ignored() -> void:
	var director: StealthDirector = _make_director()
	var g: FakeGuard = _make_guard(Vector3.ZERO, director)
	_make_player(Vector3(5, 0, 0))
	g.sees = false
	g.state = ALERT
	director.tick(DT)
	assert_int(director.alarm_level).is_equal(0)
	assert_int(_alarms.size()).is_equal(0)


func test_alert_with_no_player_in_group_is_ignored() -> void:
	var director: StealthDirector = _make_director()
	var g: FakeGuard = _make_guard(Vector3.ZERO, director)
	g.state = ALERT
	director.tick(DT)
	assert_int(director.alarm_level).is_equal(0)


func test_sustained_alert_counts_as_one_sighting() -> void:
	var director: StealthDirector = _make_director()
	var g: FakeGuard = _make_guard(Vector3.ZERO, director)
	_make_player(Vector3(5, 0, 0))
	g.state = ALERT
	director.tick(DT)
	director.tick(DT)
	director.tick(DT)
	assert_int(director.alarm_level).is_equal(1)
	assert_int(_alarms.size()).is_equal(1)


func test_second_sighting_escalates_to_alarm() -> void:
	var director: StealthDirector = _make_director()
	var g: FakeGuard = _make_guard(Vector3.ZERO, director)
	_make_player(Vector3(5, 0, 0))
	_sight(g, director)
	assert_int(director.alarm_level).is_equal(1)
	_sight(g, director)
	assert_int(director.alarm_level).is_equal(2)
	_sight(g, director)
	assert_int(director.alarm_level).is_equal(2)
	assert_int(_levels.size()).is_equal(2)
	assert_int(_levels[1]).is_equal(2)


func test_alarm_decays_to_zero_after_12_seconds() -> void:
	var director: StealthDirector = _make_director()
	var g: FakeGuard = _make_guard(Vector3.ZERO, director)
	_make_player(Vector3(5, 0, 0))
	_sight(g, director)
	for i: int in range(115):
		director.tick(0.1)
	assert_int(director.alarm_level).is_equal(1)
	for i: int in range(10):
		director.tick(0.1)
	assert_int(director.alarm_level).is_equal(0)
	assert_int(_levels[_levels.size() - 1]).is_equal(0)


func test_sighting_resets_decay_timer() -> void:
	var director: StealthDirector = _make_director()
	var g: FakeGuard = _make_guard(Vector3.ZERO, director)
	_make_player(Vector3(5, 0, 0))
	_sight(g, director)
	_sight(g, director)
	for i: int in range(80):
		director.tick(0.1)
	assert_int(director.alarm_level).is_equal(2)
	_sight(g, director)
	for i: int in range(80):
		director.tick(0.1)
	assert_int(director.alarm_level).is_equal(2)
	for i: int in range(50):
		director.tick(0.1)
	assert_int(director.alarm_level).is_equal(0)


func test_alarm_level_2_switches_nearby_guards_to_chase_alarm_position() -> void:
	var director: StealthDirector = _make_director()
	var a: FakeGuard = _make_guard(Vector3(0, 0, 0), director)
	var b: FakeGuard = _make_guard(Vector3(10, 0, 0), director)
	var c: FakeGuard = _make_guard(Vector3(30, 0, 0), director)
	_make_player(Vector3(5, 0, 0))
	_sight(a, director)
	assert_int(b.forced_state).is_equal(-1)
	_sight(a, director)
	assert_int(director.alarm_level).is_equal(2)
	assert_int(b.forced_state).is_equal(CHASE)
	assert_object(b.target).is_not_null()
	assert_float(b.target.global_position.x).is_equal_approx(5.0, 0.001)
	assert_float(b.target.global_position.z).is_equal_approx(0.0, 0.001)
	assert_int(c.forced_state).is_equal(-1)


func test_guard_range_is_15_metres_from_alarm() -> void:
	var director: StealthDirector = _make_director()
	var a: FakeGuard = _make_guard(Vector3(0, 0, 0), director)
	var near: FakeGuard = _make_guard(Vector3(5 + 14.9, 0, 0), director)
	var far: FakeGuard = _make_guard(Vector3(5 + 15.5, 0, 0), director)
	_make_player(Vector3(5, 0, 0))
	_sight(a, director)
	_sight(a, director)
	assert_int(near.forced_state).is_equal(CHASE)
	assert_int(far.forced_state).is_equal(-1)


func test_dissolving_guard_is_not_switched_to_chase() -> void:
	var director: StealthDirector = _make_director()
	var a: FakeGuard = _make_guard(Vector3(0, 0, 0), director)
	var b: FakeGuard = _make_guard(Vector3(10, 0, 0), director)
	b.state = DISSOLVE
	_make_player(Vector3(5, 0, 0))
	_sight(a, director)
	_sight(a, director)
	assert_int(b.forced_state).is_equal(-1)


func test_unregistered_guard_is_ignored() -> void:
	var director: StealthDirector = _make_director()
	var g: FakeGuard = _make_guard(Vector3.ZERO, director)
	director.unregister_guard(g)
	assert_int(director.guard_count()).is_equal(0)
	_make_player(Vector3(5, 0, 0))
	g.state = ALERT
	director.tick(DT)
	assert_int(director.alarm_level).is_equal(0)


func test_freed_guard_is_pruned_without_error() -> void:
	var director: StealthDirector = _make_director()
	var g: FakeGuard = FakeGuard.new()
	add_child(g)
	director.register_guard(g)
	assert_int(director.guard_count()).is_equal(1)
	g.free()
	director.tick(DT)
	assert_int(director.guard_count()).is_equal(0)


func test_guard_already_alert_at_registration_counts_as_sighting() -> void:
	var director: StealthDirector = _make_director()
	var g: FakeGuard = FakeGuard.new()
	add_child(g)
	auto_free(g)
	g.state = ALERT
	_make_player(Vector3(5, 0, 0))
	director.register_guard(g)
	director.tick(DT)
	assert_int(director.alarm_level).is_equal(1)


func test_decay_is_frame_rate_independent() -> void:
	for dt: float in [1.0 / 30.0, 1.0 / 60.0]:
		var director: StealthDirector = _make_director()
		var g: FakeGuard = _make_guard(Vector3.ZERO, director)
		_make_player(Vector3(5, 0, 0))
		g.state = ALERT
		director.tick(dt)
		var steps_first: int = roundi(11.9 / dt)
		for i: int in range(steps_first):
			director.tick(dt)
		assert_int(director.alarm_level).is_equal(1)
		var steps_second: int = roundi(0.2 / dt)
		for i: int in range(steps_second):
			director.tick(dt)
		assert_int(director.alarm_level).is_equal(0)
