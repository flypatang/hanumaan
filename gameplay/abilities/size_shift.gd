class_name SizeShift
extends Node
## Hanuman's size shift (DESIGN §4.2, §9 M19). A child of the Player that steps the size one notch at a time:
## SMALL (0.35x), NORMAL (1x), LARGE (2.5x) and GIANT (6x, only through force_size for scripted moments).
## Every size change tweens the player's visual scale and collision shapes over 0.4 s, sets the Player's
## speed / damage multipliers, stores the "size_state" meta for enemy vision, and emits EventBus.size_changed.
## While LARGE, Smarana drains at 6 per second through a devotion node; if the drain fails, Hanuman shrinks to NORMAL.
## Growing refuses when a ShapeCast3D upward finds a ceiling.
## The tween is advanced by tick(delta), which _process calls, so tests can step it with fixed deltas.

enum SIZE { SMALL = 0, NORMAL = 1, LARGE = 2, GIANT = 3 }

## Index by SIZE. GIANT has no row in the §4.2 table; it uses LARGE's combat values (assumption, see the report).
const SCALES: Array[float] = [0.35, 1.0, 2.5, 6.0]
const SPEEDS: Array[float] = [0.8, 1.0, 0.75, 0.75]
const DAMAGES: Array[float] = [0.3, 1.0, 2.0, 2.0]
const DAMAGE_TAKEN: Array[float] = [1.0, 1.0, 0.6, 0.6]

const TWEEN_TIME: float = 0.4
## Absorbs float error from summing fixed ticks (e.g. 12 ticks of 1/30 s), so the tween ends on the same tick at any frame rate.
const TIME_EPSILON: float = 0.0001
const DRAIN_PER_SECOND: float = 6.0
const BODY_HEIGHT: float = 1.7
const CEILING_RADIUS: float = 0.3
const META_KEY: StringName = &"size_state"
const PIVOT_NAME: String = "Pivot"

## Overrides the EventBus lookup (tests). When null, /root/EventBus is used.
var event_bus: Node = null

var _size: SIZE = SIZE.NORMAL
var _player: Node3D = null
var _devotion: Node = null
var _visual: float = 1.0
var _tween_from: float = 1.0
var _tween_elapsed: float = 0.0
var _tweening: bool = false
var _probe: ShapeCast3D = null


func _ready() -> void:
	_player = get_parent() as Node3D
	_visual = SCALES[_size]
	_apply_fields()
	_apply_visual()


func _process(delta: float) -> void:
	tick(delta)


# ---------------------------------------------------------------- public API

func get_size() -> SIZE:
	return _size


## The logical scale of the current size (the table value), not the interpolated visual scale.
func get_scale_target() -> float:
	return SCALES[_size]


## The scale currently drawn, which lags behind the target during the 0.4 s tween.
func get_visual_scale() -> float:
	return _visual


func is_transitioning() -> bool:
	return _tweening


## Sets the node that pays for LARGE. It needs `spend(amount: float) -> bool`. Null means no drain.
func set_devotion(node: Node) -> void:
	_devotion = node


## Steps one size up. Returns false when refused: GIANT is never reached this way, LARGE needs the "grow"
## unlock, and a blocked ceiling refuses too.
func grow() -> bool:
	if _size >= SIZE.LARGE:
		return false
	var next: SIZE = (_size + 1) as SIZE
	if next == SIZE.LARGE and not _unlocked(&"grow"):
		return false
	if _ceiling_blocked(SCALES[next]):
		return false
	_change_size(next)
	return true


## Steps one size down. Returns false when refused: SMALL needs the "shrink" unlock.
func shrink() -> bool:
	if _size <= SIZE.SMALL:
		return false
	var next: SIZE = (_size - 1) as SIZE
	if next == SIZE.SMALL and not _unlocked(&"shrink"):
		return false
	_change_size(next)
	return true


## Sets the size directly, for scripted moments (the leap, Surasa). Skips unlocks and the ceiling check.
func force_size(size: SIZE) -> void:
	_change_size(size)


## Advances the visual tween and the Smarana drain by delta seconds.
func tick(delta: float) -> void:
	if _tweening:
		_tween_elapsed = minf(_tween_elapsed + delta, TWEEN_TIME)
		var t: float = _tween_elapsed / TWEEN_TIME
		var eased: float = t * t * (3.0 - 2.0 * t)
		_visual = lerpf(_tween_from, SCALES[_size], eased)
		if _tween_elapsed >= TWEEN_TIME - TIME_EPSILON:
			_tweening = false
			_visual = SCALES[_size]
		_apply_visual()
	if _size == SIZE.LARGE:
		_drain(delta)


# ---------------------------------------------------------------- private

func _change_size(next: SIZE) -> void:
	if next == _size:
		return
	_size = next
	_tween_from = _visual
	_tween_elapsed = 0.0
	_tweening = true
	_apply_fields()
	if event_bus != null:
		event_bus.emit_signal(&"size_changed", int(next))
	else:
		var bus: Node = get_node_or_null("/root/EventBus")
		if bus != null:
			bus.emit_signal(&"size_changed", int(next))


func _apply_fields() -> void:
	if _player == null:
		return
	_player.set(&"speed_multiplier", SPEEDS[_size])
	_player.set(&"damage_multiplier", DAMAGES[_size])
	_player.set(&"damage_taken_multiplier", DAMAGE_TAKEN[_size])
	_player.set_meta(META_KEY, int(_size))


func _apply_visual() -> void:
	if _player == null:
		return
	var pivot: Node3D = _player.get_node_or_null(PIVOT_NAME) as Node3D
	if pivot != null:
		pivot.scale = Vector3.ONE * _visual
	for child: Node in _player.get_children():
		var shape: CollisionShape3D = child as CollisionShape3D
		if shape != null:
			# Scale the shape's offset too: the capsule is centred above the feet, and scaling only its size left it
			# floating at full height, so a SMALL Hanuman sank into the ground (director review 2026-11-26).
			if not shape.has_meta(&"base_position"):
				shape.set_meta(&"base_position", shape.position)
			shape.position = (shape.get_meta(&"base_position") as Vector3) * _visual
			shape.scale = Vector3.ONE * _visual


## Reads GameState through the autoload path (autoload names are not known to the static check).
func _unlocked(ability: StringName) -> bool:
	var state: Node = get_node_or_null("/root/GameState")
	if state == null:
		return false
	return state.call(&"is_unlocked", ability) as bool


func _drain(delta: float) -> void:
	if _devotion == null or not _devotion.has_method(&"spend"):
		return
	var paid: Variant = _devotion.call(&"spend", DRAIN_PER_SECOND * delta)
	if not (paid as bool):
		_change_size(SIZE.NORMAL)


## True when a sphere swept from the current head height up to the target head height hits world geometry.
func _ceiling_blocked(target_scale: float) -> bool:
	if _player == null:
		return false
	var probe: ShapeCast3D = _get_probe()
	var current_top: float = BODY_HEIGHT * SCALES[_size]
	var target_top: float = BODY_HEIGHT * target_scale
	probe.position = Vector3(0.0, current_top, 0.0)
	probe.target_position = Vector3(0.0, target_top - current_top, 0.0)
	var sphere: SphereShape3D = probe.shape as SphereShape3D
	sphere.radius = CEILING_RADIUS * target_scale
	probe.force_shapecast_update()
	return probe.is_colliding()


func _get_probe() -> ShapeCast3D:
	if _probe == null:
		_probe = ShapeCast3D.new()
		_probe.name = "SizeShiftCeiling"
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = CEILING_RADIUS
		_probe.shape = sphere
		_probe.collision_mask = Layers.mask([Layers.WORLD])
		_probe.enabled = true
		_player.add_child(_probe)
		var body: CollisionObject3D = _player as CollisionObject3D
		if body != null:
			_probe.add_exception(body)
	return _probe
