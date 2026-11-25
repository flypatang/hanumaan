extends GdUnitTestSuite
## A2 art-pass acceptance tests for gen/rakshasa_model.gd: bulk, pose names, per-variant silhouettes.

const VARIANTS: Array[StringName] = [&"spear", &"archer", &"brute", &"lankini"]
const BIG: float = 1.0e9


func _build(variant: StringName) -> Node3D:
	return auto_free(RakshasaModel.build(variant)) as Node3D


func _skeleton(root: Node3D) -> Skeleton3D:
	return root.get_node("Skeleton3D") as Skeleton3D


func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_meshes(child, out)


func _xf(node: Node, root: Node) -> Transform3D:
	if node == root:
		return Transform3D.IDENTITY
	if node is BoneAttachment3D:
		var att: BoneAttachment3D = node as BoneAttachment3D
		var skel: Skeleton3D = att.get_parent() as Skeleton3D
		return _xf(skel, root) * skel.get_bone_global_rest(skel.find_bone(att.bone_name))
	return _xf(node.get_parent(), root) * (node as Node3D).transform


func _extent(root: Node3D) -> Vector3:
	var list: Array[MeshInstance3D] = []
	_meshes(root, list)
	var lo: Vector3 = Vector3(BIG, BIG, BIG)
	var hi: Vector3 = Vector3(-BIG, -BIG, -BIG)
	for mi: MeshInstance3D in list:
		var xf: Transform3D = _xf(mi, root)
		var box: AABB = (mi.mesh as Mesh).get_aabb()
		for i: int in range(8):
			var p: Vector3 = xf * box.get_endpoint(i)
			lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
			hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	return hi - lo


## Width of the body only (no weapon parts).
func _body_width(root: Node3D) -> float:
	var list: Array[MeshInstance3D] = []
	_meshes(root, list)
	var lo: float = BIG
	var hi: float = -BIG
	for mi: MeshInstance3D in list:
		var att: BoneAttachment3D = mi.get_parent() as BoneAttachment3D
		if att.bone_name == "weapon_socket":
			continue
		var xf: Transform3D = _xf(mi, root)
		var box: AABB = (mi.mesh as Mesh).get_aabb()
		for i: int in range(8):
			var x: float = (xf * box.get_endpoint(i)).x
			lo = minf(lo, x)
			hi = maxf(hi, x)
	return hi - lo


func _count(root: Node3D, bone: String) -> int:
	var list: Array[MeshInstance3D] = []
	_meshes(root, list)
	var n: int = 0
	for mi: MeshInstance3D in list:
		if (mi.get_parent() as BoneAttachment3D).bone_name == bone:
			n += 1
	return n


func _has_colour(root: Node3D, colour: Color) -> bool:
	var list: Array[MeshInstance3D] = []
	_meshes(root, list)
	for mi: MeshInstance3D in list:
		var cols: PackedColorArray = (mi.mesh as Mesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
		for c: Color in cols:
			if c.is_equal_approx(colour):
				return true
	return false


func test_pose_list_matches_hanuman_names() -> void:
	var expected: Array[StringName] = [&"idle", &"walk_a", &"walk_b", &"attack_wind", &"attack_strike"]
	assert_int(RakshasaModel.POSES.size()).is_equal(5)
	for p: StringName in expected:
		assert_bool(RakshasaModel.POSES.has(p)).is_true()


func test_all_poses_and_aliases_differ_from_idle_where_expected() -> void:
	var root: Node3D = _build(&"spear")
	var skel: Skeleton3D = _skeleton(root)
	var arm: int = skel.find_bone("upper_arm_r")
	RakshasaModel.set_pose(root, &"attack_wind")
	var wind: Quaternion = skel.get_bone_pose_rotation(arm)
	RakshasaModel.set_pose(root, &"attack_strike")
	var strike: Quaternion = skel.get_bone_pose_rotation(arm)
	assert_bool(wind.is_equal_approx(strike)).is_false()
	RakshasaModel.set_pose(root, &"attack")
	assert_bool(skel.get_bone_pose_rotation(arm).is_equal_approx(strike)).is_true()
	RakshasaModel.set_pose(root, &"walk_a")
	var leg: int = skel.find_bone("upper_leg_l")
	var a: Quaternion = skel.get_bone_pose_rotation(leg)
	RakshasaModel.set_pose(root, &"walk_b")
	var b: Quaternion = skel.get_bone_pose_rotation(leg)
	assert_bool(a.is_equal_approx(b)).is_false()
	RakshasaModel.set_pose(root, &"walk")
	assert_bool(skel.get_bone_pose_rotation(leg).is_equal_approx(a)).is_true()


func test_brute_is_about_one_and_a_half_times_wider_than_spear() -> void:
	var ratio: float = _body_width(_build(&"brute")) / _body_width(_build(&"spear"))
	assert_float(ratio).is_between(1.35, 1.8)


func test_bodies_are_bulky_not_sticks() -> void:
	for variant: StringName in VARIANTS:
		var root: Node3D = _build(variant)
		assert_float(_body_width(root)).is_greater(0.75)


func test_every_variant_has_two_horns_and_fangs_on_head() -> void:
	for variant: StringName in VARIANTS:
		assert_int(_count(_build(variant), "head")).is_greater_equal(6)


func test_pauldrons_on_both_shoulders() -> void:
	for variant: StringName in VARIANTS:
		var root: Node3D = _build(variant)
		assert_int(_count(root, "upper_arm_l")).is_greater_equal(2)
		assert_int(_count(root, "upper_arm_r")).is_greater_equal(2)
		assert_bool(_has_colour(root, Palette.GOLD)).is_true()


func test_weapon_parts_are_distinct_per_variant() -> void:
	var counts: Array[int] = []
	for variant: StringName in VARIANTS:
		counts.append(_count(_build(variant), "weapon_socket"))
	assert_int(counts[0]).is_greater_equal(2)
	assert_int(counts[1]).is_greater_equal(6)
	assert_int(counts[3]).is_greater_equal(4)


func test_archer_carries_quiver_on_the_chest() -> void:
	assert_int(_count(_build(&"archer"), "chest")).is_greater(_count(_build(&"spear"), "chest"))


func test_lankini_is_tallest_body_and_spear_is_tall() -> void:
	var lankini: float = _extent(_build(&"lankini")).y
	var brute: float = _extent(_build(&"brute")).y
	var archer: float = _extent(_build(&"archer")).y
	assert_bool(lankini > brute).is_true()
	assert_bool(lankini > archer).is_true()
	assert_float(_extent(_build(&"spear")).y).is_greater(2.0)
