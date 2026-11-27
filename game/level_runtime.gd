class_name LevelRuntime
extends Node3D
## One playable level (DESIGN §3, §5, §9 M40). load_level(id) builds levels/<id>.json with LevelBuilder, then adds
## lighting, the Player (SizeShift + Devotion children), an IsoCamera that follows him, the HUD, the dialogue box, a
## cutscene player, enemies (through a factory), static NPCs, Shrines, a StealthDirector, a FireSystem and an
## EncounterDirector. Every Trigger Area3D is routed by its on_enter text:
##   dialogue:<file>[#node]  cutscene:<id>  level:<id>  objective:<id>  search:<id>  chapter_complete:<id>
## Everything that happens is also announced through the generic `game_event(name)` signal, which ChapterFlow reads.
## The leap (levels/ocean_leap.json has no tiles) builds a LeapController, a flying rider and a chase camera instead.
## There is no game-over state: the Devotion node recovers an exhausted Hanuman at the last shrine (DESIGN §2).

signal loaded(level_id: StringName)
signal level_exit(level_id: StringName)
signal searched(search_id: StringName)
signal chapter_complete(chapter_id: StringName)
signal trigger_fired(trigger_id: StringName, on_enter: String)
signal cutscene_finished(cutscene_id: StringName)
signal dialogue_done(file_id: StringName)
signal game_event(event_name: String)

const LEVELS_DIR: String = "res://levels/"
const LEAP_LEVEL: StringName = &"ocean_leap"
const NIGHT_PREFIX: String = "lanka_"
const PLAYER_GROUP: StringName = &"player"
const OCCLUDER_GROUP: StringName = &"occluder"
const START_SMARANA: float = 60.0
const SPAWN_LIFT: float = 0.1
const CAMERA_SIZE: float = 7.5  # closer framing so the v2 Hanuman reads (owner review 2026-11-26)
## Per-level base framing (ortho size) and a zoom factor per Hanuman size, so a cat-sized Hanuman is never a speck
## and a giant one stays in frame (director review 2026-11-26).
const LEVEL_CAMERA_SIZE: Dictionary = {"lanka_streets": 9.5, "lanka_rooftops": 12.5, "ashoka_vatika": 9.5}
const SIZE_ZOOM: Dictionary = {0: 0.7, 1: 1.0, 2: 1.6, 3: 2.6}
const NIGHT_LEVELS: Array[String] = ["ashoka_vatika", "ravana_court"]
const WALKABLE: Array[String] = ["ground", "stone_floor", "grass", "sand"]
const SPAWN_SEARCH_RADIUS: int = 24
const NIGHT_AMBIENT_ENERGY: float = 1.9
const NIGHT_SUN_ENERGY: float = 0.32
const DAY_AMBIENT_ENERGY: float = 0.4
const DAY_SUN_ENERGY: float = 0.8
const TAIL_FIRE_RADIUS: float = 2.4
const FADE_CLEAR_TIME: float = 0.6
const NPC_PREFIX: String = "npc_"
const BOSS_PREFIX: String = "boss_"
const OCCLUDING_KINDS: Array[String] = ["wall", "tier_house", "gopuram", "rooftop"]
const ENEMY_KINDS: Array[String] = [
	"guard_spear", "guard_archer", "kinkara", "boss_lankini", "boss_jambumali", "boss_akshaya", "boss_simhika",
]
const GUARD_KINDS: Array[String] = ["guard_spear", "guard_archer"]
## Dialogue / cutscene flags that unlock abilities.
const FLAG_UNLOCKS: Dictionary = {
	"grow_unlocked": "grow",
	"shrink_unlocked": "shrink",
	"surge_unlocked": "surge",
	"tail_fire": "tail_fire",
}
const SPAWN_META_SKIP: Array[String] = ["id", "kind", "pos", "facing"]
const FLIGHT_POSE: StringName = &"attack_strike"
## Abilities that get an unlock card (DESIGN §4.1a point 3) and the GameState flag that remembers the card was shown.
const CARD_ABILITIES: Array[StringName] = [&"grow", &"shrink", &"surge", &"tail_fire"]
const CARD_FLAG_PREFIX: String = "unlock_card_"
## Dialogue triggers that wait for the Interact key near their NPC while tutorial hints are on: trigger id -> actor id.
const TALK_GATES: Dictionary = {"t_jambavan": "jambavan"}
const PROLOGUE_TRIGGER: StringName = &"t_jambavan"
const BEACON_REFRESH: float = 0.25
const NPC_BODY_DEFAULT: Vector2 = Vector2(0.45, 1.8)
## Collision capsule (radius, height) of the NPCs that are bigger than a person.
const NPC_BODIES: Dictionary = {"jambavan": Vector2(0.7, 2.3), "ravana": Vector2(0.9, 2.8), "sita": Vector2(0.4, 1.7)}
const BOSS_HINT_FRACTION: float = 0.66
const TALK_FLAG: StringName = &"grow_unlocked"

## Tests and tools switch these off. Music builds its tracks lazily and is not needed headless.
var music_enabled: bool = true
## Overrides the autoload lookups (tests). When null, /root/<Name> is used.
var event_bus: Node = null
var game_state: Node = null

var _level_id: StringName = &""
var _level_root: Node3D = null
var _options: Dictionary = {}
var _player: Player = null
var _size_shift: SizeShift = null
var _devotion: Devotion = null
var _camera: IsoCamera = null
var _hud: Hud = null
var _dialogue_box: DialogueBox = null
var _cutscene: CutscenePlayer = null
var _encounter: EncounterDirector = null
var _fire: FireSystem = null
var _stealth: StealthDirector = null
var _leap: LeapController = null
var _rider: Node3D = null
var _ui_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _prompt_label: Label = null
var _shloka_card: ShlokaCard = null
var _cut_camera: Camera3D = null
var _actors: Dictionary = {}
var _triggers: Dictionary = {}
var _fired: Dictionary = {}
var _flammable: Array[Node3D] = []
var _pillars: Array[Vector3] = []
var _lock_depth: int = 0
var _bound: bool = false
var _tail_fire: bool = false
var _cutscene_dialogue: bool = false
var _spawn_position: Vector3 = Vector3.ZERO
var _tiles: Dictionary = {}
var _fade_tween: Tween = null
var _step_time: float = 0.0
var _prompt: WorldPrompt = null
var _unlock_card: UnlockCard = null
var _controls: ControlsScreen = null
var _tutorial: TutorialDirector = null
var _talk_nodes: Dictionary = {}
var _beacon: ObjectiveBeacon = null
var _beacon_clock: float = 0.0
var _beacon_locked: bool = false
## PX1 (experiment): the low-resolution view of the 'pixel' visual style, or null in the 'painterly' style.
var _pixel_view: PixelView = null
## A style chosen with set_visual_style(); empty means "use the saved Settings choice".
var _style_choice: StringName = &""


# ---------------------------------------------------------------- accessors

func player() -> Player:
	return _player


func camera() -> IsoCamera:
	return _camera


func hud() -> Hud:
	return _hud


func dialogue_box() -> DialogueBox:
	return _dialogue_box


func cutscene_player() -> CutscenePlayer:
	return _cutscene


func encounter() -> EncounterDirector:
	return _encounter


func fire() -> FireSystem:
	return _fire


func stealth() -> StealthDirector:
	return _stealth


func leap() -> LeapController:
	return _leap


func rider() -> Node3D:
	return _rider


func size_shift() -> SizeShift:
	return _size_shift


func devotion() -> Devotion:
	return _devotion


func world_prompt() -> WorldPrompt:
	return _prompt


func unlock_card() -> UnlockCard:
	return _unlock_card


func controls_screen() -> ControlsScreen:
	return _controls


func tutorial() -> TutorialDirector:
	return _tutorial


## The PixelView that shows the world as 3D pixel art, or null while the style is 'painterly' (PX1).
func pixel_view() -> PixelView:
	return _pixel_view


## "painterly" or "pixel": the style the next (or the current) level is shown in.
func visual_style() -> StringName:
	if _style_choice != &"":
		return _style_choice
	return StringName(Menus.visual_style())


## Switches the visual style now and for the levels loaded later. Menus calls it (through the group
## Menus.VISUAL_STYLE_GROUP) when the player changes Settings -> Visual style. Unknown styles are ignored.
func set_visual_style(style: StringName) -> void:
	if not Menus.VISUAL_STYLES.has(String(style)):
		return
	_style_choice = style
	_apply_visual_style()


func level_id() -> StringName:
	return _level_id


func level_root() -> Node3D:
	return _level_root


func spawn_position() -> Vector3:
	return _spawn_position


func actors() -> Dictionary:
	return _actors


func options() -> Dictionary:
	return _options


func trigger_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in _triggers.keys():
		out.append(StringName(str(key)))
	return out


# ---------------------------------------------------------------- loading

## Builds the level. `options` may hold: size ("small"/"normal"), skip_triggers (Array of trigger ids),
## encounter_chapter (int, not started here: see begin_encounter), extra_npcs (Array of {id, pos, facing}).
func load_level(id: StringName, options: Dictionary = {}) -> Error:
	var path: String = "%s%s.json" % [LEVELS_DIR, str(id)]
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return ERR_PARSE_ERROR
	_clear()
	_level_id = id
	_options = options
	var data: Dictionary = parsed as Dictionary
	_build_ui()
	if id == LEAP_LEVEL:
		_load_leap()
	else:
		_load_world(data, id)
	_apply_visual_style()
	_announce_loaded()
	return OK


## Frees everything built by load_level.
func unload() -> void:
	_clear()


func _clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_level_root = null
	_player = null
	_size_shift = null
	_devotion = null
	_camera = null
	_hud = null
	_dialogue_box = null
	_cutscene = null
	_encounter = null
	_fire = null
	_stealth = null
	_leap = null
	_rider = null
	_ui_layer = null
	_fade_rect = null
	_prompt_label = null
	_shloka_card = null
	_prompt = null
	_unlock_card = null
	_controls = null
	_tutorial = null
	_talk_nodes = {}
	_beacon = null
	_beacon_clock = 0.0
	_pixel_view = null
	_cut_camera = null
	_actors = {}
	_triggers = {}
	_fired = {}
	_flammable = []
	_pillars = []
	_tiles = {}
	_lock_depth = 0
	_bound = false
	_tail_fire = false
	_cutscene_dialogue = false


func _enter_tree() -> void:
	add_to_group(Menus.VISUAL_STYLE_GROUP)


## Adds or removes the PixelView so the loaded level matches visual_style(). The world is not re-parented: the
## view renders the same World3D at low resolution below the HUD and dialogue layers, which stay full resolution.
func _apply_visual_style() -> void:
	var wanted: bool = _ui_layer != null and visual_style() == &"pixel"
	if wanted == (_pixel_view != null):
		return
	if wanted:
		_pixel_view = PixelView.new()
		_pixel_view.name = "PixelView"
		add_child(_pixel_view)
	else:
		remove_child(_pixel_view)
		_pixel_view.queue_free()
		_pixel_view = null


func _announce_loaded() -> void:
	var bus: Node = _bus()
	if bus != null:
		bus.emit_signal("level_loaded", _level_id)
	_music_for_level()
	loaded.emit(_level_id)


func _load_world(data: Dictionary, id: StringName) -> void:
	_read_tiles(data)
	_level_root = LevelBuilder.build(data)
	add_child(_level_root)
	_build_bounds()
	Look.apply_for_level(id, self)  # Art Direction v2 mood lighting (F1)
	_make_occluders()
	_collect_props()
	_hud = Hud.new()
	_hud.name = "Hud"
	add_child(_hud)
	_build_directors()
	_spawn_shrines()
	_spawn_from_markers(data)
	_connect_triggers()
	_ensure_shrine_record()
	_apply_sync_unlocks()
	_build_teaching()
	_build_beacon()


# ---------------------------------------------------------------- UI, dialogue and cutscenes

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UiLayer"
	_ui_layer.layer = 20
	add_child(_ui_layer)
	_dialogue_box = DialogueBox.new()
	_dialogue_box.name = "DialogueBox"
	_dialogue_box.shloka_mode = StringName(Menus.shloka_cards_mode())
	_ui_layer.add_child(_dialogue_box)
	_dialogue_box.finished.connect(_on_dialogue_finished)
	_shloka_card = ShlokaCard.new()
	_shloka_card.name = "CutsceneShlokaCard"
	_shloka_card.mode = StringName(Menus.shloka_cards_mode())
	_ui_layer.add_child(_shloka_card)
	_shloka_card.closed.connect(_on_cutscene_card_closed)
	_prompt_label = Label.new()
	_prompt_label.name = "Prompt"
	_prompt_label.add_theme_font_size_override("font_size", 34)
	_prompt_label.add_theme_color_override("font_color", Palette.GOLD)
	_prompt_label.add_theme_color_override("font_outline_color", Palette.UI_DARK)
	_prompt_label.add_theme_constant_override("outline_size", 8)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_prompt_label.custom_minimum_size = Vector2(900.0, 0.0)
	_prompt_label.position.x -= 450.0
	_prompt_label.position.y = 120.0
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.visible = false
	_ui_layer.add_child(_prompt_label)
	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"
	_fade_rect.color = Color(Palette.UI_DARK, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_fade_rect)
	KeyGlyph.ensure_actions()
	_unlock_card = UnlockCard.new()
	_ui_layer.add_child(_unlock_card)
	_unlock_card.closed.connect(_on_unlock_card_closed)
	_controls = ControlsScreen.new()
	_controls.game_state = _state()
	_ui_layer.add_child(_controls)
	_cutscene = CutscenePlayer.new()
	_cutscene.name = "CutscenePlayer"
	add_child(_cutscene)
	_cutscene.dialogue_requested.connect(_on_cutscene_dialogue)
	_cutscene.shloka_requested.connect(_on_cutscene_shloka)
	_cutscene.fade_requested.connect(_on_cutscene_fade)
	_cutscene.flag_set.connect(_on_cutscene_flag)
	_cutscene.finished.connect(_on_cutscene_finished)


## Shows a centred prompt line (for example the Surasa "Shrink!" cue). An empty text hides it.
func show_prompt(text: String) -> void:
	if _prompt_label == null:
		return
	_prompt_label.text = text
	_prompt_label.visible = text != ""


## The centred prompt line as shown (empty when hidden).
func prompt_text() -> String:
	return _prompt_label.text if _prompt_label != null and _prompt_label.visible else ""


## Plays data/dialogue/<file>[#node]. Returns false when it could not start.
func play_dialogue(file_and_node: String) -> bool:
	if _dialogue_box == null:
		return false
	if _dialogue_box.is_playing():
		return false  # never restart a conversation that is already on screen (e.g. walking back into its trigger)
	var err: Error = _dialogue_box.play(StringName(file_and_node), &"")
	if err != OK:
		push_warning("LevelRuntime: dialogue '%s' did not start (error %d)" % [file_and_node, err])
		return false
	_lock_input(true)
	_playing_ref = file_and_node
	var bus: Node = _bus()
	if bus != null:
		bus.emit_signal("dialogue_started", StringName(file_and_node.get_slice("#", 0)))
	return true


## Plays data/cutscenes/<id>.json. The player is locked until it finishes.
func play_cutscene(cutscene_id: StringName) -> bool:
	if _cutscene == null or _cutscene.is_playing():
		return false
	_lock_input(true)
	_begin_cut_camera()
	var err: Error = _cutscene.play(cutscene_id, _actors, _cut_camera)
	if err != OK:
		push_warning("LevelRuntime: cutscene '%s' did not start (error %d)" % [str(cutscene_id), err])
		_end_cut_camera()
		_lock_input(false)
		return false
	return true


func _begin_cut_camera() -> void:
	if _cut_camera != null:
		return
	_cut_camera = Camera3D.new()
	_cut_camera.name = "CutsceneCamera"
	_cut_camera.fov = 50.0
	_cut_camera.far = 800.0
	add_child(_cut_camera)
	if _camera != null and _camera.get_camera() != null:
		_cut_camera.global_transform = _camera.get_camera().global_transform
	elif _rider != null:
		_cut_camera.global_position = _rider.global_position + Vector3(0.0, 6.0, 16.0)
	_cut_camera.make_current()
	if _camera != null:
		_camera.locked = true


func _end_cut_camera() -> void:
	if _cut_camera != null:
		_cut_camera.queue_free()
		_cut_camera = null
	if _camera != null and _camera.get_camera() != null:
		_camera.get_camera().make_current()
		_camera.locked = false


func _on_cutscene_dialogue(id: StringName, node: StringName) -> void:
	_cutscene_dialogue = true
	var file: String = str(id)
	if node != &"":
		file = "%s#%s" % [file, str(node)]
	if not play_dialogue(file):
		_cutscene_dialogue = false
		_cutscene.continue_after_ui()


func _on_cutscene_shloka(id: StringName) -> void:
	if _shloka_card == null:
		_cutscene.continue_after_ui()
		return
	_shloka_card.mode = StringName(Menus.shloka_cards_mode())
	_shloka_card.show_shloka(id)
	if not _shloka_card.is_open():
		_cutscene.continue_after_ui()
	else:
		SoundPlayer.cue(self, &"shloka_open")


func _on_cutscene_card_closed(_id: StringName) -> void:
	if _cutscene != null and _cutscene.is_awaiting_ui():
		_cutscene.continue_after_ui()


func _on_cutscene_fade(color: Color, duration: float, fade_out: bool) -> void:
	if _fade_rect == null:
		return
	if _fade_tween != null:
		_fade_tween.kill()
	var from_alpha: float = 0.0 if fade_out else 1.0
	var to_alpha: float = 1.0 if fade_out else 0.0
	_fade_rect.color = Color(color, from_alpha)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", to_alpha, maxf(duration, 0.01))


func _on_cutscene_flag(key: StringName, value: Variant) -> void:
	var gs: Node = _state()
	if gs != null:
		gs.call("set_flag", key, value)
	_apply_sync_unlocks()
	game_event.emit("flag:%s" % str(key))


func _on_cutscene_finished(id: StringName) -> void:
	_end_cut_camera()
	_lock_input(false)
	if _fade_rect != null and _fade_rect.color.a > 0.0:
		if _fade_tween != null:
			_fade_tween.kill()
		_fade_tween = create_tween()
		_fade_tween.tween_property(_fade_rect, "color:a", 0.0, FADE_CLEAR_TIME)
	cutscene_finished.emit(id)
	game_event.emit("cutscene:%s" % str(id))


var _playing_ref: String = ""


func _dialogue_done(ref: String) -> bool:
	var gs: Node = _state()
	return gs != null and (gs.call("get_flag", StringName("dlg_done_" + ref), false) as bool)


func _on_dialogue_finished(file_id: StringName) -> void:
	var gs: Node = _state()
	if gs != null and _playing_ref != "":
		gs.call("set_flag", StringName("dlg_done_" + _playing_ref), true)
	_playing_ref = ""
	var flags: Dictionary = {}
	if gs != null:
		flags = gs.get("flags") as Dictionary
	_apply_sync_unlocks()
	_lock_input(false)
	var bus: Node = _bus()
	if bus != null:
		bus.emit_signal("dialogue_finished", file_id, flags)
	if _cutscene_dialogue:
		_cutscene_dialogue = false
		if _cutscene != null:
			_cutscene.continue_after_ui()
	dialogue_done.emit(file_id)
	game_event.emit("dialogue:%s" % str(file_id))


# ---------------------------------------------------------------- input locking

## Counts lock requests; the player reads input only when none is open and he is not bound.
func _lock_input(lock: bool) -> void:
	_lock_depth = maxi(_lock_depth + (1 if lock else -1), 0)
	_refresh_player_input()


func _refresh_player_input() -> void:
	if _player == null:
		return
	var open: bool = _lock_depth == 0 and not _bound
	if _devotion != null and _devotion.is_exhausted():
		return
	_player.read_input = open
	if not open:
		_player.move_input = Vector2.ZERO


func input_locked() -> bool:
	return _lock_depth > 0


# ---------------------------------------------------------------- lighting

func _add_lighting(night: bool) -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	if night:
		env.background_color = Palette.NIGHT_INDIGO.darkened(0.35)
		env.ambient_light_color = Palette.NIGHT_INDIGO
		env.ambient_light_energy = NIGHT_AMBIENT_ENERGY
	else:
		env.background_color = Palette.SKY_DUSK
		env.ambient_light_color = Color(0.78, 0.76, 0.86)
		env.ambient_light_energy = DAY_AMBIENT_ENERGY
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_color = Palette.MOON if night else Color(1.0, 0.93, 0.8)
	sun.light_energy = NIGHT_SUN_ENERGY if night else DAY_SUN_ENERGY
	sun.shadow_enabled = true
	sun.add_to_group(&"sun")
	add_child(sun)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.name = "BackRim"
	rim.rotation_degrees = Vector3(-30.0, 145.0, 0.0)
	rim.light_color = Palette.SAFFRON.lightened(0.3) if not night else Palette.MOON.darkened(0.2)
	rim.light_energy = 0.2 if night else 0.45
	rim.shadow_enabled = false
	add_child(rim)


## Lets the camera fade walls and roofs that stand between it and Hanuman (DESIGN §4.1): the collider is moved under
## the visual so the camera's ray hit finds the mesh.
func _make_occluders() -> void:
	var props: Node = _level_root.get_node_or_null(NodePath("Props"))
	if props == null:
		return
	for prop: Node in props.get_children():
		if not OCCLUDING_KINDS.has(str(prop.get_meta("kind", ""))):
			continue
		var visual: MeshInstance3D = null
		for child: Node in prop.get_children():
			if child is MeshInstance3D:
				visual = child as MeshInstance3D
				break
		if visual == null:
			continue
		for child: Node in prop.get_children():
			if child is StaticBody3D:
				child.reparent(visual, true)
		visual.add_to_group(OCCLUDER_GROUP)


func _collect_props() -> void:
	var props: Node = _level_root.get_node_or_null(NodePath("Props"))
	if props == null:
		return
	for prop: Node in props.get_children():
		var node: Node3D = prop as Node3D
		if node == null:
			continue
		if prop.get_meta("kind", "") == "pillar":
			_pillars.append(node.position)


# ---------------------------------------------------------------- directors

func _build_directors() -> void:
	_fire = FireSystem.new()
	_fire.name = "FireSystem"
	add_child(_fire)
	var props: Node = _level_root.get_node_or_null(NodePath("Props"))
	if props != null:
		for prop: Node in props.get_children():
			var node: Node3D = prop as Node3D
			if node == null:
				continue
			_fire.register(node)
			if node.get_meta("flammable", false) as bool:
				_flammable.append(node)
	_stealth = StealthDirector.new()
	_stealth.name = "StealthDirector"
	_stealth.event_bus = _bus()
	add_child(_stealth)
	_encounter = EncounterDirector.new()
	_encounter.name = "EncounterDirector"
	add_child(_encounter)


## Starts wave 0 of the encounter chapter given in the load options (called by the chapter flow once control is free).
func begin_encounter(chapter_number: int = -1) -> void:
	var chapter: int = chapter_number
	if chapter < 0:
		chapter = (_options.get("encounter_chapter", 0) as int)
	if chapter <= 0 or _encounter == null:
		return
	_encounter.start(chapter)


func _on_boss_started(enemy: Node3D) -> void:
	var health: Health = enemy.get("health") as Health
	if health != null and _hud != null:
		var kind: String = str(enemy.get("enemy_id"))
		_hud.show_boss(StringName("BOSS_" + kind.substr(BOSS_PREFIX.length()).to_upper()), health)
	game_event.emit("boss_started:%s" % str(enemy.get("enemy_id")))


func _on_boss_finished(enemy: Node3D) -> void:
	if _hud != null:
		_hud.hide_boss()
	game_event.emit("boss_defeated:%s" % str(enemy.get("enemy_id")))


func _on_waves_completed() -> void:
	if _hud != null:
		_hud.hide_boss()
	game_event.emit("waves_completed")


func _on_fire_ignited(target_id: StringName) -> void:
	game_event.emit("fire_ignited")
	game_event.emit("fire_ignited:%s" % str(target_id))


# ---------------------------------------------------------------- spawns

func _spawn_shrines() -> void:
	var shrines: Node = _level_root.get_node_or_null(NodePath("Shrines"))
	if shrines == null:
		return
	for marker: Node in shrines.get_children():
		var spot: Marker3D = marker as Marker3D
		if spot == null:
			continue
		var shrine: Shrine = Shrine.new()
		shrine.shrine_id = str(spot.get_meta("id", spot.name))
		shrine.name = "Shrine_%s" % shrine.shrine_id
		shrines.add_child(shrine)
		shrine.position = spot.position
		shrine.meditated.connect(_on_shrine_meditated.bind(shrine.shrine_id))


func _on_shrine_meditated(shrine_id: String) -> void:
	game_event.emit("shrine:%s" % shrine_id)


## Copies the extra keys of each spawn record in the level JSON (wave, chapter, size_state, tail_fire, patrol,
## protected, bound ...) onto its marker as metadata, because LevelBuilder only stores id, kind and facing.
func _apply_spawn_meta(data: Dictionary) -> void:
	var spawns: Node = _level_root.get_node_or_null(NodePath("Spawns"))
	if spawns == null:
		return
	var records: Variant = data.get("spawns", [])
	if not (records is Array):
		return
	for entry: Variant in records as Array:
		if not (entry is Dictionary):
			continue
		var record: Dictionary = entry as Dictionary
		var marker: Node = spawns.get_node_or_null(NodePath(str(record.get("id", ""))))
		if marker == null:
			continue
		for key: Variant in record.keys():
			if SPAWN_META_SKIP.has(str(key)):
				continue
			marker.set_meta(str(key), record[key])


func _spawn_from_markers(data: Dictionary) -> void:
	_apply_spawn_meta(data)
	var spawns: Node = _level_root.get_node_or_null(NodePath("Spawns"))
	var player_marker: Marker3D = null
	if spawns != null:
		for marker: Node in spawns.get_children():
			var spot: Marker3D = marker as Marker3D
			if spot == null:
				continue
			var kind: String = str(spot.get_meta("kind", ""))
			if kind == "player":
				if player_marker == null:
					player_marker = spot
			elif kind.begins_with(NPC_PREFIX):
				_spawn_npc(spot, kind.substr(NPC_PREFIX.length()))
			elif ENEMY_KINDS.has(kind) and not (spot.has_meta("wave") and spot.has_meta("chapter")):
				_spawn_enemy(spot, kind)
	_spawn_extra_npcs()
	_spawn_player(player_marker)
	_encounter.configure(_level_root, Callable(self, "make_enemy"))
	_encounter.connect_to(_bus())
	_encounter.boss_started.connect(_on_boss_started)
	_encounter.boss_finished.connect(_on_boss_finished)
	_encounter.waves_completed.connect(_on_waves_completed)
	var bus: Node = _bus()
	if bus != null:
		bus.connect("fire_ignited", _on_fire_ignited)


## The enemy factory handed to EncounterDirector: kind -> node (null for an unknown kind).
func make_enemy(kind: String) -> Node3D:
	var enemy: Node3D = null
	match kind:
		"guard_spear":
			enemy = GuardSpear.new()
		"guard_archer":
			enemy = GuardArcher.new()
		"kinkara":
			enemy = Kinkara.new()
		"boss_lankini":
			enemy = BossLankini.new()
		"boss_jambumali":
			enemy = BossJambumali.new()
		"boss_akshaya":
			enemy = BossAkshaya.new()
		"boss_simhika":
			enemy = BossSimhika.new()
		_:
			return null
	_hook_enemy(enemy, kind)
	return enemy


func _hook_enemy(enemy: Node3D, kind: String) -> void:
	enemy.name = kind.capitalize().replace(" ", "")
	var lankini: BossLankini = enemy as BossLankini
	if lankini != null:
		lankini.yielded.connect(_on_boss_yielded.bind(kind))
	var jambumali: BossJambumali = enemy as BossJambumali
	if jambumali != null and not _pillars.is_empty():
		jambumali.set_pillars(_pillars)
	if GUARD_KINDS.has(kind) and _stealth != null:
		_stealth.register_guard(enemy)
	if kind.begins_with(BOSS_PREFIX):
		enemy.ready.connect(hook_boss_hints.bind(enemy, kind), CONNECT_ONE_SHOT)


func _on_boss_yielded(kind: String) -> void:
	game_event.emit("boss_yielded:%s" % kind)


func _spawn_enemy(spot: Marker3D, kind: String) -> void:
	var enemy: Node3D = make_enemy(kind)
	if enemy == null:
		return
	var base: EnemyBase = enemy as EnemyBase
	if base != null and spot.has_meta("patrol"):
		var points: Array[Vector3] = []
		var raw: Variant = spot.get_meta("patrol")
		if raw is Array:
			for pt: Variant in raw as Array:
				if pt is Array and (pt as Array).size() >= 2:
					points.append(Vector3((pt as Array)[0] as float, spot.position.y, (pt as Array)[1] as float))
		base.waypoints = points
	_level_root.add_child(enemy)
	enemy.position = safe_spawn(spot.position)
	enemy.rotation.y = spot.rotation.y
	_actors[str(spot.get_meta("id", spot.name))] = enemy
	if kind.begins_with(BOSS_PREFIX):
		_actors[kind.substr(BOSS_PREFIX.length())] = enemy
		_actors[kind] = enemy


func _spawn_npc(spot: Marker3D, npc_id: String) -> void:
	var marker_id: String = str(spot.get_meta("id", spot.name))
	var model_id: String = npc_id
	if npc_id == "vanara" and marker_id.begins_with("vanara_"):
		model_id = marker_id
	var npc: Node3D = NpcModels.build(StringName(model_id))
	npc.name = "Npc_%s" % marker_id
	for key: String in ["protected", "chapter", "wave"]:
		if spot.has_meta(key):
			npc.set_meta(key, spot.get_meta(key))
	_level_root.add_child(npc)
	npc.position = safe_spawn(spot.position)
	npc.rotation.y = spot.rotation.y
	_add_npc_body(npc, npc_id)
	_actors[marker_id] = npc
	_actors[npc_id] = npc


func _spawn_extra_npcs() -> void:
	var extra: Variant = _options.get("extra_npcs", [])
	if not (extra is Array):
		return
	for entry: Variant in extra as Array:
		if not (entry is Dictionary):
			continue
		var record: Dictionary = entry as Dictionary
		var npc_id: String = str(record.get("id", ""))
		if npc_id == "":
			continue
		var npc: Node3D = NpcModels.build(StringName(npc_id))
		_level_root.add_child(npc)
		var pos: Variant = record.get("pos", [0.0, 0.0])
		var pair: Array = pos as Array if pos is Array else [0.0, 0.0]
		npc.position = _ground_point(Vector2(pair[0] as float, pair[1] as float))
		npc.rotation.y = deg_to_rad((record.get("facing", 0) as float))
		_add_npc_body(npc, npc_id)
		_actors[npc_id] = npc


## NPCs are static models; each gets a capsule on the world layer so Hanuman and the enemies cannot walk through them.
func _add_npc_body(npc: Node3D, npc_id: String) -> void:
	var size: Vector2 = NPC_BODIES.get(npc_id, NPC_BODY_DEFAULT) as Vector2
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = Layers.mask([Layers.WORLD])
	body.collision_mask = 0
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = size.x
	capsule.height = maxf(size.y, size.x * 2.0)
	shape_node.shape = capsule
	shape_node.position = Vector3(0.0, capsule.height * 0.5, 0.0)
	body.add_child(shape_node)
	npc.add_child(body)


## A point on the floor at flat position `flat` (the level's tile height, found by a downward ray).
func _ground_point(flat: Vector2) -> Vector3:
	return Vector3(flat.x, _level_height_at(flat), flat.y)


func _level_height_at(flat: Vector2) -> float:
	var tiles: Node = _level_root.get_node_or_null(NodePath("Tiles/Floor"))
	if tiles == null:
		return 0.0
	var node: Node = tiles.get_node_or_null(NodePath("Tile_%d_%d" % [floori(flat.x / 2.0), floori(flat.y / 2.0)]))
	var shape: CollisionShape3D = node as CollisionShape3D
	if shape == null:
		return 0.0
	var box: BoxShape3D = shape.shape as BoxShape3D
	return shape.position.y + box.size.y * 0.5 if box != null else 0.0


func _spawn_player(marker: Marker3D) -> void:
	_player = Player.new()
	_player.name = "Player"
	_player.camera_path = NodePath("../IsoCamera")
	_player.add_to_group(PLAYER_GROUP)
	_size_shift = SizeShift.new()
	_size_shift.name = "SizeShift"
	_player.add_child(_size_shift)
	_devotion = Devotion.new()
	_devotion.name = "Devotion"
	_player.add_child(_devotion)
	add_child(_player)
	_size_shift.set_devotion(_devotion)
	_player.interact_requested.connect(_on_interact_requested)
	if marker != null:
		_spawn_position = safe_spawn(marker.position) + Vector3(0.0, SPAWN_LIFT, 0.0)
		var pivot: Node3D = _player.get_node_or_null(NodePath("Pivot")) as Node3D
		if pivot != null:
			pivot.rotation.y = marker.rotation.y
		_bound = marker.get_meta("bound", false) as bool
		_tail_fire = marker.get_meta("tail_fire", false) as bool
	_player.position = _spawn_position
	_actors["hanuman"] = _player
	_apply_start_size(marker)
	_player.set_meta("tail_fire", _tail_fire)
	_devotion.gain(START_SMARANA, "start")
	_camera = IsoCamera.new()
	_camera.name = "IsoCamera"
	_camera.target = NodePath("../Player")
	_camera.size = CAMERA_SIZE
	add_child(_camera)
	_refresh_player_input()


func _apply_start_size(marker: Marker3D) -> void:
	var wanted: String = str(_options.get("size", ""))
	if wanted == "" and marker != null:
		wanted = str(marker.get_meta("size_state", ""))
	match wanted:
		"small":
			_size_shift.force_size(SizeShift.SIZE.SMALL)
		"normal":
			_size_shift.force_size(SizeShift.SIZE.NORMAL)
		"large":
			_size_shift.force_size(SizeShift.SIZE.LARGE)


func _read_tiles(data: Dictionary) -> void:
	_tiles = {}
	var raw: Variant = data.get("tiles", [])
	if not (raw is Array):
		return
	for entry: Variant in raw as Array:
		if entry is Dictionary:
			var tile: Dictionary = entry as Dictionary
			var cell: Vector2i = Vector2i((tile.get("x", 0) as int), (tile.get("z", 0) as int))
			_tiles[cell] = {"type": str(tile.get("type", "ground")), "step": (tile.get("step", 0) as int)}


# ---------------------------------------------------------------- bounds and fall recovery
# Owner bug 2026-11-27: "If Hanuman falls into the sea, nothing happens; the player cannot do anything."
# Water and the level's outer edge are walled off with invisible colliders, and if he still ends up below the world
# he is returned to the last solid ground he stood on (no penalty: §2, Hanuman never dies).

const BOUND_HEIGHT: float = 6.0
const FALL_MARGIN: float = 3.0
var _last_safe: Vector3 = Vector3.INF
var _floor_y: float = 0.0


func _build_bounds() -> void:
	if _tiles.is_empty():
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = Layers.mask([Layers.WORLD])
	body.collision_mask = 0
	_level_root.add_child(body)
	var lo: Vector2i = Vector2i(1 << 30, 1 << 30)
	var hi: Vector2i = Vector2i(-(1 << 30), -(1 << 30))
	var min_step: int = 1 << 30
	for cell: Vector2i in _tiles:
		lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
		hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
		min_step = mini(min_step, (_tiles[cell] as Dictionary)["step"] as int)
	_floor_y = float(min_step) * LevelBuilder.STEP_HEIGHT
	var blocked: Array[Vector2i] = []
	for cell: Vector2i in _tiles:
		if str((_tiles[cell] as Dictionary)["type"]) == "water":
			blocked.append(cell)
	for x: int in range(lo.x - 1, hi.x + 2):
		for z: int in range(lo.y - 1, hi.y + 2):
			var c: Vector2i = Vector2i(x, z)
			if not _tiles.has(c):
				blocked.append(c)
	var t: float = LevelBuilder.TILE_SIZE
	for c: Vector2i in blocked:
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(t, BOUND_HEIGHT, t)
		shape.shape = box
		shape.position = Vector3(c.x * t + t * 0.5, _floor_y + BOUND_HEIGHT * 0.5 - 1.0, c.y * t + t * 0.5)
		body.add_child(shape)


func _guard_fall() -> void:
	if _player == null or not is_instance_valid(_player) or _leap != null or _tiles.is_empty():
		return
	var pos: Vector3 = _player.global_position
	if pos.y < _floor_y - FALL_MARGIN:
		var back: Vector3 = _last_safe if _last_safe != Vector3.INF else _spawn_position
		_player.global_position = back + Vector3(0.0, SPAWN_LIFT, 0.0)
		_player.velocity = Vector3.ZERO
		var snd: Node = get_node_or_null(^"/root/Sound")
		if snd != null:
			snd.call("play", &"recovered")
		return
	if _player.is_grounded():
		var cell: Vector2i = Vector2i(floori(pos.x / LevelBuilder.TILE_SIZE), floori(pos.z / LevelBuilder.TILE_SIZE))
		if _is_walkable(cell):
			_last_safe = pos


func _is_walkable(cell: Vector2i) -> bool:
	return _tiles.has(cell) and WALKABLE.has(str((_tiles[cell] as Dictionary)["type"]))


## Some level files place a spawn on a wall or water tile. A spawn there is moved to the nearest walkable tile centre,
## so nobody starts inside solid geometry. Walkable and unknown positions are returned unchanged.
func safe_spawn(pos: Vector3) -> Vector3:
	var cell: Vector2i = Vector2i(floori(pos.x / LevelBuilder.TILE_SIZE), floori(pos.z / LevelBuilder.TILE_SIZE))
	if _tiles.is_empty() or _is_walkable(cell):
		return pos
	var best: Vector3 = pos
	var best_distance: float = INF
	for radius: int in range(1, SPAWN_SEARCH_RADIUS):
		for dx: int in range(-radius, radius + 1):
			for dz: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius:
					continue
				var candidate: Vector2i = cell + Vector2i(dx, dz)
				if not _is_walkable(candidate):
					continue
				var centre: Vector3 = Vector3((float(candidate.x) + 0.5) * LevelBuilder.TILE_SIZE, 0.0, (float(candidate.y) + 0.5) * LevelBuilder.TILE_SIZE)
				var d: float = Vector2(centre.x - pos.x, centre.z - pos.z).length()
				if d < best_distance:
					best_distance = d
					best = centre
					best.y = float((_tiles[candidate] as Dictionary)["step"] as int) * LevelBuilder.STEP_HEIGHT
		if best_distance < INF and float(radius) * LevelBuilder.TILE_SIZE > best_distance:
			break
	return best


## If the last shrine belongs to another level, the spawn becomes the recovery point, so Exhausted works everywhere.
func _ensure_shrine_record() -> void:
	var gs: Node = _state()
	if gs == null:
		return
	var record: Dictionary = gs.get("last_shrine") as Dictionary
	if str(record.get("level", "")) == str(_level_id) and record.has("pos"):
		return
	gs.set("last_shrine", {"level": str(_level_id), "pos": _spawn_position, "id": "spawn"})


func _on_interact_requested(target: Area3D) -> void:
	var shrine: Shrine = target as Shrine
	if shrine != null and _player != null:
		shrine.interact(_player)
		if _prompt != null:
			_prompt.register_use(&"meditate")


# ---------------------------------------------------------------- triggers

func _connect_triggers() -> void:
	var group: Node = _level_root.get_node_or_null(NodePath("Triggers"))
	if group == null:
		return
	var skip: Array = _options.get("skip_triggers", []) as Array
	for node: Node in group.get_children():
		var area: Area3D = node as Area3D
		if area == null:
			continue
		var tid: String = str(area.get_meta("id", area.name))
		if skip.has(tid):
			continue
		area.collision_layer = 0
		area.collision_mask = Layers.mask([Layers.PLAYER])
		area.monitoring = true
		area.body_entered.connect(_on_trigger_body.bind(tid))
		_triggers[tid] = area
		if TALK_GATES.has(tid) and Menus.tutorial_hints_enabled():
			_talk_nodes[tid] = null  # filled in by _build_teaching, once the NPC exists


func _on_trigger_body(body: Node3D, trigger_id: String) -> void:
	if body != _player:
		return
	# Story dialogue must never depend on knowing a key (owner bug 2026-11-27: "there's no dialog"). Walking up to the
	# NPC starts it; pressing Interact near the NPC (see _try_talk) also works.
	fire_trigger(StringName(trigger_id))


## Fires a trigger as if Hanuman had walked in. A `once` trigger fires a single time. Returns true when it routed.
func fire_trigger(trigger_id: StringName) -> bool:
	var key: String = str(trigger_id)
	if not _triggers.has(key):
		return false
	var area: Area3D = _triggers[key] as Area3D
	var once: bool = area.get_meta("once", false) as bool
	if once and _fired.has(key):
		return false
	_fired[key] = true
	var on_enter: String = str(area.get_meta("on_enter", ""))
	_forget_talk_target(key)
	trigger_fired.emit(trigger_id, on_enter)
	if _tutorial != null:
		_tutorial.notify_trigger(trigger_id)
	route(on_enter)
	return true


## Routes one on_enter value. Unknown values are only announced through trigger_fired.
func route(on_enter: String) -> void:
	var colon: int = on_enter.find(":")
	if colon < 0:
		return
	var verb: String = on_enter.substr(0, colon)
	var arg: String = on_enter.substr(colon + 1)
	match verb:
		"dialogue":
			# A finished story conversation never replays from a trigger (owner bug 2026-11-27: walking back past
			# Jambavan restarted the prologue speech).
			if _dialogue_done(arg):
				return
			play_dialogue(arg)
		"cutscene":
			play_cutscene(StringName(arg))
		"level":
			level_exit.emit(StringName(arg))
			game_event.emit("level:%s" % arg)
		"objective":
			var objectives: Node = _autoload("Objectives")
			if objectives != null:
				objectives.call("complete", StringName(arg))
			game_event.emit("objective:%s" % arg)
		"search":
			searched.emit(StringName(arg))
			game_event.emit("search:%s" % arg)
		"chapter_complete":
			chapter_complete.emit(StringName(arg))
			game_event.emit("chapter_complete:%s" % arg)


# ---------------------------------------------------------------- unlocks

## Turns story flags into ability unlocks (SizeShift reads GameState.is_unlocked).
static func sync_unlocks(state: Node) -> void:
	if state == null:
		return
	for flag: String in FLAG_UNLOCKS.keys():
		if state.call("get_flag", StringName(flag), false) as bool:
			state.call("unlock", StringName(FLAG_UNLOCKS[flag] as String))


func _apply_sync_unlocks() -> void:
	var gs: Node = _state()
	sync_unlocks(gs)
	if gs != null and gs.call("get_flag", &"tail_fire", false) as bool:
		_tail_fire = true


# ---------------------------------------------------------------- objective beacon (FX1)

func beacon() -> ObjectiveBeacon:
	return _beacon


func _build_beacon() -> void:
	if _player == null or _tiles.is_empty():
		return
	_beacon = ObjectiveBeacon.new()
	add_child(_beacon)
	refresh_beacon()


## True when the objective is registered with the Objectives autoload and not yet done.
func _objective_open(id: StringName) -> bool:
	var objectives: Node = _autoload("Objectives")
	if objectives == null:
		return false
	var texts: Dictionary = objectives.get("_texts") as Dictionary
	return texts != null and texts.has(id) and not (objectives.call("is_done", id) as bool)


## The node the current objective points at (an actor, a trigger area), or null when it has no place.
func beacon_target_node() -> Node3D:
	var entry: Dictionary = ObjectiveBeacon.pick(_level_id, Callable(self, "_objective_open"))
	if entry.is_empty():
		return null
	var ref: String = str(entry["ref"])
	match str(entry["kind"]):
		"actor":
			return _actors.get(ref, null) as Node3D
		"search":
			var ids: Array[String] = []
			for key: Variant in _triggers_in_level():
				var tid: String = str(key)
				if tid.begins_with(ref) and not _fired.has(tid):
					ids.append(tid)
			ids.sort()
			return _trigger_node(ids[0]) if not ids.is_empty() else null
		_:
			if _fired.has(ref) and (_trigger_node(ref) == null or _trigger_node(ref).get_meta("once", false) as bool):
				return null
			return _trigger_node(ref)


func _triggers_in_level() -> Array[String]:
	var out: Array[String] = []
	var group: Node = _level_root.get_node_or_null(NodePath("Triggers")) if _level_root != null else null
	if group != null:
		for child: Node in group.get_children():
			out.append(str(child.get_meta("id", child.name)))
	return out


func _trigger_node(trigger_id: String) -> Node3D:
	if _level_root == null:
		return null
	return _level_root.get_node_or_null(NodePath("Triggers/%s" % trigger_id)) as Node3D


## Re-reads the objectives, points the beacon at the right place and hides it during dialogue and cutscenes.
func refresh_beacon() -> void:
	if _beacon == null:
		return
	_beacon.set_target(beacon_target_node())
	_beacon_locked = input_locked()
	_beacon.set_suppressed(_beacon_locked)
	_update_beacon_arrow()


func _update_beacon_arrow() -> void:
	if _hud == null:
		return
	var cam: Camera3D = _camera.get_camera() if _camera != null else null
	if _beacon == null or cam == null or not _beacon.is_active() or not cam.is_inside_tree():
		_hud.hide_objective_arrow()
		return
	var goal: Vector3 = ObjectiveBeacon.ground_position(_beacon.target_node()) + Vector3(0.0, 1.0, 0.0)
	_hud.show_objective_arrow(cam.unproject_position(goal), get_viewport().get_visible_rect().size)


# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	check_unlock_cards()
	if _player == null or not is_instance_valid(_player):
		return
	_update_camera_zoom(delta)
	if _beacon != null:
		_beacon_clock += delta
		if _beacon_clock >= BEACON_REFRESH or input_locked() != _beacon_locked:
			_beacon_clock = 0.0
			refresh_beacon()
		else:
			_update_beacon_arrow()
	if _lock_depth == 0 and not _bound and _devotion != null and not _devotion.is_exhausted():
		if Input.is_action_just_pressed(&"grow"):
			_size_shift.grow()
		if Input.is_action_just_pressed(&"shrink"):
			_size_shift.shrink()
		if Input.is_action_just_pressed(&"smarana_surge"):
			_devotion.surge()


func _update_camera_zoom(delta: float) -> void:
	if _camera == null or _size_shift == null:
		return
	var base: float = LEVEL_CAMERA_SIZE.get(str(_level_id), CAMERA_SIZE) as float
	var zoom: float = SIZE_ZOOM.get(int(_size_shift.get_size()), 1.0) as float
	_camera.size = lerpf(_camera.size, base * zoom, clampf(delta * 3.0, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	_guard_fall()
	_footsteps(delta)
	if _tail_fire and _player != null and _fire != null:
		burn_near(_player.global_position)


## Plays a footstep every FOOTSTEP_INTERVAL seconds while the player walks, by the tile under the player.
func _footsteps(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _leap != null:
		return
	var flat: Vector2 = Vector2(_player.velocity.x, _player.velocity.z)
	if flat.length() < 0.5 or absf(_player.velocity.y) > 0.5 or _player.is_dodging():
		_step_time = SoundPlayer.FOOTSTEP_INTERVAL
		return
	_step_time += delta
	if _step_time < SoundPlayer.FOOTSTEP_INTERVAL:
		return
	_step_time = 0.0
	var pos: Vector3 = _player.global_position
	var cell: Vector2i = Vector2i(floori(pos.x / LevelBuilder.TILE_SIZE), floori(pos.z / LevelBuilder.TILE_SIZE))
	var tile_type: String = "ground"
	if _tiles.has(cell):
		tile_type = str((_tiles[cell] as Dictionary)["type"])
	SoundPlayer.cue(self, SoundPlayer.footstep_id_for(tile_type))


## The burning tail sets alight every flammable prop within reach of `where`. Returns how many caught.
func burn_near(where: Vector3) -> int:
	var count: int = 0
	var reach: float = TAIL_FIRE_RADIUS
	if _size_shift != null:
		reach *= maxf(_size_shift.get_scale_target(), 1.0)
	for prop: Node3D in _flammable:
		if not is_instance_valid(prop):
			continue
		var flat: Vector3 = prop.global_position - where
		flat.y = 0.0
		if flat.length() <= reach + 1.5 and _fire.ignite(prop):
			count += 1
	return count


# ---------------------------------------------------------------- the leap (chapter 1)

func _load_leap() -> void:
	_hud = Hud.new()
	_hud.name = "Hud"
	add_child(_hud)
	_hud.bind_abilities(_state(), null, null, null)
	_rider = Node3D.new()
	_rider.name = "Rider"
	var pivot: Node3D = Node3D.new()
	pivot.name = "Pivot"
	_rider.add_child(pivot)
	var model: HanumanModel = HanumanModel.new()
	pivot.add_child(model)
	model.build()
	model.set_pose(FLIGHT_POSE)
	_size_shift = SizeShift.new()
	_size_shift.name = "SizeShift"
	_rider.add_child(_size_shift)
	var chase: Camera3D = Camera3D.new()
	chase.name = "ChaseCamera"
	chase.fov = 62.0
	chase.far = 2000.0
	chase.position = Vector3(0.0, 5.0, 17.0)
	chase.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	_rider.add_child(chase)
	add_child(_rider)
	_leap = LeapController.new()
	_leap.name = "LeapController"
	_leap.rider = _rider
	add_child(_leap)
	chase.make_current()
	_actors["hanuman"] = _rider
	_size_shift.force_size(SizeShift.SIZE.GIANT)
	_apply_sync_unlocks()
	_hud.bind_abilities(_state(), null, _size_shift, null)
	_build_tutorial(null, false)


# ---------------------------------------------------------------- teaching the controls (DESIGN §4.1a)

## Builds the world prompt, binds the HUD ability bar and starts the tutorial director for a walkable level.
func _build_teaching() -> void:
	if _player == null or _ui_layer == null:
		return
	if _hud != null:
		_hud.bind_abilities(_state(), _player, _size_shift, _devotion)
	_prompt = WorldPrompt.new()
	_prompt.suppressed = Callable(self, "input_locked")
	_prompt.game_state = _state()
	_prompt.bind(_player, _camera.get_camera() if _camera != null else null)
	_ui_layer.add_child(_prompt)
	var shrines: Node = _level_root.get_node_or_null(NodePath("Shrines"))
	if shrines != null:
		for child: Node in shrines.get_children():
			var shrine: Shrine = child as Shrine
			if shrine != null:
				_prompt.add_target(shrine, &"meditate", &"interact", true, 1.7)
	var talk_npc: Node3D = null
	for tid: Variant in _talk_nodes.keys():
		var npc: Node3D = _actors.get(TALK_GATES[tid], null) as Node3D
		_talk_nodes[tid] = npc
		if npc != null:
			_prompt.add_target(npc, &"talk", &"interact", false, 2.1)
			talk_npc = npc
	_build_tutorial(talk_npc, _triggers.has(str(PROLOGUE_TRIGGER)))


func _build_tutorial(talk_npc: Node3D, prologue: bool) -> void:
	_tutorial = TutorialDirector.new()
	_tutorial.enabled = Menus.tutorial_hints_enabled()
	_tutorial.locked = Callable(self, "input_locked")
	_tutorial.game_state = _state()
	_tutorial.stuck_hints_enabled = _leap == null
	add_child(_tutorial)
	_tutorial.setup(_ui_layer, _player, talk_npc, prologue)
	game_event.connect(_tutorial.notify_event)
	var gs: Node = _state()
	if prologue and gs != null and gs.call("get_flag", TALK_FLAG, false) as bool:
		_tutorial.notify_event(TutorialDirector.TALK_FILE)  # a continued game has already spoken with Jambavan
	var bus: Node = _bus()
	if bus != null:
		bus.connect("objective_updated", _tutorial.notify_objective)
		bus.connect("enemy_defeated", _on_enemy_defeated_progress)


func _on_enemy_defeated_progress(_enemy_id: StringName, _pos: Vector3) -> void:
	if _tutorial != null:
		_tutorial.notify_progress()


## Connects a boss to the tutorial director: one hint at its first phase change (a phase_changed signal, or the first
## time it falls to two thirds of its health).
func hook_boss_hints(boss: Node, kind: String) -> void:
	if _tutorial == null or boss == null:
		return
	if boss.has_signal(&"phase_changed"):
		boss.connect(&"phase_changed", _on_boss_phase.bind(kind))
		return
	var health: Health = boss.get("health") as Health
	if health != null:
		health.changed.connect(_on_boss_health.bind(kind))


func _on_boss_phase(_phase: int, kind: String) -> void:
	if _tutorial != null:
		_tutorial.notify_boss_phase(kind)


func _on_boss_health(value: int, max_now: int, kind: String) -> void:
	if _tutorial != null and max_now > 0 and float(value) <= float(max_now) * BOSS_HINT_FRACTION:
		_tutorial.notify_boss_phase(kind)


func _forget_talk_target(trigger_id: String) -> void:
	if not _talk_nodes.has(trigger_id):
		return
	var npc: Node3D = _talk_nodes[trigger_id] as Node3D
	if npc != null and _prompt != null:
		_prompt.remove_target(npc)
	_talk_nodes.erase(trigger_id)


## The Interact key near an NPC whose dialogue waits for it. Returns true when it started the dialogue.
func _try_talk() -> bool:
	if _player == null or _lock_depth > 0:
		return false
	for tid: Variant in _talk_nodes.keys():
		var npc: Node3D = _talk_nodes[tid] as Node3D
		if npc == null or _fired.has(str(tid)):
			continue
		var offset: Vector3 = npc.global_position - _player.global_position
		offset.y = 0.0
		if offset.length() <= WorldPrompt.SHOW_RANGE:
			if _prompt != null:
				_prompt.register_use(&"talk")
			return fire_trigger(StringName(str(tid)))
	return false


func _input(event: InputEvent) -> void:
	if _controls == null:
		return
	if KeyGlyph.observe(event) and _controls.visible:
		_controls.refresh()
	if event.is_echo():
		return
	if event.is_action(KeyGlyph.ACTION_SHOW_CONTROLS):
		_set_controls_overlay(event.is_pressed())
	elif event.is_action_pressed(&"interact"):
		_try_talk()


## Holding the show_controls action (Tab) shows the controls screen over the game; releasing it hides it.
func _set_controls_overlay(open: bool) -> void:
	if _controls == null:
		return
	if open and not (_unlock_card != null and _unlock_card.is_open()):
		_controls.open_overlay()
	else:
		_controls.close_overlay()


## Shows the card of the first unlocked ability that has not had one yet, when nothing else holds the player.
## Returns true when a card opened. The runtime calls this every frame; tests call it directly.
func check_unlock_cards() -> bool:
	if _unlock_card == null or _unlock_card.is_open() or _lock_depth > 0:
		return false
	var gs: Node = _state()
	if gs == null:
		return false
	for ability: StringName in CARD_ABILITIES:
		var flag: StringName = StringName(CARD_FLAG_PREFIX + str(ability))
		if gs.call("is_unlocked", ability) as bool and not (gs.call("get_flag", flag, false) as bool):
			gs.call("set_flag", flag, true)
			_open_unlock_card(ability)
			return true
	return false


func _open_unlock_card(ability: StringName) -> void:
	_lock_input(true)
	if _leap != null:
		_leap.set_physics_process(false)
	if _controls != null:
		_controls.close_overlay()
	_unlock_card.show_for(ability)


func _on_unlock_card_closed(_ability: StringName) -> void:
	_lock_input(false)
	if _leap != null:
		_leap.set_physics_process(true)
	if _tutorial != null:
		_tutorial.notify_progress()


# ---------------------------------------------------------------- music and autoloads

func _music_for_level() -> void:
	if not music_enabled:
		return
	var music: Node = _autoload("Music")
	if music == null:
		return
	var track: StringName = &"calm"
	var chapter: int = (_options.get("encounter_chapter", 0) as int)
	if _level_id == &"lanka_streets":
		track = &"stealth"
	elif _level_id == &"lanka_rooftops":
		track = &"dahan"
	elif chapter > 0:
		track = &"combat"
	music.call("play", track, 1.0)


func _bus() -> Node:
	if event_bus != null:
		return event_bus
	return _autoload("EventBus")


func _state() -> Node:
	if game_state != null:
		return game_state
	return _autoload("GameState")


func _autoload(autoload_name: String) -> Node:
	var tree: SceneTree = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(autoload_name)
