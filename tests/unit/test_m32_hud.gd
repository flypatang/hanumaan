extends GdUnitTestSuite
## M32 acceptance tests: the HUD (ui/hud.gd, DESIGN §9 M32). Headless and deterministic.
## Signals are driven through a bus instance created from core/event_bus.gd, so the autoload is never touched.
## The Locale instance is created from core/locale.gd and only its signal is emitted; no settings are written.
##
## The HUD labels come from tr() with a built-in fallback table (Hud.FALLBACK_EN / Hud.FALLBACK_HI), because the
## UI_HUD_* rows are not in strings.csv on this branch. Tests that check label words therefore assert the HUD's own
## fallback text, and they state that dependency where it applies. Boss and objective names are injected here as
## test translations, so those tests do not depend on any string data.

const HudScript: GDScript = preload("res://ui/hud.gd")
const HealthScript: GDScript = preload("res://gameplay/components/health.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")
const LocaleScript: GDScript = preload("res://core/locale.gd")

const MIN_FONT_SIZE: int = 18
const RAMA_TEXT: String = "राम"


func after_test() -> void:
	TranslationServer.set_locale("en")


func _make_bus() -> Node:
	var bus: Node = BusScript.new() as Node
	auto_free(bus)
	return bus


func _make_hud(bus: Node) -> Hud:
	var hud: Hud = HudScript.new() as Hud
	auto_free(hud)
	hud.connect_to(bus, null)
	add_child(hud)
	return hud


func _make_health(max_hp: int) -> Health:
	var h: Health = HealthScript.new() as Health
	h.max_value = max_hp
	auto_free(h)
	add_child(h)
	return h


## Registers one English test translation and returns it so the caller can remove it again.
func _add_test_name(key: String, value: String) -> Translation:
	var translation: Translation = Translation.new()
	translation.locale = "en"
	translation.add_message(StringName(key), StringName(value))
	TranslationServer.add_translation(translation)
	return translation


func test_hud_is_a_canvas_layer() -> void:
	var hud: Hud = _make_hud(_make_bus())
	assert_bool(hud is CanvasLayer).is_true()


func test_vitality_bar_follows_vitality_changed() -> void:
	var bus: Node = _make_bus()
	var hud: Hud = _make_hud(bus)
	bus.emit_signal("vitality_changed", 70, 100)
	assert_int(hud.vitality_bar_value()).is_equal(70)
	assert_int(hud.vitality_bar_max()).is_equal(100)


func test_vitality_label_shows_numbers() -> void:
	var bus: Node = _make_bus()
	var hud: Hud = _make_hud(bus)
	bus.emit_signal("vitality_changed", 45, 125)
	# The HUD formats the numbers itself as "<label>  <value> / <max>", so this holds with or without strings.
	assert_str(hud.vitality_text()).ends_with("45 / 125")


func test_vitality_reaches_zero_and_recovers() -> void:
	var bus: Node = _make_bus()
	var hud: Hud = _make_hud(bus)
	bus.emit_signal("vitality_changed", 0, 100)
	assert_int(hud.vitality_bar_value()).is_equal(0)
	bus.emit_signal("vitality_changed", 100, 100)
	assert_int(hud.vitality_bar_value()).is_equal(100)


func test_smarana_meter_follows_smarana_changed() -> void:
	var bus: Node = _make_bus()
	var hud: Hud = _make_hud(bus)
	bus.emit_signal("smarana_changed", 42.5)
	assert_float(hud.smarana_bar_value()).is_equal_approx(42.5, 0.001)


func test_smarana_meter_is_clamped_to_its_range() -> void:
	var bus: Node = _make_bus()
	var hud: Hud = _make_hud(bus)
	bus.emit_signal("smarana_changed", 150.0)
	assert_float(hud.smarana_bar_value()).is_equal_approx(100.0, 0.001)
	bus.emit_signal("smarana_changed", -5.0)
	assert_float(hud.smarana_bar_value()).is_equal_approx(0.0, 0.001)


func test_smarana_label_carries_devanagari_rama() -> void:
	# Dependency: the "राम" text comes from the HUD's fallback table (UI_HUD_SMARANA), since no strings.csv row exists.
	TranslationServer.set_locale("en")
	var hud: Hud = _make_hud(_make_bus())
	assert_str(hud.smarana_text()).contains(RAMA_TEXT)
	TranslationServer.set_locale("hi")
	hud.refresh_texts()
	assert_str(hud.smarana_text()).contains(RAMA_TEXT)


func test_smarana_label_uses_the_ui_font() -> void:
	var hud: Hud = _make_hud(_make_bus())
	var label: Label = hud.smarana_label()
	assert_bool(label.has_theme_font_override("font")).is_true()
	var locale: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Locale")
	assert_object(label.get_theme_font("font")).is_same(locale.call("font_for", &"ui"))


func test_size_indicator_shows_small_normal_large() -> void:
	# Dependency: the size words are the HUD's English fallback, pinned to English here.
	TranslationServer.set_locale("en")
	var bus: Node = _make_bus()
	var hud: Hud = _make_hud(bus)
	bus.emit_signal("size_changed", Hud.SIZE_SMALL)
	assert_int(hud.size_icon_index()).is_equal(0)
	assert_str(hud.size_text()).contains(Hud.FALLBACK_EN["UI_HUD_SIZE_SMALL"] as String)
	bus.emit_signal("size_changed", Hud.SIZE_NORMAL)
	assert_int(hud.size_icon_index()).is_equal(1)
	assert_str(hud.size_text()).contains(Hud.FALLBACK_EN["UI_HUD_SIZE_NORMAL"] as String)
	bus.emit_signal("size_changed", Hud.SIZE_LARGE)
	assert_int(hud.size_icon_index()).is_equal(2)
	assert_str(hud.size_text()).contains(Hud.FALLBACK_EN["UI_HUD_SIZE_LARGE"] as String)


func test_size_indicator_giant_uses_the_large_icon() -> void:
	TranslationServer.set_locale("en")
	var bus: Node = _make_bus()
	var hud: Hud = _make_hud(bus)
	bus.emit_signal("size_changed", Hud.SIZE_GIANT)
	assert_int(hud.size_icon_index()).is_equal(2)
	assert_str(hud.size_text()).contains(Hud.FALLBACK_EN["UI_HUD_SIZE_GIANT"] as String)


func test_objective_added_and_listed() -> void:
	var bus: Node = _make_bus()
	var hud: Hud = _make_hud(bus)
	bus.emit_signal("objective_updated", &"find_sita", "Find Sita in the grove", false)
	assert_int(hud.objective_count()).is_equal(1)
	assert_str(hud.objective_label_text(&"find_sita")).is_equal("Find Sita in the grove")
	assert_bool(hud.is_objective_shown_done(&"find_sita")).is_false()


func test_objective_update_replaces_instead_of_duplicating() -> void:
	TranslationServer.set_locale("en")
	var bus: Node = _make_bus()
	var hud: Hud = _make_hud(bus)
	bus.emit_signal("objective_updated", &"find_sita", "Find Sita", false)
	bus.emit_signal("objective_updated", &"find_sita", "Find Sita", true)
	assert_int(hud.objective_count()).is_equal(1)
	assert_bool(hud.is_objective_shown_done(&"find_sita")).is_true()
	# Dependency: the "done" word is the HUD's English fallback (UI_HUD_OBJ_DONE).
	assert_str(hud.objective_label_text(&"find_sita")).contains(Hud.FALLBACK_EN["UI_HUD_OBJ_DONE"] as String)


func test_boss_bar_shows_name_and_tracks_health() -> void:
	var translation: Translation = _add_test_name("UI_BOSS_TEST_SIMHIKA", "Simhika")
	var hud: Hud = _make_hud(_make_bus())
	var boss: Health = _make_health(400)
	hud.show_boss(&"UI_BOSS_TEST_SIMHIKA", boss)
	assert_bool(hud.boss_visible()).is_true()
	assert_str(hud.boss_name_text()).is_equal("Simhika")
	assert_int(hud.boss_bar_max()).is_equal(400)
	assert_int(hud.boss_bar_value()).is_equal(400)
	boss.damage(30, null)
	assert_int(hud.boss_bar_value()).is_equal(370)
	TranslationServer.remove_translation(translation)


func test_boss_name_without_translation_passes_through() -> void:
	var hud: Hud = _make_hud(_make_bus())
	hud.show_boss(&"Plain Boss Name", _make_health(50))
	assert_str(hud.boss_name_text()).is_equal("Plain Boss Name")


func test_hide_boss_hides_and_stops_tracking() -> void:
	var hud: Hud = _make_hud(_make_bus())
	var boss: Health = _make_health(250)
	hud.show_boss(&"UI_BOSS_TEST_LANKINI", boss)
	hud.hide_boss()
	assert_bool(hud.boss_visible()).is_false()
	boss.damage(50, null)
	assert_int(hud.boss_bar_value()).is_equal(250)


func test_showing_a_new_boss_stops_tracking_the_old_one() -> void:
	var hud: Hud = _make_hud(_make_bus())
	var first: Health = _make_health(100)
	var second: Health = _make_health(200)
	hud.show_boss(&"UI_BOSS_TEST_FIRST", first)
	hud.show_boss(&"UI_BOSS_TEST_SECOND", second)
	first.damage(10, null)
	assert_int(hud.boss_bar_value()).is_equal(200)
	second.damage(20, null)
	assert_int(hud.boss_bar_value()).is_equal(180)


func test_alarm_shows_then_hides_after_a_few_seconds() -> void:
	var bus: Node = _make_bus()
	var hud: Hud = _make_hud(bus)
	assert_bool(hud.alarm_visible()).is_false()
	bus.emit_signal("alarm_raised", Vector3(1.0, 0.0, 2.0))
	assert_bool(hud.alarm_visible()).is_true()
	hud.advance(0.5)
	assert_bool(hud.alarm_visible()).is_true()
	hud.advance(10.0)
	assert_bool(hud.alarm_visible()).is_false()


func test_language_switch_relabels_the_hud() -> void:
	# Dependency: the label words are the HUD's fallback table, so the expected words are read from it.
	var bus: Node = _make_bus()
	var locale: Node = LocaleScript.new() as Node
	auto_free(locale)
	var hud: Hud = HudScript.new() as Hud
	auto_free(hud)
	hud.connect_to(bus, locale)
	add_child(hud)
	TranslationServer.set_locale("en")
	hud.refresh_texts()
	var english: String = Hud.FALLBACK_EN["UI_HUD_VITALITY"] as String
	var hindi: String = Hud.FALLBACK_HI["UI_HUD_VITALITY"] as String
	assert_str(hud.vitality_text()).contains(english)
	TranslationServer.set_locale("hi")
	locale.emit_signal("language_changed", &"hi")
	assert_str(hud.vitality_text()).contains(hindi)
	assert_bool(hud.vitality_text().contains(english)).is_false()


func test_disconnecting_the_old_bus_stops_updates() -> void:
	var first_bus: Node = _make_bus()
	var second_bus: Node = _make_bus()
	var hud: Hud = _make_hud(first_bus)
	hud.connect_to(second_bus, null)
	first_bus.emit_signal("vitality_changed", 10, 100)
	assert_int(hud.vitality_bar_value()).is_equal(100)
	second_bus.emit_signal("vitality_changed", 60, 100)
	assert_int(hud.vitality_bar_value()).is_equal(60)


func test_all_hud_text_is_at_least_18px() -> void:
	var hud: Hud = _make_hud(_make_bus())
	var labels: Array[Node] = hud.find_children("*", "Label", true, false)
	assert_bool(labels.size() > 0).is_true()
	for node: Node in labels:
		var label: Label = node as Label
		var size: int = label.get_theme_font_size("font_size")
		assert_bool(size >= MIN_FONT_SIZE).is_true()
