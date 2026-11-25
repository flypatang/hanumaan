extends GdUnitTestSuite
## P2 acceptance tests: HUD polish (ui/hud.gd, DESIGN §9 M32 polish pass). Headless and deterministic.
##
## The HUD is laid out inside a SubViewport of the exact size under test (1280x800 and 1920x1080), so the
## real Control layout is measured. Labels and bars must never overlap, in English and in Hindi (Devanagari
## is taller), with every HUD element visible at once. The value labels sit above their bars with padding, and
## the Objectives header is hidden while the objective list is empty.

const HudScript: GDScript = preload("res://ui/hud.gd")
const HealthScript: GDScript = preload("res://gameplay/components/health.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")

const OVERLAP_TOLERANCE: float = 1.0
const LAYOUT_FRAMES: int = 4
const SIZE_LAPTOP: Vector2i = Vector2i(1280, 800)
const SIZE_FULL_HD: Vector2i = Vector2i(1920, 1080)


func after_test() -> void:
	TranslationServer.set_locale("en")


func _make_bus() -> Node:
	var bus: Node = BusScript.new() as Node
	auto_free(bus)
	return bus


## Builds a HUD inside a SubViewport of `size`, with every element populated, and lets the layout settle.
func _make_laid_out_hud(size: Vector2i, bus: Node) -> Hud:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	viewport.transparent_bg = true
	auto_free(viewport)
	add_child(viewport)
	var hud: Hud = HudScript.new() as Hud
	hud.connect_to(bus, null)
	viewport.add_child(hud)
	return hud


func _populate(hud: Hud, bus: Node) -> Health:
	bus.emit_signal("vitality_changed", 100, 100)
	bus.emit_signal("smarana_changed", 64.0)
	bus.emit_signal("size_changed", Hud.SIZE_NORMAL)
	bus.emit_signal("objective_updated", &"p2_short", "Find Sita", false)
	bus.emit_signal(
		"objective_updated",
		&"p2_long",
		"Search the mansions, Ravana's palace and the Pushpaka courtyard, then report to Hanuman",
		true
	)
	bus.emit_signal("alarm_raised", Vector3.ZERO)
	var boss: Health = HealthScript.new() as Health
	boss.max_value = 400
	auto_free(boss)
	hud.add_child(boss)
	hud.show_boss(&"BOSS_SIMHIKA", boss)
	return boss


func _collect_elements(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			if child is Label or child is ProgressBar:
				out.append(child as Control)
		_collect_elements(child, out)


func _find_overlaps(hud: Hud) -> Array[String]:
	var elements: Array[Control] = []
	_collect_elements(hud, elements)
	var overlaps: Array[String] = []
	for i: int in elements.size():
		for j: int in range(i + 1, elements.size()):
			var a: Control = elements[i]
			var b: Control = elements[j]
			var inter: Rect2 = a.get_global_rect().intersection(b.get_global_rect())
			if inter.size.x > OVERLAP_TOLERANCE and inter.size.y > OVERLAP_TOLERANCE:
				overlaps.append("%s overlaps %s" % [a.get_path(), b.get_path()])
	return overlaps


func _settle() -> void:
	for i: int in LAYOUT_FRAMES:
		await await_idle_frame()


func test_p2_no_overlaps_at_1280x800_english() -> void:
	TranslationServer.set_locale("en")
	var bus: Node = _make_bus()
	var hud: Hud = _make_laid_out_hud(SIZE_LAPTOP, bus)
	_populate(hud, bus)
	await _settle()
	assert_array(_find_overlaps(hud)).is_empty()


func test_p2_no_overlaps_at_1280x800_hindi() -> void:
	TranslationServer.set_locale("hi")
	var bus: Node = _make_bus()
	var hud: Hud = _make_laid_out_hud(SIZE_LAPTOP, bus)
	_populate(hud, bus)
	hud.refresh_texts()
	await _settle()
	assert_array(_find_overlaps(hud)).is_empty()


func test_p2_no_overlaps_at_1920x1080_english() -> void:
	TranslationServer.set_locale("en")
	var bus: Node = _make_bus()
	var hud: Hud = _make_laid_out_hud(SIZE_FULL_HD, bus)
	_populate(hud, bus)
	await _settle()
	assert_array(_find_overlaps(hud)).is_empty()


func test_p2_no_overlaps_at_1920x1080_hindi() -> void:
	TranslationServer.set_locale("hi")
	var bus: Node = _make_bus()
	var hud: Hud = _make_laid_out_hud(SIZE_FULL_HD, bus)
	_populate(hud, bus)
	hud.refresh_texts()
	await _settle()
	assert_array(_find_overlaps(hud)).is_empty()


func test_p2_vitality_value_sits_above_its_bar_with_padding() -> void:
	TranslationServer.set_locale("en")
	var bus: Node = _make_bus()
	var hud: Hud = _make_laid_out_hud(SIZE_LAPTOP, bus)
	bus.emit_signal("vitality_changed", 100, 100)
	await _settle()
	var label: Label = hud.vitality_label()
	var bar: ProgressBar = hud.vitality_bar()
	var gap: float = bar.get_global_rect().position.y - label.get_global_rect().end.y
	assert_float(gap).is_greater_equal(0.0)
	# The label box must fully contain its glyphs: at least the font's line height tall.
	var font: Font = label.get_theme_font("font")
	var line_height: float = font.get_height(label.get_theme_font_size("font_size"))
	assert_float(label.get_global_rect().size.y).is_greater_equal(line_height)


func test_p2_smarana_value_sits_above_its_bar_with_padding_in_hindi() -> void:
	TranslationServer.set_locale("hi")
	var bus: Node = _make_bus()
	var hud: Hud = _make_laid_out_hud(SIZE_LAPTOP, bus)
	bus.emit_signal("smarana_changed", 30.0)
	hud.refresh_texts()
	await _settle()
	var label: Label = hud.smarana_label()
	var bar: ProgressBar = hud.smarana_bar()
	var gap: float = bar.get_global_rect().position.y - label.get_global_rect().end.y
	assert_float(gap).is_greater_equal(0.0)


func test_p2_objectives_header_hidden_when_list_is_empty() -> void:
	var hud: Hud = _make_laid_out_hud(SIZE_LAPTOP, _make_bus())
	await _settle()
	assert_int(hud.objective_count()).is_equal(0)
	assert_bool(hud.objectives_header_visible()).is_false()


func test_p2_objectives_header_shown_once_an_objective_exists() -> void:
	var bus: Node = _make_bus()
	var hud: Hud = _make_laid_out_hud(SIZE_LAPTOP, bus)
	bus.emit_signal("objective_updated", &"p2_header", "Find Sita", false)
	assert_bool(hud.objectives_header_visible()).is_true()


func test_p2_objectives_header_hidden_again_after_clear() -> void:
	var bus: Node = _make_bus()
	var hud: Hud = _make_laid_out_hud(SIZE_LAPTOP, bus)
	bus.emit_signal("objective_updated", &"p2_header", "Find Sita", false)
	hud.clear_objectives()
	assert_bool(hud.objectives_header_visible()).is_false()


func test_p2_level_load_clears_objectives_and_hides_header() -> void:
	var bus: Node = _make_bus()
	var hud: Hud = _make_laid_out_hud(SIZE_LAPTOP, bus)
	bus.emit_signal("objective_updated", &"p2_header", "Find Sita", false)
	bus.emit_signal("level_loaded", &"lanka_streets")
	assert_int(hud.objective_count()).is_equal(0)
	assert_bool(hud.objectives_header_visible()).is_false()
