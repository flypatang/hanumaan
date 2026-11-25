extends GdUnitTestSuite
## M40 acceptance tests: the Surasa size puzzle and the leap gates (DESIGN §3 Ch1). Hanuman must grow three times
## (forced steps through SizeShift.force_size) and then SHRINK inside a 1.5 s window. A late shrink only resets it.

const GameStateScript: GDScript = preload("res://core/game_state.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")

var _mouth: Array[int] = []
var _opened: int = 0
var _failed: int = 0
var _solved: int = 0


func before_test() -> void:
	_mouth.clear()
	_opened = 0
	_failed = 0
	_solved = 0


func _make_shift() -> SizeShift:
	var holder: Node3D = Node3D.new()
	var pivot: Node3D = Node3D.new()
	pivot.name = "Pivot"
	holder.add_child(pivot)
	var shift: SizeShift = SizeShift.new()
	shift.event_bus = auto_free(BusScript.new()) as Node
	holder.add_child(shift)
	add_child(holder)
	auto_free(holder)
	return shift


func _make_puzzle(shift: SizeShift) -> ChapterFlow.SurasaPuzzle:
	var puzzle: ChapterFlow.SurasaPuzzle = ChapterFlow.SurasaPuzzle.new()
	puzzle.mouth_changed.connect(func(level: int) -> void: _mouth.append(level))
	puzzle.window_opened.connect(func() -> void: _opened += 1)
	puzzle.window_failed.connect(func() -> void: _failed += 1)
	puzzle.solved.connect(func() -> void: _solved += 1)
	puzzle.begin(shift)
	return puzzle


func test_three_grows_then_a_shrink_in_the_window_solves_it() -> void:
	var shift: SizeShift = _make_shift()
	var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(shift)
	assert_int(shift.get_size()).is_equal(SizeShift.SIZE.NORMAL)
	assert_bool(puzzle.on_grow()).is_true()
	assert_int(shift.get_size()).is_equal(SizeShift.SIZE.LARGE)
	assert_bool(puzzle.on_grow()).is_true()
	assert_int(shift.get_size()).is_equal(SizeShift.SIZE.GIANT)
	assert_int(_opened).is_equal(0)
	assert_bool(puzzle.on_grow()).is_true()
	assert_int(_opened).is_equal(1)
	assert_int(puzzle.phase).is_equal(ChapterFlow.SurasaPuzzle.Phase.WINDOW)
	puzzle.tick(1.0)
	assert_bool(puzzle.on_shrink()).is_true()
	assert_int(_solved).is_equal(1)
	assert_int(shift.get_size()).is_equal(SizeShift.SIZE.SMALL)
	assert_array(_mouth).contains_exactly([0, 1, 2, 3])


func test_the_mouth_widens_with_every_grow() -> void:
	var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(_make_shift())
	puzzle.on_grow()
	puzzle.on_grow()
	assert_int(puzzle.grows).is_equal(2)
	assert_array(_mouth).contains_exactly([0, 1, 2])


func test_shrinking_before_the_third_grow_does_nothing() -> void:
	var shift: SizeShift = _make_shift()
	var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(shift)
	puzzle.on_grow()
	assert_bool(puzzle.on_shrink()).is_false()
	assert_int(puzzle.grows).is_equal(1)
	assert_int(_solved).is_equal(0)
	assert_int(shift.get_size()).is_equal(SizeShift.SIZE.LARGE)


func test_a_late_shrink_resets_the_puzzle() -> void:
	var shift: SizeShift = _make_shift()
	var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(shift)
	for i: int in 3:
		puzzle.on_grow()
	puzzle.tick(1.6)
	assert_int(_failed).is_equal(1)
	assert_int(puzzle.grows).is_equal(0)
	assert_int(puzzle.phase).is_equal(ChapterFlow.SurasaPuzzle.Phase.GROWING)
	assert_int(shift.get_size()).is_equal(SizeShift.SIZE.NORMAL)
	assert_bool(puzzle.on_shrink()).is_false()
	for i: int in 3:
		puzzle.on_grow()
	assert_bool(puzzle.on_shrink()).is_true()
	assert_int(_solved).is_equal(1)


func test_the_window_is_the_same_at_30_and_60_fps() -> void:
	for step: float in [1.0 / 30.0, 1.0 / 60.0]:
		var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(_make_shift())
		for i: int in 3:
			puzzle.on_grow()
		var elapsed: float = 0.0
		while elapsed < 1.4:
			puzzle.tick(step)
			elapsed += step
		assert_int(puzzle.phase).is_equal(ChapterFlow.SurasaPuzzle.Phase.WINDOW)
		puzzle.tick(0.15)
		assert_int(puzzle.phase).is_equal(ChapterFlow.SurasaPuzzle.Phase.GROWING)


func test_grow_is_ignored_once_the_window_is_open_or_solved() -> void:
	var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(_make_shift())
	for i: int in 3:
		puzzle.on_grow()
	assert_bool(puzzle.on_grow()).is_false()
	puzzle.on_shrink()
	assert_bool(puzzle.on_grow()).is_false()
	assert_bool(puzzle.is_active()).is_false()


# --- the gates on a real leap runtime -------------------------------------------------------------------------

func _make_leap() -> Array:
	var gs: Node = auto_free(GameStateScript.new()) as Node
	var rt: LevelRuntime = LevelRuntime.new()
	rt.music_enabled = false
	rt.game_state = gs
	rt.event_bus = auto_free(BusScript.new()) as Node
	add_child(rt)
	auto_free(rt)
	assert_int(rt.load_level(&"ocean_leap")).is_equal(OK)
	var flow: ChapterFlow = ChapterFlow.new()
	flow.autosave = false
	flow.game_state = gs
	flow.event_bus = rt.event_bus
	add_child(flow)
	auto_free(flow)
	flow.bind_leap(rt)
	return [rt, flow, gs]


func test_mainaka_gate_plays_her_dialogue_then_flies_on() -> void:
	var parts: Array = _make_leap()
	var rt: LevelRuntime = parts[0] as LevelRuntime
	var leap: LeapController = rt.leap()
	leap.paused_at_gate = true
	leap.gate_reached.emit(&"mainaka")
	assert_bool(rt.dialogue_box().is_playing()).is_true()
	rt.dialogue_box().finished.emit(&"ch1_mainaka")
	assert_bool(leap.paused_at_gate).is_false()


func test_surasa_gate_runs_the_puzzle_and_unlocks_shrink() -> void:
	var parts: Array = _make_leap()
	var rt: LevelRuntime = parts[0] as LevelRuntime
	var flow: ChapterFlow = parts[1] as ChapterFlow
	var gs: Node = parts[2] as Node
	var leap: LeapController = rt.leap()
	leap.paused_at_gate = true
	assert_bool(gs.call("is_unlocked", &"shrink") as bool).is_false()
	leap.gate_reached.emit(&"surasa")
	assert_bool(rt.dialogue_box().is_playing()).is_true()
	rt.dialogue_box().finished.emit(&"ch1_surasa")
	assert_bool(flow.puzzle().is_active()).is_true()
	assert_bool(leap.paused_at_gate).is_true()
	for i: int in 3:
		flow.puzzle().on_grow()
	flow.tick_leap(0.5)
	assert_bool(flow.puzzle().on_shrink()).is_true()
	assert_bool(rt.dialogue_box().is_playing()).is_true()
	rt.dialogue_box().finished.emit(&"ch1_surasa")
	assert_bool(gs.call("is_unlocked", &"shrink") as bool).is_true()
	assert_bool(leap.paused_at_gate).is_false()


func test_simhika_gate_engages_the_boss_after_the_dialogue() -> void:
	var parts: Array = _make_leap()
	var rt: LevelRuntime = parts[0] as LevelRuntime
	var leap: LeapController = rt.leap()
	leap.paused_at_gate = true
	leap.gate_reached.emit(&"simhika")
	var boss: BossSimhika = rt.get_node("BossSimhika") as BossSimhika
	assert_bool(boss.active).is_false()
	rt.dialogue_box().finished.emit(&"ch1_simhika")
	assert_bool(boss.active).is_true()
	boss.free()


func test_a_failed_flight_heals_and_never_ends_the_run() -> void:
	var parts: Array = _make_leap()
	var rt: LevelRuntime = parts[0] as LevelRuntime
	var leap: LeapController = rt.leap()
	leap.distance = 300.0
	leap.health.damage(1000, null)
	assert_int(leap.health.value).is_equal(leap.health.max_value)
	assert_float(leap.distance).is_equal_approx(220.0, 0.01)
