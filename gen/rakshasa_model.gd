class_name RakshasaModel
extends RefCounted
## Rakshasa foes (DESIGN §6.2, §9 M08, A2 art pass). Built from primitives with MeshKit, the same technique as Hanuman:
## a Skeleton3D with bones created in code, and every rigid part on its own BoneAttachment3D. There is no skinning.
## Forward is -Z. Variants: spear (tall, crested helmet, long spear), archer (lighter armour, recurved bow, quiver),
## brute (the kinkara: enormous, hunched, club), lankini (tall regal guardian: gold crown and armour, trident).
## Pose names match HanumanModel: idle, walk_a, walk_b, attack_wind, attack_strike ("walk" and "attack" are aliases).

const POSES: Array[StringName] = [&"idle", &"walk_a", &"walk_b", &"attack_wind", &"attack_strike"]

## Pose table: bone name -> Euler angles (radians, x = pitch, y = twist, z = roll) applied on top of the rest pose.
## Positive pitch swings a hanging limb forward (-Z) and tips the upright torso backward.
const _POSE_IDLE: Dictionary = {"chest": Vector3(0.02, 0.0, 0.0), "upper_arm_l": Vector3(0.0, 0.0, 0.08), "upper_arm_r": Vector3(0.0, 0.0, -0.08)}
const _POSE_WALK_A: Dictionary = {
	"upper_leg_l": Vector3(0.55, 0.0, 0.0),
	"upper_leg_r": Vector3(-0.55, 0.0, 0.0),
	"lower_leg_r": Vector3(0.4, 0.0, 0.0),
	"upper_arm_l": Vector3(-0.45, 0.0, 0.08),
	"upper_arm_r": Vector3(0.3, 0.0, -0.08),
	"chest": Vector3(-0.05, 0.0, 0.0),
}
const _POSE_WALK_B: Dictionary = {
	"upper_leg_l": Vector3(-0.55, 0.0, 0.0),
	"upper_leg_r": Vector3(0.55, 0.0, 0.0),
	"lower_leg_l": Vector3(0.4, 0.0, 0.0),
	"upper_arm_l": Vector3(0.45, 0.0, 0.08),
	"upper_arm_r": Vector3(-0.3, 0.0, -0.08),
	"chest": Vector3(-0.05, 0.0, 0.0),
}
const _POSE_ATTACK_WIND: Dictionary = {
	"upper_arm_r": Vector3(-2.4, 0.0, -0.2),
	"lower_arm_r": Vector3(-0.5, 0.0, 0.0),
	"upper_arm_l": Vector3(0.6, 0.0, 0.1),
	"chest": Vector3(0.25, 0.3, 0.0),
}
const _POSE_ATTACK_STRIKE: Dictionary = {
	"upper_arm_r": Vector3(1.2, 0.0, -0.1),
	"lower_arm_r": Vector3(0.3, 0.0, 0.0),
	"upper_arm_l": Vector3(-0.5, 0.0, 0.1),
	"chest": Vector3(-0.35, -0.3, 0.0),
	"upper_leg_l": Vector3(0.35, 0.0, 0.0),
	"upper_leg_r": Vector3(-0.25, 0.0, 0.0),
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
		&"walk_a", &"walk":
			return _POSE_WALK_A
		&"walk_b":
			return _POSE_WALK_B
		&"attack_wind":
			return _POSE_ATTACK_WIND
		&"attack_strike", &"attack":
			return _POSE_ATTACK_STRIKE
		_:
			return _POSE_IDLE


static func _find_skeleton(root: Node3D) -> Skeleton3D:
	for child: Node in root.get_children():
		if child is Skeleton3D:
			return child as Skeleton3D
	return null


## h = height scale, w = body width scale (torso, limbs), hunch = forward chest tilt (radians).
static func _spec(variant: StringName) -> Dictionary:
	match variant:
		&"archer":
			return {"h": 1.0, "w": 0.85, "hunch": 0.1, "weapon": &"bow", "gold": false, "pauldron": 0.75}
		&"brute":
			return {"h": 0.98, "w": 1.85, "hunch": 0.4, "weapon": &"club", "gold": false, "pauldron": 1.25}
		&"lankini":
			return {"h": 1.15, "w": 0.9, "hunch": 0.0, "weapon": &"trident", "gold": true, "pauldron": 1.0}
		_:
			return {"h": 1.0, "w": 1.0, "hunch": 0.15, "weapon": &"spear", "gold": false, "pauldron": 1.0}


static func _add_bones(skeleton: Skeleton3D, spec: Dictionary) -> void:
	var h: float = spec["h"] as float
	var w: float = spec["w"] as float
	var hunch: float = spec["hunch"] as float
	var sx: float = 0.26 * w + 0.1
	_add_bone(skeleton, "root", "", Vector3.ZERO, 0.0)
	_add_bone(skeleton, "hips", "root", Vector3(0.0, 0.95 * h, 0.0), 0.0)
	_add_bone(skeleton, "spine", "hips", Vector3(0.0, 0.12 * h, 0.0), -hunch * 0.4)
	_add_bone(skeleton, "chest", "spine", Vector3(0.0, 0.28 * h, 0.0), -hunch * 0.6)
	_add_bone(skeleton, "head", "chest", Vector3(0.0, 0.36 * h, -0.05 * h * (1.0 + hunch)), hunch * 0.7)
	_add_bone(skeleton, "upper_arm_l", "chest", Vector3(sx, 0.2 * h, 0.0), 0.0)
	_add_bone(skeleton, "lower_arm_l", "upper_arm_l", Vector3(0.0, -0.32 * h, 0.0), 0.0)
	_add_bone(skeleton, "upper_arm_r", "chest", Vector3(-sx, 0.2 * h, 0.0), 0.0)
	_add_bone(skeleton, "lower_arm_r", "upper_arm_r", Vector3(0.0, -0.32 * h, 0.0), 0.0)
	_add_bone(skeleton, "upper_leg_l", "hips", Vector3(0.14 * w + 0.04, -0.05 * h, 0.0), 0.0)
	_add_bone(skeleton, "lower_leg_l", "upper_leg_l", Vector3(0.0, -0.45 * h, 0.0), 0.0)
	_add_bone(skeleton, "upper_leg_r", "hips", Vector3(-0.14 * w - 0.04, -0.05 * h, 0.0), 0.0)
	_add_bone(skeleton, "lower_leg_r", "upper_leg_r", Vector3(0.0, -0.45 * h, 0.0), 0.0)
	_add_bone(skeleton, "weapon_socket", "lower_arm_r", Vector3(0.0, -0.3 * h, 0.0), 0.0)
	skeleton.reset_bone_poses()


static func _add_bone(skeleton: Skeleton3D, bone: String, parent: String, offset: Vector3, pitch: float) -> void:
	var idx: int = skeleton.add_bone(bone)
	if parent != "":
		skeleton.set_bone_parent(idx, skeleton.find_bone(parent))
	skeleton.set_bone_rest(idx, Transform3D(Basis(Vector3.RIGHT, pitch), offset))


static func _attach_parts(skeleton: Skeleton3D, spec: Dictionary) -> void:
	var h: float = spec["h"] as float
	var w: float = spec["w"] as float
	var weapon: StringName = spec["weapon"] as StringName
	var gold: bool = spec["gold"] as bool
	var pauld: float = spec["pauldron"] as float
	var skin: Color = Palette.RAKSHASA_SKIN
	var armor: Color = Palette.RAKSHASA_ARMOR
	var trim: Color = Palette.GOLD
	var plate: Color = trim if gold else armor
	var arm_r: float = 0.075 * h * w * 0.9 + 0.02
	var leg_r: float = 0.1 * h * w * 0.9 + 0.02

	# Torso: pelvis, belly, broad chest, front plate, belt and gold trim.
	_part(skeleton, "hips", MeshKit.box(Vector3(0.5 * w, 0.24 * h, 0.34 * w), skin), Vector3.ZERO)
	_part(skeleton, "hips", MeshKit.box(Vector3(0.56 * w, 0.08 * h, 0.38 * w), armor), Vector3(0.0, 0.1 * h, 0.0))
	_part(skeleton, "hips", MeshKit.box(Vector3(0.14 * w, 0.06 * h, 0.04), trim), Vector3(0.0, 0.1 * h, -0.2 * w))
	_part(skeleton, "hips", MeshKit.box(Vector3(0.34 * w, 0.26 * h, 0.04), armor), Vector3(0.0, -0.2 * h, -0.17 * w))
	_part(skeleton, "spine", MeshKit.cylinder(0.25 * w, 0.28 * w, 0.34 * h, 8, skin), Vector3(0.0, 0.14 * h, -0.02))
	_part(skeleton, "chest", MeshKit.box(Vector3(0.66 * w, 0.36 * h, 0.4 * w), skin), Vector3(0.0, 0.1 * h, 0.0))
	_part(skeleton, "chest", MeshKit.box(Vector3(0.52 * w, 0.32 * h, 0.07), plate), Vector3(0.0, 0.1 * h, -0.2 * w))
	_part(skeleton, "chest", MeshKit.box(Vector3(0.56 * w, 0.045 * h, 0.09), trim), Vector3(0.0, 0.27 * h, -0.2 * w))
	_part(skeleton, "chest", MeshKit.box(Vector3(0.1 * w, 0.18 * h, 0.09), trim), Vector3(0.0, 0.08 * h, -0.21 * w))

	# Head: big, jutting jaw, two horn cones, gold fangs.
	var hr: float = 0.19 * h * (0.85 + 0.15 * w)
	_part(skeleton, "head", MeshKit.sphere(hr, 7, 9, skin), Vector3(0.0, 0.1 * h, 0.0))
	_part(skeleton, "head", MeshKit.box(Vector3(hr * 1.4, hr * 0.7, hr * 1.1), skin), Vector3(0.0, 0.02 * h, -hr * 0.55))
	_part(skeleton, "head", MeshKit.box(Vector3(hr * 1.6, hr * 0.28, hr * 0.5), armor), Vector3(0.0, 0.17 * h, -hr * 0.7))
	var horn: ArrayMesh = MeshKit.cone(0.055 * h, 0.34 * h, 6, armor)
	_part_xf(skeleton, "head", horn, Transform3D(Basis(Vector3.FORWARD, 0.45), Vector3(0.12 * h, 0.2 * h, 0.0)))
	_part_xf(skeleton, "head", horn, Transform3D(Basis(Vector3.FORWARD, -0.45), Vector3(-0.12 * h, 0.2 * h, 0.0)))
	var fang: ArrayMesh = MeshKit.cone(0.022 * h, 0.075 * h, 5, trim)
	_part_xf(skeleton, "head", fang, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0.055 * h, -0.06 * h, -hr * 1.05)))
	_part_xf(skeleton, "head", fang, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(-0.055 * h, -0.06 * h, -hr * 1.05)))
	_attach_headgear(skeleton, spec, hr)

	# Pauldrons (armour plates with gold trim) and thick arms.
	for side: String in ["l", "r"]:
		var arm: String = "upper_arm_" + side
		var low: String = "lower_arm_" + side
		_part(skeleton, arm, MeshKit.sphere(0.17 * h * pauld, 6, 8, plate), Vector3(0.0, 0.03 * h, 0.0))
		_part(skeleton, arm, MeshKit.cylinder(0.18 * h * pauld, 0.2 * h * pauld, 0.04 * h, 8, trim), Vector3(0.0, -0.04 * h, 0.0))
		_part(skeleton, arm, MeshKit.cylinder(arm_r * 1.1, arm_r * 0.95, 0.32 * h, 7, skin), Vector3(0.0, -0.16 * h, 0.0))
		_part(skeleton, low, MeshKit.cylinder(arm_r * 1.15, arm_r * 0.9, 0.3 * h, 7, skin), Vector3(0.0, -0.15 * h, 0.0))
		_part(skeleton, low, MeshKit.cylinder(arm_r * 1.3, arm_r * 1.3, 0.07 * h, 7, trim if gold else armor), Vector3(0.0, -0.06 * h, 0.0))
		_part(skeleton, low, MeshKit.sphere(arm_r * 1.2, 5, 7, skin), Vector3(0.0, -0.31 * h, 0.0))

	# Thick legs with armoured boots.
	for side2: String in ["l", "r"]:
		var up: String = "upper_leg_" + side2
		var lo: String = "lower_leg_" + side2
		_part(skeleton, up, MeshKit.cylinder(leg_r * 1.1, leg_r * 0.95, 0.45 * h, 7, skin), Vector3(0.0, -0.225 * h, 0.0))
		_part(skeleton, lo, MeshKit.cylinder(leg_r * 0.95, leg_r * 0.8, 0.45 * h, 7, skin), Vector3(0.0, -0.225 * h, 0.0))
		_part(skeleton, lo, MeshKit.box(Vector3(leg_r * 2.6, 0.08 * h, 0.34 * h), armor), Vector3(0.0, -0.41 * h, -0.05 * h))
		_part(skeleton, lo, MeshKit.sphere(leg_r * 1.15, 5, 7, plate), Vector3(0.0, 0.0, -leg_r * 0.5))

	_attach_weapon(skeleton, weapon, h, w)


static func _attach_headgear(skeleton: Skeleton3D, spec: Dictionary, hr: float) -> void:
	var h: float = spec["h"] as float
	var weapon: StringName = spec["weapon"] as StringName
	var trim: Color = Palette.GOLD
	match weapon:
		&"spear":
			# Crested helmet: armour cap with a tall gold crest.
			_part(skeleton, "head", MeshKit.cylinder(hr * 0.95, hr * 1.02, 0.1 * h, 8, Palette.RAKSHASA_ARMOR), Vector3(0.0, 0.2 * h, 0.0))
			_part(skeleton, "head", MeshKit.box(Vector3(0.04 * h, 0.2 * h, 0.22 * h), trim), Vector3(0.0, 0.34 * h, 0.0))
		&"trident":
			# Gold crown with points.
			_part(skeleton, "head", MeshKit.cylinder(hr * 0.95, hr * 1.0, 0.07 * h, 8, trim), Vector3(0.0, 0.22 * h, 0.0))
			for i: int in range(5):
				var a: float = TAU * float(i) / 5.0
				var p: Vector3 = Vector3(sin(a) * hr * 0.8, 0.31 * h, cos(a) * hr * 0.8)
				_part(skeleton, "head", MeshKit.cone(0.03 * h, 0.12 * h, 5, trim), p)
		_:
			pass


static func _attach_weapon(skeleton: Skeleton3D, weapon: StringName, h: float, w: float) -> void:
	var armor: Color = Palette.RAKSHASA_ARMOR
	var trim: Color = Palette.GOLD
	var wood: Color = Palette.RAKSHASA_SKIN
	match weapon:
		&"spear":
			_part(skeleton, "weapon_socket", MeshKit.cylinder(0.025 * h, 0.025 * h, 1.9 * h, 5, armor), Vector3(0.0, 0.55 * h, 0.0))
			_part(skeleton, "weapon_socket", MeshKit.cone(0.06 * h, 0.34 * h, 5, trim), Vector3(0.0, 1.72 * h, 0.0))
			_part(skeleton, "weapon_socket", MeshKit.box(Vector3(0.14 * h, 0.03 * h, 0.03 * h), trim), Vector3(0.0, 1.55 * h, 0.0))
		&"bow":
			# Big recurved bow in the XY plane, bulging outward (-X): a central arc plus tips curling back.
			var big: float = 0.85 * h
			for i: int in range(7):
				var a: float = -1.05 + 0.35 * float(i)
				var pos: Vector3 = Vector3(big * (cos(a) - 1.0) * 0.55, 0.15 * h + big * sin(a), 0.0)
				_part_xf(skeleton, "weapon_socket", MeshKit.box(Vector3(0.045 * h, 0.3 * h, 0.045 * h), armor), Transform3D(Basis(Vector3.BACK, a), pos))
			for sgn: float in [-1.0, 1.0]:
				var tip: Vector3 = Vector3(big * (cos(1.05) - 1.0) * 0.55 + 0.1 * h, 0.15 * h + sgn * big * sin(1.05) + sgn * 0.14 * h, 0.0)
				_part_xf(skeleton, "weapon_socket", MeshKit.box(Vector3(0.04 * h, 0.22 * h, 0.04 * h), trim), Transform3D(Basis(Vector3.BACK, -sgn * 0.6), tip))
			var top_y: float = 0.15 * h + big * sin(1.05) + 0.14 * h
			var sx: float = big * (cos(1.05) - 1.0) * 0.55 + 0.17 * h
			_part(skeleton, "weapon_socket", MeshKit.box(Vector3(0.012 * h, 2.0 * top_y, 0.012 * h), wood), Vector3(sx, 0.15 * h, 0.0))
			# Quiver on the back with arrow tips.
			_part_xf(skeleton, "chest", MeshKit.cylinder(0.09 * h, 0.08 * h, 0.55 * h, 6, armor), Transform3D(Basis(Vector3.BACK, 0.25), Vector3(0.1 * h, 0.16 * h, 0.27 * h * w)))
			for k: int in range(3):
				_part_xf(skeleton, "chest", MeshKit.cone(0.025 * h, 0.1 * h, 4, trim), Transform3D(Basis(Vector3.BACK, 0.25), Vector3(0.03 * h + 0.05 * h * float(k), 0.46 * h + 0.005 * float(k), 0.27 * h * w)))
		&"club":
			_part(skeleton, "weapon_socket", MeshKit.cylinder(0.06 * h, 0.13 * h, 0.9 * h, 7, armor), Vector3(0.0, 0.6 * h, 0.0))
			_part(skeleton, "weapon_socket", MeshKit.sphere(0.2 * h, 6, 8, armor), Vector3(0.0, 1.08 * h, 0.0))
			_part(skeleton, "weapon_socket", MeshKit.cylinder(0.14 * h, 0.14 * h, 0.04 * h, 7, trim), Vector3(0.0, 0.85 * h, 0.0))
		&"trident":
			_part(skeleton, "weapon_socket", MeshKit.cylinder(0.022 * h, 0.022 * h, 2.3 * h, 5, trim), Vector3(0.0, 0.85 * h, 0.0))
			_part(skeleton, "weapon_socket", MeshKit.box(Vector3(0.36 * h, 0.04 * h, 0.04 * h), trim), Vector3(0.0, 1.92 * h, 0.0))
			for dx: float in [-0.16, 0.0, 0.16]:
				var len: float = 0.34 * h if dx == 0.0 else 0.26 * h
				_part(skeleton, "weapon_socket", MeshKit.cone(0.035 * h, len, 5, trim), Vector3(dx * h, 1.94 * h + len * 0.5, 0.0))
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
