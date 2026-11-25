class_name EncounterDirector
extends Node
## Enemy waves for a chapter (DESIGN §9 M37). Reads the level root's "Spawns" markers, which carry meta `wave` (int) and
## `chapter` (int) and `kind` (String). start(chapter) spawns wave 0 of that chapter through the injected factory
## (kind -> Node3D). Once every enemy of the active wave has been defeated (EventBus.enemy_defeated), the director waits
## WAVE_GAP seconds, then starts the next wave. Kinds starting with "boss_" emit boss_started / boss_finished.
## waves_completed fires when the last wave of the chapter ends.
## All timing uses the `delta` passed to advance(), so the outcome does not depend on frame rate.

signal boss_started(enemy: Node3D)
signal boss_finished(enemy: Node3D)
signal waves_completed

## Seconds between a wave ending and the next wave starting.
const WAVE_GAP: float = 2.0
const BOSS_PREFIX: String = "boss_"

var _markers: Array[Dictionary] = []
var _chapter_markers: Array[Dictionary] = []
var _factory: Callable = Callable()
var _level_root: Node3D = null
var _waves: Array[int] = []
var _wave_pos: int = -1
var _active: Array[Dictionary] = []
var _gap_left: float = -1.0
var _running: bool = false
var _finished: bool = false


## Reads the spawn markers under `level_root/Spawns` and stores the factory used to create enemies.
func configure(level_root: Node3D, factory: Callable) -> void:
	_level_root = level_root
	_factory = factory
	_markers.clear()
	if level_root == null:
		return
	var spawns: Node = level_root.get_node_or_null(NodePath("Spawns"))
	if spawns == null:
		return
	for child: Node in spawns.get_children():
		var marker: Node3D = child as Node3D
		if marker == null or not child.has_meta("wave") or not child.has_meta("chapter"):
			continue
		var entry: Dictionary = {
			"kind": str(child.get_meta("kind", "")),
			"wave": (child.get_meta("wave") as int),
			"chapter": (child.get_meta("chapter") as int),
			"pos": marker.position,
		}
		_markers.append(entry)


## Subscribes to EventBus.enemy_defeated.
func connect_to(bus: Node) -> void:
	if bus == null:
		return
	var handler: Callable = Callable(self, "_on_enemy_defeated")
	if not bus.is_connected("enemy_defeated", handler):
		bus.connect("enemy_defeated", handler)


## Begins wave 0 of `chapter`. A chapter with no spawns completes immediately.
func start(chapter: int) -> void:
	_chapter_markers.clear()
	_waves.clear()
	for entry: Dictionary in _markers:
		if (entry.get("chapter", -1) as int) != chapter:
			continue
		_chapter_markers.append(entry)
		var wave_no: int = (entry.get("wave", 0) as int)
		if not _waves.has(wave_no):
			_waves.append(wave_no)
	_waves.sort()
	_wave_pos = -1
	_active.clear()
	_gap_left = -1.0
	_finished = false
	_running = true
	if _waves.is_empty():
		_finish()
		return
	_begin_next_wave()


## Counts down the gap between waves. Call with the frame delta (also driven by _process).
func advance(delta: float) -> void:
	if not _running or _finished or _gap_left < 0.0:
		return
	_gap_left -= delta
	if _gap_left <= 0.0:
		_gap_left = -1.0
		_begin_next_wave()


func _process(delta: float) -> void:
	advance(delta)


## Number of enemies of the active wave still alive.
func living_count() -> int:
	return _active.size()


## The wave number currently active, or -1 when none is.
func current_wave() -> int:
	if _wave_pos < 0 or _wave_pos >= _waves.size():
		return -1
	return _waves[_wave_pos]


func is_finished() -> bool:
	return _finished


func _begin_next_wave() -> void:
	_wave_pos += 1
	if _wave_pos >= _waves.size():
		_finish()
		return
	_active.clear()
	var wave_no: int = _waves[_wave_pos]
	for entry: Dictionary in _chapter_markers:
		if (entry.get("wave", -1) as int) == wave_no:
			_spawn(entry)
	if _active.is_empty():
		_wave_ended()


func _spawn(entry: Dictionary) -> void:
	if not _factory.is_valid():
		return
	var kind: String = str(entry.get("kind", ""))
	var result: Variant = _factory.call(kind)
	var node: Node3D = result as Node3D
	if node == null:
		return
	var parent: Node = _level_root if _level_root != null else self
	parent.add_child(node)
	node.position = entry.get("pos", Vector3.ZERO) as Vector3
	_active.append({"kind": kind, "node": node})
	if kind.begins_with(BOSS_PREFIX):
		boss_started.emit(node)


func _wave_ended() -> void:
	if _wave_pos >= _waves.size() - 1:
		_finish()
	else:
		_gap_left = WAVE_GAP


func _finish() -> void:
	_running = false
	_finished = true
	waves_completed.emit()


func _on_enemy_defeated(enemy_id: StringName, _pos: Vector3) -> void:
	if not _running or _finished or _gap_left >= 0.0:
		return
	var kind: String = String(enemy_id)
	for i: int in range(_active.size()):
		var entry: Dictionary = _active[i]
		if str(entry.get("kind", "")) != kind:
			continue
		var node: Node3D = entry.get("node") as Node3D
		_active.remove_at(i)
		if kind.begins_with(BOSS_PREFIX) and node != null:
			boss_finished.emit(node)
		if _active.is_empty():
			_wave_ended()
		return
