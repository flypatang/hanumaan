class_name TutorialDirector
extends Node
## Teaches the controls just in time (DESIGN §4.1a points 1 and 7).
##
## On Mahendra it runs the prologue sequence: move, talk to Jambavan, light attack, the 3-hit chain, heavy attack, dodge,
## grow, then the climb to the peak. Each step is a centred card with the live key glyph and a short instruction, and it
## waits for the REAL action (an input event, or the polled action state), so a step the player already did is skipped.
## The card hides during dialogue, cutscenes and unlock cards, and never asks for an ability that is not unlocked yet.
##
## In every level it also gives stuck hints (20 s without objective progress: Jambavan's voice in the prologue, the narrator
## elsewhere) and one hint per boss at its first phase change. All of it is switched off by Settings -> Tutorial hints: off.
##
## The runtime feeds it: notify_event(), notify_trigger(), notify_progress(), notify_objective(), notify_boss_phase().
## tick(delta) is the whole clock (the node calls it from _process, tests call it with fixed deltas).

signal step_changed(step_id: StringName)
signal finished
signal hint_shown(speaker_key: String, text: String)

const STEPS: Array[StringName] = [&"move", &"talk", &"light", &"chain", &"heavy", &"dodge", &"grow", &"peak"]
## step -> {action: glyph action, text: key, hint: stuck hint key (prologue), needs: ability that must be unlocked}.
const CARDS: Dictionary = {
	&"move": {"action": &"move", "text": "TUT_MOVE", "hint": "HINT_PRO_MOVE", "needs": &""},
	&"talk": {"action": &"interact", "text": "TUT_TALK", "hint": "HINT_PRO_TALK", "needs": &""},
	&"light": {"action": &"attack_light", "text": "TUT_LIGHT", "hint": "HINT_PRO_LIGHT", "needs": &""},
	&"chain": {"action": &"attack_light", "text": "TUT_CHAIN", "hint": "HINT_PRO_CHAIN", "needs": &""},
	&"heavy": {"action": &"attack_heavy", "text": "TUT_HEAVY", "hint": "HINT_PRO_HEAVY", "needs": &""},
	&"dodge": {"action": &"leap", "text": "TUT_DODGE", "hint": "HINT_PRO_DODGE", "needs": &""},
	&"grow": {"action": &"grow", "text": "TUT_GROW", "hint": "HINT_PRO_GROW", "needs": &"grow"},
	&"peak": {"action": &"", "text": "TUT_PEAK", "hint": "HINT_PRO_PEAK", "needs": &""},
}
const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
const WATCHED_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"attack_light", &"leap"]
const TALK_TARGET_RANGE: float = 3.0
const CHAIN_NEEDED: int = 3
const CHAIN_GAP: float = 1.0
const HEAVY_HOLD_SECONDS: float = 0.0  # heavy has its own button (RMB / B) since 2026-11-27: one press counts
const STUCK_SECONDS: float = 20.0
const HINT_SECONDS: float = 8.0
const MAX_STUCK_HINTS: int = 3
const PEAK_TRIGGER: StringName = &"t_leap"
const TALK_FILE: String = "dialogue:pro_jambavan"
const SIZE_LARGE: int = 2
const BOSS_FLAG_PREFIX: String = "hint_boss_"
const CARD_FONT_SIZE: int = 28
const HINT_FONT_SIZE: int = 22
const FADE_SPEED: float = 6.0

## Settings -> Tutorial hints. When false nothing is shown and nothing is counted.
var enabled: bool = true
## Stuck hints (20 s without progress). Off in the on-rails leap.
var stuck_hints_enabled: bool = true
## True on Mahendra during the prologue: the step cards run and stuck hints speak in Jambavan's voice.
var prologue: bool = false
## Returns true while a dialogue, cutscene or card holds the player (the runtime passes `input_locked`).
var locked: Callable = Callable()
## Overrides the GameState autoload (tests).
var game_state: Node = null

var _player: Node3D = null
var _talk_target: Node3D = null
var _index: int = 0
var _seen: Dictionary = {}
var _event_frame: Dictionary = {}
var _chain_count: int = 0
var _chain_age: float = 99.0
var _heavy_hold: float = 0.0
var _idle: float = 0.0
var _stuck_hints: int = 0
var _hint_left: float = 0.0
var _objectives: Dictionary = {}
var _objective_order: Array[StringName] = []
var _boss_hinted: Dictionary = {}
var _finished: bool = false

var _layer: Control = null
var _card: PanelContainer = null
var _card_glyph: KeyGlyph = null
var _card_label: Label = null
var _card_alpha: float = 0.0
var _hint: PanelContainer = null
var _hint_speaker: Label = null
var _hint_text: Label = null
var _hint_alpha: float = 0.0


func _init() -> void:
	name = "TutorialDirector"


func _ready() -> void:
	set_process_input(true)


func _process(delta: float) -> void:
	if enabled:
		_poll_actions()
	tick(delta)


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	for action: StringName in WATCHED_ACTIONS:
		if event.is_action_pressed(action):
			_event_frame[action] = Engine.get_process_frames()
			_register_press(action)


# ---------------------------------------------------------------- setup

## Builds the card and the hint banner under `ui_parent` (a Control or CanvasLayer child) and starts tracking `player`.
## `talk_target` is Jambavan, the node the talk step walks to (null outside the prologue).
func setup(ui_parent: Node, player: Node3D, talk_target: Node3D, is_prologue: bool) -> void:
	_player = player
	_talk_target = talk_target
	prologue = is_prologue
	_layer = Control.new()
	_layer.name = "TutorialLayer"
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_parent.add_child(_layer)
	_build_card()
	_build_hint()
	_index = 0
	_skip_done_steps()
	_refresh_card()


# ---------------------------------------------------------------- queries

func current_step() -> StringName:
	if _index >= STEPS.size():
		return &""
	return STEPS[_index]


func is_finished() -> bool:
	return _finished


## True while the step card is on screen (wanted, not suppressed, not finished).
func card_visible() -> bool:
	return _card_wanted() and _card.visible


func card_text() -> String:
	return _card_label.text


## The action whose glyph the card shows ("" when the step has no key).
func card_action() -> StringName:
	return _card_glyph.action() if _card_glyph.visible else &""


func card_glyph_text() -> String:
	return _card_glyph.shown_text() if _card_glyph.visible else ""


func hint_visible() -> bool:
	return _hint_left > 0.0


func hint_text() -> String:
	return _hint_text.text


func hint_speaker() -> String:
	return _hint_speaker.text


func idle_seconds() -> float:
	return _idle


func has_seen(key: StringName) -> bool:
	return _seen.get(key, false) as bool


func chain_count() -> int:
	return _chain_count


# ---------------------------------------------------------------- notifications from the runtime

## Any LevelRuntime game_event ("dialogue:<file>", "objective:<id>", "search:<id>" ...).
func notify_event(event_name: String) -> void:
	notify_progress()
	if event_name == TALK_FILE:
		_mark(&"talk")


## A level trigger fired.
func notify_trigger(trigger_id: StringName) -> void:
	notify_progress()
	if trigger_id == &"t_jambavan":
		_mark(&"talk")
	elif trigger_id == PEAK_TRIGGER:
		_mark(&"peak")


## Something that counts as progress happened: the stuck timer starts again.
func notify_progress() -> void:
	_idle = 0.0


func notify_objective(id: StringName, text: String, done: bool) -> void:
	notify_progress()
	if not _objectives.has(id):
		_objective_order.append(id)
	_objectives[id] = {"text": text, "done": done}


## A boss changed phase. `kind` is the enemy kind ("boss_lankini"); each boss gets one hint, ever.
func notify_boss_phase(kind: String) -> void:
	if not enabled or _boss_hinted.has(kind):
		return
	var key: String = "HINT_%s" % kind.to_upper()
	var flag: StringName = StringName(BOSS_FLAG_PREFIX + kind)
	var state: Node = _state()
	if state != null and state.call("get_flag", flag, false) as bool:
		_boss_hinted[kind] = true
		return
	_boss_hinted[kind] = true
	if state != null:
		state.call("set_flag", flag, true)
	var line: String = tr(key)
	if line == key:
		return
	if kind == "boss_simhika":
		line = line % KeyGlyph.text_for(&"shrink")
	_show_hint("HINT_SPEAKER_NARRATOR", line)


# ---------------------------------------------------------------- the clock

func tick(delta: float) -> void:
	if not enabled:
		_apply_visibility(delta, false, false)
		return
	_chain_age += delta
	var held: bool = locked.is_valid() and locked.call() as bool
	if not held:
		_track_heavy(delta)
		_track_size()
		_idle += delta
		if stuck_hints_enabled and _idle >= STUCK_SECONDS and _stuck_hints < MAX_STUCK_HINTS:
			_stuck_hint()
	_skip_done_steps()
	if _hint_left > 0.0:
		_hint_left = maxf(_hint_left - delta, 0.0)
	_apply_visibility(delta, _card_wanted() and not held, _hint_left > 0.0)


# ---------------------------------------------------------------- the steps

## Presses made with Input.action_press (no input event, as the playthrough bot does) are found by polling each frame.
## A press that already arrived as an event this frame is not counted twice.
func _poll_actions() -> void:
	var frame: int = Engine.get_process_frames()
	for action: StringName in WATCHED_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action) and _event_frame.get(action, -1) != frame:
			_register_press(action)


## One press of a watched action.
func _register_press(action: StringName) -> void:
	if MOVE_ACTIONS.has(action):
		_mark(&"move")
	elif action == &"attack_light":
		_mark(&"light")
		_chain_count = _chain_count + 1 if _chain_age <= CHAIN_GAP else 1
		_chain_age = 0.0
		if _chain_count >= CHAIN_NEEDED:
			_mark(&"chain")
	elif action == &"leap":
		_mark(&"dodge")


## The heavy attack is its own button (RMB / gamepad B): pressing it at the heavy step counts.
func _track_heavy(delta: float) -> void:
	if current_step() != &"heavy" or not InputMap.has_action(&"attack_heavy"):
		_heavy_hold = 0.0
		return
	if Input.is_action_pressed(&"attack_heavy"):
		_heavy_hold += delta
		if _heavy_hold > HEAVY_HOLD_SECONDS:
			_mark(&"heavy")
	else:
		_heavy_hold = 0.0


func _track_size() -> void:
	if _player != null and is_instance_valid(_player) and (_player.get_meta(&"size_state", 1) as int) >= SIZE_LARGE:
		_mark(&"grow")


func _mark(key: StringName) -> void:
	if not _seen.get(key, false) as bool:
		_seen[key] = true
		_idle = 0.0
		_skip_done_steps()


func _skip_done_steps() -> void:
	while _index < STEPS.size() and has_seen(STEPS[_index]):
		_index += 1
		_idle = 0.0
		_refresh_card()
		if _index < STEPS.size():
			step_changed.emit(STEPS[_index])
	if _index >= STEPS.size() and not _finished:
		_finished = true
		finished.emit()


func _card_wanted() -> bool:
	if not enabled or not prologue or _finished or _index >= STEPS.size():
		return false
	var needs: StringName = (CARDS[STEPS[_index]] as Dictionary)["needs"] as StringName
	if needs != &"":
		var state: Node = _state()
		if state == null or not (state.call("is_unlocked", needs) as bool):
			return false
	return true


func _refresh_card() -> void:
	if _card == null or _index >= STEPS.size():
		return
	var step: StringName = STEPS[_index]
	var entry: Dictionary = CARDS[step] as Dictionary
	var action: StringName = entry["action"] as StringName
	var key: String = entry["text"] as String
	if step == &"talk" and not _near_talk_target():
		key = "TUT_TALK_GO"
		action = &""
	_card_glyph.visible = action != &""
	if action != &"":
		_card_glyph.set_action(action)
	var text: String = tr(key)
	if step == &"chain":
		text = text % mini(_chain_count, CHAIN_NEEDED)
	_card_label.text = text


func _near_talk_target() -> bool:
	if _player == null or _talk_target == null or not is_instance_valid(_player) or not is_instance_valid(_talk_target):
		return true
	var offset: Vector3 = _talk_target.global_position - _player.global_position
	offset.y = 0.0
	return offset.length() <= TALK_TARGET_RANGE


# ---------------------------------------------------------------- hints

func _stuck_hint() -> void:
	_idle = 0.0
	_stuck_hints += 1
	if prologue and _index < STEPS.size():
		var step: StringName = STEPS[_index]
		var entry: Dictionary = CARDS[step] as Dictionary
		var line: String = tr(entry["hint"] as String)
		if line.contains("%s"):
			var action: StringName = entry["action"] as StringName
			line = line % KeyGlyph.text_for(action if action != &"" else &"interact")
		_show_hint("HINT_SPEAKER_JAMBAVAN", line)
		return
	_show_hint("HINT_SPEAKER_NARRATOR", _narrator_line())


func _narrator_line() -> String:
	for i: int in range(_objective_order.size() - 1, -1, -1):
		var entry: Dictionary = _objectives[_objective_order[i]] as Dictionary
		if not (entry["done"] as bool):
			return tr("HINT_NARR_TASK") % ChapterFlow.text(entry["text"] as String)
	return tr("HINT_NARR_NONE")


func _show_hint(speaker_key: String, text: String) -> void:
	if not enabled:
		return
	_hint_speaker.text = tr(speaker_key)
	_hint_text.text = text
	_hint_left = HINT_SECONDS
	hint_shown.emit(speaker_key, text)


func _apply_visibility(delta: float, card_on: bool, hint_on: bool) -> void:
	if _card == null:
		return
	if card_on:
		_refresh_card()
	_card_alpha = move_toward(_card_alpha, 1.0 if card_on else 0.0, delta * FADE_SPEED)
	_card.modulate = Color(1.0, 1.0, 1.0, _card_alpha)
	_card.visible = _card_alpha > 0.01
	_hint_alpha = move_toward(_hint_alpha, 1.0 if hint_on else 0.0, delta * FADE_SPEED)
	_hint.modulate = Color(1.0, 1.0, 1.0, _hint_alpha)
	_hint.visible = _hint_alpha > 0.01


# ---------------------------------------------------------------- building the UI

func _build_card() -> void:
	_card = PanelContainer.new()
	_card.name = "StepCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 0)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.offset_top = 96.0
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(Palette.UI_DARK, 0.86)
	box.border_color = Palette.GOLD
	box.set_border_width_all(2)
	box.set_corner_radius_all(16)
	box.content_margin_left = 22.0
	box.content_margin_right = 30.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	box.shadow_size = 10
	_card.add_theme_stylebox_override("panel", box)
	_layer.add_child(_card)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	_card_glyph = KeyGlyph.new()
	_card_glyph.custom_minimum_size = Vector2(64.0, 54.0)
	row.add_child(_card_glyph)
	_card_label = _make_label(CARD_FONT_SIZE, Palette.MOON)
	row.add_child(_card_label)


func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint.name = "HintBanner"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 0)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -150.0
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(Palette.UI_DARK, 0.84)
	box.border_color = Color(Palette.SAFFRON, 0.9)
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.content_margin_left = 26.0
	box.content_margin_right = 26.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 12.0
	_hint.add_theme_stylebox_override("panel", box)
	_layer.add_child(_hint)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(column)
	_hint_speaker = _make_label(HINT_FONT_SIZE - 2, Palette.GOLD)
	column.add_child(_hint_speaker)
	_hint_text = _make_label(HINT_FONT_SIZE, Palette.MOON)
	_hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_text.custom_minimum_size = Vector2(620.0, 0.0)
	column.add_child(_hint_text)


func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.UI_DARK)
	label.add_theme_constant_override("outline_size", 3)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var locale: Node = tree.root.get_node_or_null("Locale") if tree != null else null
	if locale != null:
		var font: Font = locale.call("font_for", &"ui") as Font
		if font != null:
			label.add_theme_font_override("font", font)
	return label


func _state() -> Node:
	if game_state != null:
		return game_state
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameState")
