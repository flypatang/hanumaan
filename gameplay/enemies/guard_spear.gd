class_name GuardSpear
extends EnemyBase
## Rakshasa spear-guard (DESIGN §4.5, §9 M22). It pokes and lunges: during the strike it dashes LUNGE_DISTANCE
## forward in STRIKE_TIME seconds (LUNGE_SPEED), along the facing it had when the strike began.
## Timing comes from the base state machine and uses `delta`, so the lunge is the same at 30 and 60 fps (§8).

## Distance covered by the lunge, in metres.
const LUNGE_DISTANCE: float = 1.2
## Dash speed in metres per second. Equals LUNGE_DISTANCE over the 0.2 s strike window of EnemyBase.
const LUNGE_SPEED: float = 6.0

var _lunge_dir: Vector3 = Vector3.ZERO


func _init() -> void:
	enemy_id = &"guard_spear"


func _tick_attack() -> void:
	if not _strike_done:
		velocity = Vector3.ZERO
		if _state_time >= windup:
			_strike_done = true
			telegraph.visible = false
			_on_attack_strike()
			velocity = _lunge_dir * LUNGE_SPEED
	elif _state_time < windup + STRIKE_TIME:
		velocity = _lunge_dir * LUNGE_SPEED
	else:
		velocity = Vector3.ZERO
		if _state_time >= windup + STRIKE_TIME + RECOVER_TIME:
			_cooldown_left = cooldown
			_enter(State.CHASE)


func _on_attack_strike() -> void:
	super()
	var fwd: Vector3 = -global_transform.basis.z
	fwd.y = 0.0
	_lunge_dir = fwd.normalized()
