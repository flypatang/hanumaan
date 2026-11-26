extends GdUnitTestSuite
## B2 (art direction v2) acceptance tests for gen/simhika_model.gd: a sinuous smooth serpent body, a mane that
## streams in the wind, glowing SINDOOR eyes, translucent water_edge fins and foam, and a jaw that drops open.


func _build() -> Node3D:
	return auto_free(SimhikaModel.build()) as Node3D


func _mesh(root: Node3D, node_name: String) -> MeshInstance3D:
	return root.find_child(node_name, true, false) as MeshInstance3D


func test_named_parts_exist() -> void:
	var m: Node3D = _build()
	for node_name: String in ["Rig", "Body", "Head", "Jaw", "EyeL", "EyeR", "Mane", "Serpent", "Belly", "Crest", "Skull", "Fangs", "Horns", "Foam"]:
		assert_object(m.find_child(node_name, true, false)).is_not_null()
	assert_int(SimhikaModel.POSES.size()).is_equal(4)


func test_body_is_one_smooth_sinuous_tube() -> void:
	var serpent: MeshInstance3D = _mesh(_build(), "Serpent")
	var box: AABB = serpent.mesh.get_aabb()
	## It rises from under the water to the head, swaying to both sides on the way.
	assert_float(box.position.y).is_less(-1.0)
	assert_float(box.end.y).is_greater(9.0)
	assert_float(box.size.x).is_greater(6.0)
	var normals: PackedVector3Array = serpent.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var smooth: int = 0
	for t: int in range(normals.size() / 3):
		if not normals[t * 3].is_equal_approx(normals[t * 3 + 1]) or not normals[t * 3].is_equal_approx(normals[t * 3 + 2]):
			smooth += 1
	assert_float(float(smooth) / float(normals.size() / 3)).is_greater(0.9)


func test_eyes_glow_sindoor() -> void:
	var m: Node3D = _build()
	for eye_name: String in ["EyeL", "EyeR"]:
		var eye: MeshInstance3D = _mesh(m, eye_name)
		var cols: PackedColorArray = eye.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
		assert_bool(cols[0].is_equal_approx(Palette.SINDOOR)).is_true()
		assert_object(eye.material_override).is_same(RakshasaModel.glow_material())
	assert_float(_mesh(m, "EyeL").position.x).is_less(0.0)
	assert_float(_mesh(m, "EyeR").position.x).is_greater(0.0)


func test_fins_and_foam_use_water_edge() -> void:
	var m: Node3D = _build()
	var water: Material = Materials.get_material(&"water_edge")
	for node_name: String in ["Crest", "PectoralL", "PectoralR", "Fluke", "EarL", "EarR", "Foam"]:
		assert_object(_mesh(m, node_name).material_override).is_same(water)
	## Foam fades out: its opacity (vertex alpha) runs from nearly opaque to clear.
	var cols: PackedColorArray = _mesh(m, "Foam").mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
	var lo: float = 1.0
	var hi: float = 0.0
	for c: Color in cols:
		lo = minf(lo, c.a)
		hi = maxf(hi, c.a)
	assert_float(lo).is_equal_approx(0.0, 0.01)
	assert_float(hi).is_greater(0.8)


func test_mane_is_cloth_pinned_at_the_scalp_and_free_at_the_tips() -> void:
	var mane: Node3D = _build().find_child("Mane", true, false) as Node3D
	assert_int(mane.get_child_count()).is_greater_equal(3)
	var lo: float = 1.0
	var hi: float = 0.0
	for child: Node in mane.get_children():
		var mi: MeshInstance3D = child as MeshInstance3D
		assert_object(mi.material_override).is_same(Materials.get_material(&"cloth"))
		var cols: PackedColorArray = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
		for c: Color in cols:
			lo = minf(lo, c.a)
			hi = maxf(hi, c.a)
	assert_float(lo).is_equal_approx(0.0, 0.01)
	assert_float(hi).is_equal_approx(1.0, 0.01)


func test_mouth_opens_downward_and_kneel_bows_the_head() -> void:
	var m: Node3D = _build()
	var head: Node3D = m.find_child("Head", true, false) as Node3D
	var jaw: Node3D = m.find_child("Jaw", true, false) as Node3D
	SimhikaModel.set_pose(m, &"mouth_open")
	assert_float(jaw.rotation.x).is_equal_approx(-SimhikaModel.JAW_OPEN_ANGLE, 0.001)
	## The jaw tip (forward of the hinge, -Z) swings down.
	assert_float((jaw.transform.basis * Vector3(0.0, 0.0, -2.5)).y).is_less(-1.5)
	SimhikaModel.set_pose(m, &"kneel")
	assert_float((head.transform.basis * Vector3.FORWARD).y).is_less(-0.5)
	assert_float(jaw.rotation.x).is_equal_approx(0.0, 0.001)
	SimhikaModel.set_pose(m, &"no_such_pose")
	assert_float(head.rotation.x).is_equal_approx(0.0, 0.001)


func test_head_sits_on_the_neck() -> void:
	var m: Node3D = _build()
	var head: Node3D = m.find_child("Head", true, false) as Node3D
	assert_bool(head.position.is_equal_approx(SimhikaModel.HEAD_POSITION)).is_true()
	var serpent: MeshInstance3D = _mesh(m, "Serpent")
	## The top of the body tube ends inside the skull.
	assert_float(absf(serpent.mesh.get_aabb().end.y - head.position.y)).is_less(1.5)


func test_sway_keeps_her_moving() -> void:
	var m: Node3D = SimhikaModel.build()
	add_child(m)
	var rig: Node3D = m.get_node("Rig") as Node3D
	var sway: SimhikaModel.Sway = m.get_node("Sway") as SimhikaModel.Sway
	sway._process(1.0)
	var a: Vector3 = rig.rotation
	sway._process(1.0)
	assert_bool(a.is_equal_approx(rig.rotation)).is_false()
	assert_float(absf(rig.rotation.z)).is_less(0.05)
	m.free()


func test_triangle_budget() -> void:
	assert_int(RakshasaModel.triangle_count(_build())).is_between(4000, 10000)
