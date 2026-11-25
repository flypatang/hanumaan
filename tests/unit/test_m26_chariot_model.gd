extends GdUnitTestSuite
## M26 acceptance: the chariot model is a gilded two-wheeled car with two horses, all MeshKit geometry.


func test_parts_present() -> void:
	var c: Node3D = auto_free(ChariotModel.build()) as Node3D
	for n: String in ["Car", "Wheel_L", "Wheel_R", "Horse_A", "Horse_B", "Pole"]:
		assert_object(c.get_node_or_null(n)).is_not_null()


func test_meshes_have_geometry_and_flat_material() -> void:
	var c: Node3D = auto_free(ChariotModel.build()) as Node3D
	for child: Node in c.get_children():
		var mi: MeshInstance3D = child as MeshInstance3D
		assert_object(mi).is_not_null()
		assert_int(mi.mesh.get_surface_count()).is_greater(0)
		assert_object(mi.material_override).is_not_null()


func test_wheels_spin() -> void:
	var c: Node3D = auto_free(ChariotModel.build()) as Node3D
	ChariotModel.spin_wheels(c, 0.5)
	assert_float((c.get_node("Wheel_L") as Node3D).rotation.x).is_equal_approx(0.5, 0.001)
