class_name SoundPlayer
extends Node
## Autoload `Sound` (DESIGN §7, §9 AU1). Plays the Kenney CC0 sound effects (assets/sfx/kenney) through a pool of
## AudioStreamPlayer / AudioStreamPlayer3D nodes on the "SFX" bus. Every event id maps to one or more .ogg files
## in BANK; a random variation and a slight pitch jitter are chosen on each play. It also trims the music drone
## to -10 dB and ducks it under dialogue (an AudioEffectAmplify on the "Music" bus, so Menus' bus volumes stay
## untouched). Gameplay code calls `SoundPlayer.cue(self, &"id")` which finds the autoload and never fails.

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const IMPACT: String = "res://assets/sfx/kenney/kenney_impact-sounds/"
const UI: String = "res://assets/sfx/kenney/kenney_interface-sounds/"
const RPG: String = "res://assets/sfx/kenney/kenney_rpg-audio/"
const POOL_SIZE: int = 12
const HISTORY_SIZE: int = 16
const MUSIC_TRIM_DB: float = -10.0
const DUCK_DB: float = -9.0
const DUCK_TIME: float = 0.4
const FOOTSTEP_INTERVAL: float = 0.35
const SPATIAL_UNIT_SIZE: float = 60.0
const HEAVY_HIT_DAMAGE: int = 30
const NO_POSITION: Vector3 = Vector3.INF

## id -> {files: Array[String], db: float, pitch: float (+/- jitter), base: float (pitch scale), loop: bool}
static var BANK: Dictionary = _build_bank()

## The last HISTORY_SIZE ids played, oldest first (test hook).
var recent: Array[StringName] = []

var _players: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _next: int = 0
var _next_3d: int = 0
var _streams: Dictionary = {}
var _last_pick: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _amp: AudioEffectAmplify = null
var _owns_amp: bool = false
var _duck_tween: Tween = null
var _bus_node: Node = null


static func _seq(dir: String, stem: String, count: int, first: int = 0, width: int = 3) -> Array[String]:
	var out: Array[String] = []
	for i: int in count:
		out.append("%s%s_%s.ogg" % [dir, stem, str(first + i).pad_zeros(width)])
	return out


static func _entry(files: Array[String], db: float = 0.0, pitch: float = 0.06, base: float = 1.0, loop: bool = false) -> Dictionary:
	return {"files": files, "db": db, "pitch": pitch, "base": base, "loop": loop}


static func _build_bank() -> Dictionary:
	var b: Dictionary = {}
	b["footstep_grass"] = _entry(_seq(IMPACT, "footstep_grass", 5), -8.0, 0.1)
	b["footstep_stone"] = _entry(_seq(IMPACT, "footstep_concrete", 5), -8.0, 0.1)
	b["footstep_sand"] = _entry(_seq(IMPACT, "footstep_snow", 5), -9.0, 0.1)
	b["gada_swing_light"] = _entry([RPG + "knifeSlice.ogg", RPG + "knifeSlice2.ogg"], -4.0, 0.1, 0.8)
	b["gada_swing_heavy"] = _entry([RPG + "drawKnife1.ogg", RPG + "drawKnife2.ogg", RPG + "drawKnife3.ogg"], -1.0, 0.05, 0.6)
	b["impact_light"] = _entry(_seq(IMPACT, "impactPunch_medium", 5), -2.0)
	b["impact_heavy"] = _entry(_seq(IMPACT, "impactPunch_heavy", 5), 1.0, 0.05)
	b["player_hurt"] = _entry(_seq(IMPACT, "impactSoft_heavy", 5), 0.0, 0.08, 0.9)
	b["enemy_hurt"] = _entry(_seq(IMPACT, "impactWood_medium", 5), -3.0, 0.1)
	b["enemy_dissolve"] = _entry(_seq(IMPACT, "impactGlass_medium", 5), -4.0, 0.05, 0.7)
	b["dodge_whoosh"] = _entry([RPG + "clothBelt.ogg", RPG + "clothBelt2.ogg", RPG + "cloth3.ogg"], -3.0, 0.1, 1.1)
	b["size_grow"] = _entry(_seq(UI, "maximize", 3, 1, 3), -2.0, 0.03, 0.6)
	b["size_shrink"] = _entry(_seq(UI, "minimize", 3, 1, 3), -2.0, 0.03, 0.9)
	b["surge"] = _entry(_seq(IMPACT, "impactMetal_heavy", 5), 2.0, 0.03, 0.7)
	b["exhausted"] = _entry(_seq(UI, "drop", 4, 1, 3), 0.0, 0.03, 0.6)
	b["recovered"] = _entry(_seq(UI, "confirmation", 2, 1, 3), -2.0, 0.03, 0.9)
	b["shrine_meditate"] = _entry(_seq(IMPACT, "impactBell_heavy", 5), -2.0, 0.02, 0.9)
	b["fire_ignite"] = _entry(_seq(UI, "scratch", 5, 1, 3), -3.0, 0.08, 0.7)
	b["fire_loop"] = _entry(_seq(UI, "scratch", 2, 1, 3), -12.0, 0.04, 0.5, true)
	b["alarm"] = _entry(_seq(UI, "error", 3, 1, 3), 0.0, 0.02, 0.8)
	b["ui_click"] = _entry(_seq(UI, "click", 5, 1, 3), -4.0, 0.03)
	b["ui_hover"] = _entry(_seq(UI, "tick", 2, 1, 3), -12.0, 0.04)
	b["ui_confirm"] = _entry(_seq(UI, "confirmation", 4, 1, 3), -3.0, 0.02)
	b["ui_back"] = _entry(_seq(UI, "back", 4, 1, 3), -4.0, 0.02)
	b["dialogue_advance"] = _entry(_seq(UI, "toggle", 4, 1, 3), -12.0, 0.05)
	b["choice_select"] = _entry(_seq(UI, "select", 4, 1, 3), -4.0, 0.03)
	var bell: Array[String] = [UI + "bong_001.ogg"]
	b["shloka_open"] = _entry(bell, -2.0, 0.01, 0.8)
	return b


## Footstep event id for a level tile type ("grass", "sand", anything else is stone).
static func footstep_id_for(tile_type: String) -> StringName:
	match tile_type:
		"grass":
			return &"footstep_grass"
		"sand":
			return &"footstep_sand"
		_:
			return &"footstep_stone"


## Plays `id` through the Sound autoload from any node in the tree. Returns the player, or null when there is no
## autoload (a bare unit test) or the node is not in a tree. A Node3D source plays positionally.
static func cue(from: Node, id: StringName, position: Vector3 = NO_POSITION) -> Node:
	if from == null or not from.is_inside_tree():
		return null
	var sound: SoundPlayer = from.get_tree().root.get_node_or_null("Sound") as SoundPlayer
	if sound == null:
		return null
	return sound.play(id, position)


## Like cue(), at the global position of `from`.
static func cue_at(from: Node3D, id: StringName) -> Node:
	if from == null or not from.is_inside_tree():
		return null
	return cue(from, id, from.global_position)


## Stops a looping player returned by cue()/play() and releases it.
static func stop_loop(player: Node) -> void:
	if player != null and is_instance_valid(player):
		if player is AudioStreamPlayer3D:
			(player as AudioStreamPlayer3D).stop()
		elif player is AudioStreamPlayer:
			(player as AudioStreamPlayer).stop()
		var par: Node = player.get_parent()
		if par != null:
			par.remove_child(player)
		player.queue_free()


func _ready() -> void:
	_rng.randomize()
	ensure_buses()
	_apply_saved_volumes()
	_trim_music()
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bind_bus(bus)


## Creates the Master / Music / SFX buses when missing. Safe to call repeatedly.
static func ensure_buses() -> void:
	for bus_name: StringName in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index: int = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, BUS_MASTER)


## Listens to an EventBus: alarm_raised plays the alarm, dialogue_started / finished duck the music.
func bind_bus(bus: Node) -> void:
	_bus_node = bus
	bus.connect("alarm_raised", _on_alarm_raised)
	bus.connect("dialogue_started", _on_dialogue_started)
	bus.connect("dialogue_finished", _on_dialogue_finished)


## True when every id of the bank has at least one file that can be loaded.
func resolves(id: StringName) -> bool:
	var info: Dictionary = BANK.get(String(id), {}) as Dictionary
	if info.is_empty():
		return false
	for path: String in (info["files"] as Array[String]):
		if not ResourceLoader.exists(path):
			return false
	return true


## Plays one event. With a position (not Vector3.INF) it plays on a 3D player there, otherwise 2D.
## Returns the AudioStreamPlayer / AudioStreamPlayer3D used, or null for an unknown id.
func play(id: StringName, position: Vector3 = NO_POSITION) -> Node:
	var info: Dictionary = BANK.get(String(id), {}) as Dictionary
	if info.is_empty():
		push_warning("Sound: unknown id '%s'" % String(id))
		return null
	recent.append(id)
	while recent.size() > HISTORY_SIZE:
		recent.pop_front()
	var stream: AudioStream = _stream_for(id, info)
	var volume: float = info["db"] as float
	var pitch: float = (info["base"] as float) * (1.0 + _rng.randf_range(-1.0, 1.0) * (info["pitch"] as float))
	var looping: bool = info["loop"] as bool
	var spatial: bool = position.is_finite()
	var node: Node = null
	if spatial:
		var p3: AudioStreamPlayer3D = _take_3d(looping)
		p3.stream = stream
		p3.volume_db = volume
		p3.pitch_scale = pitch
		p3.position = position
		node = p3
	else:
		var p2: AudioStreamPlayer = _take_2d(looping)
		p2.stream = stream
		p2.volume_db = volume
		p2.pitch_scale = pitch
		node = p2
	if node.is_inside_tree() and stream != null:
		if spatial:
			(node as AudioStreamPlayer3D).play()
		else:
			(node as AudioStreamPlayer).play()
	return node


## The ids played most recently (a copy), oldest first.
func recent_ids() -> Array[StringName]:
	return recent.duplicate()


func clear_history() -> void:
	recent.clear()


## Current extra gain on the music bus, in dB (-10 trim, lower while ducked).
func music_gain_db() -> float:
	return _amp.volume_db if _amp != null else MUSIC_TRIM_DB


func _pick(id: StringName, info: Dictionary) -> String:
	var files: Array[String] = info["files"] as Array[String]
	var index: int = _rng.randi_range(0, files.size() - 1)
	if files.size() > 1 and index == (_last_pick.get(id, -1) as int):
		index = (index + 1) % files.size()
	_last_pick[id] = index
	return files[index]


func _stream_for(id: StringName, info: Dictionary) -> AudioStream:
	var path: String = _pick(id, info)
	if _streams.has(path):
		return _streams[path] as AudioStream
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream != null and (info["loop"] as bool):
		var ogg: AudioStreamOggVorbis = stream.duplicate() as AudioStreamOggVorbis
		if ogg != null:
			ogg.loop = true
			stream = ogg
	_streams[path] = stream
	return stream


func _take_2d(fresh: bool) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = null
	if fresh or _players.size() < POOL_SIZE:
		p = AudioStreamPlayer.new()
		p.bus = BUS_SFX if AudioServer.get_bus_index(BUS_SFX) >= 0 else BUS_MASTER
		add_child(p)
		if not fresh:
			_players.append(p)
		return p
	for candidate: AudioStreamPlayer in _players:
		if not candidate.playing:
			return candidate
	p = _players[_next]
	_next = (_next + 1) % POOL_SIZE
	return p


func _take_3d(fresh: bool) -> AudioStreamPlayer3D:
	var p: AudioStreamPlayer3D = null
	if fresh or _players_3d.size() < POOL_SIZE:
		p = AudioStreamPlayer3D.new()
		p.bus = BUS_SFX if AudioServer.get_bus_index(BUS_SFX) >= 0 else BUS_MASTER
		p.unit_size = SPATIAL_UNIT_SIZE
		add_child(p)
		if not fresh:
			_players_3d.append(p)
		return p
	for candidate: AudioStreamPlayer3D in _players_3d:
		if not candidate.playing:
			return candidate
	p = _players_3d[_next_3d]
	_next_3d = (_next_3d + 1) % POOL_SIZE
	return p


func _apply_saved_volumes() -> void:
	var options: Dictionary = {&"volume_master": BUS_MASTER, &"volume_music": BUS_MUSIC, &"volume_sfx": BUS_SFX}
	for option: StringName in options.keys():
		var level: float = Menus.saved_option(option) as float
		var index: int = AudioServer.get_bus_index(options[option] as StringName)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, -80.0 if level <= 0.0 else linear_to_db(level))


func _trim_music() -> void:
	var index: int = AudioServer.get_bus_index(BUS_MUSIC)
	if index < 0:
		return
	# Reuse an amplify already on the bus so repeated instances never stack effects.
	for i: int in AudioServer.get_bus_effect_count(index):
		var existing: AudioEffectAmplify = AudioServer.get_bus_effect(index, i) as AudioEffectAmplify
		if existing != null:
			_amp = existing
			return
	_amp = AudioEffectAmplify.new()
	_amp.volume_db = MUSIC_TRIM_DB
	AudioServer.add_bus_effect(index, _amp)
	_owns_amp = true


func _exit_tree() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	if not _owns_amp or _amp == null:
		return
	var index: int = AudioServer.get_bus_index(BUS_MUSIC)
	if index >= 0:
		for i: int in AudioServer.get_bus_effect_count(index):
			if AudioServer.get_bus_effect(index, i) == _amp:
				AudioServer.remove_bus_effect(index, i)
				break
	_owns_amp = false


func _duck(target_db: float) -> void:
	if _amp == null:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	if not is_inside_tree():
		_amp.volume_db = target_db
		return
	_duck_tween = create_tween()
	_duck_tween.tween_property(_amp, "volume_db", target_db, DUCK_TIME)


func _on_alarm_raised(pos: Vector3) -> void:
	play(&"alarm", pos)


func _on_dialogue_started(_id: StringName) -> void:
	_duck(MUSIC_TRIM_DB + DUCK_DB)


func _on_dialogue_finished(_id: StringName, _flags: Dictionary) -> void:
	_duck(MUSIC_TRIM_DB)
