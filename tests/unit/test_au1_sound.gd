extends GdUnitTestSuite
## Acceptance tests for AU1 (core/sound.gd): the event bank, the pooled players and the hook that records
## the ids played, plus the wiring of the gameplay files.

const IDS: Array[String] = [
	"footstep_grass", "footstep_stone", "footstep_sand", "gada_swing_light", "gada_swing_heavy", "impact_light",
	"impact_heavy", "player_hurt", "enemy_hurt", "enemy_dissolve", "dodge_whoosh", "size_grow", "size_shrink",
	"surge", "exhausted", "recovered", "shrine_meditate", "fire_ignite", "fire_loop", "alarm", "ui_click",
	"ui_hover", "ui_confirm", "ui_back", "dialogue_advance", "choice_select", "shloka_open",
]


func _sound() -> SoundPlayer:
	var s: SoundPlayer = auto_free(SoundPlayer.new()) as SoundPlayer
	add_child(s)
	return s


func test_bank_resolves_every_id_to_existing_files() -> void:
	var s: SoundPlayer = _sound()
	for id: String in IDS:
		assert_bool(SoundPlayer.BANK.has(id)).is_true()
		assert_bool(s.resolves(StringName(id))).is_true()
		var files: Array[String] = (SoundPlayer.BANK[id] as Dictionary)["files"] as Array[String]
		assert_bool(files.size() >= 1).is_true()
		for path: String in files:
			assert_bool(ResourceLoader.exists(path)).is_true()
			assert_bool(load(path) is AudioStream).is_true()


func test_play_returns_a_player_2d_and_3d() -> void:
	var s: SoundPlayer = _sound()
	var flat: Node = s.play(&"ui_click")
	assert_object(flat).is_not_null()
	assert_bool(flat is AudioStreamPlayer).is_true()
	assert_str(String((flat as AudioStreamPlayer).bus)).is_equal("SFX")
	var spatial: Node = s.play(&"impact_heavy", Vector3(1.0, 2.0, 3.0))
	assert_bool(spatial is AudioStreamPlayer3D).is_true()
	assert_vector((spatial as AudioStreamPlayer3D).position).is_equal(Vector3(1.0, 2.0, 3.0))
	assert_object(s.play(&"no_such_sound")).is_null()


func test_history_records_last_ids_and_is_capped() -> void:
	var s: SoundPlayer = _sound()
	for i: int in 20:
		s.play(&"ui_hover")
	s.play(&"ui_back")
	assert_int(s.recent_ids().size()).is_equal(SoundPlayer.HISTORY_SIZE)
	assert_str(String(s.recent_ids()[SoundPlayer.HISTORY_SIZE - 1])).is_equal("ui_back")
	s.clear_history()
	assert_int(s.recent_ids().size()).is_equal(0)


func test_buses_exist_and_music_is_trimmed() -> void:
	var s: SoundPlayer = _sound()
	assert_bool(AudioServer.get_bus_index("Music") >= 0).is_true()
	assert_bool(AudioServer.get_bus_index("SFX") >= 0).is_true()
	assert_float(s.music_gain_db()).is_equal_approx(-10.0, 0.001)


func test_dialogue_ducks_music() -> void:
	var s: SoundPlayer = _sound()
	var bus: Node = auto_free((load("res://core/event_bus.gd") as GDScript).new()) as Node
	s.bind_bus(bus)
	bus.emit_signal("dialogue_started", &"x")
	await get_tree().create_timer(SoundPlayer.DUCK_TIME + 0.2).timeout
	assert_float(s.music_gain_db()).is_less(-15.0)
	bus.emit_signal("dialogue_finished", &"x", {})
	await get_tree().create_timer(SoundPlayer.DUCK_TIME + 0.2).timeout
	assert_float(s.music_gain_db()).is_equal_approx(-10.0, 0.01)


func test_alarm_event_plays_alarm() -> void:
	var s: SoundPlayer = _sound()
	var bus: Node = auto_free((load("res://core/event_bus.gd") as GDScript).new()) as Node
	s.bind_bus(bus)
	bus.emit_signal("alarm_raised", Vector3(1.0, 0.0, 1.0))
	assert_str(String(s.recent_ids()[0])).is_equal("alarm")


func test_footstep_surface_choice() -> void:
	assert_str(String(SoundPlayer.footstep_id_for("grass"))).is_equal("footstep_grass")
	assert_str(String(SoundPlayer.footstep_id_for("sand"))).is_equal("footstep_sand")
	assert_str(String(SoundPlayer.footstep_id_for("stone_floor"))).is_equal("footstep_stone")
	assert_str(String(SoundPlayer.footstep_id_for("ground"))).is_equal("footstep_stone")


func test_cue_without_autoload_node_does_not_crash() -> void:
	assert_object(SoundPlayer.cue(null, &"ui_click")).is_null()
	var n: Node = auto_free(Node.new()) as Node
	assert_object(SoundPlayer.cue(n, &"ui_click")).is_null()
