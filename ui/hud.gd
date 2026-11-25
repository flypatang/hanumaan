class_name Hud
extends CanvasLayer
## HUD (DESIGN §9 M32): Vitality bar, Smarana meter labelled "राम", size indicator, objective list,
## boss bar and the alarm indicator. Designed for 1280x800; every text is at least 18 px.
##
## Systems talk to it only through EventBus signals. Call `connect_to(bus)` to choose the bus (tests pass their own);
## without that call the HUD listens to the EventBus and Locale autoloads once it is in the tree.
## Size values: SIZE_SMALL < SIZE_NORMAL < SIZE_LARGE < SIZE_GIANT, matching the §4.2 order.
## All text goes through tr(); `refresh_texts()` re-reads it, and it runs on every Locale.language_changed.

const SIZE_SMALL: int = 0
const SIZE_NORMAL: int = 1
const SIZE_LARGE: int = 2
const SIZE_GIANT: int = 3

const MIN_FONT_SIZE: int = 18
const BODY_FONT_SIZE: int = 20
const TITLE_FONT_SIZE: int = 22
const ALARM_SECONDS: float = 3.0
const SMARANA_MAX: float = 100.0
const LEFT_WIDTH: float = 340.0
const RIGHT_WIDTH: float = 380.0
const BOSS_WIDTH: float = 440.0
const MARGIN: int = 16
const BAR_HEIGHT: float = 18.0
const LABEL_PADDING: float = 8.0
const DEVANAGARI_LINE_FACTOR: float = 1.6
const LEFT_SEPARATION: int = 6
const ICON_RADII: PackedFloat32Array = [6.0, 10.0, 15.0]
const ICON_SPACING: float = 60.0
const ICON_LEFT: float = 16.0
const DONE_ALPHA: float = 0.5
const BUS_NAME: String = "EventBus"
const LOCALE_NAME: String = "Locale"
const UI_FONT_ROLE: StringName = &"ui"
const HINDI_PREFIX: String = "hi"

## The HUD's own labels, used whenever tr() returns the key unchanged (the translation row is missing).
## Keeps the HUD readable in both languages without depending on strings.csv.
const FALLBACK_EN: Dictionary = {
	"UI_HUD_VITALITY": "Vitality",
	"UI_HUD_SMARANA": "Smarana राम",
	"UI_HUD_SIZE": "Size",
	"UI_HUD_SIZE_SMALL": "Small",
	"UI_HUD_SIZE_NORMAL": "Normal",
	"UI_HUD_SIZE_LARGE": "Large",
	"UI_HUD_SIZE_GIANT": "Giant",
	"UI_HUD_OBJECTIVES": "Objectives",
	"UI_HUD_OBJ_DONE": "done",
	"UI_HUD_ALARM": "The rakshasas are alarmed!",
}
const FALLBACK_HI: Dictionary = {
	"UI_HUD_VITALITY": "जीवन-शक्ति",
	"UI_HUD_SMARANA": "स्मरण राम",
	"UI_HUD_SIZE": "आकार",
	"UI_HUD_SIZE_SMALL": "छोटा",
	"UI_HUD_SIZE_NORMAL": "सामान्य",
	"UI_HUD_SIZE_LARGE": "विशाल",
	"UI_HUD_SIZE_GIANT": "महाकाय",
	"UI_HUD_OBJECTIVES": "लक्ष्य",
	"UI_HUD_OBJ_DONE": "पूर्ण",
	"UI_HUD_ALARM": "राक्षस सचेत हुए!",
}

var _bus: Node = null
var _locale: Node = null
var _bound: bool = false

var _vitality_value: int = 100
var _vitality_max: int = 100
var _smarana: float = 0.0
var _size: int = SIZE_NORMAL
var _objective_ids: Array[StringName] = []
var _objective_texts: Dictionary = {}
var _objective_done: Dictionary = {}
var _objective_labels: Dictionary = {}
var _boss_health: Health = null
var _boss_name_key: StringName = &""
var _alarm_left: float = 0.0
var _alarm_pos: Vector3 = Vector3.ZERO

var _root: Control = null
var _vitality_label: Label = null
var _vitality_bar: ProgressBar = null
var _smarana_label: Label = null
var _smarana_bar: ProgressBar = null
var _size_label: Label = null
var _size_icons: Control = null
var _objectives_title: Label = null
var _objectives_box: VBoxContainer = null
var _boss_panel: VBoxContainer = null
var _boss_name_label: Label = null
var _boss_bar: ProgressBar = null
var _alarm_label: Label = null


func _init() -> void:
	layer = 10
	_build_ui()
	refresh_texts()


func _ready() -> void:
	if not _bound:
		connect_to(_autoload(BUS_NAME), null)


func _process(delta: float) -> void:
	advance(delta)


## Chooses the EventBus and Locale this HUD listens to. A null locale means the Locale autoload.
## Replaces any earlier connection.
func connect_to(bus: Node, locale: Node = null) -> void:
	_bound = true
	_set_bus_wiring(false)
	_wire(_locale, &"language_changed", _on_language_changed, false)
	_bus = bus
	_locale = locale if locale != null else _autoload(LOCALE_NAME)
	_set_bus_wiring(true)
	_wire(_locale, &"language_changed", _on_language_changed, true)


## Removes every objective row. Runs on EventBus.level_loaded so a new chapter starts with an empty list.
func clear_objectives() -> void:
	for id: StringName in _objective_ids:
		var label: Label = _objective_labels[id] as Label
		_objectives_box.remove_child(label)
		label.queue_free()
	_objective_ids.clear()
	_objective_texts.clear()
	_objective_done.clear()
	_objective_labels.clear()
	_refresh_objectives_header()


## Re-reads every translated string with the current language.
func refresh_texts() -> void:
	_refresh_vitality()
	_refresh_smarana()
	_refresh_size()
	_objectives_title.text = _tr("UI_HUD_OBJECTIVES")
	for id: StringName in _objective_ids:
		_refresh_objective(id)
	_refresh_boss_name()
	_alarm_label.text = _tr("UI_HUD_ALARM")
	_fit_all_labels()


## Moves the alarm timer forward. The HUD calls this from _process; tests call it directly.
func advance(delta: float) -> void:
	if _alarm_left <= 0.0:
		return
	_alarm_left = maxf(0.0, _alarm_left - delta)
	if _alarm_left <= 0.0:
		_alarm_label.visible = false
		return
	var fade: float = clampf(_alarm_left / ALARM_SECONDS, 0.3, 1.0)
	_alarm_label.modulate = Color(1.0, 1.0, 1.0, fade)


## Shows the boss bar for `health` under the name translation key `name_key`. Replaces any earlier boss.
func show_boss(name_key: StringName, health: Health) -> void:
	_disconnect_boss()
	if health == null:
		hide_boss()
		return
	_boss_name_key = name_key
	_boss_health = health
	health.changed.connect(_on_boss_health_changed)
	_boss_bar.max_value = float(maxi(health.max_value, 1))
	_boss_bar.value = float(health.value)
	_refresh_boss_name()
	_boss_panel.visible = true


func hide_boss() -> void:
	_disconnect_boss()
	_boss_name_key = &""
	_boss_panel.visible = false


func vitality_bar_value() -> int:
	return roundi(_vitality_bar.value)


func vitality_bar_max() -> int:
	return roundi(_vitality_bar.max_value)


func vitality_text() -> String:
	return _vitality_label.text


func smarana_bar_value() -> float:
	return _smarana_bar.value


func smarana_text() -> String:
	return _smarana_label.text


func smarana_label() -> Label:
	return _smarana_label


func smarana_bar() -> ProgressBar:
	return _smarana_bar


func vitality_label() -> Label:
	return _vitality_label


func vitality_bar() -> ProgressBar:
	return _vitality_bar


func objectives_header_visible() -> bool:
	return _objectives_title.visible


func size_icon_index() -> int:
	return _size_icon_index()


func size_text() -> String:
	return _size_label.text


func objective_count() -> int:
	return _objective_ids.size()


func objective_label_text(id: StringName) -> String:
	if not _objective_labels.has(id):
		return ""
	var label: Label = _objective_labels[id] as Label
	return label.text


func is_objective_shown_done(id: StringName) -> bool:
	var done: bool = _objective_done.get(id, false) as bool
	return done


func boss_visible() -> bool:
	return _boss_panel.visible


func boss_name_text() -> String:
	return _boss_name_label.text


func boss_bar_value() -> int:
	return roundi(_boss_bar.value)


func boss_bar_max() -> int:
	return roundi(_boss_bar.max_value)


func alarm_visible() -> bool:
	return _alarm_label.visible


func alarm_position() -> Vector3:
	return _alarm_pos


# --- Event handlers --------------------------------------------------------------------------

func _on_vitality_changed(value: int, max_value: int) -> void:
	_vitality_max = maxi(max_value, 1)
	_vitality_value = clampi(value, 0, _vitality_max)
	_refresh_vitality()


func _on_smarana_changed(value: float) -> void:
	_smarana = clampf(value, 0.0, SMARANA_MAX)
	_refresh_smarana()


func _on_size_changed(new_size: int) -> void:
	_size = new_size
	_refresh_size()
	_size_icons.queue_redraw()


func _on_objective_updated(id: StringName, text: String, done: bool) -> void:
	if not _objective_labels.has(id):
		var label: Label = _make_label(BODY_FONT_SIZE)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(RIGHT_WIDTH, 0.0)
		_objectives_box.add_child(label)
		_objective_labels[id] = label
		_objective_ids.append(id)
	_objective_texts[id] = text
	_objective_done[id] = done
	_refresh_objective(id)
	_refresh_objectives_header()


func _on_level_loaded(_id: StringName) -> void:
	clear_objectives()


func _on_alarm_raised(pos: Vector3) -> void:
	_alarm_pos = pos
	_alarm_left = ALARM_SECONDS
	_alarm_label.text = _tr("UI_HUD_ALARM")
	_alarm_label.modulate = Color.WHITE
	_alarm_label.visible = true


func _on_boss_health_changed(new_value: int, max_value_now: int) -> void:
	_boss_bar.max_value = float(maxi(max_value_now, 1))
	_boss_bar.value = float(new_value)


func _on_language_changed(_code: StringName) -> void:
	refresh_texts()


# --- Text lookup ----------------------------------------------------------------------------

## tr() with the HUD's own fallback: when the key has no translation, the built-in table answers.
## An unknown key comes back unchanged, so raw text (objective lines, boss names) passes through.
func _tr(key: String) -> String:
	var text: String = tr(key)
	if text != key:
		return text
	var is_hindi: bool = TranslationServer.get_locale().begins_with(HINDI_PREFIX)
	var table: Dictionary = FALLBACK_HI if is_hindi else FALLBACK_EN
	return str(table.get(key, key))


# --- Refresh helpers -------------------------------------------------------------------------

func _refresh_vitality() -> void:
	_vitality_bar.max_value = float(_vitality_max)
	_vitality_bar.value = float(_vitality_value)
	_vitality_label.text = "%s  %d / %d" % [_tr("UI_HUD_VITALITY"), _vitality_value, _vitality_max]


func _refresh_smarana() -> void:
	_smarana_bar.value = _smarana
	_smarana_label.text = _tr("UI_HUD_SMARANA")


func _refresh_size() -> void:
	_size_label.text = "%s: %s" % [_tr("UI_HUD_SIZE"), _tr(_size_key())]


func _refresh_objective(id: StringName) -> void:
	if not _objective_labels.has(id):
		return
	var label: Label = _objective_labels[id] as Label
	var text: String = _tr(_objective_texts[id] as String)
	var done: bool = _objective_done[id] as bool
	if done:
		label.text = "%s (%s)" % [text, _tr("UI_HUD_OBJ_DONE")]
		label.add_theme_color_override("font_color", Color(Palette.MOON, DONE_ALPHA))
	else:
		label.text = text
		label.add_theme_color_override("font_color", Palette.MOON)


## The Objectives header is shown only while there is at least one objective to list.
func _refresh_objectives_header() -> void:
	_objectives_title.visible = not _objective_ids.is_empty()


func _fit_all_labels() -> void:
	for label: Label in [_vitality_label, _smarana_label, _size_label, _objectives_title, _boss_name_label, _alarm_label]:
		_fit_label(label)
	for id: StringName in _objective_ids:
		_fit_label(_objective_labels[id] as Label)


## Gives a label a box tall enough for its glyphs plus padding, so the bar below never covers the text.
## Devanagari needs more height than Latin, so the box is at least DEVANAGARI_LINE_FACTOR times the font size.
func _fit_label(label: Label) -> void:
	if label == null:
		return
	var size: int = label.get_theme_font_size("font_size")
	var font: Font = label.get_theme_font("font")
	var line: float = float(size) * DEVANAGARI_LINE_FACTOR
	if font != null:
		line = maxf(line, font.get_height(size))
	label.custom_minimum_size.y = ceilf(line + LABEL_PADDING)


func _refresh_boss_name() -> void:
	if _boss_name_key == &"":
		_boss_name_label.text = ""
		return
	_boss_name_label.text = _tr(String(_boss_name_key))


func _size_key() -> String:
	if _size == SIZE_SMALL:
		return "UI_HUD_SIZE_SMALL"
	if _size == SIZE_LARGE:
		return "UI_HUD_SIZE_LARGE"
	if _size == SIZE_GIANT:
		return "UI_HUD_SIZE_GIANT"
	return "UI_HUD_SIZE_NORMAL"


func _size_icon_index() -> int:
	if _size == SIZE_SMALL:
		return 0
	if _size == SIZE_LARGE or _size == SIZE_GIANT:
		return 2
	return 1


func _draw_size_icons() -> void:
	var active: int = _size_icon_index()
	var mid: float = _size_icons.size.y * 0.5
	for i: int in ICON_RADII.size():
		var center: Vector2 = Vector2(ICON_LEFT + ICON_SPACING * float(i), mid)
		var color: Color = Palette.GOLD if i == active else Color(Palette.STONE, 0.35)
		_size_icons.draw_circle(center, ICON_RADII[i], color)


# --- Connections -----------------------------------------------------------------------------

func _set_bus_wiring(on: bool) -> void:
	_wire(_bus, &"vitality_changed", _on_vitality_changed, on)
	_wire(_bus, &"smarana_changed", _on_smarana_changed, on)
	_wire(_bus, &"size_changed", _on_size_changed, on)
	_wire(_bus, &"objective_updated", _on_objective_updated, on)
	_wire(_bus, &"alarm_raised", _on_alarm_raised, on)
	_wire(_bus, &"level_loaded", _on_level_loaded, on)


func _wire(source: Node, signal_name: StringName, handler: Callable, on: bool) -> void:
	if source == null:
		return
	var connected: bool = source.is_connected(signal_name, handler)
	if on and not connected:
		source.connect(signal_name, handler)
	elif not on and connected:
		source.disconnect(signal_name, handler)


func _disconnect_boss() -> void:
	if is_instance_valid(_boss_health):
		if _boss_health.changed.is_connected(_on_boss_health_changed):
			_boss_health.changed.disconnect(_on_boss_health_changed)
	_boss_health = null


func _autoload(node_name: String) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name)) as Node


# --- Building the UI -------------------------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_WIDTH, 0.0)
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	left.add_theme_constant_override("separation", LEFT_SEPARATION)
	_root.add_child(left)

	_vitality_label = _make_caption()
	left.add_child(_vitality_label)
	_vitality_bar = _make_bar(Palette.SINDOOR)
	left.add_child(_vitality_bar)

	_smarana_label = _make_caption()
	left.add_child(_smarana_label)
	_smarana_bar = _make_bar(Palette.SAFFRON)
	left.add_child(_smarana_bar)

	_size_label = _make_caption()
	left.add_child(_size_label)
	_size_icons = Control.new()
	_size_icons.custom_minimum_size = Vector2(LEFT_WIDTH, 40.0)
	_size_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_size_icons.draw.connect(_draw_size_icons)
	left.add_child(_size_icons)

	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(RIGHT_WIDTH, 0.0)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(right)
	_objectives_title = _make_label(TITLE_FONT_SIZE)
	_objectives_title.visible = false
	right.add_child(_objectives_title)
	_objectives_box = VBoxContainer.new()
	right.add_child(_objectives_box)

	var center: VBoxContainer = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, MARGIN)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.add_child(center)
	_boss_panel = VBoxContainer.new()
	_boss_panel.custom_minimum_size = Vector2(BOSS_WIDTH, 0.0)
	_boss_panel.visible = false
	center.add_child(_boss_panel)
	_boss_name_label = _make_label(TITLE_FONT_SIZE)
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_panel.add_child(_boss_name_label)
	_boss_bar = _make_bar(Palette.ASHOKA_RED)
	_boss_bar.custom_minimum_size = Vector2(BOSS_WIDTH, BAR_HEIGHT)
	_boss_panel.add_child(_boss_bar)
	_alarm_label = _make_label(TITLE_FONT_SIZE)
	_alarm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alarm_label.add_theme_color_override("font_color", Palette.SINDOOR)
	_alarm_label.visible = false
	center.add_child(_alarm_label)


func _make_label(size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", maxi(size, MIN_FONT_SIZE))
	var font: Font = _ui_font()
	if font != null:
		label.add_theme_font_override("font", font)
	_fit_label(label)
	return label


## A caption for a bar: its text sits on the bottom of its box, so it hugs the bar it names and the padding
## above it separates it from the bar before.
func _make_caption() -> Label:
	var label: Label = _make_label(BODY_FONT_SIZE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label


func _make_bar(fill: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.custom_minimum_size = Vector2(LEFT_WIDTH, BAR_HEIGHT)
	bar.add_theme_stylebox_override("fill", _flat_box(fill))
	bar.add_theme_stylebox_override("background", _flat_box(Palette.UI_DARK))
	return bar


func _flat_box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(4)
	return box


func _ui_font() -> Font:
	var locale: Node = _autoload(LOCALE_NAME)
	if locale == null:
		return null
	return locale.call("font_for", UI_FONT_ROLE) as Font
