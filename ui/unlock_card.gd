class_name UnlockCard
extends Control
## The ability-unlock card (DESIGN §4.1a point 3): a centred card for Grow, Shrink, the Smarana surge and Tail fire with
## the key glyph and one sentence. While it is open the runtime locks play; it closes when the player presses interact
## or accept, or clicks, and then plays the confirm sound. `closed(ability)` tells the runtime to unlock play again.

signal closed(ability: StringName)

## The abilities that have a card: ability id -> {action, title key, text key}. Tail fire has no key.
const CARDS: Dictionary = {
	&"grow": {"action": &"grow", "title": "UNLOCK_GROW_TITLE", "text": "UNLOCK_GROW_TEXT"},
	&"shrink": {"action": &"shrink", "title": "UNLOCK_SHRINK_TITLE", "text": "UNLOCK_SHRINK_TEXT"},
	&"surge": {"action": &"smarana_surge", "title": "UNLOCK_SURGE_TITLE", "text": "UNLOCK_SURGE_TEXT"},
	&"tail_fire": {"action": &"", "title": "UNLOCK_TAIL_FIRE_TITLE", "text": "UNLOCK_TAIL_FIRE_TEXT"},
}
const CARD_WIDTH: float = 620.0
const TITLE_SIZE: int = 40
const TEXT_SIZE: int = 24
const SMALL_SIZE: int = 20
const FADE_TIME: float = 0.25

## Seconds after opening in which the card ignores input (so the press that ended the dialogue does not close it).
var guard_seconds: float = 0.4

var _ability: StringName = &""
var _open: bool = false
var _age: float = 0.0
var _backdrop: ColorRect = null
var _panel: PanelContainer = null
var _kicker: Label = null
var _title: Label = null
var _glyph_row: HBoxContainer = null
var _glyph: KeyGlyph = null
var _text: Label = null
var _continue_row: HBoxContainer = null
var _continue_label: Label = null


func _init() -> void:
	name = "UnlockCard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()


func _ready() -> void:
	var locale: Node = get_node_or_null(^"/root/Locale")
	if locale != null:
		var font: Font = locale.call("font_for", &"ui") as Font
		if font != null:
			for label: Label in [_kicker, _title, _text, _continue_label]:
				label.add_theme_font_override("font", font)
		if not locale.is_connected("language_changed", _on_language_changed):
			locale.connect("language_changed", _on_language_changed)


func _process(delta: float) -> void:
	if not _open:
		return
	_age += delta
	modulate.a = clampf(_age / FADE_TIME, 0.0, 1.0)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	KeyGlyph.observe(event)
	if _age < guard_seconds:
		return
	if _is_dismiss(event):
		get_viewport().set_input_as_handled()
		dismiss()


func _is_dismiss(event: InputEvent) -> bool:
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		return true
	var click: InputEventMouseButton = event as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT


## True for an ability that has a card.
static func has_card(ability: StringName) -> bool:
	return CARDS.has(ability)


## Opens the card for `ability`. Returns false (and shows nothing) for an ability without a card.
func show_for(ability: StringName) -> bool:
	if not CARDS.has(ability):
		return false
	_ability = ability
	_open = true
	_age = 0.0
	modulate.a = 0.0
	visible = true
	_fill()
	return true


func is_open() -> bool:
	return _open


func ability() -> StringName:
	return _ability


func title_text() -> String:
	return _title.text


func body_text() -> String:
	return _text.text


## The glyph text shown on the card ("" for Tail fire, which has no key).
func glyph_text() -> String:
	return _glyph.shown_text() if _glyph.visible else ""


## Closes the card, plays the confirm sound and announces it.
func dismiss() -> void:
	if not _open:
		return
	_open = false
	visible = false
	SoundPlayer.cue(self, &"ui_confirm")
	closed.emit(_ability)


func _fill() -> void:
	var entry: Dictionary = CARDS[_ability] as Dictionary
	var action: StringName = entry["action"] as StringName
	_kicker.text = tr("UNLOCK_NEW")
	_title.text = tr(str(entry["title"]))
	_text.text = tr(str(entry["text"]))
	_glyph.visible = action != &""
	if action != &"":
		_glyph.set_action(action)
	_continue_label.text = tr("UNLOCK_CONTINUE") % KeyGlyph.text_for(&"interact")


func _on_language_changed(_code: StringName) -> void:
	if _open:
		_fill()


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.03, 0.02, 0.05, 0.55)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Card"
	_panel.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(Palette.UI_DARK, 0.93)
	box.border_color = Palette.GOLD
	box.set_border_width_all(3)
	box.set_corner_radius_all(18)
	box.content_margin_left = 40.0
	box.content_margin_right = 40.0
	box.content_margin_top = 28.0
	box.content_margin_bottom = 26.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	box.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", box)
	center.add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(column)
	_kicker = _make_label(SMALL_SIZE, Palette.SAFFRON)
	column.add_child(_kicker)
	_title = _make_label(TITLE_SIZE, Palette.GOLD)
	column.add_child(_title)
	_glyph_row = HBoxContainer.new()
	_glyph_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_glyph_row)
	_glyph = KeyGlyph.new()
	_glyph.custom_minimum_size = Vector2(72.0, 54.0)
	_glyph_row.add_child(_glyph)
	_text = _make_label(TEXT_SIZE, Palette.MOON)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(CARD_WIDTH - 80.0, 0.0)
	column.add_child(_text)
	_continue_row = HBoxContainer.new()
	_continue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_continue_row.add_theme_constant_override("separation", 10)
	column.add_child(_continue_row)
	_continue_label = _make_label(SMALL_SIZE, Color(Palette.MOON, 0.7))
	_continue_row.add_child(_continue_label)


func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
