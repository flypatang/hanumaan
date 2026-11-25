class_name BossLankini
extends EnemyBase
## Lankini, guardian of Lanka's gate (DESIGN §3, §4.5, §9 M24). A fast duel: 3-hit combo strings and a wide trident
## sweep, each strike telegraphed for at least 0.4 s. PARRY: a light hit that lands within PARRY_WINDOW seconds of her
## strike start (before or after) staggers her for PARRY_STAGGER seconds. Ordinary hits never stagger her.
## At 0 HP she does not dissolve: she kneels and yields (GameState flag `lankini_yielded`, signal `yielded`).
## Stats are fixed here (data/enemies.json has no row for her). All timing uses delta (§8).

## Emitted once when she kneels and yields.
signal yielded

const BOSS_HP: int = 250
const COMBO_HITS: int = 3
const COMBO_WINDUPS: Array[float] = [0.5, 0.4, 0.4]
const COMBO_GAP: float = 0.15
const COMBO_DAMAGE: int = 12
const SWEEP_WINDUP: float = 0.7
const SWEEP_DAMAGE: int = 18
const SWEEP_RADIUS: float = 3.2
const PARRY_WINDOW: float = 0.15
const PARRY_STAGGER: float = 1.5
const YIELD_FLAG: StringName = &"lankini_yielded"
## Light hits stay below this damage; heavy hits are at or above it (same rule as EnemyBase).
const KNEEL_DROP: float = 0.6

## Test/integration hook: the node that holds flags (an autoload `GameState`). Defaults to /root/GameState.
var game_state: Node = null
## Number of strikes started since spawn, and the index of the current hit within the pattern.
var strike_count: int = 0
var combo_index: int = 0
var is_sweep: bool = false
var yielded_done: bool = false

var _pattern_count: int = 0
var _cur_windup: float = 0.5
var _stagger_time: float = STAGGER_TIME
var _combo_telegraph_mesh: CylinderMesh = null
var _sweep_telegraph_mesh: CylinderMesh = null
var _combo_shape: SphereShape3D = null
var _sweep_shape: SphereShape3D = null


func _init() -> void:
	enemy_id = &"boss_lankini"


func _ready() -> void:
	super()
	_combo_telegraph_mesh = telegraph.mesh as CylinderMesh
	_sweep_telegraph_mesh = CylinderMesh.new()
	_sweep_telegraph_mesh.top_radius = SWEEP_RADIUS
	_sweep_telegraph_mesh.bottom_radius = SWEEP_RADIUS
	_sweep_telegraph_mesh.height = 0.02
	var shape: CollisionShape3D = hitbox.get_child(0) as CollisionShape3D
	if shape != null:
		_combo_shape = shape.shape as SphereShape3D
		_sweep_shape = SphereShape3D.new()
		_sweep_shape.radius = SWEEP_RADIUS


## Pre-table setup: Lankini has no enemies.json row, so her stats are set here.
func _apply_stats() -> void:
	hp = BOSS_HP
	speed = 5.5
	damage = COMBO_DAMAGE
	attack_range = 2.5
	windup = COMBO_WINDUPS[0]
	cooldown = 0.8
	vision_range = 20.0
	vision_angle_deg = 360.0
	stagger_heavy_only = false
	model_variant = &"lankini"


## True while a light hit would parry: during an attack, within PARRY_WINDOW of the current strike start.
func is_parry_window_open() -> bool:
	if state != State.ATTACK or _yielded():
		return false
	return absf(_state_time - _cur_windup) <= PARRY_WINDOW


func has_yielded() -> bool:
	return yielded_done


func tick(delta: float) -> void:
	if yielded_done:
		return
	super(delta)


func apply_hit(amount: int, knockback: Vector3, heavy: bool) -> void:
	if yielded_done:
		return
	super(amount, knockback, heavy)


# ---- overrides ---------------------------------------------------------------------------------------

func _stagger_on_hit(heavy: bool) -> bool:
	if yielded_done or heavy:
		return false
	if is_parry_window_open():
		_stagger_time = PARRY_STAGGER
		return true
	return false


func _tick_stagger() -> void:
	if _state_time >= _stagger_time:
		_stagger_time = STAGGER_TIME
		_enter(State.CHASE if _get_target() != null else State.IDLE)


func _on_attack_started() -> void:
	if _pattern_count % 2 == 1:
		is_sweep = true
	else:
		is_sweep = false
	combo_index = 0
	_pattern_count += 1
	_begin_hit()


func _tick_attack() -> void:
	velocity = Vector3.ZERO
	if not _strike_done:
		if _state_time >= _cur_windup:
			_strike_done = true
			telegraph.visible = false
			strike_count += 1
			hitbox.damage = SWEEP_DAMAGE if is_sweep else COMBO_DAMAGE
			if model != null:
				RakshasaModel.set_pose(model, &"attack_strike")
			_on_attack_strike()
		return
	var last: bool = is_sweep or combo_index >= COMBO_HITS - 1
	var rest: float = RECOVER_TIME if last else COMBO_GAP
	if _state_time < _cur_windup + STRIKE_TIME + rest:
		return
	if last:
		_cooldown_left = cooldown
		_enter(State.CHASE)
	else:
		combo_index += 1
		_begin_hit()


func _on_depleted(_source: Node) -> void:
	if yielded_done:
		return
	yielded_done = true
	velocity = Vector3.ZERO
	hitbox.deactivate()
	telegraph.visible = false
	hurtbox.monitoring = false
	if model != null:
		RakshasaModel.set_pose(model, &"idle")
		model.position.y = -KNEEL_DROP
	var gs: Node = game_state
	if gs == null:
		gs = get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("set_flag", YIELD_FLAG, true)
	yielded.emit()


# ---- helpers -----------------------------------------------------------------------------------------

func _yielded() -> bool:
	return yielded_done


func _begin_hit() -> void:
	_state_time = 0.0
	_strike_done = false
	_cur_windup = SWEEP_WINDUP if is_sweep else COMBO_WINDUPS[combo_index]
	windup = _cur_windup
	var t: Node3D = _get_target()
	if t != null:
		_face(t.global_position)
	telegraph.mesh = _sweep_telegraph_mesh if is_sweep else _combo_telegraph_mesh
	if _combo_shape != null:
		var shape: CollisionShape3D = hitbox.get_child(0) as CollisionShape3D
		shape.shape = _sweep_shape if is_sweep else _combo_shape
		shape.position = Vector3(0.0, 1.0, 0.0) if is_sweep else Vector3(0.0, 1.0, -attack_range * 0.5)
	telegraph.visible = true
	if model != null:
		RakshasaModel.set_pose(model, &"attack_wind")
