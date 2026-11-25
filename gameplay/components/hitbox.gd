class_name Hitbox
extends Area3D
## An attack volume (DESIGN §9 M14). It is only detectable while an activation is running: call `activate(duration)`
## when an attack starts. Each activation has an id, and a hurtbox applies a given activation's hit at most once.
## Hurtboxes of the same team ignore it (friendly fire). Advance the timer with `advance(delta)`, which
## `_physics_process` calls every physics tick (60 per second, so timers stay independent of frame rate).

## Damage applied to Health by a hurtbox that this hitbox hits.
@export var damage: int = 10
## Knockback speed, in world units per second, applied away from the hitbox when it hits.
@export var knockback: float = 0.0
## Team that owns this hitbox: &"player", &"enemy" or &"fire". Sets the collision layer.
@export var team: StringName = &"enemy":
	set = _set_team

## Float error from summing many small steps must not keep an activation alive.
const _EXPIRY_EPSILON: float = 0.000001

var _active: bool = false
var _remaining: float = 0.0
var _activation_id: int = 0


func _ready() -> void:
	# A hitbox only needs to be detected, not to detect anything itself.
	monitoring = false
	_set_team(team)
	_apply_active_state()


func _physics_process(delta: float) -> void:
	advance(delta)


## Starts an activation that lasts `duration` seconds. Restarting while active begins a new activation.
func activate(duration: float) -> void:
	_active = true
	_remaining = maxf(duration, 0.0)
	_activation_id += 1
	_apply_active_state()


## Ends the current activation immediately.
func deactivate() -> void:
	_active = false
	_remaining = 0.0
	_apply_active_state()


## True while an activation is running.
func is_active() -> bool:
	return _active


## Id of the current (or most recent) activation. Increases by one on every `activate()`.
func get_activation_id() -> int:
	return _activation_id


## Counts the running activation down by `delta` seconds and ends it when the time runs out.
func advance(delta: float) -> void:
	if not _active:
		return
	_remaining -= delta
	if _remaining <= _EXPIRY_EPSILON:
		deactivate()


func _set_team(value: StringName) -> void:
	team = value
	collision_layer = Layers.mask([Layers.hit_layer_for_team(value)])
	collision_mask = 0


func _apply_active_state() -> void:
	monitorable = _active
