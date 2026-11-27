extends GdUnitTestSuite
## VO1 acceptance: Settings has a Voice volume slider and a Voice-over on/off toggle (EN + HI strings).

const MENU_SCRIPT: String = "res://ui/menus.gd"


func after_test() -> void:
	var menu: Menus = auto_free((load(MENU_SCRIPT) as GDScript).new() as Menus) as Menus
	add_child(menu)
	menu.set_option(&"volume_voice", 1.0)
	menu.set_option(&"voice_over", true)


func test_voice_settings_default_and_persist() -> void:
	var menu: Menus = auto_free((load(MENU_SCRIPT) as GDScript).new() as Menus) as Menus
	add_child(menu)
	assert_bool(menu.get_option(&"voice_over") as bool).is_true()
	assert_float(menu.get_option(&"volume_voice") as float).is_equal_approx(1.0, 0.001)
	assert_bool(menu.set_option(&"voice_over", false)).is_true()
	assert_bool(Menus.saved_option(&"voice_over") as bool).is_false()
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


func test_voice_strings_exist_in_both_languages() -> void:
	var file: FileAccess = FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	var found: Array[String] = []
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3 and (row[0] == "UI_MENU_VOLUME_VOICE" or row[0] == "UI_MENU_VOICE_OVER"):
			assert_bool(row[1].is_empty()).is_false()
			assert_bool(row[2].is_empty()).is_false()
			found.append(row[0])
	assert_array(found).has_size(2)
