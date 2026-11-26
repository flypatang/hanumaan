class_name WorldPrompt
extends Control
## A floating prompt (glyph + verb) over whatever the player can use within SHOW_RANGE metres (DESIGN §4.1a point 2).
## Targets are registered by LevelRuntime: a Node3D, a verb (talk / meditate / examine) and the action that does it.
## The prompt shows for the nearest target in range, follows it on screen, and hides while play is locked (dialogue,
## cutscenes, cards). After the player has used a verb RETIRE_AFTER times it stops showing, except for targets
## registered with `always = true` (shrines). Use counts are saved in GameState flags ("prompt_uses_<verb>").

const SHOW_RANGE: float = 3.0
const RETIRE_AFTER: int = 3
const FLAG_PREFIX: String = "prompt_uses_"
const TEXT_PREFIX: String = "PROMPT_"
const LIFT: float = 2.3
const FONT_SIZE: int = 22
const FAR_ALPHA: float = 0.55
const FADE_SPEED: float = 8.0
const BOB_PIXELS: float = 5.0

## Returns true while the prompt must stay hidden (the runtime passes `input_locked`).
var suppressed: Callable = Callable()
## Overrides the GameState autoload (tests).
var game_state: Node = null

var _player: Node3D = null
var _camera: Camera3D = null
var _targets: Array[Dictionary] = []
var _current: int = -1
var _local_uses: Dictionary = {}
var _time: float = 0.0
var _alpha: float = 0.0
var _panel: PanelContainer = null
var _glyph: KeyGlyph = null
var _label: Label = null


func _init() -> void:
	name = "WorldPrompt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _ready() -> void:
	var locale: Node = get_node_or_null(^"/root/Locale")
	if locale != null:
		var font: Font = locale.call("font_for", &"ui") as Font
		if font != null:
			_label.add_theme_font_override("font", font)


func _process(delta: float) -> void:
	advance(delta)


## Points the prompt at the player and the camera used to project targets onto the screen.
func bind(player: Node3D, camera: Camera3D) -> void:
	_player = player
	_camera = camera


## Registers a target. `verb` is a StringName such as &"talk"; its text is the key PROMPT_<VERB>.
func add_target(node: Node3D, verb: StringName, action: StringName = &"interact", always: bool = false, lift: float = LIFT) -> void:
	_targets.append({"node": node, "verb": verb, "action": action, "always": always, "lift": lift})


func remove_target(node: Node3D) -> void:
	for i: int in range(_targets.size() - 1, -1, -1):
		if _targets[i]["node"] == node:
			_targets.remove_at(i)
	_current = -1


func target_count() -> int:
	return _targets.size()


## How often the player has used `verb` (saved in GameState flags, so it survives saving and loading).
func uses(verb: StringName) -> int:
	var state: Node = _state()
	if state != null:
		return state.call("get_flag", StringName(FLAG_PREFIX + str(verb)), 0) as int
	return _local_uses.get(verb, 0) as int


func register_use(verb: StringName) -> void:
	var count: int = uses(verb) + 1
	var state: Node = _state()
	if state != null:
		state.call("set_flag", StringName(FLAG_PREFIX + str(verb)), count)
	else:
		_local_uses[verb] = count


func is_retired(verb: StringName) -> bool:
	return uses(verb) >= RETIRE_AFTER


## The node the prompt is showing for, or null.
func current_target() -> Node3D:
	if _current < 0 or _current >= _targets.size():
		return null
	return _targets[_current]["node"] as Node3D


func current_verb() -> StringName:
	if _current < 0 or _current >= _targets.size():
		return &""
	return _targets[_current]["verb"] as StringName


func current_action() -> StringName:
	if _current < 0 or _current >= _targets.size():
		return &""
	return _targets[_current]["action"] as StringName


## True when a prompt is wanted right now (a target in range, not suppressed, not retired).
func is_showing() -> bool:
	return _current >= 0


func verb_text() -> String:
	return _label.text


func glyph() -> KeyGlyph:
	return _glyph


## Picks the nearest target in range and moves the widget. The node calls this from _process; tests call it directly.
func advance(delta: float) -> void:
	_time += delta
	_current = _pick()
	var wanted: float = 0.0
	if _current >= 0:
		var entry: Dictionary = _targets[_current]
		_glyph.set_action(entry["action"] as StringName)
		_label.text = _verb_text(entry["verb"] as StringName)
		var near: bool = _distance(entry["node"] as Node3D) <= Player.INTERACT_RANGE
		wanted = 1.0 if near else FAR_ALPHA
		_place(entry)
	_alpha = move_toward(_alpha, wanted, delta * FADE_SPEED)
	_panel.modulate = Color(1.0, 1.0, 1.0, _alpha)
	_panel.visible = _alpha > 0.01


func _pick() -> int:
	if _player == null or not is_instance_valid(_player):
		return -1
	if suppressed.is_valid() and suppressed.call() as bool:
		return -1
	var best: int = -1
	var best_distance: float = SHOW_RANGE
	for i: int in _targets.size():
		var entry: Dictionary = _targets[i]
		var node: Node3D = entry["node"] as Node3D
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			continue
		if not (entry["always"] as bool) and is_retired(entry["verb"] as StringName):
			continue
		var d: float = _distance(node)
		if d <= best_distance:
			best_distance = d
			best = i
	return best


func _distance(node: Node3D) -> float:
	var offset: Vector3 = node.global_position - _player.global_position
	offset.y = 0.0
	return offset.length()


func _place(entry: Dictionary) -> void:
	if _camera == null or not is_instance_valid(_camera) or not _camera.is_inside_tree():
		return
	var node: Node3D = entry["node"] as Node3D
	var world: Vector3 = node.global_position + Vector3(0.0, entry["lift"] as float, 0.0)
	if _camera.is_position_behind(world):
		return
	var screen: Vector2 = _camera.unproject_position(world)
	var bob: float = sin(_time * 3.0) * BOB_PIXELS
	_panel.reset_size()
	_panel.position = Vector2(screen.x - _panel.size.x * 0.5, screen.y - _panel.size.y + bob)


func _verb_text(verb: StringName) -> String:
	return tr(TEXT_PREFIX + str(verb).to_upper())


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Pill"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(Palette.UI_DARK, 0.78)
	box.border_color = Color(Palette.GOLD, 0.9)
	box.set_border_width_all(2)
	box.set_corner_radius_all(24)
	box.content_margin_left = 8.0
	box.content_margin_right = 18.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	box.shadow_size = 6
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_glyph = KeyGlyph.new()
	row.add_child(_glyph)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Palette.MOON)
	_label.add_theme_color_override("font_outline_color", Palette.UI_DARK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)


func _state() -> Node:
	if game_state != null:
		return game_state
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameState")
