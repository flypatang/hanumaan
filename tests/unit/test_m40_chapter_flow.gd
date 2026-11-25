extends GdUnitTestSuite
## M40 acceptance tests: game/chapter_flow.gd and its inline chapter table (DESIGN §9 M40). The flow advances on each
## completion condition (flag, level exit, waves, boss yielded, searches, event, cutscenes done), plays the entry,
## rule and exit cutscenes in order, and Continue resumes at the last chapter start.
## It runs against private GameState and EventBus instances and its own save slot.

const GameStateScript: GDScript = preload("res://core/game_state.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")
const TEST_SLOT: int = 987
const CUTSCENES_DIR: String = "res://data/cutscenes/"
const LEVELS_DIR: String = "res://levels/"

var _levels: Array[String] = []
var _cutscenes: Array[String] = []
var _finished: Array[String] = []
var _started: Array[String] = []
var _ready_ids: Array[String] = []
var _encounters: Array[int] = []
var _all_done: int = 0


func before_test() -> void:
	_levels.clear()
	_cutscenes.clear()
	_finished.clear()
	_started.clear()
	_ready_ids.clear()
	_encounters.clear()
	_all_done = 0


func after_test() -> void:
	var path: String = "user://save_%d.json" % TEST_SLOT
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _make_flow(gs: Node = null) -> ChapterFlow:
	var flow: ChapterFlow = ChapterFlow.new()
	flow.autosave = false
	flow.save_slot = TEST_SLOT
	flow.game_state = gs if gs != null else auto_free(GameStateScript.new()) as Node
	flow.event_bus = auto_free(BusScript.new()) as Node
	add_child(flow)
	auto_free(flow)
	flow.level_requested.connect(func(l: StringName, _o: Dictionary) -> void: _levels.append(str(l)))
	flow.cutscene_requested.connect(func(c: StringName) -> void: _cutscenes.append(str(c)))
	flow.chapter_finished.connect(func(c: StringName) -> void: _finished.append(str(c)))
	flow.chapter_started.connect(func(c: StringName) -> void: _started.append(str(c)))
	flow.chapter_ready.connect(func(c: StringName) -> void: _ready_ids.append(str(c)))
	flow.encounter_requested.connect(func(n: int) -> void: _encounters.append(n))
	flow.all_done.connect(func() -> void: _all_done += 1)
	return flow


func _gs(flow: ChapterFlow) -> Node:
	return flow.game_state


## Starts chapter `index`, loads its first level and plays its entry cutscenes to the end.
func _enter(flow: ChapterFlow, index: int) -> void:
	flow.start_chapter(index)
	flow.notify_level_loaded(flow.current_level(), null)
	while flow.is_busy_with_cutscene():
		flow.notify_cutscene_finished(&"")


# --- the data ---------------------------------------------------------------------------------------------------

func test_chapters_are_in_story_order() -> void:
	var flow: ChapterFlow = _make_flow()
	var ids: Array[StringName] = flow.chapter_ids()
	assert_array(ids).contains_exactly([&"prologue", &"ch1", &"ch2", &"ch3", &"ch4", &"ch5", &"epilogue", &"teaser_setu"])


func test_data_references_only_existing_files_and_strings() -> void:
	var flow: ChapterFlow = _make_flow()
	var keys: Dictionary = {}
	for k: Variant in ChapterFlow.TEXTS.keys():
		var pair: Array = ChapterFlow.TEXTS[k] as Array
		keys[str(k)] = str(pair[0]) != "" and str(pair[1]) != ""
	for i: int in range(flow.chapter_count()):
		var chapter: Dictionary = flow.chapter_data(i)
		for level: Variant in chapter["levels"] as Array:
			assert_bool(FileAccess.file_exists("%s%s.json" % [LEVELS_DIR, str((level as Dictionary)["id"])])).is_true()
		for list_key: String in ["entry_cutscenes", "exit_cutscenes"]:
			for id: Variant in chapter.get(list_key, []) as Array:
				assert_bool(FileAccess.file_exists("%s%s.json" % [CUTSCENES_DIR, str(id)])).is_true()
		for rule: Variant in chapter.get("on", []) as Array:
			assert_bool(FileAccess.file_exists("%s%s.json" % [CUTSCENES_DIR, str((rule as Dictionary)["cutscene"])])).is_true()
		for obj: Variant in chapter.get("objectives", []) as Array:
			var key: String = str((obj as Dictionary)["key"])
			assert_bool(key.begins_with("OBJ_")).is_true()
			assert_bool(keys.get(key, false) as bool).is_true()


# --- starting and advancing ---------------------------------------------------------------------------------------

func test_new_game_starts_the_prologue_on_mahendra() -> void:
	var flow: ChapterFlow = _make_flow()
	flow.new_game()
	assert_array(_started).contains_exactly(["prologue"])
	assert_array(_levels).contains_exactly(["mahendra"])
	assert_str(str(_gs(flow).get("chapter"))).is_equal("prologue")


func test_entry_cutscene_plays_before_the_chapter_is_ready() -> void:
	var flow: ChapterFlow = _make_flow()
	flow.new_game()
	flow.notify_level_loaded(&"mahendra", null)
	assert_array(_cutscenes).contains_exactly(["opening_title"])
	assert_array(_ready_ids).is_empty()
	flow.notify_cutscene_finished(&"opening_title")
	assert_array(_ready_ids).contains_exactly(["prologue"])


func test_event_condition_finishes_the_prologue() -> void:
	var flow: ChapterFlow = _make_flow()
	_enter(flow, 0)
	flow.handle_event("dialogue:pro_jambavan")
	assert_array(_finished).is_empty()
	flow.handle_event("dialogue:pro_leap")
	assert_array(_finished).contains_exactly(["prologue"])
	assert_str(str(flow.current_id())).is_equal("ch1")
	assert_array(_levels).contains(["mahendra", "ocean_leap"])


func test_flag_condition_finishes_chapter_one() -> void:
	var flow: ChapterFlow = _make_flow()
	_enter(flow, 1)
	flow.handle_event("dialogue:ch1_simhika")
	assert_array(_finished).is_empty()
	_gs(flow).call("set_flag", &"ch1_done", true)
	flow.handle_event("dialogue:ch1_simhika")
	assert_array(_finished).contains_exactly(["ch1"])
	assert_str(str(flow.current_id())).is_equal("ch2")
	assert_bool(_gs(flow).call("is_unlocked", &"shrink") as bool).is_true()


func test_level_exit_waits_for_its_requirement() -> void:
	var flow: ChapterFlow = _make_flow()
	_enter(flow, 2)
	assert_str(str(flow.current_level())).is_equal("lanka_gate")
	flow.handle_event("level:lanka_streets")
	assert_str(str(flow.current_level())).is_equal("lanka_gate")
	_gs(flow).call("set_flag", &"gate_open", true)
	flow.handle_event("level:lanka_streets")
	assert_str(str(flow.current_level())).is_equal("lanka_streets")
	assert_str(_levels[_levels.size() - 1]).is_equal("lanka_streets")
	assert_array(_finished).is_empty()


func test_search_count_gates_the_end_of_chapter_two() -> void:
	var flow: ChapterFlow = _make_flow()
	_enter(flow, 2)
	_gs(flow).call("set_flag", &"gate_open", true)
	flow.handle_event("level:lanka_streets")
	flow.handle_event("search:mansions")
	flow.handle_event("search:mansions")
	flow.handle_event("search:palace")
	assert_int(flow.search_count()).is_equal(2)
	flow.handle_event("level:ashoka_vatika")
	assert_array(_finished).is_empty()
	flow.handle_event("search:pushpaka")
	assert_int(flow.search_count()).is_equal(3)
	assert_bool(flow.is_objective_done(&"search")).is_true()
	flow.handle_event("level:ashoka_vatika")
	assert_array(_finished).contains_exactly(["ch2"])
	assert_str(str(flow.current_id())).is_equal("ch3")


func test_boss_yield_plays_the_rule_cutscene_and_ticks_the_objective() -> void:
	var flow: ChapterFlow = _make_flow()
	_enter(flow, 2)
	assert_bool(flow.is_objective_done(&"lankini")).is_false()
	flow.handle_event("boss_yielded:boss_lankini")
	assert_array(_cutscenes).contains(["ch2_lankini_yields"])
	assert_bool(flow.is_objective_done(&"lankini")).is_true()
	flow.handle_event("boss_yielded:boss_lankini")
	assert_int(_cutscenes.count("ch2_lankini_yields")).is_equal(1)


func test_flag_condition_finishes_chapter_three() -> void:
	var flow: ChapterFlow = _make_flow()
	_enter(flow, 3)
	_gs(flow).call("set_flag", &"ch3_done", true)
	flow.handle_event("dialogue:ch3_grove")
	assert_array(_finished).contains_exactly(["ch3"])
	assert_str(str(flow.current_id())).is_equal("ch4")


func test_waves_condition_runs_the_battle_chapter() -> void:
	var flow: ChapterFlow = _make_flow()
	flow.start_chapter(4)
	flow.notify_level_loaded(&"ashoka_vatika", null)
	assert_array(_cutscenes).contains_exactly(["ch4_battle_cry"])
	assert_array(_encounters).is_empty()
	flow.notify_cutscene_finished(&"ch4_battle_cry")
	assert_array(_encounters).contains_exactly([4])
	flow.handle_event("waves_completed")
	assert_array(_cutscenes).contains(["ch4_brahmastra"])
	assert_array(_finished).is_empty()
	flow.notify_cutscene_finished(&"ch4_brahmastra")
	assert_array(_finished).contains_exactly(["ch4"])
	assert_str(str(flow.current_id())).is_equal("ch5")


func test_level_advance_inside_chapter_five_and_exit_cutscene() -> void:
	var flow: ChapterFlow = _make_flow()
	_enter(flow, 5)
	assert_str(str(flow.current_level())).is_equal("ravana_court")
	flow.handle_event("dialogue:ch5_court")
	assert_str(str(flow.current_level())).is_equal("lanka_rooftops")
	assert_array(_finished).is_empty()
	flow.handle_event("fire_ignited")
	assert_bool(flow.is_objective_done(&"burn")).is_true()
	flow.handle_event("chapter_complete:ch5")
	assert_array(_cutscenes).contains(["ch5_return"])
	assert_array(_finished).is_empty()
	flow.notify_cutscene_finished(&"ch5_return")
	assert_array(_finished).contains_exactly(["ch5"])
	assert_str(str(flow.current_id())).is_equal("epilogue")


func test_cutscenes_done_condition_runs_the_epilogue_and_the_teaser() -> void:
	var flow: ChapterFlow = _make_flow()
	flow.start_chapter(6)
	flow.notify_level_loaded(&"mahendra", null)
	assert_array(_cutscenes).contains_exactly(["epilogue"])
	flow.notify_cutscene_finished(&"epilogue")
	assert_array(_finished).contains_exactly(["epilogue"])
	assert_str(str(flow.current_id())).is_equal("teaser_setu")
	flow.notify_level_loaded(&"mahendra", null)
	assert_array(_cutscenes).contains(["teaser_setu"])
	assert_int(_all_done).is_equal(0)
	flow.notify_cutscene_finished(&"teaser_setu")
	assert_array(_finished).contains(["teaser_setu"])
	assert_int(_all_done).is_equal(1)
	assert_bool(flow.is_finished()).is_true()


func test_the_whole_story_can_be_walked_to_the_credits() -> void:
	var flow: ChapterFlow = _make_flow()
	var gs: Node = _gs(flow)
	flow.new_game()
	flow.notify_level_loaded(&"mahendra", null)
	flow.notify_cutscene_finished(&"opening_title")
	flow.handle_event("dialogue:pro_leap")
	flow.notify_level_loaded(&"ocean_leap", null)
	gs.call("set_flag", &"ch1_done", true)
	flow.handle_event("dialogue:ch1_simhika")
	flow.notify_level_loaded(&"lanka_gate", null)
	gs.call("set_flag", &"gate_open", true)
	flow.handle_event("level:lanka_streets")
	flow.notify_level_loaded(&"lanka_streets", null)
	for s: String in ["mansions", "palace", "pushpaka"]:
		flow.handle_event("search:%s" % s)
	flow.handle_event("level:ashoka_vatika")
	flow.notify_level_loaded(&"ashoka_vatika", null)
	gs.call("set_flag", &"ch3_done", true)
	flow.handle_event("dialogue:ch3_grove")
	flow.notify_level_loaded(&"ashoka_vatika", null)
	flow.notify_cutscene_finished(&"ch4_battle_cry")
	flow.handle_event("waves_completed")
	flow.notify_cutscene_finished(&"ch4_brahmastra")
	flow.notify_level_loaded(&"ravana_court", null)
	flow.handle_event("dialogue:ch5_court")
	flow.notify_level_loaded(&"lanka_rooftops", null)
	flow.handle_event("chapter_complete:ch5")
	flow.notify_cutscene_finished(&"ch5_return")
	flow.notify_level_loaded(&"mahendra", null)
	flow.notify_cutscene_finished(&"epilogue")
	flow.notify_level_loaded(&"mahendra", null)
	flow.notify_cutscene_finished(&"teaser_setu")
	assert_array(_finished).has_size(8)
	assert_int(_all_done).is_equal(1)


# --- objectives, saving and continue -----------------------------------------------------------------------------

func test_objectives_are_announced_on_the_bus_when_a_level_loads() -> void:
	var flow: ChapterFlow = _make_flow()
	var seen: Array[String] = []
	flow.event_bus.connect("objective_updated", func(id: StringName, _t: String, done: bool) -> void: seen.append("%s:%s" % [str(id), str(done)]))
	flow.start_chapter(0)
	flow.notify_level_loaded(&"mahendra", null)
	assert_array(seen).contains(["talk_jambavan:false", "training:false", "reach_peak:false"])
	flow.handle_event("objective:training")
	assert_bool(flow.is_objective_done(&"training")).is_true()


func test_chapter_start_saves_and_continue_resumes_there() -> void:
	var gs: Node = auto_free(GameStateScript.new()) as Node
	var flow: ChapterFlow = _make_flow(gs)
	flow.autosave = true
	flow.start_chapter(3)
	assert_bool(flow.has_save()).is_true()
	var fresh: ChapterFlow = _make_flow(auto_free(GameStateScript.new()) as Node)
	_levels.clear()
	assert_bool(fresh.continue_game()).is_true()
	assert_str(str(fresh.current_id())).is_equal("ch3")
	assert_array(_levels).contains_exactly(["ashoka_vatika"])


func test_continue_without_a_save_is_refused() -> void:
	var flow: ChapterFlow = _make_flow()
	assert_bool(flow.has_save()).is_false()
	assert_bool(flow.continue_game()).is_false()
