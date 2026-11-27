class_name ObjectiveBeacon
extends Node3D
## A soft golden light pillar with a floating diamond marker at the current objective's place (FX1: "climb to the
## peak is not apparent"). The LevelRuntime picks the target (`pick` below maps the objective ids to a trigger or an
## actor id per level) and hides the beacon during dialogue and cutscenes.

const PILLAR_HEIGHT: float = 10.0
const PILLAR_RADIUS: float = 0.55
const MARKER_HEIGHT: float = 3.4
const BOB_AMPLITUDE: float = 0.25
const BOB_SPEED: float = 2.0
const SPIN_SPEED: float = 1.4
const PILLAR_ALPHA: float = 0.2
const CORE_ALPHA: float = 0.32

## Objective id -> where it points, per level, in the order the chapters give the objectives. `actor` is a key of
## LevelRuntime.actors(), `trigger` a trigger id and `search` the first unvisited "t_search_*" trigger. The first
## entry whose objective is still open is the target.
const TARGETS: Dictionary = {
	"mahendra": [
		{"id": "talk_jambavan", "kind": "actor", "ref": "jambavan"},
		{"id": "training", "kind": "trigger", "ref": "t_training_done"},
		{"id": "reach_peak", "kind": "trigger", "ref": "t_leap"},
	],
	"lanka_gate": [
		{"id": "lankini", "kind": "actor", "ref": "lankini"},
		{"id": "search", "kind": "trigger", "ref": "t_gate_open"},
		{"id": "vatika", "kind": "trigger", "ref": "t_gate_open"},
	],
	"lanka_streets": [
		{"id": "search", "kind": "search", "ref": "t_search_"},
		{"id": "vatika", "kind": "trigger", "ref": "t_vatika"},
	],
	"ashoka_vatika": [
		{"id": "sita", "kind": "trigger", "ref": "t_grove_story"},
	],
	"ravana_court": [
		{"id": "court", "kind": "trigger", "ref": "t_court"},
	],
	"lanka_rooftops": [
		{"id": "burn", "kind": "trigger", "ref": "t_dahan_start"},
		{"id": "ocean", "kind": "trigger", "ref": "t_ocean_exit"},
	],
}

var _target: Node3D = null
var _suppressed: bool = false
var _time: float = 0.0
var _marker: MeshInstance3D = null
var _pillar: MeshInstance3D = null


func _init() -> void:
	name = "ObjectiveBeacon"
	visible = false
	_pillar = _glow_mesh(PILLAR_RADIUS, PILLAR_HEIGHT, PILLAR_ALPHA)
	_pillar.position.y = PILLAR_HEIGHT * 0.5
	add_child(_pillar)
	var core: MeshInstance3D = _glow_mesh(PILLAR_RADIUS * 0.4, PILLAR_HEIGHT, CORE_ALPHA)
	core.position.y = PILLAR_HEIGHT * 0.5
	add_child(core)
	_marker = MeshInstance3D.new()
	_marker.name = "Marker"
	var gem: SphereMesh = SphereMesh.new()
	gem.radius = 0.4
	gem.height = 1.0
	gem.radial_segments = 4
	gem.rings = 2
	_marker.mesh = gem
	_marker.material_override = _glow_material(Palette.GOLD, 0.95)
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.position.y = MARKER_HEIGHT
	add_child(_marker)


## The first open objective of `level_id` as {id, kind, ref}, or an empty Dictionary. `is_open` takes an objective id
## and says whether it is registered and not yet done.
static func pick(level_id: StringName, is_open: Callable) -> Dictionary:
	var entries: Array = TARGETS.get(str(level_id), []) as Array
	for entry: Variant in entries:
		var record: Dictionary = entry as Dictionary
		if is_open.call(StringName(str(record["id"]))) as bool:
			return record
	return {}


## The point on the ground under a target: triggers are boxes centred a half height up, so their base is used.
static func ground_position(node: Node3D) -> Vector3:
	var pos: Vector3 = node.global_position
	if node is Area3D:
		for child: Node in node.get_children():
			var shape_node: CollisionShape3D = child as CollisionShape3D
			if shape_node != null and shape_node.shape is BoxShape3D:
				pos.y -= (shape_node.shape as BoxShape3D).size.y * 0.5
				break
	return pos


func set_target(node: Node3D) -> void:
	_target = node
	_update_visibility()
	if _target != null and is_inside_tree():
		global_position = ground_position(_target)


func target_node() -> Node3D:
	return _target if _target != null and is_instance_valid(_target) else null


func set_suppressed(value: bool) -> void:
	_suppressed = value
	_update_visibility()


func is_active() -> bool:
	return target_node() != null and not _suppressed


func _process(delta: float) -> void:
	var node: Node3D = target_node()
	if node == null:
		visible = false
		return
	_time += delta
	global_position = ground_position(node)
	_marker.position.y = MARKER_HEIGHT + sin(_time * BOB_SPEED) * BOB_AMPLITUDE
	_marker.rotation.y = _time * SPIN_SPEED
	visible = not _suppressed


func _update_visibility() -> void:
	visible = is_active()


func _glow_mesh(radius: float, height: float, alpha: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius * 0.7
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 12
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = _glow_material(Palette.GOLD, alpha)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _glow_material(colour: Color, alpha: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(colour, alpha)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	return mat
