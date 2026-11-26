class_name Shrine
extends Area3D
## A meditation shrine (DESIGN §9 M27). Interacting with it meditates: it records `GameState.last_shrine`,
## refills the player's Health to max (the Health child found by type), refills Smarana completely and saves
## game slot 0. Built procedurally: a stone plinth, a saffron flag and a gold lamp (MeshKit, DESIGN §6.1 palette).
##
## Smarana is owned by the devotion code (M20), which this module must not depend on. The refill goes two ways:
## a descendant of the player with a `refill()` method is called directly, and `EventBus.smarana_changed(100.0)`
## is emitted so any listener can follow. Vitality is announced with `EventBus.vitality_changed` for the HUD.
## Exhaustion and `Health.invulnerable` belong to other systems and are left untouched here.

signal meditated

const SAVE_SLOT: int = 0
const GAME_STATE_NAME: String = "GameState"
const EVENT_BUS_NAME: String = "EventBus"
const SMARANA_FULL: float = 100.0
const REFILL_METHOD: StringName = &"refill"
const _HALF_EXTENT: float = 0.8
const _COLLIDER_HEIGHT: float = 1.6

## Shrine id as written in the level JSON (levels/SCHEMA.md). Empty falls back to the node name.
@export var shrine_id: String = ""


func _ready() -> void:
	add_to_group(&"interactable")
	var layers: Array[int] = [Layers.INTERACT]
	collision_layer = Layers.mask(layers)
	collision_mask = 0
	monitoring = false
	monitorable = true
	_add_collision()
	_add_visuals()


## Meditates at this shrine. `player` is any node that may have a Health child and a `refill()` component;
## a player missing either is still recorded and saved, just not refilled.
func interact(player: Node) -> void:
	var state: Node = _autoload(GAME_STATE_NAME)
	if state != null:
		state.set("last_shrine", {
			"level": _level_id(),
			"pos": global_position,
			"id": _id(),
		})
	var health: Health = _find_health(player)
	if health != null:
		health.heal(health.max_value)
		_announce_vitality(health)
	_refill_smarana(player)
	if state != null:
		state.call("save_game", SAVE_SLOT)
	SoundPlayer.cue_at(self, &"shrine_meditate")
	meditated.emit()


func _id() -> String:
	return shrine_id if shrine_id != "" else str(name)


## The `level_id` metadata of the nearest ancestor that carries it (LevelBuilder sets it on the level root).
func _level_id() -> String:
	var node: Node = get_parent()
	while node != null:
		if node.has_meta("level_id"):
			return str(node.get_meta("level_id"))
		node = node.get_parent()
	return ""


## Returns the named autoload (e.g. "GameState") from the scene tree root, or null when it is not present.
func _autoload(autoload_name: String) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(autoload_name) as Node


func _announce_vitality(health: Health) -> void:
	var bus: Node = _autoload(EVENT_BUS_NAME)
	if bus != null:
		bus.emit_signal("vitality_changed", health.value, health.max_value)


func _refill_smarana(player: Node) -> void:
	var refillable: Node = _find_refillable(player)
	if refillable != null:
		refillable.call(REFILL_METHOD)
	var bus: Node = _autoload(EVENT_BUS_NAME)
	if bus != null:
		bus.emit_signal("smarana_changed", SMARANA_FULL)


## Depth-first search for the first Health component under `node`.
func _find_health(node: Node) -> Health:
	if node == null:
		return null
	for child: Node in node.get_children():
		if child is Health:
			return child as Health
	for child: Node in node.get_children():
		var found: Health = _find_health(child)
		if found != null:
			return found
	return null


## Depth-first search for the first node under `node` (inclusive) that has a `refill()` method.
func _find_refillable(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method(REFILL_METHOD):
		return node
	for child: Node in node.get_children():
		var found: Node = _find_refillable(child)
		if found != null:
			return found
	return null


func _add_collision() -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(_HALF_EXTENT * 2.0, _COLLIDER_HEIGHT, _HALF_EXTENT * 2.0)
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Collider"
	collider.shape = shape
	collider.position = Vector3(0.0, _COLLIDER_HEIGHT * 0.5, 0.0)
	add_child(collider)


func _add_visuals() -> void:
	var parts: Array[Dictionary] = []
	parts.append(_part(MeshKit.box(Vector3(1.2, 0.5, 1.2), Palette.STONE), Vector3(0.0, 0.25, 0.0)))
	parts.append(_part(MeshKit.box(Vector3(0.9, 0.35, 0.9), Palette.STONE), Vector3(0.0, 0.675, 0.0)))
	parts.append(_part(MeshKit.cylinder(0.04, 0.04, 1.4, 6, Palette.BARK), Vector3(0.45, 1.2, -0.45)))
	parts.append(_part(MeshKit.box(Vector3(0.05, 0.4, 0.5), Palette.SAFFRON), Vector3(0.45, 1.6, -0.2)))
	parts.append(_part(MeshKit.box(Vector3(0.3, 0.12, 0.3), Palette.GOLD), Vector3(0.0, 0.92, 0.0)))
	parts.append(_part(MeshKit.sphere(0.14, 4, 6, Palette.FIRE_CORE), Vector3(0.0, 1.06, 0.0)))
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Visual"
	mesh_instance.mesh = MeshKit.merge(parts)
	mesh_instance.material_override = MeshKit.flat_material()
	add_child(mesh_instance)


func _part(mesh: ArrayMesh, offset: Vector3) -> Dictionary:
	return {"mesh": mesh, "transform": Transform3D(Basis.IDENTITY, offset)}
