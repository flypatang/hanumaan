class_name EnemyBase
extends CharacterBody3D
## Enemy state machine (DESIGN §9 M21, §4.3, §4.5): idle, patrol, alert, chase, attack, stagger, dissolve.
## Stats come from data/enemies.json. All timers use delta; `tick(delta)` is the whole brain, so tests can
## drive it with fixed deltas. Defeated enemies dissolve (shrink and fade); there is no gore (§2).
## Subclasses (M22) may override `_stagger_on_hit()`, `_on_attack_started()` and `_on_attack_strike()`.

enum State { IDLE, PATROL, ALERT, CHASE, ATTACK, STAGGER, DISSOLVE }

const DATA_PATH: String = "res://data/enemies.json"
const SMALL_SIZE_STATE: int = 0
## A SMALL player is only seen within this fraction of the vision range (§4.2).
const SMALL_VISION_FACTOR: float = 0.25
const ALERT_TIME: float = 0.5
const LOSE_TARGET_TIME: float = 3.0
const STAGGER_TIME: float = 0.5
const DISSOLVE_TIME: float = 0.8
const STRIKE_TIME: float = 0.2
const RECOVER_TIME: float = 0.3
const MIN_WINDUP: float = 0.4
const WAYPOINT_REACHED: float = 0.5

@export var enemy_id: StringName = &"guard_spear"

var state: State = State.IDLE
var hp: int = 1
var speed: float = 3.0
var damage: int = 10
var attack_range: float = 2.0
var windup: float = 0.5
var cooldown: float = 1.5
var vision_range: float = 12.0
var vision_angle_deg: float = 90.0
var model_variant: StringName = &"spear"
var waypoints: Array[Vector3] = []
## When true (kinkara), only heavy hits stagger this enemy.
var stagger_heavy_only: bool = false

var health: Health
var hitbox: Hitbox
var hurtbox: Hurtbox
var telegraph: MeshInstance3D
var nav_agent: NavigationAgent3D
var model: Node3D

var _target: Node3D = null
var _waypoint_index: int = 0
var _state_time: float = 0.0
var _cooldown_left: float = 0.0
var _lost_time: float = 0.0
var _strike_done: bool = false
var _dissolve_done: bool = false
var _models_meshes: Array[MeshInstance3D] = []


## Reads the whole enemy table (id -> stats row) from data/enemies.json.
static func load_table() -> Dictionary:
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _ready() -> void:
	_apply_stats()
	_build_nodes()
	add_to_group(&"enemy")


func _physics_process(delta: float) -> void:
	tick(delta)
	if state != State.DISSOLVE:
		move_and_slide()


## Sets the target explicitly (otherwise the first node in group 'player' is used).
func set_target(t: Node3D) -> void:
	_target = t


## Forces a state (used by spawners and tests). Resets the state timer.
func force_state(s: State) -> void:
	_enter(s)


## True if `t` is inside the vision cone and range with a clear line. A SMALL player is seen only within 25% of range.
func can_see(t: Node3D) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	var to: Vector3 = t.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var reach: float = vision_range
	if t.has_meta("size_state") and (t.get_meta("size_state") as int) == SMALL_SIZE_STATE:
		reach *= SMALL_VISION_FACTOR
	if dist > reach:
		return false
	if dist > 0.001:
		var fwd: Vector3 = -global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var angle: float = rad_to_deg(fwd.angle_to(to.normalized()))
		if angle > vision_angle_deg * 0.5:
			return false
	return _line_clear(t)


## Applies a hit: damages Health, knocks back, and staggers if `_stagger_on_hit(heavy)` allows.
func apply_hit(amount: int, knockback: Vector3, heavy: bool) -> void:
	if state == State.DISSOLVE:
		return
	velocity = Vector3(knockback.x, 0.0, knockback.z)
	health.damage(amount, self)
	if state == State.DISSOLVE:
		return
	if _stagger_on_hit(heavy):
		hitbox.deactivate()
		telegraph.visible = false
		_enter(State.STAGGER)


## Advances the state machine by `delta` seconds.
func tick(delta: float) -> void:
	_state_time += delta
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	match state:
		State.IDLE:
			_tick_idle()
		State.PATROL:
			_tick_patrol()
		State.ALERT:
			_tick_alert()
		State.CHASE:
			_tick_chase(delta)
		State.ATTACK:
			_tick_attack()
		State.STAGGER:
			_tick_stagger()
		State.DISSOLVE:
			_tick_dissolve()


# ---- overridable hooks -------------------------------------------------------------------------------

func _stagger_on_hit(heavy: bool) -> bool:
	return heavy or not stagger_heavy_only


func _on_attack_started() -> void:
	pass


func _on_attack_strike() -> void:
	hitbox.activate(STRIKE_TIME)


# ---- states ------------------------------------------------------------------------------------------

func _tick_idle() -> void:
	velocity = Vector3.ZERO
	if _spot():
		_enter(State.ALERT)
	elif not waypoints.is_empty():
		_enter(State.PATROL)


func _tick_patrol() -> void:
	if _spot():
		_enter(State.ALERT)
		return
	if waypoints.is_empty():
		_enter(State.IDLE)
		return
	var goal: Vector3 = waypoints[_waypoint_index % waypoints.size()]
	var flat: Vector3 = goal - global_position
	flat.y = 0.0
	if flat.length() <= WAYPOINT_REACHED:
		_waypoint_index = (_waypoint_index + 1) % waypoints.size()
		velocity = Vector3.ZERO
		return
	_move_toward(goal, speed * 0.5)


func _tick_alert() -> void:
	velocity = Vector3.ZERO
	var t: Node3D = _get_target()
	if t != null:
		_face(t.global_position)
	if _state_time >= ALERT_TIME:
		_enter(State.CHASE if t != null else State.IDLE)


func _tick_chase(_delta: float) -> void:
	var t: Node3D = _get_target()
	if t == null:
		_enter(State.IDLE)
		return
	if can_see(t):
		_lost_time = 0.0
	else:
		_lost_time += _delta
		if _lost_time >= LOSE_TARGET_TIME:
			_enter(State.PATROL if not waypoints.is_empty() else State.IDLE)
			return
	var dist: float = _flat_distance(t.global_position)
	if dist <= attack_range and _cooldown_left <= 0.0:
		_enter(State.ATTACK)
		return
	if dist > attack_range * 0.8:
		nav_agent.target_position = t.global_position
		_move_toward(_next_path_point(t.global_position), speed)
	else:
		velocity = Vector3.ZERO
	_face(t.global_position)


func _tick_attack() -> void:
	velocity = Vector3.ZERO
	if not _strike_done:
		if _state_time >= windup:
			_strike_done = true
			telegraph.visible = false
			_on_attack_strike()
	elif _state_time >= windup + STRIKE_TIME + RECOVER_TIME:
		_cooldown_left = cooldown
		_enter(State.CHASE)


func _tick_stagger() -> void:
	if _state_time >= STAGGER_TIME:
		_enter(State.CHASE if _get_target() != null else State.IDLE)


func _tick_dissolve() -> void:
	var k: float = clampf(_state_time / DISSOLVE_TIME, 0.0, 1.0)
	scale = Vector3.ONE * maxf(1.0 - k, 0.001)
	for m: MeshInstance3D in _models_meshes:
		m.transparency = k
	if k >= 1.0 and not _dissolve_done:
		_dissolve_done = true
		var bus: Node = get_node_or_null("/root/EventBus")
		if bus != null:
			bus.emit_signal("enemy_defeated", enemy_id, global_position)
		queue_free()


# ---- helpers -----------------------------------------------------------------------------------------

func _enter(s: State) -> void:
	state = s
	_state_time = 0.0
	match s:
		State.ATTACK:
			_strike_done = false
			telegraph.visible = true
			_on_attack_started()
		State.ALERT:
			_lost_time = 0.0
		State.DISSOLVE:
			velocity = Vector3.ZERO
			SoundPlayer.cue_at(self, &"enemy_dissolve")
			hitbox.deactivate()
			telegraph.visible = false
			hurtbox.monitoring = false
			if model != null:
				RakshasaModel.set_pose(model, &"idle")
		_:
			pass
	if s != State.ATTACK and telegraph != null:
		telegraph.visible = false


func _spot() -> bool:
	return can_see(_get_target())


func _get_target() -> Node3D:
	if _target != null and is_instance_valid(_target):
		return _target
	if is_inside_tree():
		var nodes: Array[Node] = get_tree().get_nodes_in_group(&"player")
		if not nodes.is_empty():
			return nodes[0] as Node3D
	return null


func _flat_distance(p: Vector3) -> float:
	var d: Vector3 = p - global_position
	d.y = 0.0
	return d.length()


func _face(p: Vector3) -> void:
	var d: Vector3 = p - global_position
	d.y = 0.0
	if d.length_squared() > 0.0001:
		rotation.y = atan2(-d.x, -d.z)


func _next_path_point(fallback: Vector3) -> Vector3:
	var p: Vector3 = nav_agent.get_next_path_position()
	if p.distance_to(global_position) < 0.1:
		return fallback
	return p


func _move_toward(p: Vector3, spd: float) -> void:
	var d: Vector3 = p - global_position
	d.y = 0.0
	if d.length_squared() < 0.0001:
		velocity = Vector3.ZERO
		return
	velocity = d.normalized() * spd
	_face(p)


func _line_clear(t: Node3D) -> bool:
	if not is_inside_tree():
		return true
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return true
	var from: Vector3 = global_position + Vector3(0, 1.0, 0)
	var to: Vector3 = t.global_position + Vector3(0, 1.0, 0)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, Layers.mask([Layers.WORLD]))
	var hit: Dictionary = space.intersect_ray(q)
	return hit.is_empty()


func _apply_stats() -> void:
	var table: Dictionary = load_table()
	if not table.has(String(enemy_id)):
		return
	var row: Dictionary = table[String(enemy_id)] as Dictionary
	hp = row["hp"] as int
	speed = row["speed"] as float
	damage = row["damage"] as int
	attack_range = row["attack_range"] as float
	windup = maxf(row["windup"] as float, MIN_WINDUP)
	cooldown = row["cooldown"] as float
	vision_range = row["vision_range"] as float
	vision_angle_deg = row["vision_angle_deg"] as float
	stagger_heavy_only = enemy_id == &"kinkara"
	model_variant = StringName(row["model_variant"] as String)


func _build_nodes() -> void:
	collision_layer = Layers.mask([Layers.ENEMY])
	collision_mask = Layers.mask([Layers.WORLD])
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)

	health = Health.new()
	health.name = "Health"
	health.max_value = hp
	add_child(health)
	health.depleted.connect(_on_depleted)

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.team = &"enemy"
	hurtbox.health_path = NodePath("../Health")
	var hs: CollisionShape3D = CollisionShape3D.new()
	hs.shape = cap
	hs.position = Vector3(0, 0.9, 0)
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hurtbox.hit_taken.connect(_on_hurtbox_hit)

	hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	hitbox.team = &"enemy"
	hitbox.damage = damage
	var atk: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = maxf(attack_range * 0.5, 0.5)
	atk.shape = sphere
	atk.position = Vector3(0, 1.0, -attack_range * 0.5)
	hitbox.add_child(atk)
	add_child(hitbox)

	nav_agent = NavigationAgent3D.new()
	nav_agent.name = "NavigationAgent3D"
	add_child(nav_agent)

	telegraph = MeshInstance3D.new()
	telegraph.name = "Telegraph"
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = attack_range
	disc.bottom_radius = attack_range
	disc.height = 0.02
	telegraph.mesh = disc
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(Palette.SINDOOR, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph.material_override = mat
	telegraph.position = Vector3(0, 0.03, 0)
	telegraph.visible = false
	add_child(telegraph)

	model = RakshasaModel.build(model_variant)
	add_child(model)
	_collect_meshes(model)


func _collect_meshes(n: Node) -> void:
	var m: MeshInstance3D = n as MeshInstance3D
	if m != null:
		_models_meshes.append(m)
	for c: Node in n.get_children():
		_collect_meshes(c)


func _on_depleted(_source: Node) -> void:
	_enter(State.DISSOLVE)


func _on_hurtbox_hit(amount: int, knockback: Vector3, _source: Node) -> void:
	# Health was already reduced by the hurtbox; only the reaction is needed here.
	velocity = Vector3(knockback.x, 0.0, knockback.z)
	if state != State.DISSOLVE and _stagger_on_hit(amount >= 30):
		hitbox.deactivate()
		_enter(State.STAGGER)
