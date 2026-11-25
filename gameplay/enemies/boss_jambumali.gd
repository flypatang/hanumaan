class_name BossJambumali
extends EnemyBase
## Jambumali, archer boss of the Ashoka grove (DESIGN §4.5, §9 M25). 350 HP; relocates to the next pillar every
## PILLAR_INTERVAL seconds; alternates an arrow storm (a telegraphed 5 m disc where arrows fall after 0.8 s) with an
## aimed triple shot. Only heavy hits stagger it. It dissolves at 0 HP. Its stats are set here, not in enemies.json.

const BOSS_HP: int = 350
const PILLAR_INTERVAL: float = 6.0
const STORM_RADIUS: float = 5.0
const STORM_DELAY: float = 0.8
const STORM_ACTIVE_TIME: float = 0.3
const TRIPLE_WINDUP: float = 0.6
const TRIPLE_ARROWS: int = 3
const TRIPLE_SPREAD: float = 0.12
const ARROW_SPEED: float = 20.0
const ARROW_LIFETIME: float = 2.0
const MODEL_SCALE: float = 1.3
const STORM_GROUP: StringName = &"boss_storm"
const PILLAR_GROUP: StringName = &"arena_pillar"
const PATTERN_STORM: StringName = &"storm"
const PATTERN_TRIPLE: StringName = &"triple"
const _PILLAR_REACHED: float = 0.4
const _ARROW_SPAWN_HEIGHT: float = 1.8

## Pillar positions the boss moves between (set by the level; falls back to nodes in group `arena_pillar`).
var pillars: Array[Vector3] = []
var pillar_index: int = -1
var pattern: StringName = PATTERN_STORM
var storm_center: Vector3 = Vector3.ZERO

var _pillar_timer: float = 0.0
var _relocating: bool = false
var _attack_count: int = 0


## A falling arrow storm: an enemy Hitbox covering a disc of STORM_RADIUS.
class Storm extends Hitbox:
	func _ready() -> void:
		super()
		var shape: CollisionShape3D = CollisionShape3D.new()
		var cyl: CylinderShape3D = CylinderShape3D.new()
		cyl.radius = BossJambumali.STORM_RADIUS
		cyl.height = 4.0
		shape.shape = cyl
		add_child(shape)
		add_to_group(BossJambumali.STORM_GROUP)

	func _physics_process(delta: float) -> void:
		advance(delta)
		if not is_active():
			queue_free()


func _init() -> void:
	enemy_id = &"boss_jambumali"


func _ready() -> void:
	super()
	telegraph.top_level = true
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = STORM_RADIUS
	disc.bottom_radius = STORM_RADIUS
	disc.height = 0.02
	telegraph.mesh = disc
	model.scale = Vector3.ONE * MODEL_SCALE
	_add_gold_trim()


func set_pillars(points: Array[Vector3]) -> void:
	pillars = points.duplicate()
	pillar_index = -1


func is_relocating() -> bool:
	return _relocating


func tick(delta: float) -> void:
	if state == State.CHASE:
		_pillar_timer += delta
	super(delta)


func _apply_stats() -> void:
	hp = BOSS_HP
	speed = 6.0
	damage = 20
	attack_range = 16.0
	windup = STORM_DELAY
	cooldown = 2.5
	vision_range = 40.0
	vision_angle_deg = 360.0
	stagger_heavy_only = true
	model_variant = &"archer"


func _tick_chase(delta: float) -> void:
	var t: Node3D = _get_target()
	if t == null:
		_enter(State.IDLE)
		return
	if _relocating:
		_tick_relocate()
		return
	_face(t.global_position)
	velocity = Vector3.ZERO
	if _pillar_timer >= PILLAR_INTERVAL and not _pillar_points().is_empty():
		_pillar_timer = 0.0
		pillar_index = (pillar_index + 1) % _pillar_points().size()
		_relocating = true
		return
	if _cooldown_left <= 0.0 and _flat_distance(t.global_position) <= attack_range:
		_enter(State.ATTACK)


func _on_attack_started() -> void:
	var t: Node3D = _get_target()
	pattern = PATTERN_STORM if _attack_count % 2 == 0 else PATTERN_TRIPLE
	_attack_count += 1
	if pattern == PATTERN_STORM:
		windup = STORM_DELAY
		storm_center = t.global_position if t != null else global_position
		storm_center.y = global_position.y
		telegraph.mesh = _disc_mesh()
		telegraph.global_position = storm_center + Vector3(0.0, 0.03, 0.0)
		telegraph.visible = true
	else:
		windup = TRIPLE_WINDUP
		telegraph.visible = false
	if t != null:
		_face(t.global_position)


func _on_attack_strike() -> void:
	if pattern == PATTERN_STORM:
		_drop_storm()
	else:
		_fire_triple()


func _enter(s: State) -> void:
	if s != State.CHASE or state == State.IDLE or state == State.ALERT:
		_relocating = false if s != State.CHASE else _relocating
	super(s)


func _tick_relocate() -> void:
	var goal: Vector3 = _pillar_points()[pillar_index]
	if _flat_distance(goal) <= _PILLAR_REACHED:
		_relocating = false
		velocity = Vector3.ZERO
		return
	_move_toward(goal, speed)


func _pillar_points() -> Array[Vector3]:
	if not pillars.is_empty() or not is_inside_tree():
		return pillars
	var out: Array[Vector3] = []
	for n: Node in get_tree().get_nodes_in_group(PILLAR_GROUP):
		out.append((n as Node3D).global_position)
	return out


func _disc_mesh() -> CylinderMesh:
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = STORM_RADIUS
	disc.bottom_radius = STORM_RADIUS
	disc.height = 0.02
	return disc


func _drop_storm() -> void:
	var parent: Node = get_parent()
	if parent == null:
		parent = self
	var storm: Storm = Storm.new()
	storm.damage = damage
	storm.activate(STORM_ACTIVE_TIME)
	parent.add_child(storm)
	storm.global_position = storm_center


func _fire_triple() -> void:
	var parent: Node = get_parent()
	if parent == null:
		parent = self
	var t: Node3D = _get_target()
	var origin: Vector3 = global_position + Vector3(0.0, _ARROW_SPAWN_HEIGHT, 0.0)
	var aim: Vector3 = global_position - global_transform.basis.z * attack_range
	if t != null:
		aim = t.global_position + Vector3(0.0, 1.0, 0.0)
	var base_dir: Vector3 = aim - origin
	var arrow_damage: int = maxi(1, damage / TRIPLE_ARROWS)
	for i: int in TRIPLE_ARROWS:
		var offset: float = (float(i) - float(TRIPLE_ARROWS - 1) * 0.5) * TRIPLE_SPREAD
		var arrow: GuardArcher.Arrow = GuardArcher.Arrow.new()
		arrow.damage = arrow_damage
		arrow.flight = base_dir.rotated(Vector3.UP, offset).normalized() * ARROW_SPEED
		arrow.activate(ARROW_LIFETIME)
		parent.add_child(arrow)
		arrow.global_position = origin


func _add_gold_trim() -> void:
	var crown: MeshInstance3D = MeshInstance3D.new()
	crown.name = "GoldCrown"
	crown.mesh = MeshKit.cylinder(0.2, 0.22, 0.1, 8, Palette.GOLD)
	crown.material_override = MeshKit.flat_material()
	crown.position = Vector3(0.0, 1.78, 0.0)
	model.add_child(crown)
	_models_meshes.append(crown)
