extends GdUnitTestSuite
## M40 acceptance tests: game/level_runtime.gd (DESIGN §9 M40). Every level loads headless, the player spawns with a
## camera and HUD, the triggers route by their on_enter text, and no game-over state exists.
## The runtime gets private GameState and EventBus instances so the autoloads and the save file stay untouched.

const GameStateScript: GDScript = preload("res://core/game_state.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")
const LEVELS: Array[String] = [
	"mahendra", "lanka_gate", "lanka_streets", "ashoka_vatika", "ravana_court", "lanka_rooftops", "test_tiny",
]

var _events: Array[String] = []
var _exits: Array[String] = []
var _searched: Array[String] = []
var _completed: Array[String] = []


func before_test() -> void:
	_events.clear()
	_exits.clear()
	_searched.clear()
	_completed.clear()


func _make(level_id: String, options: Dictionary = {}) -> LevelRuntime:
	var rt: LevelRuntime = LevelRuntime.new()
	rt.music_enabled = false
	rt.game_state = auto_free(GameStateScript.new()) as Node
	rt.event_bus = auto_free(BusScript.new()) as Node
	add_child(rt)
	auto_free(rt)
	rt.game_event.connect(func(e: String) -> void: _events.append(e))
	rt.level_exit.connect(func(l: StringName) -> void: _exits.append(str(l)))
	rt.searched.connect(func(s: StringName) -> void: _searched.append(str(s)))
	rt.chapter_complete.connect(func(c: StringName) -> void: _completed.append(str(c)))
	var err: Error = rt.load_level(StringName(level_id), options)
	assert_int(err).is_equal(OK)
	return rt


func test_every_level_loads_and_spawns_the_player() -> void:
	for level_id: String in LEVELS:
		var rt: LevelRuntime = _make(level_id)
		assert_object(rt.player()).is_not_null()
		assert_object(rt.camera()).is_not_null()
		assert_object(rt.hud()).is_not_null()
		assert_object(rt.dialogue_box()).is_not_null()
		assert_object(rt.cutscene_player()).is_not_null()
		assert_object(rt.encounter()).is_not_null()
		assert_object(rt.fire()).is_not_null()
		assert_object(rt.level_root()).is_not_null()
		assert_bool(rt.player().is_in_group(&"player")).is_true()
		assert_bool(rt.player().get_node_or_null(rt.player().camera_path) == rt.camera()).is_true()
		assert_bool(rt.actors().has("hanuman")).is_true()


func test_missing_level_is_an_error_not_a_crash() -> void:
	var rt: LevelRuntime = LevelRuntime.new()
	rt.music_enabled = false
	add_child(rt)
	auto_free(rt)
	assert_int(rt.load_level(&"no_such_level")).is_equal(ERR_FILE_NOT_FOUND)


func test_player_spawns_at_the_player_marker_and_applies_meta() -> void:
	var mahendra: LevelRuntime = _make("mahendra")
	var marker: Node3D = mahendra.level_root().get_node("Spawns/hanuman_start") as Node3D
	assert_float(mahendra.player().position.x).is_equal_approx(marker.position.x, 0.01)
	assert_float(mahendra.player().position.z).is_equal_approx(marker.position.z, 0.01)
	assert_bool(mahendra.player().get_meta("tail_fire") as bool).is_false()
	assert_int(mahendra.size_shift().get_size()).is_equal(SizeShift.SIZE.NORMAL)
	var streets: LevelRuntime = _make("lanka_streets")
	assert_int(streets.size_shift().get_size()).is_equal(SizeShift.SIZE.SMALL)
	assert_int(streets.player().get_meta("size_state") as int).is_equal(SizeShift.SIZE.SMALL)
	var roof: LevelRuntime = _make("lanka_rooftops")
	assert_bool(roof.player().get_meta("tail_fire") as bool).is_true()


func test_a_spawn_inside_a_wall_moves_to_the_nearest_walkable_tile() -> void:
	var rt: LevelRuntime = _make("lanka_streets")
	# The level file puts hanuman_start on wall tile (2, 2); the runtime must not leave him inside it.
	var marker: Node3D = rt.level_root().get_node("Spawns/hanuman_start") as Node3D
	var moved: Vector3 = rt.safe_spawn(marker.position)
	assert_bool(moved.is_equal_approx(marker.position)).is_false()
	assert_float(Vector2(moved.x - marker.position.x, moved.z - marker.position.z).length()).is_less(4.1)
	assert_float(rt.player().position.x).is_equal_approx(moved.x, 0.01)
	assert_float(rt.player().position.z).is_equal_approx(moved.z, 0.01)
	var open_air: Vector3 = Vector3(3.0, 0.0, 19.0)
	assert_bool(rt.safe_spawn(open_air).is_equal_approx(open_air)).is_true()


func test_size_option_overrides_spawn_size() -> void:
	var rt: LevelRuntime = _make("ashoka_vatika", {"size": "normal"})
	assert_int(rt.size_shift().get_size()).is_equal(SizeShift.SIZE.NORMAL)
	var small: LevelRuntime = _make("ashoka_vatika")
	assert_int(small.size_shift().get_size()).is_equal(SizeShift.SIZE.SMALL)


func test_night_levels_use_indigo_ambient_and_moonlight() -> void:
	var rt: LevelRuntime = _make("lanka_streets")
	var env: Environment = (rt.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_bool(env.ambient_light_color.is_equal_approx(Palette.NIGHT_INDIGO)).is_true()
	var sun: DirectionalLight3D = rt.get_node("Sun") as DirectionalLight3D
	assert_bool(sun.light_color.is_equal_approx(Palette.MOON)).is_true()
	var day: LevelRuntime = _make("mahendra")
	var day_env: Environment = (day.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_bool(day_env.ambient_light_color.is_equal_approx(Palette.NIGHT_INDIGO)).is_false()
	assert_object(day.get_node_or_null("BackRim")).is_not_null()


func test_shrines_and_npcs_are_built() -> void:
	var rt: LevelRuntime = _make("mahendra")
	var shrine_count: int = 0
	for node: Node in rt.level_root().get_node("Shrines").get_children():
		if node is Shrine:
			shrine_count += 1
	assert_int(shrine_count).is_equal(1)
	assert_bool(rt.actors().has("jambavan")).is_true()
	assert_bool(rt.actors().has("angada")).is_true()
	assert_bool(rt.actors().has("vanara_3")).is_true()


func test_guards_are_registered_with_the_stealth_director() -> void:
	var rt: LevelRuntime = _make("lanka_streets")
	assert_int(rt.stealth().guard_count()).is_equal(6)
	var guard: EnemyBase = rt.actors()["guard_0"] as EnemyBase
	assert_int(guard.waypoints.size()).is_equal(2)


func test_wave_spawns_are_left_for_the_encounter_director() -> void:
	var rt: LevelRuntime = _make("ashoka_vatika", {"encounter_chapter": 4})
	var enemies: int = 0
	for node: Node in rt.level_root().get_children():
		if node is EnemyBase:
			enemies += 1
	assert_int(enemies).is_equal(0)
	assert_bool(rt.get_tree().get_nodes_in_group(&"enemy").is_empty()).is_true()
	rt.begin_encounter()
	assert_int(rt.encounter().current_wave()).is_equal(0)
	assert_int(rt.encounter().living_count()).is_equal(3)
	assert_bool(rt.get_tree().get_nodes_in_group(&"enemy").is_empty()).is_false()


func test_lankini_is_spawned_with_the_level() -> void:
	var rt: LevelRuntime = _make("lanka_gate")
	assert_bool(rt.actors()["lankini"] is BossLankini).is_true()


func test_enemy_factory_knows_every_kind() -> void:
	var rt: LevelRuntime = _make("test_tiny")
	for kind: String in ["guard_spear", "guard_archer", "kinkara", "boss_lankini", "boss_jambumali", "boss_akshaya", "boss_simhika"]:
		var enemy: Node3D = rt.make_enemy(kind)
		assert_object(enemy).is_not_null()
		enemy.free()
	assert_object(rt.make_enemy("bogus")).is_null()


func test_fire_system_knows_the_flammable_props() -> void:
	var rt: LevelRuntime = _make("lanka_rooftops")
	var flammable: Node3D = null
	var protected_prop: Node3D = null
	for prop: Node in rt.level_root().get_node("Props").get_children():
		if (prop.get_meta("flammable", false) as bool) and flammable == null:
			flammable = prop as Node3D
		if (prop.get_meta("protected", false) as bool) and protected_prop == null:
			protected_prop = prop as Node3D
	assert_object(flammable).is_not_null()
	assert_bool(rt.fire().ignite(flammable)).is_true()
	assert_bool(rt.fire().is_burning(flammable)).is_true()
	if protected_prop != null:
		assert_bool(rt.fire().ignite(protected_prop)).is_false()


func test_tail_fire_ignites_props_next_to_hanuman() -> void:
	var rt: LevelRuntime = _make("lanka_rooftops")
	var flammable: Node3D = null
	for prop: Node in rt.level_root().get_node("Props").get_children():
		if (prop.get_meta("flammable", false) as bool):
			flammable = prop as Node3D
			break
	assert_object(flammable).is_not_null()
	assert_int(rt.burn_near(flammable.global_position + Vector3(400.0, 0.0, 400.0))).is_equal(0)
	assert_int(rt.burn_near(flammable.global_position)).is_greater_equal(1)
	assert_bool(rt.fire().is_burning(flammable)).is_true()


# --- triggers -------------------------------------------------------------------------------------------------

func test_triggers_are_connected_to_the_player_layer() -> void:
	var rt: LevelRuntime = _make("lanka_streets")
	assert_int(rt.trigger_ids().size()).is_equal(5)
	var area: Area3D = rt.level_root().get_node("Triggers/t_search_0") as Area3D
	assert_int(area.collision_mask).is_equal(Layers.mask([Layers.PLAYER]))
	assert_bool(area.body_entered.get_connections().size() > 0).is_true()


func test_skip_triggers_option_disconnects_them() -> void:
	var rt: LevelRuntime = _make("ashoka_vatika", {"skip_triggers": ["t_grove_story"]})
	assert_bool(rt.fire_trigger(&"t_grove_story")).is_false()
	assert_int(rt.trigger_ids().size()).is_equal(0)


func test_search_trigger_emits_searched() -> void:
	var rt: LevelRuntime = _make("lanka_streets")
	assert_bool(rt.fire_trigger(&"t_search_0")).is_true()
	assert_array(_searched).contains_exactly(["mansions"])
	assert_array(_events).contains(["search:mansions"])
	assert_bool(rt.fire_trigger(&"t_search_0")).is_false()
	assert_int(_searched.size()).is_equal(1)


func test_level_trigger_emits_level_exit() -> void:
	var rt: LevelRuntime = _make("lanka_gate")
	assert_bool(rt.fire_trigger(&"t_gate_open")).is_true()
	assert_array(_exits).contains_exactly(["lanka_streets"])
	assert_array(_events).contains(["level:lanka_streets"])


func test_chapter_complete_trigger_emits_chapter_complete() -> void:
	var rt: LevelRuntime = _make("lanka_rooftops")
	assert_bool(rt.fire_trigger(&"t_ocean_exit")).is_true()
	assert_array(_completed).contains_exactly(["ch5"])
	assert_array(_events).contains(["chapter_complete:ch5"])


func test_dialogue_trigger_plays_the_dialogue_and_locks_input() -> void:
	var rt: LevelRuntime = _make("mahendra")
	assert_bool(rt.player().read_input).is_true()
	assert_bool(rt.fire_trigger(&"t_jambavan")).is_true()
	assert_bool(rt.dialogue_box().is_playing()).is_true()
	assert_bool(rt.input_locked()).is_true()
	assert_bool(rt.player().read_input).is_false()
	rt.dialogue_box().finished.emit(&"pro_jambavan")
	assert_bool(rt.input_locked()).is_false()
	assert_bool(rt.player().read_input).is_true()
	assert_array(_events).contains(["dialogue:pro_jambavan"])


func test_dialogue_with_node_starts_at_that_node() -> void:
	var rt: LevelRuntime = _make("lanka_rooftops")
	assert_bool(rt.fire_trigger(&"t_grove_check")).is_true()
	assert_bool(rt.dialogue_box().is_playing()).is_true()


func test_cutscene_route_plays_a_cutscene_and_reports_the_end() -> void:
	var rt: LevelRuntime = _make("mahendra")
	rt.route("cutscene:ch2_lankini_yields")
	assert_bool(rt.cutscene_player().is_playing()).is_true()
	assert_bool(rt.input_locked()).is_true()
	rt.cutscene_player().stop()
	rt.dialogue_box().finished.emit(&"ch2_lankini")
	rt.cutscene_player().finished.emit(&"ch2_lankini_yields")
	assert_bool(rt.input_locked()).is_false()
	assert_array(_events).contains(["cutscene:ch2_lankini_yields"])


func test_objective_route_reports_the_objective() -> void:
	var rt: LevelRuntime = _make("mahendra")
	rt.route("objective:training")
	assert_array(_events).contains(["objective:training"])


func test_unknown_on_enter_only_announces_the_trigger() -> void:
	var rt: LevelRuntime = _make("test_tiny")
	var fired: Array[String] = []
	rt.trigger_fired.connect(func(t: StringName, e: String) -> void: fired.append("%s=%s" % [str(t), e]))
	assert_bool(rt.fire_trigger(&"intro_trigger")).is_true()
	assert_array(fired).contains_exactly(["intro_trigger=intro_seen"])
	assert_array(_events).is_empty()


func test_unlock_flags_become_abilities() -> void:
	var gs: Node = auto_free(GameStateScript.new()) as Node
	gs.call("set_flag", &"grow_unlocked", true)
	gs.call("set_flag", &"shrink_unlocked", true)
	LevelRuntime.sync_unlocks(gs)
	assert_bool(gs.call("is_unlocked", &"grow") as bool).is_true()
	assert_bool(gs.call("is_unlocked", &"shrink") as bool).is_true()
	assert_bool(gs.call("is_unlocked", &"surge") as bool).is_false()


# --- exhausted recovery, no game over -------------------------------------------------------------------------

func test_exhausted_recovery_works_in_every_level() -> void:
	for level_id: String in LEVELS:
		var rt: LevelRuntime = _make(level_id)
		var player: Player = rt.player()
		var devotion: Devotion = rt.devotion()
		devotion.game_state = rt.game_state
		var spawn: Vector3 = rt.spawn_position()
		player.global_position = spawn + Vector3(3.0, 0.0, 3.0)
		player.get_health().damage(1000, null)
		assert_bool(devotion.is_exhausted()).is_true()
		devotion.tick(Devotion.FADE_TIME + 0.1)
		assert_bool(devotion.is_exhausted()).is_false()
		assert_int(player.get_health().value).is_equal(player.get_health().max_value)
		assert_float(player.global_position.distance_to(spawn)).is_less(0.01)


func test_shrine_record_points_at_the_spawn_when_none_is_for_this_level() -> void:
	var rt: LevelRuntime = _make("mahendra")
	var record: Dictionary = rt.game_state.get("last_shrine") as Dictionary
	assert_str(str(record["level"])).is_equal("mahendra")
	assert_bool((record["pos"] as Vector3).is_equal_approx(rt.spawn_position())).is_true()


func test_no_game_over_state_exists() -> void:
	var rt: LevelRuntime = _make("mahendra")
	assert_bool(rt.has_method("game_over")).is_false()
	assert_bool(rt.has_signal("game_over")).is_false()
	for path: String in ["res://game/level_runtime.gd", "res://game/chapter_flow.gd", "res://main.gd"]:
		var text: String = FileAccess.get_file_as_string(path).to_lower()
		assert_bool(text.contains("game_over") or text.contains("gameover")).is_false()


# --- the leap -------------------------------------------------------------------------------------------------

func test_the_leap_builds_a_rider_instead_of_a_level() -> void:
	var rt: LevelRuntime = _make("ocean_leap")
	assert_object(rt.leap()).is_not_null()
	assert_object(rt.rider()).is_not_null()
	assert_object(rt.player()).is_null()
	assert_object(rt.hud()).is_not_null()
	assert_int(rt.size_shift().get_size()).is_equal(SizeShift.SIZE.GIANT)
