class_name Health
extends Node
## Hit-point component (DESIGN §9 M13). Owned by any actor that can take damage (Hanuman, rakshasas, bosses).
## Holds no reference to other systems: callers pass the damage source and listen to the signals.
## Keeps `value` within 0..max_value. Emits `changed` on every real change and `depleted` once per death
## (on the transition from above 0 to 0; it can fire again after a heal brings the value back above 0).

signal changed(new_value: int, max_value_now: int)
signal depleted(source: Node)

@export var max_value: int = 100

## Multiplies incoming damage in `damage()`. 1.0 means no change.
var damage_multiplier: float = 1.0
## While true, `damage()` is ignored entirely (dodge frames, cutscenes).
var invulnerable: bool = false

var _current: int = -1


## Current hit points, always within 0..max_value. Before the first change it equals max_value.
## Setting it clamps the value but emits no signals; gameplay code should use damage() and heal().
var value: int:
	get:
		return max_value if _current < 0 else _current
	set(v):
		_current = clampi(v, 0, max_value)


## Takes `n` points of damage, scaled by `damage_multiplier`. Ignored if `n <= 0` or while invulnerable.
func damage(n: int, source: Node) -> void:
	if n <= 0 or invulnerable:
		return
	var before: int = value
	if before <= 0:
		return
	var amount: int = roundi(float(n) * damage_multiplier)
	if amount <= 0:
		return
	value = before - amount
	if value != before:
		changed.emit(value, max_value)
	if before > 0 and value == 0:
		depleted.emit(source)


## Restores `n` points, clamped at max_value. Ignored if `n <= 0`.
func heal(n: int) -> void:
	if n <= 0:
		return
	var before: int = value
	value = before + n
	if value != before:
		changed.emit(value, max_value)
