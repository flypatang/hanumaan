extends Node3D
## The playable game (DESIGN §3, §9 M40). Title (New Game / Continue / Settings / Quit) -> the chapters in order
## (the prologue opens with the opening_title cutscene) -> epilogue -> teaser_setu -> credits -> title.
## ChapterFlow decides what comes next; this scene loads the levels it asks for (LevelRuntime), plays its cutscenes,
## handles Esc (pause) and keeps the save and Continue working. There is no game-over screen: an exhausted Hanuman
## is recovered by the Devotion node of the player.

const CREDITS_SECONDS: float = 6.0
const CONTINUE_BUTTON: String = "ContinueButton"
const TITLE_PANEL: String = "TitlePanel"
const UI_LAYER: int = 60

var _flow: ChapterFlow = null
var _menus: Menus = null
var _world: Node3D = null
var _runtime: LevelRuntime = null
var _ui: CanvasLayer = null
var _backdrop: ColorRect = null
var _continue: Button = null
var _credits: Control = null
var _credits_time: float = 0.0
var _playing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world = Node3D.new()
	_world.name = "World"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	_flow = ChapterFlow.new()
	_flow.name = "ChapterFlow"
	_flow.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_flow)
	_flow.level_requested.connect(_on_level_requested)
	_flow.cutscene_requested.connect(_on_cutscene_requested)
	_flow.encounter_requested.connect(_on_encounter_requested)
	_flow.all_done.connect(_show_credits)
	_build_ui()
	_show_title()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "MenuLayer"
	_ui.layer = UI_LAYER
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui)
	_backdrop = ColorRect.new()
	_backdrop.name = "TitleBackdrop"
	_backdrop.color = Palette.UI_DARK
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_backdrop)
	_menus = Menus.new()
	_menus.name = "Menus"
	_menus.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui.add_child(_menus)
	_menus.start_requested.connect(_on_new_game)
	_menus.resume_requested.connect(_resume)
	_menus.quit_to_title_requested.connect(_on_quit_to_title)
	_menus.quit_requested.connect(_on_quit)
	_add_continue_button()
	var locale: Node = get_node_or_null("/root/Locale")
	if locale != null:
		locale.connect("language_changed", _on_language_changed)


## Menus has no Continue button of its own, so one is added under New Game on the title panel.
func _add_continue_button() -> void:
	var panel: VBoxContainer = _menus.find_child(TITLE_PANEL, true, false) as VBoxContainer
	if panel == null:
		return
	_continue = Button.new()
	_continue.name = CONTINUE_BUTTON
	_continue.custom_minimum_size = Vector2(0.0, 44.0)
	_continue.pressed.connect(_on_continue)
	panel.add_child(_continue)
	var begin: Node = panel.get_node_or_null(NodePath("BeginButton"))
	panel.move_child(_continue, begin.get_index() + 1 if begin != null else 1)
	_refresh_continue()


func _refresh_continue() -> void:
	if _continue == null:
		return
	_continue.text = tr("UI_MENU_CONTINUE")
	_continue.visible = _flow.has_save()


func _on_language_changed(_code: StringName) -> void:
	_refresh_continue()


# ---------------------------------------------------------------- title and game start

func _show_title() -> void:
	_playing = false
	get_tree().paused = false
	_clear_runtime()
	if _credits != null:
		_credits.queue_free()
		_credits = null
	_backdrop.visible = true
	_menus.show_screen(Menus.Screen.TITLE)
	_refresh_continue()
	_play_music(&"calm")


func _on_new_game() -> void:
	_begin_play()
	_flow.new_game()


func _on_continue() -> void:
	_begin_play()
	if not _flow.continue_game():
		_show_title()


func _begin_play() -> void:
	_playing = true
	_menus.hide_menus()
	_backdrop.visible = false


func _on_quit() -> void:
	get_tree().quit()


func _on_quit_to_title() -> void:
	_show_title()


# ---------------------------------------------------------------- levels and cutscenes

func _on_level_requested(level_id: StringName, options: Dictionary) -> void:
	# Level swaps are often requested from a trigger's body_entered (a physics callback); building and freeing
	# collision objects there is an engine error, so swap at the end of the frame instead.
	if Engine.is_in_physics_frame():
		_load_level_now.call_deferred(level_id, options)
		return
	_load_level_now(level_id, options)


func _load_level_now(level_id: StringName, options: Dictionary) -> void:
	_clear_runtime()
	_runtime = LevelRuntime.new()
	_runtime.name = "Level_%s" % str(level_id)
	_world.add_child(_runtime)
	var err: Error = _runtime.load_level(level_id, options)
	if err != OK:
		push_error("Main: level '%s' could not be loaded (error %d)" % [str(level_id), err])
		return
	if not _runtime.game_event.is_connected(_flow.handle_event):
		_runtime.game_event.connect(_flow.handle_event)
	_runtime.cutscene_finished.connect(_flow.notify_cutscene_finished)
	_flow.notify_level_loaded(level_id, _runtime)


func _clear_runtime() -> void:
	if _runtime != null:
		_world.remove_child(_runtime)
		_runtime.queue_free()
		_runtime = null


func _on_cutscene_requested(cutscene_id: StringName) -> void:
	if _runtime == null or not _runtime.play_cutscene(cutscene_id):
		_flow.notify_cutscene_finished(cutscene_id)


func _on_encounter_requested(chapter_number: int) -> void:
	if _runtime != null:
		_runtime.begin_encounter(chapter_number)


# ---------------------------------------------------------------- pause

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	get_viewport().set_input_as_handled()
	if _credits != null:
		_show_title()
		return
	if not _playing:
		return
	if get_tree().paused:
		if _menus.current_screen() == Menus.Screen.SETTINGS:
			_menus.go_back()
		else:
			_resume()
		return
	if _runtime != null and (_runtime.input_locked() or (_runtime.player() != null and _runtime.devotion().is_exhausted())):
		return
	get_tree().paused = true
	_menus.show_screen(Menus.Screen.PAUSE)


func _resume() -> void:
	get_tree().paused = false
	_menus.hide_menus()


# ---------------------------------------------------------------- credits

func _show_credits() -> void:
	_clear_runtime()
	_playing = false
	_menus.hide_menus()
	_backdrop.visible = true
	_credits = Control.new()
	_credits.name = "Credits"
	_credits.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_credits)
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	_credits.add_child(column)
	var locale: Node = get_node_or_null("/root/Locale")
	var font: Font = null
	if locale != null:
		font = locale.call("font_for", &"ui") as Font
	for key: String in ["UI_MENU_TITLE", "UI_CREDITS_1", "UI_CREDITS_2", "UI_CREDITS_3"]:
		var line: Label = Label.new()
		line.text = ChapterFlow.text(key)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_font_size_override("font_size", 40 if key == "UI_MENU_TITLE" else 26)
		line.add_theme_color_override("font_color", Palette.GOLD if key == "UI_MENU_TITLE" else Palette.MOON)
		if font != null:
			line.add_theme_font_override("font", font)
		column.add_child(line)
	_credits_time = 0.0
	_play_music(&"calm")


func _process(delta: float) -> void:
	if _credits == null:
		return
	_credits_time += delta
	if _credits_time >= CREDITS_SECONDS and Input.is_anything_pressed():
		_show_title()


func _play_music(track: StringName) -> void:
	var music: Node = get_node_or_null("/root/Music")
	if music != null:
		music.call("play", track, 1.0)
