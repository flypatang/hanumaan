extends GdUnitTestSuite
## M23 gen/simhika_model.gd: a huge serpentine-lioness form with sindoor eyes, no gore (DESIGN §2, §6).


func _count(n: Node, type_name: String) -> int:
	var c: int = 1 if n.get_class() == type_name else 0
	for ch: Node in n.get_children():
		c += _count(ch, type_name)
	return c


func test_build_has_parts_and_is_large() -> void:
	var m: Node3D = SimhikaModel.build()
	auto_free(m)
	assert_object(m.find_child("Head", true, false)).is_not_null()
	assert_object(m.find_child("Jaw", true, false)).is_not_null()
	assert_object(m.find_child("EyeL", true, false)).is_not_null()
	assert_int(_count(m, "MeshInstance3D")).is_greater(15)
	var top: float = 0.0
	for mi: Node in m.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = mi as MeshInstance3D
		top = maxf(top, _height(inst))
	assert_float(top).is_greater(6.0)


func test_mouth_pose_opens_jaw() -> void:
	var m: Node3D = SimhikaModel.build()
	auto_free(m)
	var jaw: Node3D = m.find_child("Jaw", true, false) as Node3D
	SimhikaModel.set_pose(m, &"idle")
	var closed: float = jaw.rotation.x
	SimhikaModel.set_pose(m, &"mouth_open")
	assert_float(absf(jaw.rotation.x - closed)).is_greater(0.4)


func test_eyes_use_sindoor() -> void:
	var m: Node3D = SimhikaModel.build()
	auto_free(m)
	var eye: MeshInstance3D = m.find_child("EyeL", true, false) as MeshInstance3D
	var arrays: Array = eye.mesh.surface_get_arrays(0)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	assert_bool(cols[0].is_equal_approx(Palette.SINDOOR)).is_true()


func _height(n: Node3D) -> float:
	var y: float = 0.0
	var cur: Node3D = n
	while cur != null:
		y += cur.position.y
		cur = cur.get_parent() as Node3D
	return y
