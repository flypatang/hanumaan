extends GdUnitTestSuite
## M40 acceptance tests: the Surasa trial and the leap gates (DESIGN §3 Ch1). Redesigned 2026-11-27: the player grows
## and shrinks freely, Surasa opens one step wider than Hanuman, bites if he lingers, and is tricked by shrinking
## once her jaws are fully open, then darting in and out before they close. No step can fail the run.

const GameStateScript: GDScript = preload("res://core/game_state.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")

var _states: Array[StringName] = []
var _solved: int = 0


func before_test() -> void:
	_states.clear()
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
	puzzle.state_changed.connect(func(state: StringName) -> void: _states.append(state))
	puzzle.solved.connect(func() -> void: _solved += 1)
	puzzle.begin(shift)
	return puzzle


func _run(puzzle: ChapterFlow.SurasaPuzzle, seconds: float, step: float = 1.0 / 60.0) -> void:
	var t: float = 0.0
	while t < seconds - 0.00001:
		puzzle.tick(step)
		t += step


## Grows to `growth` and waits until her jaws are fully open (before her bite).
func _bait(puzzle: ChapterFlow.SurasaPuzzle, growth: int) -> void:
	while puzzle.growth < growth:
		puzzle.on_grow()
	_run(puzzle, float(growth) / ChapterFlow.SurasaPuzzle.OPEN_SPEED + 0.1)


func test_the_trick_solves_it() -> void:
	var shift: SizeShift = _make_shift()
	var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(shift)
	assert_int(shift.get_size()).is_equal(SizeShift.SIZE.GIANT)
	_bait(puzzle, 3)
	assert_bool(puzzle.is_fully_open()).is_true()
	assert_float(shift.get_bonus_scale()).is_greater(1.0)
	assert_bool(puzzle.on_shrink()).is_true()
	assert_int(shift.get_size()).is_equal(SizeShift.SIZE.SMALL)
	assert_float(shift.get_bonus_scale()).is_equal(1.0)
	assert_bool(puzzle.on_dart()).is_true()
	assert_int(puzzle.phase).is_equal(ChapterFlow.SurasaPuzzle.Phase.INSIDE)
	_run(puzzle, 0.5)
	assert_bool(puzzle.on_dart()).is_true()
	assert_int(_solved).is_equal(1)
	assert_bool(puzzle.is_active()).is_false()
	assert_array(_states).contains([&"opening", &"open", &"tiny", &"inside"])


func test_surasa_always_opens_one_step_wider_than_hanuman() -> void:
	var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(_make_shift())
	for growth: int in [2, 3, 4]:
		_bait(puzzle, growth)
		assert_float(puzzle.mouth).is_equal_approx(float(growth + 1), 0.001)
	assert_bool(puzzle.on_grow()).is_false()  # MAX_GROWTH reached
	assert_int(puzzle.growth).is_equal(ChapterFlow.SurasaPuzzle.MAX_GROWTH)


func test_lingering_gets_bitten_and_the_trial_resets() -> void:
	var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(_make_shift())
	_bait(puzzle, 2)
	_run(puzzle, ChapterFlow.SurasaPuzzle.WINDUP_DELAY + 0.05)
	assert_bool(_states.has(&"windup")).is_true()
	assert_float(puzzle.windup_fraction()).is_greater(0.0)
	_run(puzzle, ChapterFlow.SurasaPuzzle.WINDUP_TIME)
	assert_bool(_states.has(&"gulped")).is_true()
	assert_int(puzzle.gulps).is_equal(1)
	assert_int(puzzle.growth).is_equal(1)
	assert_float(puzzle.mouth).is_less(2.0)  # closed, and already opening again for growth 1
	assert_bool(puzzle.is_active()).is_true()


func test_growing_again_cancels_the_bite() -> void:
	var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(_make_shift())
	_bait(puzzle, 2)
	_run(puzzle, ChapterFlow.SurasaPuzzle.WINDUP_DELAY + 0.5)
	assert_float(puzzle.windup_fraction()).is_greater(0.0)
	puzzle.on_grow()
	assert_float(puzzle.windup_fraction()).is_equal(0.0)
	assert_int(puzzle.gulps).is_equal(0)


func test_shrinking_while_she_still_opens_is_a_feint_she_sees_through() -> void:
	var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(_make_shift())
	puzzle.on_grow()
	puzzle.on_grow()
	_run(puzzle, 0.5)  # still opening toward 4
	assert_bool(puzzle.is_fully_open()).is_false()
	puzzle.on_shrink()
	assert_bool(_states.has(&"feint")).is_true()
	_run(puzzle, 0.2)
	assert_bool(puzzle.on_dart()).is_false()  # she snapped shut too fast
	assert_bool(_states.has(&"too_narrow")).is_true()
	_run(puzzle, 2.0)
	assert_bool(_states.has(&"closed")).is_true()
	assert_bool(puzzle.on_grow()).is_true()  # he can always try again
	assert_bool(puzzle.is_active()).is_true()


func test_baiting_only_one_step_is_not_wide_enough() -> void:
	var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(_make_shift())
	_run(puzzle, 1.0)
	assert_bool(puzzle.is_fully_open()).is_true()  # growth 1: jaws at 2
	puzzle.on_shrink()
	assert_bool(puzzle.on_dart()).is_false()


func test_dart_needs_hanuman_to_be_tiny() -> void:
	var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(_make_shift())
	_bait(puzzle, 3)
	assert_bool(puzzle.on_dart()).is_false()
	assert_bool(_states.has(&"too_big")).is_true()


func test_staying_inside_too_long_gets_him_spat_out() -> void:
	var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(_make_shift())
	_bait(puzzle, 2)
	puzzle.on_shrink()
	puzzle.on_dart()
	assert_int(puzzle.phase).is_equal(ChapterFlow.SurasaPuzzle.Phase.INSIDE)
	_run(puzzle, 5.0)
	assert_bool(_states.has(&"spat")).is_true()
	assert_int(puzzle.phase).is_equal(ChapterFlow.SurasaPuzzle.Phase.PLAYING)
	assert_int(puzzle.growth).is_equal(1)
	assert_int(_solved).is_equal(0)


func test_wider_bait_gives_more_time_inside() -> void:
	var times: Array[float] = []
	for growth: int in [2, 4]:
		var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(_make_shift())
		_bait(puzzle, growth)
		puzzle.on_shrink()
		puzzle.on_dart()
		var t: float = 0.0
		while puzzle.phase == ChapterFlow.SurasaPuzzle.Phase.INSIDE and t < 20.0:
			puzzle.tick(0.01)
			t += 0.01
		times.append(t)
	assert_float(times[1]).is_greater(times[0] + 2.0)


func test_fully_open_jaws_are_always_wider_than_hanuman_is_tall() -> void:
	for growth: int in range(1, ChapterFlow.SurasaPuzzle.MAX_GROWTH + 1):
		var open: float = ChapterFlow.jaw_width_metres(float(growth + 1))
		var tall: float = ChapterFlow.hanuman_height_metres(growth)
		assert_float(open).is_greater(tall)
		assert_float(open).is_less(tall * 1.8)  # close enough to compare by eye
	assert_float(ChapterFlow.jaw_width_metres(1.0)).is_less(ChapterFlow.hanuman_height_metres(1))


func test_timing_is_the_same_at_30_and_60_fps() -> void:
	var mouths: Array[float] = []
	for step: float in [1.0 / 30.0, 1.0 / 60.0]:
		var puzzle: ChapterFlow.SurasaPuzzle = _make_puzzle(_make_shift())
		puzzle.on_grow()
		puzzle.on_grow()
		_run(puzzle, 1.0, step)
		mouths.append(puzzle.mouth)
	assert_float(mouths[0]).is_equal_approx(mouths[1], 0.01)


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
	assert_str(rt.prompt_text()).contains("Surasa")
	for i: int in 2:
		flow.puzzle().on_grow()
	for i: int in 44:
		flow.tick_leap(0.05)
	assert_bool(flow.puzzle().is_fully_open()).is_true()
	assert_bool(flow.puzzle().on_shrink()).is_true()
	assert_bool(flow.puzzle().on_dart()).is_true()
	flow.tick_leap(0.5)
	assert_bool(flow.puzzle().on_dart()).is_true()
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
