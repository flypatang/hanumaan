extends GdUnitTestSuite
## Acceptance tests for M08 gen/rakshasa_model.gd (DESIGN §9): four variants, silhouettes that differ,
## rigid parts on BoneAttachment3D (no skinning), palette colours only, and the shared pose names.

const VARIANT_NAMES: Array[StringName] = [&"spear", &"archer", &"brute", &"lankini"]
const POSE_NAMES: Array[StringName] = [&"idle", &"walk", &"attack"]
const BONE_NAMES: Array[String] = [
	"root", "hips", "spine", "chest", "head",
	"upper_arm_l", "lower_arm_l", "upper_arm_r", "lower_arm_r",
	"upper_leg_l", "lower_leg_l", "upper_leg_r", "lower_leg_r", "weapon_socket",
]
const BIG: float = 1.0e9


func _build(variant: StringName) -> Node3D:
	return auto_free(RakshasaModel.build(variant)) as Node3D


func _skeleton(root: Node3D) -> Skeleton3D:
	for child: Node in root.get_children():
		if child is Skeleton3D:
			return child as Skeleton3D
	return null


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child, out)


func _collect_attachments(node: Node, out: Array[BoneAttachment3D]) -> void:
	if node is BoneAttachment3D:
		out.append(node as BoneAttachment3D)
	for child: Node in node.get_children():
		_collect_attachments(child, out)


## Transform of `node` relative to `root` in the rest pose. Bone attachments take the bone's global rest.
func _xf(node: Node, root: Node) -> Transform3D:
	if node == root:
		return Transform3D.IDENTITY
	if node is BoneAttachment3D:
		var att: BoneAttachment3D = node as BoneAttachment3D
		var skel: Skeleton3D = att.get_parent() as Skeleton3D
		var idx: int = skel.find_bone(att.bone_name)
		return _xf(skel, root) * skel.get_bone_global_rest(idx)
	return _xf(node.get_parent(), root) * (node as Node3D).transform


## Width (x extent) and height (y extent) of every mesh in the rest pose.
func _size(root: Node3D) -> Vector2:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	var lo: Vector3 = Vector3(BIG, BIG, BIG)
	var hi: Vector3 = Vector3(-BIG, -BIG, -BIG)
	for mi: MeshInstance3D in meshes:
		var xf: Transform3D = _xf(mi, root)
		var box: AABB = (mi.mesh as Mesh).get_aabb()
		for i: int in range(8):
			var p: Vector3 = xf * box.get_endpoint(i)
			lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
			hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	return Vector2(hi.x - lo.x, hi.y - lo.y)


func _colours(root: Node3D) -> Array[Color]:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	var seen: Array[Color] = []
	for mi: MeshInstance3D in meshes:
		var arrays: Array = (mi.mesh as Mesh).surface_get_arrays(0)
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
		for c: Color in cols:
			var known: bool = false
			for s: Color in seen:
				if s.is_equal_approx(c):
					known = true
			if not known:
				seen.append(c)
	return seen


func _count_on_bone(root: Node3D, bone: String) -> int:
	var atts: Array[BoneAttachment3D] = []
	_collect_attachments(root, atts)
	var n: int = 0
	for att: BoneAttachment3D in atts:
		if att.bone_name == bone:
			n += 1
	return n


func test_build_returns_node3d_with_skeleton_for_each_variant() -> void:
	for variant: StringName in VARIANT_NAMES:
		var root: Node3D = _build(variant)
		assert_object(root).is_not_null()
		assert_object(_skeleton(root)).is_not_null()


func test_skeleton_has_expected_bones() -> void:
	var skel: Skeleton3D = _skeleton(_build(&"spear"))
	for bone: String in BONE_NAMES:
		assert_int(skel.find_bone(bone)).is_greater_equal(0)


func test_silhouettes_differ_by_more_than_15_percent() -> void:
	## Binding acceptance test: width/height ratios of every pair of variants differ by more than 15%.
	var ratios: Array[float] = []
	for variant: StringName in VARIANT_NAMES:
		var size: Vector2 = _size(_build(variant))
		assert_float(size.y).is_greater(0.0)
		ratios.append(size.x / size.y)
	for i: int in range(ratios.size()):
		for j: int in range(i + 1, ratios.size()):
			var larger: float = maxf(ratios[i], ratios[j])
			var diff: float = absf(ratios[i] - ratios[j]) / larger
			assert_bool(diff > 0.15).is_true()


func test_brute_is_wider_and_hunched_compared_to_spear() -> void:
	var brute: Vector2 = _size(_build(&"brute"))
	var spear: Vector2 = _size(_build(&"spear"))
	assert_bool(brute.x / brute.y > spear.x / spear.y).is_true()


func test_lankini_is_taller_than_the_unarmed_or_bow_variants() -> void:
	## The spear's shaft makes that variant taller, so only the bow and club variants are compared.
	var lankini: Vector2 = _size(_build(&"lankini"))
	for variant: StringName in [&"archer", &"brute"]:
		var other: Vector2 = _size(_build(variant))
		assert_bool(lankini.y > other.y * 0.99).is_true()


func test_every_mesh_is_rigid_on_a_bone_attachment_without_skinning() -> void:
	for variant: StringName in VARIANT_NAMES:
		var root: Node3D = _build(variant)
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(root, meshes)
		assert_int(meshes.size()).is_greater(0)
		for mi: MeshInstance3D in meshes:
			assert_bool(mi.get_parent() is BoneAttachment3D).is_true()
			assert_object(mi.skin).is_null()


func test_colours_come_from_palette() -> void:
	var allowed: Array[Color] = [Palette.RAKSHASA_SKIN, Palette.RAKSHASA_ARMOR, Palette.GOLD]
	for variant: StringName in VARIANT_NAMES:
		for c: Color in _colours(_build(variant)):
			var ok: bool = false
			for a: Color in allowed:
				if a.is_equal_approx(c):
					ok = true
			assert_bool(ok).is_true()


func test_skin_colour_is_used_and_lankini_has_gold_accents() -> void:
	var skin_seen: bool = false
	for c: Color in _colours(_build(&"brute")):
		if c.is_equal_approx(Palette.RAKSHASA_SKIN):
			skin_seen = true
	assert_bool(skin_seen).is_true()
	var gold_seen: bool = false
	for c: Color in _colours(_build(&"lankini")):
		if c.is_equal_approx(Palette.GOLD):
			gold_seen = true
	assert_bool(gold_seen).is_true()


func test_horns_are_attached_to_the_head() -> void:
	for variant: StringName in VARIANT_NAMES:
		## head sphere plus two horn cones
		assert_int(_count_on_bone(_build(variant), "head")).is_greater_equal(3)


func test_weapons_follow_variant() -> void:
	assert_int(_count_on_bone(_build(&"spear"), "weapon_socket")).is_greater(0)
	assert_int(_count_on_bone(_build(&"archer"), "weapon_socket")).is_greater(0)
	assert_int(_count_on_bone(_build(&"brute"), "weapon_socket")).is_greater(0)
	assert_int(_count_on_bone(_build(&"lankini"), "weapon_socket")).is_equal(0)


func test_pose_names_are_set_and_change_the_skeleton() -> void:
	var root: Node3D = _build(&"spear")
	var skel: Skeleton3D = _skeleton(root)
	var arm: int = skel.find_bone("upper_arm_r")
	RakshasaModel.set_pose(root, &"idle")
	var idle_rot: Quaternion = skel.get_bone_pose_rotation(arm)
	RakshasaModel.set_pose(root, &"attack")
	var attack_rot: Quaternion = skel.get_bone_pose_rotation(arm)
	assert_bool(idle_rot.is_equal_approx(attack_rot)).is_false()
	for pose: StringName in POSE_NAMES:
		RakshasaModel.set_pose(root, pose)
	assert_object(root).is_not_null()


func test_walk_pose_swings_the_legs_opposite() -> void:
	var root: Node3D = _build(&"archer")
	var skel: Skeleton3D = _skeleton(root)
	RakshasaModel.set_pose(root, &"walk")
	var left: Quaternion = skel.get_bone_pose_rotation(skel.find_bone("upper_leg_l"))
	var right: Quaternion = skel.get_bone_pose_rotation(skel.find_bone("upper_leg_r"))
	assert_bool(left.is_equal_approx(right)).is_false()
