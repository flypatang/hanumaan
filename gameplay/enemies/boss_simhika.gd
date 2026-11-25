class_name BossSimhika
extends Node3D
## Simhika, the shadow-seizing sea demoness (DESIGN §4.5, §9 M23). Ch1 boss, 400 HP, fought at the leap's
## "simhika" gate. Phase table (by HP):
##   1 SHADOW GRAB (400..281): a dark pool chases the player's shadow; being caught costs HP and stuns briefly.
##   2 WAVES (280..141): a sweeping wave band, telegraphed for 0.6 s before it strikes.
##   3 SWALLOW (140..1): the mouth opens for a 3 s window; the player must SHRINK (SizeShift) to dive in.
##     Inside, the boss is vulnerable through three hit phases (HP 140-93, 93-47, 47-0). A missed window is a bite.
## A hit never skips a phase (damage is clamped at the phase floor). Defeat: she kneels, then dissolves into sea
## foam (no gore, §2) and emits EventBus.enemy_defeated. `tick(delta)` is the whole brain (frame-rate independent).

signal phase_changed(new_phase: int)
signal window_opened()
signal window_missed()
signal dived_in()
signal inner_phase_cleared(inner: int)
signal player_stunned(duration: float)
signal defeated()

const MAX_HP: int = 400
const PHASE2_HP: int = 280
const PHASE3_HP: int = 140
## HP at which each inner hit phase (1..3) of phase 3 ends.
const INNER_FLOORS: Array[int] = [93, 47, 0]
const SMALL_SIZE_STATE: int = 0
const SIZE_META: StringName = &"size_state"
const BOSS_ID: StringName = &"boss_simhika"
const NAME_KEY: StringName = &"BOSS_SIMHIKA"

const SHADOW_SPEED: float = 6.0
const SHADOW_SPAWN_DISTANCE: float = 14.0
const SHADOW_DELAY: float = 1.0
const SHADOW_COOLDOWN: float = 3.0
const SHADOW_LIFETIME: float = 8.0
const CATCH_RADIUS: float = 1.2
const GRAB_DAMAGE: int = 15
const GRAB_STUN: float = 1.0

const WAVE_TELEGRAPH: float = 0.6
const WAVE_GAP: float = 2.5
const WAVE_HALF_WIDTH: float = 3.5
const WAVE_LENGTH: float = 40.0
const WAVE_DAMAGE: int = 20
const WAVE_VISUAL_TIME: float = 0.3

const CLOSED_TIME: float = 2.0
const WINDOW_TIME: float = 3.0
const INSIDE_MAX_TIME: float = 12.0
const BITE_DAMAGE: int = 25

const KNEEL_TIME: float = 1.2
const DISSOLVE_TIME: float = 1.5

enum Mouth { CLOSED, OPEN, INSIDE }

## Overrides the EventBus lookup (tests).
var event_bus: Node = null
## The player's Health (damage target); the leap controller's health when attached.
var player_health: Health = null
var health: Health
var target: Node3D = null
var active: bool = false
var phase: int = 1
var inner_phase: int = 0
var mouth: Mouth = Mouth.CLOSED
var shadow_active: bool = false
var shadow_pos: Vector3 = Vector3.ZERO
var player_stun_left: float = 0.0
var waves_struck: int = 0
var model: Node3D = null

var _hurtbox: Hurtbox = null
var _leap: LeapController = null
var _hud: Hud = null
var _mouth_time: float = 0.0
var _shadow_wait: float = SHADOW_DELAY
var _shadow_age: float = 0.0
var _wave_wait: float = WAVE_GAP
var _wave_time: float = -1.0
var _wave_dir: Vector3 = Vector3.FORWARD
var _wave_visual: float = 0.0
var _defeat_time: float = -1.0
var _defeat_sent: bool = false
var _shadow_mesh: MeshInstance3D = null
var _wave_mesh: MeshInstance3D = null
var _foam: CPUParticles3D = null


## Phase (1..3) for a boss HP value.
static func phase_for_hp(hp: int) -> int:
	if hp <= PHASE3_HP:
		return 3
	if hp <= PHASE2_HP:
		return 2
	return 1


## Inner hit phase (1..3) of phase 3 for a boss HP value; 0 outside phase 3.
static func inner_phase_for_hp(hp: int) -> int:
	if hp > PHASE3_HP:
		return 0
	if hp > INNER_FLOORS[0]:
		return 1
	if hp > INNER_FLOORS[1]:
		return 2
	return 3


## The lowest HP a hit may bring the boss to from `hp` (a hit never skips a phase).
static func floor_for_hp(hp: int) -> int:
	match phase_for_hp(hp):
		1:
			return PHASE2_HP
		2:
			return PHASE3_HP
		_:
			return INNER_FLOORS[inner_phase_for_hp(hp) - 1]


func _ready() -> void:
	_build()


func _physics_process(delta: float) -> void:
	tick(delta)


## Starts the fight against `t`.
func engage(t: Node3D) -> void:
	target = t
	active = true
	if _hud != null:
		_hud.show_boss(NAME_KEY, health)


## Hooks the boss to the leap: engages at the "simhika" gate and resumes the rail once she is gone.
func attach_leap(leap: LeapController, player: Node3D) -> void:
	_leap = leap
	target = player
	if player_health == null:
		player_health = leap.health
	leap.gate_reached.connect(_on_gate_reached)


## Shows the boss bar when the fight starts.
func bind_hud(hud: Hud) -> void:
	_hud = hud


## Test and spawner hook: jumps into phase 3 with the player already inside.
func force_inside() -> void:
	health.value = mini(health.value, PHASE3_HP)
	_set_phase(3)
	_set_mouth(Mouth.INSIDE)
	active = true


func is_defeated() -> bool:
	return _defeat_time >= 0.0


func is_kneeling() -> bool:
	return is_defeated() and _defeat_time < KNEEL_TIME


func is_inside() -> bool:
	return mouth == Mouth.INSIDE


## True while the 3 s shrink-and-dive window is open.
func window_open() -> bool:
	return phase == 3 and mouth == Mouth.OPEN and not is_defeated()


func window_left() -> float:
	return maxf(WINDOW_TIME - _mouth_time, 0.0) if window_open() else 0.0


## Hits land in phases 1 and 2, and in phase 3 only while the player is inside.
func is_vulnerable() -> bool:
	if is_defeated():
		return false
	return phase < 3 or mouth == Mouth.INSIDE


func wave_telegraph_visible() -> bool:
	return _wave_time >= 0.0 and _wave_time < WAVE_TELEGRAPH


## Applies a player hit. Ignored when not vulnerable; clamped at the phase floor.
func apply_hit(amount: int, _knockback: Vector3, _heavy: bool) -> void:
	if not is_vulnerable():
		return
	var allowed: int = mini(amount, health.value - floor_for_hp(health.value))
	if allowed > 0:
		health.damage(allowed, self)
	_sync_phase()


## Starts a shadow pool at `pos` (flat).
func shadow_start(pos: Vector3) -> void:
	shadow_active = true
	shadow_pos = Vector3(pos.x, 0.0, pos.z)
	_shadow_age = 0.0


## Starts a wave: telegraph for WAVE_TELEGRAPH seconds, then the band strikes.
func wave_start() -> void:
	var dir: Vector3 = Vector3.FORWARD
	if target != null:
		dir = _flat(target.global_position - global_position)
	_wave_dir = dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD
	_wave_time = 0.0
	_wave_wait = WAVE_GAP


## Advances the fight by `delta` seconds.
func tick(delta: float) -> void:
	player_stun_left = maxf(player_stun_left - delta, 0.0)
	if is_defeated():
		_tick_defeat(delta)
		return
	if not active:
		return
	_sync_phase()
	match phase:
		1:
			_tick_shadow(delta)
		2:
			_tick_wave(delta)
		_:
			_tick_mouth(delta)
	_update_visuals()


# ---- phases ------------------------------------------------------------------------------------------

func _tick_shadow(delta: float) -> void:
	if not shadow_active:
		_shadow_wait -= delta
		if _shadow_wait <= 0.0 and target != null:
			var away: Vector3 = _flat(global_position - target.global_position)
			var dir: Vector3 = away.normalized() if away.length() > 0.001 else Vector3.BACK
			shadow_start(_flat(target.global_position) + dir * SHADOW_SPAWN_DISTANCE)
		return
	if target == null:
		return
	_shadow_age += delta
	var to: Vector3 = _flat(target.global_position) - shadow_pos
	if to.length() <= CATCH_RADIUS:
		shadow_active = false
		_shadow_wait = SHADOW_COOLDOWN
		_hurt_player(GRAB_DAMAGE)
		player_stun_left = GRAB_STUN
		player_stunned.emit(GRAB_STUN)
	elif _shadow_age >= SHADOW_LIFETIME:
		shadow_active = false
		_shadow_wait = SHADOW_COOLDOWN
	else:
		shadow_pos += to.normalized() * minf(SHADOW_SPEED * delta, to.length())


func _tick_wave(delta: float) -> void:
	if _wave_time < 0.0:
		_wave_wait -= delta
		if _wave_wait <= 0.0:
			wave_start()
		return
	_wave_time += delta
	if _wave_time >= WAVE_TELEGRAPH:
		_wave_time = -1.0
		_wave_visual = WAVE_VISUAL_TIME
		waves_struck += 1
		if target != null and _in_wave_band(target.global_position):
			_hurt_player(WAVE_DAMAGE)


func _tick_mouth(delta: float) -> void:
	_mouth_time += delta
	match mouth:
		Mouth.CLOSED:
			if _mouth_time >= CLOSED_TIME:
				_set_mouth(Mouth.OPEN)
				window_opened.emit()
		Mouth.OPEN:
			if _target_is_small():
				_set_mouth(Mouth.INSIDE)
				dived_in.emit()
			elif _mouth_time >= WINDOW_TIME:
				_hurt_player(BITE_DAMAGE)
				window_missed.emit()
				_set_mouth(Mouth.CLOSED)
		Mouth.INSIDE:
			if _mouth_time >= INSIDE_MAX_TIME:
				_set_mouth(Mouth.CLOSED)


func _sync_phase() -> void:
	if health.value <= 0 and not is_defeated():
		_start_defeat()
		return
	var p: int = phase_for_hp(health.value)
	if p != phase:
		_set_phase(p)
	if phase == 3:
		var ip: int = inner_phase_for_hp(health.value)
		if ip != inner_phase:
			var cleared: int = inner_phase
			inner_phase = ip
			if mouth == Mouth.INSIDE and cleared > 0 and ip > cleared:
				inner_phase_cleared.emit(cleared)
				_set_mouth(Mouth.CLOSED)


func _set_phase(p: int) -> void:
	phase = p
	_shadow_wait = SHADOW_DELAY
	shadow_active = false
	_wave_time = -1.0
	_wave_wait = WAVE_GAP
	inner_phase = inner_phase_for_hp(health.value)
	_set_mouth(Mouth.CLOSED)
	phase_changed.emit(p)


func _set_mouth(m: Mouth) -> void:
	mouth = m
	_mouth_time = 0.0
	if model != null:
		SimhikaModel.set_pose(model, &"mouth_open" if m != Mouth.CLOSED else &"idle")


# ---- defeat ------------------------------------------------------------------------------------------

func _start_defeat() -> void:
	_defeat_time = 0.0
	shadow_active = false
	_wave_time = -1.0
	if model != null:
		SimhikaModel.set_pose(model, &"kneel")
	if _hud != null:
		_hud.hide_boss()
	defeated.emit()


func _tick_defeat(delta: float) -> void:
	_defeat_time += delta
	_update_visuals()
	if _defeat_time < KNEEL_TIME:
		return
	var k: float = clampf((_defeat_time - KNEEL_TIME) / DISSOLVE_TIME, 0.0, 1.0)
	if model != null:
		model.scale = Vector3(1.0, maxf(1.0 - k, 0.001), 1.0)
		for mi: Node in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).transparency = k
	if _foam != null:
		_foam.emitting = true
	if k >= 1.0 and not _defeat_sent:
		_defeat_sent = true
		var bus: Node = _bus()
		if bus != null:
			bus.emit_signal("enemy_defeated", BOSS_ID, global_position)
		if _leap != null:
			_leap.resume()
		queue_free()


# ---- helpers -----------------------------------------------------------------------------------------

func _on_gate_reached(id: StringName) -> void:
	if id == &"simhika" and target != null:
		engage(target)


func _on_depleted(_source: Node) -> void:
	if not is_defeated():
		_start_defeat()


func _on_hurtbox_hit(amount: int, knockback: Vector3, _source: Node) -> void:
	apply_hit(amount, knockback, amount >= 30)


func _target_is_small() -> bool:
	if target == null or not target.has_meta(SIZE_META):
		return false
	return (target.get_meta(SIZE_META) as int) == SMALL_SIZE_STATE


func _hurt_player(amount: int) -> void:
	if player_health == null:
		return
	var before: int = player_health.value
	player_health.damage(amount, self)
	if player_health.value != before:
		var bus: Node = _bus()
		if bus != null:
			bus.emit_signal("player_damaged", before - player_health.value, self)


## True if `p` is inside the wave band (a strip of WAVE_HALF_WIDTH either side of the line from the boss).
func _in_wave_band(p: Vector3) -> bool:
	var rel: Vector3 = _flat(p - global_position)
	var along: float = rel.dot(_wave_dir)
	if along < 0.0 or along > WAVE_LENGTH:
		return false
	return (rel - _wave_dir * along).length() <= WAVE_HALF_WIDTH


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _bus() -> Node:
	if event_bus != null:
		return event_bus
	if is_inside_tree():
		return get_node_or_null("/root/EventBus")
	return null


func _update_visuals() -> void:
	if _shadow_mesh == null:
		return
	_shadow_mesh.visible = shadow_active
	_shadow_mesh.global_position = shadow_pos + Vector3(0.0, 0.05, 0.0)
	var telegraph: bool = wave_telegraph_visible()
	_wave_visual = maxf(_wave_visual - get_physics_process_delta_time(), 0.0)
	_wave_mesh.visible = telegraph or _wave_visual > 0.0
	var mid: Vector3 = global_position + _wave_dir * WAVE_LENGTH * 0.5
	_wave_mesh.global_position = Vector3(mid.x, 0.06, mid.z)
	_wave_mesh.rotation.y = atan2(-_wave_dir.x, -_wave_dir.z)
	var mat: StandardMaterial3D = _wave_mesh.material_override as StandardMaterial3D
	mat.albedo_color = Color(Palette.SINDOOR, 0.5) if telegraph else Color(Palette.MOON, 0.7)


func _build() -> void:
	health = Health.new()
	health.name = "Health"
	health.max_value = MAX_HP
	add_child(health)
	health.depleted.connect(_on_depleted)

	_hurtbox = Hurtbox.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.team = &"enemy"
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 3.0
	cs.shape = sphere
	cs.position = Vector3(0.0, 6.0, 0.0)
	_hurtbox.add_child(cs)
	add_child(_hurtbox)
	_hurtbox.hit_taken.connect(_on_hurtbox_hit)

	model = SimhikaModel.build()
	add_child(model)

	_shadow_mesh = _flat_disc("ShadowPool", CATCH_RADIUS * 1.6, Color(Palette.NIGHT_INDIGO, 0.8))
	_shadow_mesh.top_level = true
	_wave_mesh = MeshInstance3D.new()
	_wave_mesh.name = "WaveBand"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(WAVE_HALF_WIDTH * 2.0, 0.05, WAVE_LENGTH)
	_wave_mesh.mesh = box
	_wave_mesh.material_override = _alpha_material(Color(Palette.SINDOOR, 0.5))
	_wave_mesh.top_level = true
	_wave_mesh.visible = false
	add_child(_wave_mesh)

	_foam = CPUParticles3D.new()
	_foam.name = "SeaFoam"
	_foam.emitting = false
	_foam.amount = 40
	_foam.lifetime = 1.5
	_foam.direction = Vector3.UP
	_foam.spread = 60.0
	_foam.initial_velocity_min = 2.0
	_foam.initial_velocity_max = 5.0
	_foam.color = Palette.MOON
	var foam_mesh: SphereMesh = SphereMesh.new()
	foam_mesh.radius = 0.15
	foam_mesh.height = 0.3
	_foam.mesh = foam_mesh
	_foam.position = Vector3(0.0, 2.0, 0.0)
	add_child(_foam)
	add_to_group(&"enemy")


func _flat_disc(node_name: String, radius: float, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04
	mi.mesh = disc
	mi.material_override = _alpha_material(color)
	mi.visible = false
	add_child(mi)
	return mi


func _alpha_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
