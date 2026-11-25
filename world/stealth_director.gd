class_name StealthDirector
extends Node
## Stealth alarm (DESIGN §9 M29, §3 Ch2). Tracks registered EnemyBase guards. When a guard enters ALERT and can see a
## player (group "player"), that is a sighting: the alarm escalates by one level (0 calm, 1 suspicious, 2 alarm, max 2),
## `alarm_changed` fires on a change, and EventBus.alarm_raised(pos) fires with the player's position.
## At level 2, every guard within ALARM_RANGE metres (flat distance) of the alarm position is sent to chase a marker
## placed at that position. The alarm decays to 0 after DECAY_TIME seconds without a sighting.
## All timing uses the accumulated `delta` passed to `tick()`, so the outcome does not depend on frame rate.
## Guards are used through their public API only: `state`, `set_target()`, `force_state()` and `can_see()`.

signal alarm_changed(level: int)

## Alarm levels.
const CALM: int = 0
const SUSPICIOUS: int = 1
const ALARM: int = 2
## Metres (flat distance) within which guards respond to an alarm at level 2.
const ALARM_RANGE: float = 15.0
## Seconds without a sighting before the alarm decays to calm.
const DECAY_TIME: float = 12.0
## EnemyBase.State values used here (see gameplay/enemies/enemy_base.gd).
const _STATE_ALERT: int = 2
const _STATE_CHASE: int = 3
const _STATE_DISSOLVE: int = 6
const _PLAYER_GROUP: StringName = &"player"
const _BUS_PATH: String = "/root/EventBus"

## Current alarm level, 0 to 2. Read only from outside; changes through sightings and decay.
var alarm_level: int = CALM
## The EventBus used for alarm_raised. Left null, the autoload at /root/EventBus is used.
var event_bus: Node = null

var _guards: Array[Node3D] = []
var _last_states: Array[int] = []
var _since_sighting: float = 0.0
var _marker: Node3D = null


## Adds a guard to the tracked set. A guard already in ALERT when registered counts as entering ALERT.
func register_guard(guard: Node3D) -> void:
	if guard == null or _guards.has(guard):
		return
	_guards.append(guard)
	_last_states.append(-1)


func unregister_guard(guard: Node3D) -> void:
	var index: int = _guards.find(guard)
	if index < 0:
		return
	_guards.remove_at(index)
	_last_states.remove_at(index)


func guard_count() -> int:
	return _guards.size()


func _physics_process(delta: float) -> void:
	tick(delta)


## One step of the alarm logic. Call it once per physics tick (or from a test with a fixed delta).
func tick(delta: float) -> void:
	_prune()
	var sightings: Array[Vector3] = []
	for i: int in range(_guards.size()):
		var guard: Node3D = _guards[i]
		var state: int = _state_of(guard)
		var entered_alert: bool = state == _STATE_ALERT and _last_states[i] != _STATE_ALERT
		_last_states[i] = state
		if entered_alert:
			var player: Node3D = _find_seen_player(guard)
			if player != null:
				sightings.append(player.global_position)
	for pos: Vector3 in sightings:
		_on_sighting(pos)
	if sightings.is_empty() and alarm_level > CALM:
		_since_sighting += delta
		if _since_sighting >= DECAY_TIME:
			_set_level(CALM)


func _on_sighting(pos: Vector3) -> void:
	_since_sighting = 0.0
	_set_level(mini(alarm_level + 1, ALARM))
	var bus: Node = _get_bus()
	if bus != null:
		bus.emit_signal("alarm_raised", pos)
	if alarm_level == ALARM:
		_alert_nearby_guards(pos)


func _set_level(level: int) -> void:
	if level == alarm_level:
		return
	alarm_level = level
	if level == CALM:
		_since_sighting = 0.0
	alarm_changed.emit(level)


func _alert_nearby_guards(pos: Vector3) -> void:
	var marker: Node3D = _ensure_marker()
	if is_inside_tree():
		marker.global_position = pos
	else:
		marker.position = pos
	for guard: Node3D in _guards:
		if _state_of(guard) == _STATE_DISSOLVE:
			continue
		var offset: Vector3 = guard.global_position - pos
		if Vector2(offset.x, offset.z).length() > ALARM_RANGE:
			continue
		if guard.has_method("set_target"):
			guard.call("set_target", marker)
		if guard.has_method("force_state"):
			guard.call("force_state", _STATE_CHASE)


func _find_seen_player(guard: Node3D) -> Node3D:
	if not is_inside_tree() or not guard.has_method("can_see"):
		return null
	var players: Array[Node] = get_tree().get_nodes_in_group(_PLAYER_GROUP)
	for node: Node in players:
		var player: Node3D = node as Node3D
		if player == null:
			continue
		var sees: Variant = guard.call("can_see", player)
		if sees as bool:
			return player
	return null


func _state_of(guard: Node3D) -> int:
	var value: Variant = guard.get("state")
	if value == null:
		return -1
	return value as int


func _prune() -> void:
	var i: int = _guards.size() - 1
	while i >= 0:
		if not is_instance_valid(_guards[i]):
			_guards.remove_at(i)
			_last_states.remove_at(i)
		i -= 1


func _ensure_marker() -> Node3D:
	if _marker == null or not is_instance_valid(_marker):
		_marker = Node3D.new()
		_marker.name = "AlarmMarker"
		add_child(_marker)
	return _marker


func _get_bus() -> Node:
	if event_bus != null:
		return event_bus
	if is_inside_tree():
		return get_node_or_null(_BUS_PATH)
	return null
