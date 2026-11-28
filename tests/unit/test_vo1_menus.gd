extends GdUnitTestSuite
## VO1 acceptance: Settings has a Voice volume slider and a Voice-over on/off toggle (EN + HI strings).

const MENU_SCRIPT: String = "res://ui/menus.gd"


func before_test() -> void:
	after_test()


func after_test() -> void:
	var menu: Menus = auto_free((load(MENU_SCRIPT) as GDScript).new() as Menus) as Menus
	add_child(menu)
	menu.set_option(&"volume_voice", 1.0)
	menu.set_option(&"voice_over", false)
	menu.set_option(&"voice_over_hindi", false)


func test_voice_settings_default_and_persist() -> void:
	var menu: Menus = auto_free((load(MENU_SCRIPT) as GDScript).new() as Menus) as Menus
	add_child(menu)
	assert_bool(menu.get_option(&"voice_over") as bool).is_false()
	assert_float(menu.get_option(&"volume_voice") as float).is_equal_approx(1.0, 0.001)
	assert_bool(menu.set_option(&"voice_over", true)).is_true()
	assert_bool(Menus.saved_option(&"voice_over") as bool).is_true()
	assert_bool(menu.set_option(&"volume_voice", 0.5)).is_true()
	assert_float(Menus.saved_option(&"volume_voice") as float).is_equal_approx(0.5, 0.001)


func test_voice_volume_drives_the_voice_bus() -> void:
	var menu: Menus = auto_free((load(MENU_SCRIPT) as GDScript).new() as Menus) as Menus
	add_child(menu)
	menu.set_option(&"volume_voice", 0.5)
	var index: int = AudioServer.get_bus_index("Voice")
	assert_int(index).is_greater_equal(0)
	assert_float(AudioServer.get_bus_volume_db(index)).is_equal_approx(linear_to_db(0.5), 0.01)


func test_settings_panel_has_the_voice_widgets() -> void:
	var menu: Menus = auto_free((load(MENU_SCRIPT) as GDScript).new() as Menus) as Menus
	add_child(menu)
	assert_object(menu.find_child("VolumeVoiceSlider", true, false)).is_not_null()
	assert_object(menu.find_child("VoiceOverCheck", true, false)).is_not_null()
	assert_object(menu.find_child("VoiceOverHindiCheck", true, false)).is_not_null()


func test_hindi_voice_over_toggle_defaults_off_and_persists() -> void:
	var menu: Menus = auto_free((load(MENU_SCRIPT) as GDScript).new() as Menus) as Menus
	add_child(menu)
	assert_bool(menu.get_option(&"voice_over_hindi") as bool).is_false()
	assert_bool(menu.set_option(&"voice_over_hindi", true)).is_true()
	assert_bool(Menus.saved_option(&"voice_over_hindi") as bool).is_true()


func test_voice_strings_exist_in_both_languages() -> void:
	var file: FileAccess = FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	var found: Array[String] = []
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3 and (row[0] == "UI_MENU_VOLUME_VOICE" or row[0] == "UI_MENU_VOICE_OVER" or row[0] == "UI_MENU_VOICE_OVER_HI"):
			assert_bool(row[1].is_empty()).is_false()
			assert_bool(row[2].is_empty()).is_false()
			found.append(row[0])
	assert_array(found).has_size(3)


func test_an_old_settings_file_loses_its_stored_voice_over_once() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(Menus.SETTINGS_PATH)
	config.set_value("audio", "voice_over", true)
	if config.has_section(Menus.META_SECTION):
		config.erase_section(Menus.META_SECTION)
	config.save(Menus.SETTINGS_PATH)
	Menus.migrate_settings()
	assert_bool(Menus.saved_option(&"voice_over") as bool).is_false()
	var menu: Menus = auto_free((load(MENU_SCRIPT) as GDScript).new() as Menus) as Menus
	add_child(menu)
	menu.set_option(&"voice_over", true)
	Menus.migrate_settings()  # already migrated: the player's new choice stays
	assert_bool(Menus.saved_option(&"voice_over") as bool).is_true()
