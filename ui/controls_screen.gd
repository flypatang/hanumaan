class_name ControlsScreen
extends Control
## The controls screen (DESIGN §4.1a point 5). It lists only the controls the player has unlocked, in four groups:
## Move, Fight, Powers and Menus, with live glyphs. LevelRuntime shows it as an overlay while Tab is held; Menus embeds it
## under Pause -> Controls. `entries()` is the data, so tests can check it without drawing anything.

const GROUPS: Array[StringName] = [&"move", &"fight", &"powers", &"menus"]
## Every control: {group, action (glyph pseudo actions allowed), label key, unlock (empty = always), passive (no key)}.
const CONTROLS: Array[Dictionary] = [
	{"group": &"move", "action": &"move", "label": "CTRL_MOVE", "unlock": &""},
	{"group": &"move", "action": &"look", "label": "CTRL_LOOK", "unlock": &""},
	{"group": &"move", "action": &"zoom", "label": "CTRL_ZOOM", "unlock": &""},
	{"group": &"move", "action": &"camera", "label": "CTRL_CAMERA", "unlock": &""},
	{"group": &"move", "action": &"interact", "label": "CTRL_INTERACT", "unlock": &""},
	{"group": &"fight", "action": &"attack_light", "label": "CTRL_LIGHT", "unlock": &""},
	{"group": &"fight", "action": &"attack_heavy", "label": "CTRL_HEAVY", "unlock": &""},
	{"group": &"fight", "action": &"leap", "label": "CTRL_DODGE", "unlock": &""},
	{"group": &"powers", "action": &"grow", "label": "CTRL_GROW", "unlock": &"grow"},
	{"group": &"powers", "action": &"shrink", "label": "CTRL_SHRINK", "unlock": &"shrink"},
	{"group": &"powers", "action": &"smarana_surge", "label": "CTRL_SURGE", "unlock": &"surge"},
	{"group": &"powers", "action": &"", "label": "CTRL_TAIL_FIRE", "unlock": &"tail_fire"},
	{"group": &"menus", "action": &"pause", "label": "CTRL_PAUSE", "unlock": &""},
	{"group": &"menus", "action": &"show_controls", "label": "CTRL_SHOW", "unlock": &""},
]
const COLUMN_WIDTH: float = 290.0
const TITLE_SIZE: int = 34
const GROUP_SIZE: int = 24
const ROW_SIZE: int = 20

## Overrides the GameState autoload (tests).
var game_state: Node = null

var _panel: PanelContainer = null
var _columns: HBoxContainer = null
var _title: Label = null
var _footer: Label = null


func _init() -> void:
	name = "ControlsScreen"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()


func _ready() -> void:
	KeyGlyph.ensure_actions()
	var locale: Node = get_node_or_null(^"/root/Locale")
	if locale != null and not locale.is_connected("language_changed", _on_language_changed):
		locale.connect("language_changed", _on_language_changed)
	refresh()


## The controls to show, in order: {group, action, label, passive}. `state` is a GameState node (null: everything
## that needs no unlock only).
static func entries(state: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for control: Dictionary in CONTROLS:
		var needed: StringName = control["unlock"] as StringName
		if needed != &"" and not (state != null and state.call("is_unlocked", needed) as bool):
			continue
		out.append({
			"group": control["group"], "action": control["action"], "label": control["label"],
			"passive": (control["action"] as StringName) == &"",
		})
	return out


## The groups that have at least one entry.
static func visible_groups(state: Node) -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: Dictionary in entries(state):
		var group: StringName = entry["group"] as StringName
		if not out.has(group):
			out.append(group)
	return out


## Embedded in a menu panel (Pause -> Controls): always visible, no dimmed backdrop, a fixed size to centre the panel in.
func set_embedded() -> void:
	(get_node(^"Dim") as ColorRect).visible = false
	custom_minimum_size = Vector2(1180.0, 470.0)
	_footer.visible = false
	visible = true


func shown_labels() -> PackedStringArray:
	var out: PackedStringArray = []
	for entry: Dictionary in entries(_state()):
		out.append(tr(str(entry["label"])))
	return out


func shown_groups() -> Array[StringName]:
	return visible_groups(_state())


## Rebuilds the columns from the current unlocks, bindings and language.
func refresh() -> void:
	_title.text = tr("CTRL_TITLE")
	_footer.text = tr("CTRL_RELEASE")
	for child: Node in _columns.get_children():
		_columns.remove_child(child)
		child.queue_free()
	var all: Array[Dictionary] = entries(_state())
	for group: StringName in GROUPS:
		var rows: Array[Dictionary] = []
		for entry: Dictionary in all:
			if entry["group"] == group:
				rows.append(entry)
		if rows.is_empty():
			continue
		_columns.add_child(_make_column(group, rows))


## Shows the screen as an overlay (hold Tab). `closing_hint` is the "release to close" line.
func open_overlay(closing_hint: bool = true) -> void:
	refresh()
	_footer.visible = closing_hint
	visible = true


func close_overlay() -> void:
	visible = false


func _make_column(group: StringName, rows: Array[Dictionary]) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Group_%s" % str(group)
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	column.add_theme_constant_override("separation", 12)
	var heading: Label = _make_label(GROUP_SIZE, Palette.GOLD)
	heading.text = tr("CTRL_GROUP_" + str(group).to_upper())
	column.add_child(heading)
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(Palette.GOLD, 0.5)
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	for entry: Dictionary in rows:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var action: StringName = entry["action"] as StringName
		if action != &"":
			var glyph: KeyGlyph = KeyGlyph.new()
			glyph.set_action(action)
			var holder: Control = Control.new()
			holder.custom_minimum_size = Vector2(112.0, 44.0)
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(glyph)
			row.add_child(holder)
		else:
			var spacer: Control = Control.new()
			spacer.custom_minimum_size = Vector2(112.0, 44.0)
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(spacer)
		var label: Label = _make_label(ROW_SIZE, Palette.MOON)
		label.text = tr(str(entry["label"]))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		column.add_child(row)
	return column


func _on_language_changed(_code: StringName) -> void:
	refresh()


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.03, 0.02, 0.05, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(Palette.UI_DARK, 0.92)
	box.border_color = Palette.GOLD
	box.set_border_width_all(3)
	box.set_corner_radius_all(18)
	box.content_margin_left = 36.0
	box.content_margin_right = 36.0
	box.content_margin_top = 26.0
	box.content_margin_bottom = 22.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	box.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", box)
	center.add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	_panel.add_child(column)
	_title = _make_label(TITLE_SIZE, Palette.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 34)
	_columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_columns)
	_footer = _make_label(ROW_SIZE - 2, Color(Palette.MOON, 0.6))
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_footer)


func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var locale: Node = _locale()
	if locale != null:
		var font: Font = locale.call("font_for", &"ui") as Font
		if font != null:
			label.add_theme_font_override("font", font)
	return label


func _locale() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("Locale")


func _state() -> Node:
	if game_state != null:
		return game_state
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameState")
