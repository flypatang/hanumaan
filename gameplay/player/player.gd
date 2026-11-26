class_name Player
extends CharacterBody3D
## Hanuman, the playable character (DESIGN §9 M18, §4.3). Movement relative to the camera, a 3-hit light combo
## (12 / 12 / 20), a heavy attack (35, 0.6 s windup, knockback), a leap-dodge (0.35 s invulnerable, 1.2 s cooldown)
## and interaction. Gameplay is simulated in fixed 60 Hz ticks with integer tick counters, so outcomes do not depend
## on the frame rate of the caller: `_physics_process(delta)` accumulates `delta` and runs whole ticks.

## Emitted when the interact action finds an Area3D in group "interactable" within INTERACT_RANGE.
signal interact_requested(target: Area3D)

const BASE_SPEED: float = 5.0
const TICK_RATE: int = 60
const TICK: float = 1.0 / 60.0
const TICK_EPSILON: float = 0.000001
const GRAVITY: float = 20.0
const LIGHT_DAMAGE: Array[int] = [12, 12, 20]
const LIGHT_SWING_TIME: float = 0.25
const CHAIN_WINDOW: float = 0.6
const HEAVY_DAMAGE: int = 35
const HEAVY_WINDUP: float = 0.6
const HEAVY_STRIKE_TIME: float = 0.2
const HEAVY_RECOVERY: float = 0.2
const HEAVY_KNOCKBACK: float = 8.0
const DODGE_DURATION: float = 0.35
const DODGE_COOLDOWN: float = 1.2
const DODGE_SPEED: float = 12.0
const INTERACT_RANGE: float = 2.0
const MAX_HEALTH: int = 100
const WALK_POSE_PERIOD: float = 0.25
const KNOCK_DECAY: float = 30.0

enum State { IDLE, LIGHT, HEAVY_WINDUP, HEAVY_STRIKE, HEAVY_RECOVER, DODGE }

## Path to the IsoCamera (any Node3D works). When empty or invalid the identity basis is used.
@export var camera_path: NodePath = NodePath("")

## Set by M19 (size shift).
var speed_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var damage_taken_multiplier: float = 1.0:
	set(v):
		damage_taken_multiplier = v
		if _health != null:
			_health.damage_multiplier = v

## Movement input on the XZ plane: x right, y toward the viewer (like Input.get_vector with move_up as negative y).
var move_input: Vector2 = Vector2.ZERO
## When true, input is read from the InputMap each physics frame. Tests turn this off and call request_*().
var read_input: bool = true
## Overrides the EventBus lookup (tests). When null, /root/EventBus is used.
var event_bus: Node = null

var _state: State = State.IDLE
var _state_ticks: int = 0
var _combo: int = 0
var _chain_ticks: int = 0
var _swing_index: int = 0
var _buffered_light: bool = false
var _dodge_cooldown_ticks: int = 0
var _dodge_dir: Vector3 = Vector3.ZERO
var _knock: Vector3 = Vector3.ZERO
var _acc: float = 0.0
var _walk_ticks: int = 0
var _grounded: bool = false
var _facing: Vector3 = Vector3(0.0, 0.0, -1.0)

var _health: Health = null
var _hurtbox: Hurtbox = null
var _light_hitbox: Hitbox = null
var _heavy_hitbox: Hitbox = null
var _pivot: Node3D = null
var _model: HanumanModel = null


func _ready() -> void:
	collision_layer = Layers.mask([Layers.PLAYER])
	collision_mask = Layers.mask([Layers.WORLD])
	_build_nodes()
	_set_pose(&"idle")
	_emit_bus(&"vitality_changed", [_health.value, _health.max_value])


func _build_nodes() -> void:
	var body_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	body_shape.shape = capsule
	body_shape.position = Vector3(0.0, 0.85, 0.0)
	add_child(body_shape)

	_health = Health.new()
	_health.name = "Health"
	_health.max_value = MAX_HEALTH
	_health.damage_multiplier = damage_taken_multiplier
	add_child(_health)
	_health.changed.connect(_on_health_changed)

	_hurtbox = Hurtbox.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.team = &"player"
	_hurtbox.health_path = NodePath("../Health")
	var hurt_shape: CollisionShape3D = CollisionShape3D.new()
	hurt_shape.shape = capsule
	hurt_shape.position = Vector3(0.0, 0.85, 0.0)
	_hurtbox.add_child(hurt_shape)
	add_child(_hurtbox)
	_hurtbox.hit_taken.connect(_on_hit_taken)

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_model = HanumanModel.new()
	_pivot.add_child(_model)
	_model.build()

	_light_hitbox = _make_hitbox("LightHitbox", 12, 0.0)
	_heavy_hitbox = _make_hitbox("HeavyHitbox", HEAVY_DAMAGE, HEAVY_KNOCKBACK)


func _make_hitbox(box_name: String, dmg: int, knock: float) -> Hitbox:
	var box: Hitbox = Hitbox.new()
	box.name = box_name
	box.team = &"player"
	box.damage = dmg
	box.knockback = knock
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	shape.position = Vector3(0.0, 1.0, -1.2)
	box.add_child(shape)
	_pivot.add_child(box)
	return box


# ---------------------------------------------------------------- public API

func get_health() -> Health:
	return _health


func get_hurtbox() -> Hurtbox:
	return _hurtbox


func get_light_hitbox() -> Hitbox:
	return _light_hitbox


func get_heavy_hitbox() -> Hitbox:
	return _heavy_hitbox


func get_state() -> State:
	return _state


func is_dodging() -> bool:
	return _state == State.DODGE


func is_attacking() -> bool:
	return _state == State.LIGHT or _state == State.HEAVY_WINDUP \
		or _state == State.HEAVY_STRIKE or _state == State.HEAVY_RECOVER


## Number of light hits already landed in the open chain (0..2). 0 when no chain window is open.
func combo_count() -> int:
	return _combo if _chain_ticks > 0 else 0


func dodge_cooldown_remaining() -> float:
	return float(_dodge_cooldown_ticks) * TICK


func can_dodge() -> bool:
	return _dodge_cooldown_ticks <= 0 and _state != State.DODGE


## Starts (or chains / buffers) a light attack.
func request_light_attack() -> void:
	match _state:
		State.IDLE:
			_start_light()
		State.LIGHT:
			_buffered_light = true
		_:
			pass


func request_heavy_attack() -> void:
	if _state != State.IDLE:
		return
	_combo = 0
	_chain_ticks = 0
	_buffered_light = false
	_enter(State.HEAVY_WINDUP)
	_set_pose(&"attack_wind")


func request_leap() -> void:
	if not can_dodge():
		return
	_end_attack_volumes()
	_combo = 0
	_chain_ticks = 0
	_buffered_light = false
	var dir: Vector3 = _world_direction(move_input)
	if dir.length_squared() <= 0.0:
		dir = _facing
	_dodge_dir = dir.normalized()
	_face(_dodge_dir)
	_dodge_cooldown_ticks = _ticks(DODGE_COOLDOWN)
	_health.invulnerable = true
	SoundPlayer.cue(self, &"dodge_whoosh")
	_enter(State.DODGE)


## Emits interact_requested for the nearest "interactable" Area3D within INTERACT_RANGE. Returns it, or null.
func request_interact() -> Area3D:
	var best: Area3D = null
	var best_d: float = INTERACT_RANGE
	for node: Node in get_tree().get_nodes_in_group(&"interactable"):
		var area: Area3D = node as Area3D
		if area == null or not area.is_inside_tree():
			continue
		var d: float = global_position.distance_to(area.global_position)
		if d <= best_d:
			best_d = d
			best = area
	if best != null:
		interact_requested.emit(best)
	return best


## Applies damage as if hit by `source` (respects dodge invulnerability and damage_taken_multiplier).
func take_damage(amount: int, source: Node = null) -> void:
	var before: int = _health.value
	_health.damage(amount, source)
	var lost: int = before - _health.value
	if lost > 0:
		_emit_bus(&"player_damaged", [lost, source])


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	if read_input:
		_poll_input()
	_acc += delta
	while _acc >= TICK - TICK_EPSILON:
		_acc = maxf(_acc - TICK, 0.0)
		_tick()


func _poll_input() -> void:
	move_input = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if Input.is_action_just_pressed(&"attack_light"):
		request_light_attack()
	if Input.is_action_just_pressed(&"attack_heavy"):
		request_heavy_attack()
	if Input.is_action_just_pressed(&"leap"):
		request_leap()
	if Input.is_action_just_pressed(&"interact"):
		request_interact()


func _tick() -> void:
	if _dodge_cooldown_ticks > 0:
		_dodge_cooldown_ticks -= 1
	if _chain_ticks > 0 and _state != State.LIGHT:
		_chain_ticks -= 1
		if _chain_ticks == 0:
			_combo = 0
	_state_ticks += 1

	match _state:
		State.LIGHT:
			if _state_ticks >= _ticks(LIGHT_SWING_TIME):
				_finish_light()
		State.HEAVY_WINDUP:
			if _state_ticks >= _ticks(HEAVY_WINDUP):
				_heavy_hitbox.damage = roundi(float(HEAVY_DAMAGE) * damage_multiplier)
				_heavy_hitbox.activate(10.0)
				SoundPlayer.cue(self, &"gada_swing_heavy")
				_enter(State.HEAVY_STRIKE)
				_set_pose(&"attack_strike")
		State.HEAVY_STRIKE:
			if _state_ticks >= _ticks(HEAVY_STRIKE_TIME):
				_heavy_hitbox.deactivate()
				_enter(State.HEAVY_RECOVER)
		State.HEAVY_RECOVER:
			if _state_ticks >= _ticks(HEAVY_RECOVERY):
				_enter(State.IDLE)
		State.DODGE:
			if _state_ticks >= _ticks(DODGE_DURATION):
				_health.invulnerable = false
				_enter(State.IDLE)

	_move()
	_animate()


func _move() -> void:
	var horizontal: Vector3 = Vector3.ZERO
	match _state:
		State.IDLE:
			var dir: Vector3 = _world_direction(move_input)
			horizontal = dir * BASE_SPEED * speed_multiplier
			if dir.length_squared() > 0.0:
				_face(dir)
		State.DODGE:
			horizontal = _dodge_dir * DODGE_SPEED
		_:
			pass
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * TICK)
	velocity.x = horizontal.x + _knock.x
	velocity.z = horizontal.z + _knock.z
	if _grounded:
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * TICK
	_slide_move(velocity * TICK)


## Moves by `motion` with one slide pass. Done by hand (not move_and_slide) so the step is always exactly one tick,
## whatever delta the engine reports to the caller.
func _slide_move(motion: Vector3) -> void:
	_grounded = false
	var col: KinematicCollision3D = move_and_collide(motion)
	var passes: int = 0
	while col != null and passes < 3:
		var n: Vector3 = col.get_normal()
		if n.y > 0.7:
			_grounded = true
		var rest: Vector3 = col.get_remainder().slide(n)
		if rest.length_squared() <= 0.0000001:
			break
		col = move_and_collide(rest)
		passes += 1


func _animate() -> void:
	if _state != State.IDLE:
		return
	if move_input.length_squared() > 0.0001:
		_walk_ticks += 1
		var phase: int = (_walk_ticks / _ticks(WALK_POSE_PERIOD)) % 2
		_set_pose(&"walk_a" if phase == 0 else &"walk_b")
	else:
		_walk_ticks = 0
		_set_pose(&"idle")


func _start_light() -> void:
	_swing_index = _combo if _chain_ticks > 0 else 0
	_chain_ticks = 0
	_buffered_light = false
	_light_hitbox.damage = roundi(float(LIGHT_DAMAGE[_swing_index]) * damage_multiplier)
	_light_hitbox.activate(10.0)
	SoundPlayer.cue(self, &"gada_swing_light")
	_enter(State.LIGHT)
	_set_pose(&"attack_strike" if _swing_index % 2 == 0 else &"attack_wind")


func _finish_light() -> void:
	_light_hitbox.deactivate()
	_enter(State.IDLE)
	_combo = _swing_index + 1
	if _combo >= LIGHT_DAMAGE.size():
		_combo = 0
		_chain_ticks = 0
		_buffered_light = false
		return
	_chain_ticks = _ticks(CHAIN_WINDOW)
	if _buffered_light:
		_start_light()


func _end_attack_volumes() -> void:
	_light_hitbox.deactivate()
	_heavy_hitbox.deactivate()


func _enter(new_state: State) -> void:
	_state = new_state
	_state_ticks = 0


func _set_pose(pose: StringName) -> void:
	if _model != null and _model.current_pose() != pose:
		_model.set_pose(pose)


func _world_direction(input: Vector2) -> Vector3:
	var v: Vector2 = input.limit_length(1.0)
	if v.length_squared() <= 0.0:
		return Vector3.ZERO
	var basis_used: Basis = Basis.IDENTITY
	var cam: Node3D = get_node_or_null(camera_path) as Node3D if not camera_path.is_empty() else null
	if cam != null:
		basis_used = cam.global_transform.basis
	var dir: Vector3 = basis_used * Vector3(v.x, 0.0, v.y)
	dir.y = 0.0
	if dir.length_squared() <= 0.000001:
		return Vector3.ZERO
	return dir.normalized() * v.length()


func _face(dir: Vector3) -> void:
	var flat: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() <= 0.000001:
		return
	_facing = flat.normalized()
	_pivot.rotation.y = atan2(-_facing.x, -_facing.z)


func _on_health_changed(new_value: int, max_now: int) -> void:
	_emit_bus(&"vitality_changed", [new_value, max_now])


func _on_hit_taken(dmg: int, knockback: Vector3, source: Node) -> void:
	if _health.invulnerable:
		return
	_knock = knockback
	_emit_bus(&"player_damaged", [roundi(float(dmg) * damage_taken_multiplier), source])


func _emit_bus(signal_name: StringName, args: Array) -> void:
	if signal_name == &"player_damaged":
		SoundPlayer.cue(self, &"player_hurt")  # the single place the player's hurt sound is cued
	var bus: Node = event_bus
	if bus == null:
		bus = get_node_or_null("/root/EventBus")
	if bus == null:
		return
	match args.size():
		1:
			bus.emit_signal(signal_name, args[0])
		2:
			bus.emit_signal(signal_name, args[0], args[1])


static func _ticks(seconds: float) -> int:
	return maxi(roundi(seconds * float(TICK_RATE)), 1)
