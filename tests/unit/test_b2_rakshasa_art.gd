extends GdUnitTestSuite
## B2 (art direction v2, docs/ART.md "Characters") acceptance tests for gen/rakshasa_model.gd: smooth sculpted
## geometry, one multi-surface part per bone with the painterly material kinds, wind-weighted cloth, glowing eyes,
## a triangle budget, weapon-aware poses and the Animator (breathing, easing, automatic walk cycle).

const VARIANTS: Array[StringName] = [&"spear", &"archer", &"brute", &"lankini"]
const BONES: Array[String] = [
	"hips", "spine", "chest", "head", "upper_arm_l", "lower_arm_l", "upper_arm_r", "lower_arm_r",
	"upper_leg_l", "lower_leg_l", "upper_leg_r", "lower_leg_r", "weapon_socket",
]


func _build(variant: StringName) -> Node3D:
	return auto_free(RakshasaModel.build(variant)) as Node3D


func _skeleton(root: Node3D) -> Skeleton3D:
	return root.get_node("Skeleton3D") as Skeleton3D


func _part(root: Node3D, bone: String) -> ArrayMesh:
	for child: Node in _skeleton(root).get_children():
		var att: BoneAttachment3D = child as BoneAttachment3D
		if att != null and att.bone_name == bone:
			return (att.get_child(0) as MeshInstance3D).mesh as ArrayMesh
	return null


func _surface(mesh: ArrayMesh, surface_name: String) -> int:
	for i: int in range(mesh.get_surface_count()):
		if mesh.surface_get_name(i) == surface_name:
			return i
	return -1


func _kinds(root: Node3D) -> Array[String]:
	var out: Array[String] = []
	for bone: String in BONES:
		var mesh: ArrayMesh = _part(root, bone)
		for i: int in range(mesh.get_surface_count()):
			if not out.has(mesh.surface_get_name(i)):
				out.append(mesh.surface_get_name(i))
	return out


func test_one_multi_surface_part_per_bone() -> void:
	for variant: StringName in VARIANTS:
		var root: Node3D = _build(variant)
		for bone: String in BONES:
			var mesh: ArrayMesh = _part(root, bone)
			assert_object(mesh).is_not_null()
			assert_int(mesh.get_surface_count()).is_greater(0)
			for i: int in range(mesh.get_surface_count()):
				assert_object(mesh.surface_get_material(i)).is_not_null()
		assert_int(_skeleton(root).get_child_count()).is_equal(BONES.size())


func test_material_kinds_cover_skin_armour_gold_and_cloth() -> void:
	for variant: StringName in VARIANTS:
		var kinds: Array[String] = _kinds(_build(variant))
		for wanted: String in ["skin", "gold", "lacquer_local", "cloth", RakshasaModel.GLOW_SURFACE]:
			assert_bool(kinds.has(wanted)).is_true()
	assert_bool(_kinds(_build(&"brute")).has("fur")).is_true()
	assert_bool(_kinds(_build(&"lankini")).has("fur")).is_true()
	assert_bool(_kinds(_build(&"spear")).has("wood_local")).is_true()


func test_surfaces_use_the_shared_painterly_materials() -> void:
	var chest: ArrayMesh = _part(_build(&"spear"), "chest")
	assert_object(chest.surface_get_material(_surface(chest, "skin"))).is_same(Materials.get_material(&"skin"))
	assert_object(chest.surface_get_material(_surface(chest, "gold"))).is_same(Materials.get_material(&"gold"))
	assert_object(chest.surface_get_material(_surface(chest, "cloth"))).is_same(Materials.get_material(&"cloth"))


func test_bodies_are_smooth_shaded() -> void:
	## Sculpted forms: nearly every skin triangle has differing vertex normals (flat shading has three equal ones).
	for variant: StringName in VARIANTS:
		var chest: ArrayMesh = _part(_build(variant), "chest")
		var arrays: Array = chest.surface_get_arrays(_surface(chest, "skin"))
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var smooth: int = 0
		var total: int = normals.size() / 3
		for t: int in range(total):
			if not normals[t * 3].is_equal_approx(normals[t * 3 + 1]) or not normals[t * 3].is_equal_approx(normals[t * 3 + 2]):
				smooth += 1
		assert_int(total).is_greater(100)
		assert_float(float(smooth) / float(total)).is_greater(0.9)
		for n: Vector3 in normals:
			assert_float(n.length()).is_equal_approx(1.0, 0.01)


func test_cloth_is_wind_weighted_from_pinned_to_free() -> void:
	for variant: StringName in VARIANTS:
		var hips: ArrayMesh = _part(_build(variant), "hips")
		var cols: PackedColorArray = hips.surface_get_arrays(_surface(hips, "cloth"))[Mesh.ARRAY_COLOR] as PackedColorArray
		var lo: float = 1.0
		var hi: float = 0.0
		for c: Color in cols:
			lo = minf(lo, c.a)
			hi = maxf(hi, c.a)
		## The loincloth is pinned at the belt and free at the hem.
		assert_float(lo).is_equal_approx(0.0, 0.01)
		assert_float(hi).is_greater(0.6)


func test_eyes_glow() -> void:
	for variant: StringName in VARIANTS:
		var head: ArrayMesh = _part(_build(variant), "head")
		var glow: int = _surface(head, RakshasaModel.GLOW_SURFACE)
		assert_int(glow).is_greater_equal(0)
		assert_object(head.surface_get_material(glow)).is_same(RakshasaModel.glow_material())
		var cols: PackedColorArray = head.surface_get_arrays(glow)[Mesh.ARRAY_COLOR] as PackedColorArray
		assert_bool(Color(cols[0].r, cols[0].g, cols[0].b).is_equal_approx(Palette.FIRE_CORE)).is_true()
		## Two eyes, mirrored.
		var verts: PackedVector3Array = head.surface_get_arrays(glow)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var left: float = 0.0
		var right: float = 0.0
		for v: Vector3 in verts:
			left = minf(left, v.x)
			right = maxf(right, v.x)
		assert_float(left).is_less(-0.03)
		assert_float(right).is_equal_approx(-left, 0.005)


func test_triangle_budget() -> void:
	## docs/ART.md: characters are about 3-6k triangles; the bosses' regalia may run a little over.
	for variant: StringName in VARIANTS:
		var tris: int = RakshasaModel.triangle_count(_build(variant))
		assert_int(tris).is_between(3000, 7500)


func test_meshes_are_shared_between_models_of_a_variant() -> void:
	var a: Node3D = _build(&"spear")
	var b: Node3D = _build(&"spear")
	assert_object(_part(a, "chest")).is_same(_part(b, "chest"))
	assert_object(_part(a, "chest")).is_not_same(_part(_build(&"brute"), "chest"))


func test_unknown_variant_falls_back_to_spear() -> void:
	var odd: Node3D = _build(&"no_such_variant")
	assert_object(_part(odd, "weapon_socket")).is_same(_part(_build(&"spear"), "weapon_socket"))


func test_weapon_points_up_at_rest_and_forward_in_a_thrust() -> void:
	for variant: StringName in [&"spear", &"lankini"]:
		var root: Node3D = _build(variant)
		var skel: Skeleton3D = _skeleton(root)
		var socket: int = skel.find_bone("weapon_socket")
		RakshasaModel.set_pose(root, &"idle")
		assert_float(RakshasaModel.bone_pose_in_model(skel, socket).basis.y.normalized().y).is_greater(0.95)
		RakshasaModel.set_pose(root, &"attack_strike")
		## The shaft stays level through the thrust, whatever the arm does: forward is -Z.
		assert_float(RakshasaModel.bone_pose_in_model(skel, socket).basis.y.normalized().z).is_less(-0.95)
		RakshasaModel.set_pose(root, &"attack_wind")
		assert_float(RakshasaModel.bone_pose_in_model(skel, socket).basis.y.normalized().z).is_less(-0.9)


func test_club_is_raised_then_brought_down() -> void:
	var root: Node3D = _build(&"brute")
	var skel: Skeleton3D = _skeleton(root)
	var socket: int = skel.find_bone("weapon_socket")
	RakshasaModel.set_pose(root, &"attack_wind")
	assert_float(RakshasaModel.bone_pose_in_model(skel, socket).basis.y.normalized().y).is_greater(0.6)
	RakshasaModel.set_pose(root, &"attack_strike")
	var down: Vector3 = RakshasaModel.bone_pose_in_model(skel, socket).basis.y.normalized()
	assert_float(down.y).is_less(-0.4)
	assert_float(down.z).is_less(-0.4)


func test_archer_raises_the_bow_arm_to_shoot() -> void:
	var root: Node3D = _build(&"archer")
	var skel: Skeleton3D = _skeleton(root)
	var hand: int = skel.find_bone("weapon_socket")
	RakshasaModel.set_pose(root, &"idle")
	var idle: Vector3 = RakshasaModel.bone_pose_in_model(skel, hand).origin
	RakshasaModel.set_pose(root, &"attack_wind")
	var aim: Vector3 = RakshasaModel.bone_pose_in_model(skel, hand).origin
	assert_float(aim.y).is_greater(idle.y + 0.3)
	assert_float(aim.z).is_less(idle.z - 0.2)
	## The bow is upright while aiming.
	assert_float(RakshasaModel.bone_pose_in_model(skel, hand).basis.y.normalized().y).is_greater(0.95)


func test_hunch_survives_the_idle_pose() -> void:
	## The brute's rest pose leans forward; poses are applied on top of it.
	var root: Node3D = _build(&"brute")
	var skel: Skeleton3D = _skeleton(root)
	RakshasaModel.set_pose(root, &"idle")
	var head: Vector3 = RakshasaModel.bone_pose_in_model(skel, skel.find_bone("head")).origin
	var hips: Vector3 = RakshasaModel.bone_pose_in_model(skel, skel.find_bone("hips")).origin
	assert_float(head.z).is_less(hips.z - 0.15)


func test_animator_walks_by_itself_when_an_idle_model_is_moved() -> void:
	var root: Node3D = RakshasaModel.build(&"spear")
	add_child(root)
	var animator: RakshasaModel.Animator = root.get_node("Animator") as RakshasaModel.Animator
	assert_object(animator).is_not_null()
	var skel: Skeleton3D = _skeleton(root)
	var leg_l: int = skel.find_bone("upper_leg_l")
	var leg_r: int = skel.find_bone("upper_leg_r")
	animator._process(0.1)
	var standing: float = skel.get_bone_pose_rotation(leg_l).angle_to(skel.get_bone_pose_rotation(leg_r))
	assert_float(standing).is_less(0.05)
	var widest: float = 0.0
	for step: int in range(30):
		root.position.x += 0.25
		animator._process(0.1)
		widest = maxf(widest, skel.get_bone_pose_rotation(leg_l).angle_to(skel.get_bone_pose_rotation(leg_r)))
	## Carried along at 2.5 m/s the legs stride apart.
	assert_float(widest).is_greater(0.5)
	for step2: int in range(30):
		animator._process(0.1)
	var stopped: float = skel.get_bone_pose_rotation(leg_l).angle_to(skel.get_bone_pose_rotation(leg_r))
	assert_float(stopped).is_less(0.1)
	root.free()


func test_animator_eases_toward_the_pose_and_breathes() -> void:
	var root: Node3D = RakshasaModel.build(&"brute")
	add_child(root)
	var animator: RakshasaModel.Animator = root.get_node("Animator") as RakshasaModel.Animator
	var skel: Skeleton3D = _skeleton(root)
	var arm: int = skel.find_bone("upper_arm_r")
	var chest: int = skel.find_bone("chest")
	animator._process(0.05)
	var idle_arm: Quaternion = skel.get_bone_pose_rotation(arm)
	var chest_a: Quaternion = skel.get_bone_pose_rotation(chest)
	animator._process(0.4)
	## Breathing moves the chest while the pose stays idle.
	assert_bool(chest_a.is_equal_approx(skel.get_bone_pose_rotation(chest))).is_false()
	RakshasaModel.set_pose(root, &"attack_wind")
	var snapped: Quaternion = skel.get_bone_pose_rotation(arm)
	assert_str(String(animator.target)).is_equal("attack_wind")
	## set_pose applies at once; the Animator then eases from where it was and arrives.
	animator._process(0.02)
	var easing: Quaternion = skel.get_bone_pose_rotation(arm)
	assert_float(easing.angle_to(idle_arm)).is_less(snapped.angle_to(idle_arm))
	for step: int in range(40):
		animator._process(0.05)
	assert_float(skel.get_bone_pose_rotation(arm).angle_to(snapped)).is_less(0.08)
	root.free()


func test_ember_glow_keeps_them_readable_at_night() -> void:
	for variant: StringName in VARIANTS:
		var glow: OmniLight3D = _build(variant).get_node("EmberGlow") as OmniLight3D
		assert_object(glow).is_not_null()
		assert_bool(glow.shadow_enabled).is_false()
		assert_float(glow.light_energy).is_equal_approx(RakshasaModel.EMBER_ENERGY, 0.0001)
		## Warm, in front of the chest, and local: it must not flood the street.
		assert_bool(glow.light_color.r > glow.light_color.b).is_true()
		assert_float(glow.position.z).is_less(0.0)
		assert_float(glow.omni_range).is_less(4.0)


func test_sculpt_tube_is_closed_and_faces_outward() -> void:
	var mesh: ArrayMesh = RakshasaModel.tube(PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 2.0, 0.0)]), PackedVector2Array([Vector2(0.5, 0.25)]), 8, PackedColorArray([Color.RED, Color.BLUE]), 2)
	var box: AABB = mesh.get_aabb()
	assert_float(box.size.x).is_equal_approx(1.0, 0.01)
	assert_float(box.size.z).is_equal_approx(0.5, 0.01)
	assert_float(box.size.y).is_equal_approx(2.0, 0.01)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	## 4 bands of 8 quads plus two end caps of 8 triangles.
	assert_int(verts.size() / 3).is_equal(4 * 8 * 2 + 8 * 2)
	for i: int in range(verts.size()):
		var radial: Vector3 = Vector3(verts[i].x, 0.0, verts[i].z)
		if radial.length() > 0.01:
			assert_float(normals[i].dot(radial)).is_greater(-0.001)
	## Front faces are clockwise in Godot: the face normal (b - a) x (c - a) points inward.
	for t: int in range(verts.size() / 3):
		var face: Vector3 = (verts[t * 3 + 1] - verts[t * 3]).cross(verts[t * 3 + 2] - verts[t * 3])
		var n: Vector3 = normals[t * 3] + normals[t * 3 + 1] + normals[t * 3 + 2]
		assert_float(face.dot(n)).is_less(0.0)
	## The gradient runs red to blue along the tube.
	assert_bool(cols[0].is_equal_approx(Color.RED)).is_true()
	assert_bool(cols[cols.size() - 1].is_equal_approx(Color.BLUE)).is_true()


func test_cloth_panel_hangs_down_with_rising_wind_weight() -> void:
	var mesh: ArrayMesh = RakshasaModel.cloth_panel(Vector3(0.0, 1.0, 0.0), Vector3.RIGHT, 0.8, 0.4, 0.6, Vector3(0.0, 0.0, -0.05), 0.02, PackedColorArray([Color.RED]), 0.9)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	assert_float(mesh.get_aabb().size.y).is_equal_approx(0.8, 0.01)
	for i: int in range(verts.size()):
		if verts[i].y > 0.99:
			assert_float(cols[i].a).is_equal_approx(0.0, 0.01)
		if verts[i].y < 0.21:
			assert_float(cols[i].a).is_equal_approx(0.9, 0.01)
