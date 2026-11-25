class_name BossAkshaya
extends EnemyBase
## Akshaya Kumara, Ravana's young son (DESIGN §4.5, §9 M26). A brave young warrior, 500 HP, in two phases.
## Phase 1 (MOUNTED): he rides a gilded chariot that charges along a telegraphed lane and fires volleys. Only heavy
## hits (damage >= HEAVY_DAMAGE) hurt the chariot, which has its own CHARIOT_HP pool; his own Health is untouchable
## meanwhile. When the chariot breaks he is thrown clear and phase 2 (ON_FOOT) starts: sword-and-shield-like combos.
## At 0 HP he dissolves into golden embers (no gore, §2). Stats are set here (the boss is not in enemies.json).

signal phase_changed(new_phase: int)
signal chariot_destroyed()

enum Phase { MOUNTED, ON_FOOT }
enum Move { CHARGE, VOLLEY, COMBO }

const BOSS_HP: int = 500
const CHARIOT_HP: int = 150
## A hit counts as heavy (and so hurts the chariot) from this much damage, the same threshold EnemyBase uses.
const HEAVY_DAMAGE: int = 30
const CHARGE_WINDUP: float = 1.0
const CHARGE_SPEED: float = 16.0
const CHARGE_DURATION: float = 0.8
const CHARGE_LANE_WIDTH: float = 3.0
const CHARGE_DAMAGE: int = 20
const VOLLEY_WINDUP: float = 0.6
const VOLLEY_ARROWS: int = 5
const VOLLEY_SPREAD: float = 0.14
const VOLLEY_SPEED: float = 17.0
const VOLLEY_LIFETIME: float = 2.0
const VOLLEY_DAMAGE: int = 6
const COMBO_WINDUP: float = 0.5
const COMBO_STEP_GAP: float = 0.45
const COMBO_STEPS: int = 3
const COMBO_DAMAGE: int = 12
const FOOT_SCALE: float = 1.1
const EMBER_COUNT: int = 60
const EMBER_GROUP: StringName = &"boss_embers"
const _MOVE_RECOVER: float = 0.5

var phase: Phase = Phase.MOUNTED
var chariot_health: Health
var chariot: Node3D
var move: Move = Move.VOLLEY

var _moves_done: int = 0
var _charge_dir: Vector3 = Vector3.ZERO
var _combo_step: int = 0
var _crown: MeshInstance3D


func _init() -> void:
	enemy_id = &"boss_akshaya"
	hp = BOSS_HP
	speed = 3.5
	damage = COMBO_DAMAGE
	attack_range = 2.6
	windup = COMBO_WINDUP
	cooldown = 1.2
	vision_range = 40.0
	vision_angle_deg = 360.0
	model_variant = &"spear"


func _ready() -> void:
	super()
	health.invulnerable = true
	_build_chariot()
	_build_crown()
	model.position = Vector3(0.0, ChariotModel.PLATFORM_TOP, 0.2)


## Applies a hit. Phase 1: only heavy hits count, against the chariot. Phase 2: normal damage to the boss.
func apply_hit(amount: int, knockback: Vector3, heavy: bool) -> void:
	if state == State.DISSOLVE:
		return
	if phase == Phase.MOUNTED:
		if heavy or amount >= HEAVY_DAMAGE:
			_damage_chariot(amount)
		return
	super(amount, knockback, heavy)


## Damages the chariot pool. Reaching 0 dismounts the boss.
func _damage_chariot(amount: int) -> void:
	if phase != Phase.MOUNTED or chariot_health == null:
		return
	chariot_health.damage(amount, self)


## Switches to phase 2 at once (the chariot breaks apart). Safe to call only once.
func dismount() -> void:
	if phase == Phase.ON_FOOT:
		return
	phase = Phase.ON_FOOT
	health.invulnerable = false
	if chariot != null:
		chariot.queue_free()
		chariot = null
	hitbox.deactivate()
	_set_hitbox_sphere(attack_range * 0.5, Vector3(0.0, 1.0, -attack_range * 0.5))
	model.position = Vector3(0.0, 0.0, 0.0)
	model.scale = Vector3.ONE * FOOT_SCALE
	speed = 4.5
	if state == State.ATTACK or state == State.STAGGER:
		_enter(State.CHASE)
	_cooldown_left = 0.8
	phase_changed.emit(int(Phase.ON_FOOT))
	chariot_destroyed.emit()


func _stagger_on_hit(heavy: bool) -> bool:
	return phase == Phase.ON_FOOT and heavy


func _on_hurtbox_hit(amount: int, knockback: Vector3, _source: Node) -> void:
	if phase == Phase.MOUNTED:
		if amount >= HEAVY_DAMAGE:
			_damage_chariot(amount)
		return
	super(amount, knockback, _source)


func _on_chariot_depleted(_source: Node) -> void:
	dismount()


func _enter(s: State) -> void:
	var was: State = state
	super(s)
	if s == State.DISSOLVE and was != State.DISSOLVE:
		if chariot != null:
			chariot.visible = false
		_spawn_embers()


# ---- behaviour ---------------------------------------------------------------------------------------

func _tick_chase(_delta: float) -> void:
	var t: Node3D = _get_target()
	if t == null:
		velocity = Vector3.ZERO
		return
	_face(t.global_position)
	var dist: float = _flat_distance(t.global_position)
	if phase == Phase.MOUNTED:
		velocity = Vector3.ZERO
		if _cooldown_left <= 0.0:
			_choose_mounted_move()
			_enter(State.ATTACK)
		return
	if dist <= attack_range and _cooldown_left <= 0.0:
		move = Move.COMBO
		_enter(State.ATTACK)
	elif dist > attack_range * 0.8:
		_move_toward(t.global_position, speed)
		RakshasaModel.set_pose(model, &"walk_a" if int(_state_time * 4.0) % 2 == 0 else &"walk_b")
	else:
		velocity = Vector3.ZERO


func _choose_mounted_move() -> void:
	# Charge, then two volleys, repeating.
	move = Move.CHARGE if _moves_done % 3 == 0 else Move.VOLLEY
	_moves_done += 1


func _on_attack_started() -> void:
	var t: Node3D = _get_target()
	if t != null:
		_face(t.global_position)
	_combo_step = 0
	_charge_dir = -global_transform.basis.z
	_charge_dir.y = 0.0
	_charge_dir = _charge_dir.normalized()
	match move:
		Move.CHARGE:
			var lane: BoxMesh = BoxMesh.new()
			lane.size = Vector3(CHARGE_LANE_WIDTH, 0.02, _charge_length())
			telegraph.mesh = lane
			telegraph.position = Vector3(0.0, 0.03, -_charge_length() * 0.5)
		Move.VOLLEY:
			var line: BoxMesh = BoxMesh.new()
			line.size = Vector3(0.4, 0.02, 12.0)
			telegraph.mesh = line
			telegraph.position = Vector3(0.0, 0.03, -6.0)
		_:
			var disc: CylinderMesh = CylinderMesh.new()
			disc.top_radius = attack_range
			disc.bottom_radius = attack_range
			disc.height = 0.02
			telegraph.mesh = disc
			telegraph.position = Vector3(0.0, 0.03, 0.0)
	RakshasaModel.set_pose(model, &"attack_wind")


func _tick_attack() -> void:
	match move:
		Move.CHARGE:
			_tick_charge()
		Move.VOLLEY:
			_tick_volley()
		_:
			_tick_combo()


func _windup_for(m: Move) -> float:
	match m:
		Move.CHARGE:
			return CHARGE_WINDUP
		Move.VOLLEY:
			return VOLLEY_WINDUP
		_:
			return COMBO_WINDUP


func _charge_length() -> float:
	return CHARGE_SPEED * CHARGE_DURATION


func _tick_charge() -> void:
	var wind: float = CHARGE_WINDUP
	if not _strike_done:
		velocity = Vector3.ZERO
		if _state_time >= wind:
			_strike_done = true
			telegraph.visible = false
			_set_hitbox_box(Vector3(CHARGE_LANE_WIDTH, 2.0, 3.0), Vector3(0.0, 1.0, -1.5))
			hitbox.damage = CHARGE_DAMAGE
			hitbox.knockback = 6.0
			hitbox.activate(CHARGE_DURATION)
		return
	var run: float = _state_time - wind
	if run < CHARGE_DURATION:
		velocity = _charge_dir * CHARGE_SPEED
		if chariot != null:
			ChariotModel.spin_wheels(chariot, CHARGE_SPEED * get_physics_process_delta_time() / ChariotModel.WHEEL_RADIUS)
	else:
		velocity = Vector3.ZERO
		hitbox.deactivate()
		if run >= CHARGE_DURATION + _MOVE_RECOVER:
			_finish_attack()


func _tick_volley() -> void:
	velocity = Vector3.ZERO
	if not _strike_done:
		if _state_time >= VOLLEY_WINDUP:
			_strike_done = true
			telegraph.visible = false
			_loose_volley()
	elif _state_time >= VOLLEY_WINDUP + STRIKE_TIME + _MOVE_RECOVER:
		_finish_attack()


func _tick_combo() -> void:
	velocity = Vector3.ZERO
	var t_next: float = COMBO_WINDUP + float(_combo_step) * COMBO_STEP_GAP
	if _combo_step < COMBO_STEPS:
		if _state_time >= t_next:
			telegraph.visible = false
			hitbox.damage = COMBO_DAMAGE + (6 if _combo_step == COMBO_STEPS - 1 else 0)
			hitbox.knockback = 4.0 if _combo_step == COMBO_STEPS - 1 else 0.0
			hitbox.activate(STRIKE_TIME)
			RakshasaModel.set_pose(model, &"attack_strike")
			_combo_step += 1
	elif _state_time >= COMBO_WINDUP + float(COMBO_STEPS) * COMBO_STEP_GAP + RECOVER_TIME:
		_finish_attack()


func _finish_attack() -> void:
	hitbox.deactivate()
	_cooldown_left = cooldown
	RakshasaModel.set_pose(model, &"idle")
	_enter(State.CHASE)


func _loose_volley() -> void:
	var parent: Node = get_parent()
	if parent == null:
		parent = self
	var origin: Vector3 = global_position + Vector3(0.0, ChariotModel.PLATFORM_TOP + 1.2, 0.0)
	var aim: Vector3 = origin - global_transform.basis.z * 10.0
	var t: Node3D = _get_target()
	if t != null:
		aim = t.global_position + Vector3(0.0, 1.0, 0.0)
	var base_dir: Vector3 = aim - origin
	for i: int in VOLLEY_ARROWS:
		var offset: float = (float(i) - float(VOLLEY_ARROWS - 1) * 0.5) * VOLLEY_SPREAD
		var arrow: GuardArcher.Arrow = GuardArcher.Arrow.new()
		arrow.damage = VOLLEY_DAMAGE
		arrow.flight = base_dir.rotated(Vector3.UP, offset).normalized() * VOLLEY_SPEED
		arrow.activate(VOLLEY_LIFETIME)
		parent.add_child(arrow)
		arrow.global_position = origin


# ---- construction ------------------------------------------------------------------------------------

func _build_chariot() -> void:
	chariot_health = Health.new()
	chariot_health.name = "ChariotHealth"
	chariot_health.max_value = CHARIOT_HP
	add_child(chariot_health)
	chariot_health.depleted.connect(_on_chariot_depleted)
	chariot = ChariotModel.build()
	add_child(chariot)


func _build_crown() -> void:
	var skeleton: Skeleton3D = model.get_node_or_null("Skeleton3D") as Skeleton3D
	if skeleton == null:
		return
	var attach: BoneAttachment3D = BoneAttachment3D.new()
	attach.name = "CrownAttach"
	attach.bone_name = "head"
	_crown = MeshInstance3D.new()
	_crown.name = "Crown"
	var parts: Array[Dictionary] = []
	parts.append({"mesh": MeshKit.cylinder(0.2, 0.22, 0.08, 8, Palette.GOLD), "transform": Transform3D(Basis(), Vector3(0.0, 0.2, 0.0))})
	for i: int in 5:
		var a: float = TAU * float(i) / 5.0
		parts.append({"mesh": MeshKit.cone(0.035, 0.14, 5, Palette.GOLD), "transform": Transform3D(Basis(), Vector3(sin(a) * 0.17, 0.3, cos(a) * 0.17))})
	_crown.mesh = MeshKit.merge(parts)
	_crown.material_override = MeshKit.flat_material()
	attach.add_child(_crown)
	skeleton.add_child(attach)
	_collect_meshes(attach)


func _set_hitbox_sphere(radius: float, pos: Vector3) -> void:
	var shape: CollisionShape3D = hitbox.get_child(0) as CollisionShape3D
	if shape == null:
		return
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	shape.position = pos


func _set_hitbox_box(size: Vector3, pos: Vector3) -> void:
	var shape: CollisionShape3D = hitbox.get_child(0) as CollisionShape3D
	if shape == null:
		return
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos


## Golden embers rise from the fallen warrior (an honourable end, no gore). They outlive the boss node.
func _spawn_embers() -> void:
	var embers: CPUParticles3D = CPUParticles3D.new()
	embers.name = "Embers"
	embers.amount = EMBER_COUNT
	embers.one_shot = true
	embers.explosiveness = 0.6
	embers.lifetime = 1.6
	embers.direction = Vector3.UP
	embers.spread = 35.0
	embers.initial_velocity_min = 1.5
	embers.initial_velocity_max = 3.5
	embers.gravity = Vector3(0.0, -0.4, 0.0)
	embers.color = Palette.GOLD
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Palette.GOLD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	embers.mesh = quad
	embers.add_to_group(EMBER_GROUP)
	var parent: Node = get_parent()
	if parent == null:
		parent = self
	parent.add_child(embers)
	embers.global_position = global_position + Vector3(0.0, 1.0, 0.0)
	embers.emitting = true
	embers.finished.connect(embers.queue_free)
