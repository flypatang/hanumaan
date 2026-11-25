class_name FireSystem
extends Node
## Fire spread between props (DESIGN §9 M28, §3 Ch5). Props are registered with their metadata:
## `flammable` (can burn) and `protected` (never ignites, e.g. a sacred tree). A prop ignites through `ignite()`,
## which the owner calls when a hitbox of team `fire` touches it. A burning prop spreads to every flammable,
## unprotected prop within SPREAD_RANGE metres once it has burned for SPREAD_DELAY seconds, and is burnt out
## after BURN_DURATION seconds. All timing uses accumulated `delta`, so the outcome does not depend on frame rate.
## Props should share one parent, so their positions are compared in the same space.

enum State { UNBURNT, BURNING, BURNT }

## Metres within which a burning prop sets its flammable neighbours alight.
const SPREAD_RANGE: float = 3.0
## Seconds a prop must burn before it spreads.
const SPREAD_DELAY: float = 1.5
## Seconds from ignition until a prop is burnt out.
const BURN_DURATION: float = 6.0
## Float error from summing many small steps must not change outcomes.
const _EPSILON: float = 0.000001
const _FLAME_AMOUNT: int = 24
const _CHAR_COLOR: Color = Color(0.08, 0.065, 0.06)

class _Entry:
	var prop: Node3D
	var flammable: bool = false
	var protected: bool = false
	var state: State = State.UNBURNT
	var burn_time: float = 0.0
	var spread_done: bool = false
	var flames: GPUParticles3D = null


var _entries: Array[_Entry] = []
var _charred_material: StandardMaterial3D = null


func _process(delta: float) -> void:
	step(delta)


## Adds `prop` to the fire system, reading its `flammable` and `protected` metadata (both default to false).
## Registering the same prop again does nothing.
func register(prop: Node3D) -> void:
	if prop == null or _find(prop) != null:
		return
	var entry: _Entry = _Entry.new()
	entry.prop = prop
	entry.flammable = prop.get_meta("flammable", false) as bool
	entry.protected = prop.get_meta("protected", false) as bool
	_entries.append(entry)


## Sets `prop` alight. Returns true only when it was registered, flammable, not protected and not already burning or burnt.
func ignite(prop: Node3D) -> bool:
	var entry: _Entry = _find(prop)
	if entry == null or not entry.flammable or entry.protected or entry.state != State.UNBURNT:
		return false
	_start_burning(entry)
	return true


## Advances every fire by `delta` seconds: spreads flames to neighbours and burns out finished props.
func step(delta: float) -> void:
	for entry: _Entry in _entries:
		if entry.state == State.BURNING:
			entry.burn_time += delta
	for entry: _Entry in _entries:
		if entry.state == State.BURNING and not entry.spread_done \
				and entry.burn_time + _EPSILON >= SPREAD_DELAY:
			entry.spread_done = true
			_spread_from(entry)
	for entry: _Entry in _entries:
		if entry.state == State.BURNING and entry.burn_time + _EPSILON >= BURN_DURATION:
			_burn_out(entry)


## True while `prop` is on fire.
func is_burning(prop: Node3D) -> bool:
	var entry: _Entry = _find(prop)
	return entry != null and entry.state == State.BURNING


## True once `prop` has burnt out.
func is_burnt(prop: Node3D) -> bool:
	var entry: _Entry = _find(prop)
	return entry != null and entry.state == State.BURNT


func _find(prop: Node3D) -> _Entry:
	for entry: _Entry in _entries:
		if entry.prop == prop:
			return entry
	return null


func _start_burning(entry: _Entry) -> void:
	entry.state = State.BURNING
	entry.burn_time = 0.0
	entry.flames = _make_flames()
	entry.prop.add_child(entry.flames)
	var bus: Node = _event_bus()
	if bus != null:
		bus.emit_signal("fire_ignited", StringName(entry.prop.name))


func _spread_from(source: _Entry) -> void:
	var origin: Vector3 = _world_position(source.prop)
	for other: _Entry in _entries:
		if other == source or not other.flammable or other.protected or other.state != State.UNBURNT:
			continue
		if origin.distance_to(_world_position(other.prop)) <= SPREAD_RANGE + _EPSILON:
			_start_burning(other)


func _burn_out(entry: _Entry) -> void:
	entry.state = State.BURNT
	if entry.flames != null:
		entry.flames.emitting = false
	_char_meshes(entry.prop)


func _char_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _get_charred_material()
	for child: Node in node.get_children():
		_char_meshes(child)


func _get_charred_material() -> StandardMaterial3D:
	if _charred_material == null:
		_charred_material = StandardMaterial3D.new()
		_charred_material.albedo_color = _CHAR_COLOR
	return _charred_material


func _world_position(prop: Node3D) -> Vector3:
	if prop.is_inside_tree():
		return prop.global_position
	return prop.position


func _make_flames() -> GPUParticles3D:
	var ramp_gradient: Gradient = Gradient.new()
	ramp_gradient.colors = PackedColorArray([Palette.FIRE_CORE, Palette.FIRE_EDGE])
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = ramp_gradient

	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.direction = Vector3.UP
	process_material.spread = 25.0
	process_material.initial_velocity_min = 0.6
	process_material.initial_velocity_max = 1.2
	process_material.gravity = Vector3(0.0, 0.5, 0.0)
	process_material.color_ramp = ramp

	var puff: SphereMesh = SphereMesh.new()
	puff.radius = 0.12
	puff.height = 0.24
	var puff_material: StandardMaterial3D = StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.vertex_color_use_as_albedo = true
	puff.material = puff_material

	var flames: GPUParticles3D = GPUParticles3D.new()
	flames.amount = _FLAME_AMOUNT
	flames.lifetime = 0.8
	flames.process_material = process_material
	flames.draw_pass_1 = puff
	flames.emitting = true
	return flames


func _event_bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("EventBus")
