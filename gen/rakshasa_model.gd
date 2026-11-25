class_name RakshasaModel
extends RefCounted
## Rakshasa foes (DESIGN §6.2, §9 M08). Built from primitives with MeshKit, the same technique as Hanuman (M07):
## a Skeleton3D with bones created in code, and every rigid part on its own BoneAttachment3D. There is no skinning.
## Variants: spear (lean, with a spear), archer (slim, with a bow), brute (wide and hunched, the kinkara with a club),
## lankini (tall female guardian with gold armour accents). Pose names match M07: idle, walk, attack.

const POSES: Array[StringName] = [&"idle", &"walk", &"attack"]

## Pose table: bone name -> Euler angles (radians, x = pitch, y = twist, z = roll) applied on top of the rest pose.
const _POSE_IDLE: Dictionary = {"chest": Vector3(0.02, 0.0, 0.0)}
const _POSE_WALK: Dictionary = {
	"upper_leg_l": Vector3(0.5, 0.0, 0.0),
	"upper_leg_r": Vector3(-0.5, 0.0, 0.0),
	"upper_arm_l": Vector3(-0.4, 0.0, 0.0),
	"upper_arm_r": Vector3(0.4, 0.0, 0.0),
	"lower_leg_l": Vector3(-0.3, 0.0, 0.0),
	"chest": Vector3(0.05, 0.0, 0.0),
}
const _POSE_ATTACK: Dictionary = {
	"upper_arm_r": Vector3(-1.6, 0.0, 0.0),
	"lower_arm_r": Vector3(-0.4, 0.0, 0.0),
	"upper_arm_l": Vector3(0.6, 0.0, 0.0),
	"chest": Vector3(0.0, -0.3, 0.0),
}


## Builds a rakshasa of the given variant. Returns the root Node3D; its child "Skeleton3D" holds the bones and
## BoneAttachment3D parts. Unknown variants fall back to spear.
static func build(variant: StringName) -> Node3D:
	var spec: Dictionary = _spec(variant)
	var root: Node3D = Node3D.new()
	root.name = "Rakshasa_" + String(variant)
	var skeleton: Skeleton3D = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	root.add_child(skeleton)
	_add_bones(skeleton, spec)
	_attach_parts(skeleton, spec)
	set_pose(root, &"idle")
	return root


## Applies a named pose to the Skeleton3D inside `root`. Unknown pose names reset the skeleton to rest.
static func set_pose(root: Node3D, pose: StringName) -> void:
	var skeleton: Skeleton3D = _find_skeleton(root)
	if skeleton == null:
		return
	skeleton.reset_bone_poses()
	var table: Dictionary = _pose_table(pose)
	for bone_key: String in table.keys():
		var bone: String = bone_key
		var idx: int = skeleton.find_bone(bone)
		if idx < 0:
			continue
		var euler: Vector3 = table[bone] as Vector3
		var rot: Quaternion = Basis.from_euler(euler).get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(idx, rot)


static func _pose_table(pose: StringName) -> Dictionary:
	match pose:
		&"walk":
			return _POSE_WALK
		&"attack":
			return _POSE_ATTACK
		_:
			return _POSE_IDLE


static func _find_skeleton(root: Node3D) -> Skeleton3D:
	for child: Node in root.get_children():
		if child is Skeleton3D:
			return child as Skeleton3D
	return null


static func _spec(variant: StringName) -> Dictionary:
	match variant:
		&"archer":
			return {"height": 1.0, "torso": 0.75, "spread": 0.8, "hunch": 0.05, "weapon": &"bow", "gold": false}
		&"brute":
			return {"height": 0.92, "torso": 1.9, "spread": 1.5, "hunch": 0.45, "weapon": &"club", "gold": false}
		&"lankini":
			return {"height": 1.12, "torso": 0.85, "spread": 0.8, "hunch": 0.0, "weapon": &"none", "gold": true}
		_:
			return {"height": 1.0, "torso": 0.9, "spread": 0.75, "hunch": 0.08, "weapon": &"spear", "gold": false}


static func _add_bones(skeleton: Skeleton3D, spec: Dictionary) -> void:
	var h: float = spec["height"] as float
	var spread: float = spec["spread"] as float
	var hunch: float = spec["hunch"] as float
	_add_bone(skeleton, "root", "", Vector3.ZERO, 0.0)
	_add_bone(skeleton, "hips", "root", Vector3(0.0, 0.95 * h, 0.0), 0.0)
	_add_bone(skeleton, "spine", "hips", Vector3(0.0, 0.12 * h, 0.0), 0.0)
	_add_bone(skeleton, "chest", "spine", Vector3(0.0, 0.30 * h, 0.0), hunch)
	_add_bone(skeleton, "head", "chest", Vector3(0.0, 0.38 * h, 0.0), 0.0)
	_add_bone(skeleton, "upper_arm_l", "chest", Vector3(0.32 * spread * h, 0.22 * h, 0.0), 0.0)
	_add_bone(skeleton, "lower_arm_l", "upper_arm_l", Vector3(0.0, -0.30 * h, 0.0), 0.0)
	_add_bone(skeleton, "upper_arm_r", "chest", Vector3(-0.32 * spread * h, 0.22 * h, 0.0), 0.0)
	_add_bone(skeleton, "lower_arm_r", "upper_arm_r", Vector3(0.0, -0.30 * h, 0.0), 0.0)
	_add_bone(skeleton, "upper_leg_l", "hips", Vector3(0.14 * spread * h, -0.05 * h, 0.0), 0.0)
	_add_bone(skeleton, "lower_leg_l", "upper_leg_l", Vector3(0.0, -0.45 * h, 0.0), 0.0)
	_add_bone(skeleton, "upper_leg_r", "hips", Vector3(-0.14 * spread * h, -0.05 * h, 0.0), 0.0)
	_add_bone(skeleton, "lower_leg_r", "upper_leg_r", Vector3(0.0, -0.45 * h, 0.0), 0.0)
	_add_bone(skeleton, "weapon_socket", "lower_arm_r", Vector3(0.0, -0.28 * h, 0.0), 0.0)
	skeleton.reset_bone_poses()


static func _add_bone(skeleton: Skeleton3D, bone: String, parent: String, offset: Vector3, pitch: float) -> void:
	var idx: int = skeleton.add_bone(bone)
	if parent != "":
		skeleton.set_bone_parent(idx, skeleton.find_bone(parent))
	skeleton.set_bone_rest(idx, Transform3D(Basis(Vector3.RIGHT, pitch), offset))


static func _attach_parts(skeleton: Skeleton3D, spec: Dictionary) -> void:
	var h: float = spec["height"] as float
	var t: float = spec["torso"] as float
	var weapon: StringName = spec["weapon"] as StringName
	var gold: bool = spec["gold"] as bool
	var arm_r: float = 0.05 * h * (0.5 + 0.5 * t)
	var leg_r: float = 0.065 * h * (0.5 + 0.5 * t)

	# Torso: pelvis, belly and chest plate.
	_part(skeleton, "hips", MeshKit.box(Vector3(0.36 * t, 0.2 * h, 0.24 * t), Palette.RAKSHASA_SKIN), Vector3.ZERO)
	_part(skeleton, "spine", MeshKit.cylinder(0.19 * t, 0.23 * t, 0.4 * h, 8, Palette.RAKSHASA_SKIN), Vector3(0.0, 0.2 * h, 0.0))
	_part(skeleton, "chest", MeshKit.box(Vector3(0.44 * t, 0.26 * h, 0.3 * t), Palette.RAKSHASA_ARMOR), Vector3.ZERO)
	if gold:
		_part(skeleton, "chest", MeshKit.box(Vector3(0.36 * t, 0.05 * h, 0.05 * t), Palette.GOLD), Vector3(0.0, 0.1 * h, 0.17 * t))

	# Head with two horns (cones tilted outward).
	_part(skeleton, "head", MeshKit.sphere(0.12 * h, 6, 8, Palette.RAKSHASA_SKIN), Vector3(0.0, 0.08 * h, 0.0))
	var horn: ArrayMesh = MeshKit.cone(0.035 * h, 0.26 * h, 6, Palette.RAKSHASA_ARMOR)
	_part_xf(skeleton, "head", horn, Transform3D(Basis(Vector3.FORWARD, 0.3), Vector3(0.07 * h, 0.2 * h, 0.0)))
	_part_xf(skeleton, "head", horn, Transform3D(Basis(Vector3.FORWARD, -0.3), Vector3(-0.07 * h, 0.2 * h, 0.0)))
	if gold:
		_part(skeleton, "head", MeshKit.cylinder(0.13 * h, 0.13 * h, 0.03 * h, 8, Palette.GOLD), Vector3(0.0, 0.05 * h, 0.0))

	# Arms and legs.
	_part(skeleton, "upper_arm_l", MeshKit.cylinder(arm_r, arm_r * 0.85, 0.3 * h, 6, Palette.RAKSHASA_SKIN), Vector3(0.0, -0.15 * h, 0.0))
	_part(skeleton, "lower_arm_l", MeshKit.cylinder(arm_r * 0.85, arm_r * 0.7, 0.28 * h, 6, Palette.RAKSHASA_SKIN), Vector3(0.0, -0.14 * h, 0.0))
	_part(skeleton, "upper_arm_r", MeshKit.cylinder(arm_r, arm_r * 0.85, 0.3 * h, 6, Palette.RAKSHASA_SKIN), Vector3(0.0, -0.15 * h, 0.0))
	_part(skeleton, "lower_arm_r", MeshKit.cylinder(arm_r * 0.85, arm_r * 0.7, 0.28 * h, 6, Palette.RAKSHASA_SKIN), Vector3(0.0, -0.14 * h, 0.0))
	if gold:
		_part(skeleton, "lower_arm_l", MeshKit.cylinder(arm_r * 1.05, arm_r * 1.05, 0.04 * h, 6, Palette.GOLD), Vector3(0.0, 0.02 * h, 0.0))
		_part(skeleton, "lower_arm_r", MeshKit.cylinder(arm_r * 1.05, arm_r * 1.05, 0.04 * h, 6, Palette.GOLD), Vector3(0.0, 0.02 * h, 0.0))
	_part(skeleton, "upper_leg_l", MeshKit.cylinder(leg_r, leg_r * 0.85, 0.45 * h, 6, Palette.RAKSHASA_SKIN), Vector3(0.0, -0.225 * h, 0.0))
	_part(skeleton, "lower_leg_l", MeshKit.cylinder(leg_r * 0.85, leg_r * 0.6, 0.45 * h, 6, Palette.RAKSHASA_SKIN), Vector3(0.0, -0.225 * h, 0.0))
	_part(skeleton, "upper_leg_r", MeshKit.cylinder(leg_r, leg_r * 0.85, 0.45 * h, 6, Palette.RAKSHASA_SKIN), Vector3(0.0, -0.225 * h, 0.0))
	_part(skeleton, "lower_leg_r", MeshKit.cylinder(leg_r * 0.85, leg_r * 0.6, 0.45 * h, 6, Palette.RAKSHASA_SKIN), Vector3(0.0, -0.225 * h, 0.0))
	_part(skeleton, "lower_leg_l", MeshKit.box(Vector3(0.16 * h * (0.5 + 0.5 * t), 0.06 * h, 0.26 * h), Palette.RAKSHASA_ARMOR), Vector3(0.0, -0.42 * h, 0.05 * h))
	_part(skeleton, "lower_leg_r", MeshKit.box(Vector3(0.16 * h * (0.5 + 0.5 * t), 0.06 * h, 0.26 * h), Palette.RAKSHASA_ARMOR), Vector3(0.0, -0.42 * h, 0.05 * h))

	# Weapon in the right hand.
	match weapon:
		&"spear":
			_part(skeleton, "weapon_socket", MeshKit.cylinder(0.018 * h, 0.018 * h, 1.6 * h, 5, Palette.RAKSHASA_ARMOR), Vector3(0.0, 0.55 * h, 0.0))
			_part(skeleton, "weapon_socket", MeshKit.cone(0.035 * h, 0.22 * h, 5, Palette.GOLD), Vector3(0.0, 1.46 * h, 0.0))
		&"bow":
			for i: int in range(5):
				var a: float = -0.9 + 0.45 * float(i)
				# Bow held out to the side: an arc in the XY plane, bulging outward (-X) from the hand.
				_part_xf(skeleton, "weapon_socket", MeshKit.box(Vector3(0.025 * h, 0.22 * h, 0.025 * h), Palette.RAKSHASA_ARMOR), Transform3D(Basis(Vector3.BACK, a), Vector3(0.5 * h * (cos(a) - 1.0), 0.5 * h * sin(a), 0.0)))
		&"club":
			_part(skeleton, "weapon_socket", MeshKit.cylinder(0.05 * h, 0.11 * h, 0.75 * h, 7, Palette.RAKSHASA_ARMOR), Vector3(0.0, 0.55 * h, 0.0))
		_:
			pass


static func _part(skeleton: Skeleton3D, bone: String, mesh: Mesh, offset: Vector3) -> void:
	_part_xf(skeleton, bone, mesh, Transform3D(Basis(), offset))


## One BoneAttachment3D per rigid part, with the mesh placed in the bone's local space.
static func _part_xf(skeleton: Skeleton3D, bone: String, mesh: Mesh, local: Transform3D) -> void:
	var attach: BoneAttachment3D = BoneAttachment3D.new()
	attach.name = "Attach_" + bone + "_" + str(skeleton.get_child_count())
	attach.bone_name = bone
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Part"
	mi.mesh = mesh
	mi.material_override = MeshKit.flat_material()
	mi.transform = local
	attach.add_child(mi)
	skeleton.add_child(attach)
