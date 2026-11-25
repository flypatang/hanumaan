class_name GuardArcher
extends EnemyBase
## Rakshasa archer (DESIGN §4.5, §9 M22). It keeps its distance: it backs away when the player is closer than
## RETREAT_DISTANCE, holds still between that and MIN_FIRE_DISTANCE, fires from MIN_FIRE_DISTANCE to MAX_FIRE_DISTANCE,
## and closes in when farther. Its attack is a 3-arrow volley of Arrow nodes (team enemy); each arrow deals a third
## of the table damage. The telegraph is a narrow line toward the target instead of a disc.

const RETREAT_DISTANCE: float = 5.0
const MIN_FIRE_DISTANCE: float = 6.0
const MAX_FIRE_DISTANCE: float = 10.0
const VOLLEY_ARROWS: int = 3
## Angle between neighbouring arrows of the volley, in radians.
const VOLLEY_SPREAD: float = 0.09
const ARROW_SPEED: float = 18.0
const ARROW_LIFETIME: float = 2.0
const ARROW_RADIUS: float = 0.15
const ARROW_GROUP: StringName = &"enemy_projectile"
const _ARROW_SPAWN_HEIGHT: float = 1.4


## A flying arrow: an enemy-team Hitbox that moves along `flight` until its activation runs out.
class Arrow extends Hitbox:
	var flight: Vector3 = Vector3.ZERO

	func _ready() -> void:
		super()
		var shape: CollisionShape3D = CollisionShape3D.new()
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = GuardArcher.ARROW_RADIUS
		shape.shape = sphere
		add_child(shape)
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = MeshKit.box(Vector3(0.06, 0.06, 0.9), Palette.BARK)
		mesh.material_override = MeshKit.flat_material()
		add_child(mesh)
		add_to_group(GuardArcher.ARROW_GROUP)

	func _physics_process(delta: float) -> void:
		step(delta)
		if not is_active():
			queue_free()

	## Moves the arrow by `delta` seconds and counts its activation down.
	func step(delta: float) -> void:
		global_position += flight * delta
		advance(delta)


func _init() -> void:
	enemy_id = &"guard_archer"


func _ready() -> void:
	super()
	var line: BoxMesh = BoxMesh.new()
	line.size = Vector3(0.3, 0.02, attack_range)
	telegraph.mesh = line
	telegraph.position = Vector3(0.0, 0.03, -attack_range * 0.5)


func _tick_chase(delta: float) -> void:
	var t: Node3D = _get_target()
	if t == null:
		_enter(State.IDLE)
		return
	if can_see(t):
		_lost_time = 0.0
	else:
		_lost_time += delta
		if _lost_time >= LOSE_TARGET_TIME:
			_enter(State.PATROL if not waypoints.is_empty() else State.IDLE)
			return
	_face(t.global_position)
	var dist: float = _flat_distance(t.global_position)
	if dist < RETREAT_DISTANCE:
		_back_away(t.global_position)
	elif dist > MAX_FIRE_DISTANCE:
		_move_toward(t.global_position, speed)
	else:
		velocity = Vector3.ZERO
	if dist >= MIN_FIRE_DISTANCE and dist <= MAX_FIRE_DISTANCE and _cooldown_left <= 0.0:
		_enter(State.ATTACK)


func _on_attack_strike() -> void:
	var aim: Vector3 = global_position - global_transform.basis.z * attack_range
	var t: Node3D = _get_target()
	if t != null:
		aim = t.global_position + Vector3(0.0, 1.0, 0.0)
	_loose_volley(aim)


func _back_away(p: Vector3) -> void:
	var d: Vector3 = global_position - p
	d.y = 0.0
	if d.length_squared() < 0.0001:
		velocity = Vector3.ZERO
		return
	velocity = d.normalized() * speed


func _loose_volley(aim: Vector3) -> void:
	var parent: Node = get_parent()
	if parent == null:
		parent = self
	var origin: Vector3 = global_position + Vector3(0.0, _ARROW_SPAWN_HEIGHT, 0.0)
	var base_dir: Vector3 = aim - origin
	var arrow_damage: int = maxi(1, damage / VOLLEY_ARROWS)
	for i: int in VOLLEY_ARROWS:
		var offset: float = (float(i) - float(VOLLEY_ARROWS - 1) * 0.5) * VOLLEY_SPREAD
		var dir: Vector3 = base_dir.rotated(Vector3.UP, offset).normalized()
		var arrow: Arrow = Arrow.new()
		arrow.damage = arrow_damage
		arrow.flight = dir * ARROW_SPEED
		arrow.activate(ARROW_LIFETIME)
		parent.add_child(arrow)
		arrow.global_position = origin
