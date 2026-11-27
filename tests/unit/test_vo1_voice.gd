extends GdUnitTestSuite
## VO1 acceptance: AI text-to-speech voice-over. Every voiced dialogue line has an English and a Hindi clip, every
## shloka has a Sanskrit clip, Voice picks the language folder and honours the on/off setting, advancing a dialogue
## line stops its clip, and the shloka card recites only in mode on.

const VOICE_SCRIPT: String = "res://core/voice.gd"
const BOX_SCRIPT: String = "res://ui/dialogue_box.gd"
const DIALOGUE_DIR: String = "res://data/dialogue/"
const VO_DIR: String = "res://assets/vo/"
const FIRST_FILE: String = "pro_jambavan"


func before_test() -> void:
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale("en")


## Mirror of the generator rule: a line fully in parentheses is a stage direction and is not voiced.
func _is_voiced(text: String) -> bool:
	var t: String = text.strip_edges()
	return not (t.begins_with("(") and t.ends_with(")"))


func _strings() -> Dictionary:
	var table: Dictionary = {}
	var file: FileAccess = FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3:
			table[row[0]] = [row[1], row[2]]
	return table


func _dialogue_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(DIALOGUE_DIR)
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_DIR + file_name)) as Dictionary
		var nodes: Dictionary = parsed["nodes"] as Dictionary
		for node_id: String in nodes.keys():
			var node: Dictionary = nodes[node_id] as Dictionary
			if node.has("text_key") and node.has("speaker"):
				out.append({"key": str(node["text_key"]), "speaker": str(node["speaker"])})
	return out


func _shloka_ids() -> Array[String]:
	var out: Array[String] = []
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shlokas.json")) as Dictionary
	for entry: Variant in parsed["shlokas"] as Array:
		out.append(str((entry as Dictionary)["id"]))
	return out


func _make_voice() -> VoicePlayer:
	var voice: VoicePlayer = (load(VOICE_SCRIPT) as GDScript).new() as VoicePlayer
	add_child(voice)
	auto_free(voice)
	voice.enabled_override = 1
	voice.hindi_override = 1
	return voice


func _first_voiced_key() -> String:
	var dlg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_DIR + FIRST_FILE + ".json")) as Dictionary
	var nodes: Dictionary = dlg["nodes"] as Dictionary
	return str((nodes[str(dlg["start"])] as Dictionary)["text_key"])


func test_cast_covers_every_speaker_and_the_shloka() -> void:
	var cast: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vo_cast.json")) as Dictionary
	assert_bool(cast.has("shloka")).is_true()
	for line: Dictionary in _dialogue_lines():
		assert_bool(cast.has(line["speaker"])).is_true()
	for speaker: String in cast.keys():
		if speaker.begins_with("_"):
			continue
		for lang: String in ["en", "hi"]:
			var entry: Dictionary = (cast[speaker] as Dictionary)[lang] as Dictionary
			assert_bool(str(entry["voice"]).is_empty()).is_false()
			assert_float(entry["speed"] as float).is_between(0.5, 1.5)
			assert_float(entry["pitch"] as float).is_between(0.7, 1.3)


func test_every_voiced_line_has_english_and_hindi_clips() -> void:
	var strings: Dictionary = _strings()
	var voiced: int = 0
	for line: Dictionary in _dialogue_lines():
		var key: String = str(line["key"])
		var texts: Array = strings[key] as Array
		for i: int in 2:
			var lang: String = "en" if i == 0 else "hi"
			var path: String = VO_DIR + lang + "/" + key + ".ogg"
			if _is_voiced(str(texts[i])):
				assert_bool(ResourceLoader.exists(path)).is_true()
				voiced += 1
	assert_int(voiced).is_greater(100)


func test_every_shloka_has_a_sanskrit_clip() -> void:
	var ids: Array[String] = _shloka_ids()
	assert_array(ids).is_not_empty()
	for id: String in ids:
		assert_bool(ResourceLoader.exists(VO_DIR + "sa/" + id + ".ogg")).is_true()


func test_clips_are_valid_ogg_vorbis() -> void:
	var paths: Array[String] = [
		VO_DIR + "en/" + _first_voiced_key() + ".ogg",
		VO_DIR + "hi/" + _first_voiced_key() + ".ogg",
		VO_DIR + "sa/" + _shloka_ids()[0] + ".ogg",
	]
	for path: String in paths:
		var stream: AudioStreamOggVorbis = load(path) as AudioStreamOggVorbis
		assert_object(stream).is_not_null()
		assert_float(stream.get_length()).is_greater(0.5)


func test_play_line_follows_the_language() -> void:
	var voice: VoicePlayer = _make_voice()
	var key: String = _first_voiced_key()
	assert_bool(voice.play_line(key)).is_true()
	assert_str(VoicePlayer.line_path(key)).is_equal(VO_DIR + "en/" + key + ".ogg")
	assert_str(voice.current_path()).is_equal(VO_DIR + "en/" + key + ".ogg")
	TranslationServer.set_locale("hi")
	assert_str(VoicePlayer.line_path(key)).is_equal(VO_DIR + "hi/" + key + ".ogg")
	assert_bool(voice.play_line(key)).is_true()
	assert_str(voice.current_path()).is_equal(VO_DIR + "hi/" + key + ".ogg")
	assert_str(str(voice.current_clip())).is_equal(key)


func test_play_line_is_silent_for_a_missing_clip() -> void:
	var voice: VoicePlayer = _make_voice()
	assert_bool(voice.play_line("NO_SUCH_KEY")).is_false()
	assert_bool(voice.is_playing()).is_false()


func test_play_line_respects_the_on_off_setting() -> void:
	var voice: VoicePlayer = _make_voice()
	var key: String = _first_voiced_key()
	voice.enabled_override = 0
	assert_bool(voice.play_line(key)).is_false()
	assert_bool(voice.is_playing()).is_false()
	voice.enabled_override = 1
	assert_bool(voice.play_line(key)).is_true()
	assert_bool(voice.is_playing()).is_true()


func test_stop_ends_playback() -> void:
	var voice: VoicePlayer = _make_voice()
	voice.play_line(_first_voiced_key())
	voice.stop()
	assert_bool(voice.is_playing()).is_false()
	assert_str(str(voice.current_clip())).is_equal("")


func test_voice_bus_exists() -> void:
	VoicePlayer.ensure_bus()
	assert_int(AudioServer.get_bus_index(VoicePlayer.BUS_VOICE)).is_greater_equal(0)


func test_dialogue_box_plays_the_line_and_advancing_stops_it() -> void:
	var voice: VoicePlayer = _make_voice()
	var box: DialogueBox = (load(BOX_SCRIPT) as GDScript).new() as DialogueBox
	box.voice = voice
	add_child(box)
	auto_free(box)
	assert_int(box.play(StringName(FIRST_FILE))).is_equal(OK)
	var first: String = _first_voiced_key()
	assert_str(str(voice.current_clip())).is_equal(first)
	assert_bool(voice.is_playing()).is_true()
	var accept: InputEventAction = InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	box.handle_input_event(accept)  # reveals the rest of the text; the clip keeps playing
	assert_str(str(voice.current_clip())).is_equal(first)
	var stops: Array[int] = [0]
	voice.stopped.connect(func() -> void: stops[0] += 1)
	box.handle_input_event(accept)  # advances: the first clip stops, the next line's clip starts
	assert_int(stops[0]).is_greater(0)
	assert_str(str(voice.current_clip())).is_not_equal(first)


func test_typewriter_follows_the_clip_length() -> void:
	var voice: VoicePlayer = _make_voice()
	var box: DialogueBox = (load(BOX_SCRIPT) as GDScript).new() as DialogueBox
	box.voice = voice
	add_child(box)
	auto_free(box)
	box.play(StringName(FIRST_FILE))
	var length: float = voice.current_length()
	assert_float(length).is_greater(0.5)
	box.step_typewriter(length * 0.5)
	assert_bool(box.is_typing()).is_true()
	box.step_typewriter(length * 0.6)
	assert_bool(box.is_typing()).is_false()


func test_dialogue_box_is_silent_when_voice_over_is_off() -> void:
	var voice: VoicePlayer = _make_voice()
	voice.enabled_override = 0
	var box: DialogueBox = (load(BOX_SCRIPT) as GDScript).new() as DialogueBox
	box.voice = voice
	add_child(box)
	auto_free(box)
	box.play(StringName(FIRST_FILE))
	assert_bool(voice.is_playing()).is_false()


func test_shloka_card_recites_only_in_mode_on() -> void:
	var voice: VoicePlayer = _make_voice()
	var card: ShlokaCard = (load("res://ui/shloka_card.gd") as GDScript).new() as ShlokaCard
	card.voice = voice
	add_child(card)
	auto_free(card)
	var id: String = _shloka_ids()[0]
	card.mode = ShlokaCard.MODE_SHORT
	card.show_shloka(StringName(id))
	assert_bool(voice.is_playing()).is_false()
	card.advance_time(10.0)
	card.mode = ShlokaCard.MODE_ON
	card.show_shloka(StringName(id))
	assert_bool(voice.is_playing()).is_true()
	assert_str(str(voice.current_clip())).is_equal(id)
	card.advance_time(5.0)
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	card.handle_input_event(key)
	assert_bool(voice.is_playing()).is_false()


func test_hindi_voice_over_is_off_by_default() -> void:
	assert_bool(Menus.DEFAULTS["voice_over_hindi"] as bool).is_false()
	assert_bool(Menus.DEFAULTS["voice_over"] as bool).is_true()


func test_hindi_off_gives_subtitles_only_but_english_still_plays() -> void:
	var voice: VoicePlayer = _make_voice()
	voice.hindi_override = 0
	var key: String = _first_voiced_key()
	assert_bool(voice.play_line(key)).is_true()
	TranslationServer.set_locale("hi")
	assert_bool(voice.play_line(key)).is_false()
	assert_bool(voice.is_playing()).is_false()
	assert_float(voice.line_length(key)).is_equal(0.0)
	voice.hindi_override = 1
	assert_bool(voice.play_line(key)).is_true()
	assert_str(voice.current_path()).is_equal(VO_DIR + "hi/" + key + ".ogg")


func test_shloka_recitation_follows_the_hindi_option() -> void:
	var voice: VoicePlayer = _make_voice()
	var id: String = _shloka_ids()[0]
	voice.hindi_override = 0
	assert_bool(voice.play_shloka(id)).is_false()
	voice.hindi_override = 1
	assert_bool(voice.play_shloka(id)).is_true()


func test_hindi_dialogue_box_is_silent_and_still_types_when_hindi_is_off() -> void:
	var voice: VoicePlayer = _make_voice()
	voice.hindi_override = 0
	TranslationServer.set_locale("hi")
	var box: DialogueBox = (load(BOX_SCRIPT) as GDScript).new() as DialogueBox
	box.voice = voice
	add_child(box)
	auto_free(box)
	assert_int(box.play(StringName(FIRST_FILE))).is_equal(OK)
	assert_bool(voice.is_playing()).is_false()
	box.step_typewriter(30.0)
	assert_bool(box.is_typing()).is_false()
