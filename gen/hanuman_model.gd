class_name HanumanModel
extends Node3D
## Procedural Hanuman (DESIGN §6.2, M07). A Skeleton3D is built in code with the bones listed in §9. Each bone gets
## one BoneAttachment3D, and rigid MeshKit parts hang under it. Poses are bone-rotation tables, so nothing is skinned.
## Colours come only from Palette. The feet sit at y = 0 and the model is about 1.86 m tall.

const BONE_NAMES: PackedStringArray = [
	"root", "hips", "spine", "chest", "head",
	"upper_arm_l", "lower_arm_l", "upper_arm_r", "lower_arm_r",
	"upper_leg_l", "lower_leg_l", "upper_leg_r", "lower_leg_r",
	"tail_0", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_7",
	"gada_socket",
]

## Parent of each bone. "root" has no parent. Parents always come before their children in BONE_NAMES.
const BONE_PARENTS: Dictionary = {
	"hips": "root",
	"spine": "hips",
	"chest": "spine",
	"head": "chest",
	"upper_arm_l": "chest",
	"lower_arm_l": "upper_arm_l",
	"upper_arm_r": "chest",
	"lower_arm_r": "upper_arm_r",
	"upper_leg_l": "hips",
	"lower_leg_l": "upper_leg_l",
	"upper_leg_r": "hips",
	"lower_leg_r": "upper_leg_r",
	"tail_0": "hips",
	"tail_1": "tail_0",
	"tail_2": "tail_1",
	"tail_3": "tail_2",
	"tail_4": "tail_3",
	"tail_5": "tail_4",
	"tail_6": "tail_5",
	"tail_7": "tail_6",
	"gada_socket": "lower_arm_r",
}

## Rest position of each bone in model space, in metres.
const BONE_REST: Dictionary = {
	"root": Vector3(0.0, 0.0, 0.0),
	"hips": Vector3(0.0, 0.95, 0.0),
	"spine": Vector3(0.0, 1.12, 0.0),
	"chest": Vector3(0.0, 1.32, 0.0),
	"head": Vector3(0.0, 1.58, 0.0),
	"upper_arm_l": Vector3(0.2, 1.5, 0.0),
	"lower_arm_l": Vector3(0.22, 1.2, 0.0),
	"upper_arm_r": Vector3(-0.2, 1.5, 0.0),
	"lower_arm_r": Vector3(-0.22, 1.2, 0.0),
	"upper_leg_l": Vector3(0.12, 0.92, 0.0),
	"lower_leg_l": Vector3(0.12, 0.5, 0.0),
	"upper_leg_r": Vector3(-0.12, 0.92, 0.0),
	"lower_leg_r": Vector3(-0.12, 0.5, 0.0),
	"tail_0": Vector3(0.0, 0.95, -0.12),
	"tail_1": Vector3(0.0, 0.99, -0.22),
	"tail_2": Vector3(0.0, 1.03, -0.32),
	"tail_3": Vector3(0.0, 1.07, -0.42),
	"tail_4": Vector3(0.0, 1.11, -0.52),
	"tail_5": Vector3(0.0, 1.15, -0.62),
	"tail_6": Vector3(0.0, 1.19, -0.72),
	"tail_7": Vector3(0.0, 1.23, -0.82),
	"gada_socket": Vector3(-0.22, 0.92, 0.0),
}

## Pose tables: bone name -> euler rotation in degrees. Bones not listed return to rest.
const POSES: Dictionary = {
	"idle": {
		"chest": Vector3(2.0, 0.0, 0.0),
		"upper_arm_l": Vector3(0.0, 0.0, -6.0),
		"upper_arm_r": Vector3(0.0, 0.0, 6.0),
		"tail_0": Vector3(-8.0, 0.0, 0.0),
	},
	"walk_a": {
		"hips": Vector3(0.0, 0.0, 3.0),
		"upper_leg_l": Vector3(25.0, 0.0, 0.0),
		"lower_leg_l": Vector3(-10.0, 0.0, 0.0),
		"upper_leg_r": Vector3(-20.0, 0.0, 0.0),
		"upper_arm_l": Vector3(-20.0, 0.0, -6.0),
		"upper_arm_r": Vector3(20.0, 0.0, 6.0),
	},
	"walk_b": {
		"hips": Vector3(0.0, 0.0, -3.0),
		"upper_leg_l": Vector3(-20.0, 0.0, 0.0),
		"upper_leg_r": Vector3(25.0, 0.0, 0.0),
		"lower_leg_r": Vector3(-10.0, 0.0, 0.0),
		"upper_arm_l": Vector3(20.0, 0.0, -6.0),
		"upper_arm_r": Vector3(-20.0, 0.0, 6.0),
	},
	"attack_wind": {
		"chest": Vector3(0.0, -25.0, 0.0),
		"upper_arm_r": Vector3(-140.0, 0.0, -20.0),
		"lower_arm_r": Vector3(-30.0, 0.0, 0.0),
	},
	"attack_strike": {
		"chest": Vector3(0.0, 30.0, 0.0),
		"upper_arm_r": Vector3(70.0, 0.0, 0.0),
		"lower_arm_r": Vector3(-10.0, 0.0, 0.0),
		"upper_arm_l": Vector3(-30.0, 0.0, -10.0),
	},
	"meditate": {
		"chest": Vector3(8.0, 0.0, 0.0),
		"head": Vector3(-6.0, 0.0, 0.0),
		"upper_arm_l": Vector3(-40.0, 0.0, -30.0),
		"upper_arm_r": Vector3(-40.0, 0.0, 30.0),
		"lower_arm_l": Vector3(-60.0, 0.0, 0.0),
		"lower_arm_r": Vector3(-60.0, 0.0, 0.0),
		"upper_leg_l": Vector3(-90.0, 0.0, 0.0),
		"upper_leg_r": Vector3(-90.0, 0.0, 0.0),
	},
}

var _skeleton: Skeleton3D = null
var _pose: StringName = &"idle"


## Builds the rig and the body parts as children of this node, then returns this node. Calling it again is a no-op.
func build() -> Node3D:
	if _skeleton == null:
		_build_rig()
	return self


func get_skeleton() -> Skeleton3D:
	return _skeleton


func current_pose() -> StringName:
	return _pose


## Sets the bone rotations for a named pose. Unknown names reset the body to rest.
func set_pose(pose: StringName) -> void:
	if _skeleton == null:
		build()
	for index: int in range(_skeleton.get_bone_count()):
		_skeleton.set_bone_pose_rotation(index, Quaternion.IDENTITY)
	var table: Dictionary = POSES.get(String(pose), {}) as Dictionary
	for bone_key: Variant in table:
		var index: int = _skeleton.find_bone(bone_key as String)
		if index < 0:
			continue
		var euler: Vector3 = table[bone_key] as Vector3
		_skeleton.set_bone_pose_rotation(index, Quaternion.from_euler(euler * (PI / 180.0)))
	_pose = pose


func _build_rig() -> void:
	_skeleton = Skeleton3D.new()
	_skeleton.name = "Skeleton3D"
	add_child(_skeleton)
	for bone_name: String in BONE_NAMES:
		var index: int = _skeleton.add_bone(bone_name)
		var world: Vector3 = BONE_REST[bone_name] as Vector3
		var local: Vector3 = world
		var parent_name: String = BONE_PARENTS.get(bone_name, "") as String
		if parent_name != "":
			_skeleton.set_bone_parent(index, _skeleton.find_bone(parent_name))
			local = world - (BONE_REST[parent_name] as Vector3)
		_skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, local))
	for bone_name: String in BONE_NAMES:
		var attachment: BoneAttachment3D = BoneAttachment3D.new()
		attachment.name = "Attach_" + bone_name
		attachment.bone_name = bone_name
		_skeleton.add_child(attachment)
		var part_index: int = 0
		for part: Dictionary in _bone_parts(bone_name):
			var mesh_instance: MeshInstance3D = MeshInstance3D.new()
			mesh_instance.name = bone_name + "_part_" + str(part_index)
			mesh_instance.mesh = part["mesh"] as ArrayMesh
			mesh_instance.transform = part["transform"] as Transform3D
			mesh_instance.material_override = MeshKit.flat_material()
			attachment.add_child(mesh_instance)
			part_index += 1


## The rigid parts hanging under one bone, each a MeshKit mesh and a transform relative to the bone joint.
func _bone_parts(bone_name: String) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	match bone_name:
		"hips":
			parts.append(_part(MeshKit.cylinder(0.19, 0.23, 0.3, 10, Palette.SAFFRON), Vector3(0.0, -0.1, 0.0)))
		"spine":
			parts.append(_part(MeshKit.box(Vector3(0.34, 0.2, 0.2), Palette.HANUMAN_FUR), Vector3(0.0, 0.1, 0.0)))
		"chest":
			parts.append(_part(MeshKit.box(Vector3(0.38, 0.26, 0.24), Palette.HANUMAN_FUR), Vector3(0.0, 0.11, 0.0)))
		"head":
			parts.append(_part(MeshKit.sphere(0.13, 6, 10, Palette.HANUMAN_FUR), Vector3(0.0, 0.15, 0.0)))
			parts.append(_part(MeshKit.sphere(0.06, 5, 8, Palette.SINDOOR), Vector3(0.0, 0.1, -0.12)))
			parts.append(_part(MeshKit.cylinder(0.14, 0.14, 0.07, 12, Palette.GOLD), Vector3(0.0, 0.24, 0.0)))
		"upper_arm_l", "upper_arm_r":
			parts.append(_part(MeshKit.cylinder(0.05, 0.045, 0.3, 8, Palette.HANUMAN_FUR), Vector3(0.0, -0.15, 0.0)))
		"lower_arm_l", "lower_arm_r":
			parts.append(_part(MeshKit.cylinder(0.045, 0.04, 0.28, 8, Palette.HANUMAN_FUR), Vector3(0.0, -0.14, 0.0)))
		"upper_leg_l", "upper_leg_r":
			parts.append(_part(MeshKit.cylinder(0.075, 0.06, 0.42, 8, Palette.HANUMAN_FUR), Vector3(0.0, -0.21, 0.0)))
		"lower_leg_l", "lower_leg_r":
			parts.append(_part(MeshKit.cylinder(0.06, 0.045, 0.46, 8, Palette.HANUMAN_FUR), Vector3(0.0, -0.23, 0.0)))
			parts.append(_part(MeshKit.box(Vector3(0.12, 0.06, 0.22), Palette.HANUMAN_FUR), Vector3(0.0, -0.47, -0.04)))
		"gada_socket":
			parts.append(_part(MeshKit.cylinder(0.018, 0.018, 0.8, 6, Palette.GOLD), Vector3.ZERO, Vector3(90.0, 0.0, 0.0)))
			parts.append(_part(MeshKit.sphere(0.09, 6, 10, Palette.GOLD), Vector3(0.0, 0.0, 0.42)))
		_:
			if bone_name.begins_with("tail_"):
				parts.append(_part(MeshKit.cylinder(0.035, 0.03, 0.11, 6, Palette.HANUMAN_FUR), Vector3(0.0, 0.0, -0.05), Vector3(90.0, 0.0, 0.0)))
	return parts


static func _part(mesh: ArrayMesh, offset: Vector3, euler_degrees: Vector3 = Vector3.ZERO) -> Dictionary:
	var rot: Basis = Basis.from_euler(euler_degrees * (PI / 180.0))
	return {"mesh": mesh, "transform": Transform3D(rot, offset)}
