class_name Shrine
extends Area3D
## A meditation shrine (DESIGN §9 M27). Interacting with it meditates: it records `GameState.last_shrine`,
## refills the player's Health to max (the Health child found by type) and saves game slot 0.
## Built procedurally: a stone plinth, a saffron flag and a gold lamp (MeshKit, DESIGN §6.1 palette).

signal meditated

const SAVE_SLOT: int = 0
const GAME_STATE_NAME: StringName = &"GameState"
const _HALF_EXTENT: float = 0.8

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


## Meditates at this shrine. `player` is any node that has a Health child; a player without one is still
## recorded and saved, just not healed.
func interact(player: Node) -> void:
	var state: Node = _game_state()
	if state != null:
		state.set("last_shrine", {
			"level": _level_id(),
			"pos": global_position,
			"id": _id(),
		})
	var health: Health = _find_health(player)
	if health != null:
		health.heal(health.max_value)
	if state != null:
		state.call("save_game", SAVE_SLOT)
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


func _game_state() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(str(GAME_STATE_NAME))) as Node


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


func _add_collision() -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(_HALF_EXTENT * 2.0, 1.6, _HALF_EXTENT * 2.0)
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Collider"
	collider.shape = shape
	collider.position = Vector3(0.0, 0.8, 0.0)
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
