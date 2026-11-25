extends GdUnitTestSuite
## Acceptance tests for M07 (gen/hanuman_model.gd), DESIGN §9 and §6.2.
## Bone names, height 1.7-1.9 m, palette colours only. Rigid parts only: no vertex skinning.

const REQUIRED_BONES: Array[String] = [
	"root", "hips", "spine", "chest", "head",
	"upper_arm_l", "lower_arm_l", "upper_arm_r", "lower_arm_r",
	"upper_leg_l", "lower_leg_l", "upper_leg_r", "lower_leg_r",
	"tail_0", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_7",
	"gada_socket",
]

const ALL_POSES: Array[StringName] = [&"idle", &"walk_a", &"walk_b", &"attack_wind", &"attack_strike", &"meditate"]


func _model() -> HanumanModel:
	var model: HanumanModel = auto_free(HanumanModel.new()) as HanumanModel
	model.build()
	return model


func _mesh_instances(model: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		result.append(node as MeshInstance3D)
	return result


func _world_bounds(model: HanumanModel) -> AABB:
	## Model-space bounds: each part is placed by its bone's rest pose, then its own transform.
	## This does not depend on the scene tree having updated the BoneAttachment3D nodes.
	var skeleton: Skeleton3D = model.get_skeleton()
	var bounds: AABB = AABB()
	var first: bool = true
	for mesh_instance: MeshInstance3D in _mesh_instances(model):
		var attachment: BoneAttachment3D = mesh_instance.get_parent() as BoneAttachment3D
		var bone: int = skeleton.find_bone(attachment.bone_name)
		var bone_xf: Transform3D = skeleton.get_bone_global_rest(bone)
		var local_box: AABB = (mesh_instance.mesh as ArrayMesh).get_aabb()
		var world_box: AABB = bone_xf * (mesh_instance.transform * local_box)
		if first:
			bounds = world_box
			first = false
		else:
			bounds = bounds.merge(world_box)
	return bounds


func test_build_returns_node3d_with_skeleton() -> void:
	var model: HanumanModel = _model()
	var root: Node3D = model.build()
	assert_object(root).is_not_null()
	assert_object(model.get_skeleton()).is_not_null()


func test_all_required_bones_exist() -> void:
	var model: HanumanModel = _model()
	var skeleton: Skeleton3D = model.get_skeleton()
	for bone_name: String in REQUIRED_BONES:
		assert_int(skeleton.find_bone(bone_name)).is_greater_equal(0)
	assert_int(skeleton.get_bone_count()).is_equal(REQUIRED_BONES.size())


func test_one_bone_attachment_per_bone() -> void:
	var model: HanumanModel = _model()
	var skeleton: Skeleton3D = model.get_skeleton()
	var attachments: int = 0
	for child: Node in skeleton.get_children():
		if child is BoneAttachment3D:
			attachments += 1
	assert_int(attachments).is_equal(skeleton.get_bone_count())


func test_height_is_between_1_7_and_1_9_metres() -> void:
	var model: HanumanModel = _model()
	var bounds: AABB = _world_bounds(model)
	var height: float = bounds.size.y
	assert_bool(height >= 1.7 and height <= 1.9).is_true()


func test_feet_touch_the_ground_at_y_zero() -> void:
	var model: HanumanModel = _model()
	var bounds: AABB = _world_bounds(model)
	assert_float(bounds.position.y).is_equal_approx(0.0, 0.01)


func test_colours_come_only_from_palette() -> void:
	var allowed: Array[Color] = [Palette.HANUMAN_FUR, Palette.SINDOOR, Palette.SAFFRON, Palette.GOLD]
	var model: HanumanModel = _model()
	var checked: int = 0
	for mesh_instance: MeshInstance3D in _mesh_instances(model):
		var arrays: Array = (mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
		for colour: Color in colours:
			var found: bool = false
			for token: Color in allowed:
				if colour.is_equal_approx(token):
					found = true
			assert_bool(found).is_true()
			checked += 1
	assert_int(checked).is_greater(0)


func test_parts_use_the_flat_material() -> void:
	var model: HanumanModel = _model()
	for mesh_instance: MeshInstance3D in _mesh_instances(model):
		assert_object(mesh_instance.material_override).is_same(MeshKit.flat_material())


func test_set_pose_accepts_all_six_poses() -> void:
	var model: HanumanModel = _model()
	for pose: StringName in ALL_POSES:
		model.set_pose(pose)
		assert_str(String(model.current_pose())).is_equal(String(pose))


func test_meditate_pose_moves_the_chest() -> void:
	var model: HanumanModel = _model()
	var skeleton: Skeleton3D = model.get_skeleton()
	var chest: int = skeleton.find_bone("chest")
	model.set_pose(&"idle")
	var idle_rot: Quaternion = skeleton.get_bone_pose_rotation(chest)
	model.set_pose(&"meditate")
	var meditate_rot: Quaternion = skeleton.get_bone_pose_rotation(chest)
	assert_bool(idle_rot.is_equal_approx(meditate_rot)).is_false()


func test_attack_strike_moves_the_right_arm() -> void:
	var model: HanumanModel = _model()
	var skeleton: Skeleton3D = model.get_skeleton()
	var arm: int = skeleton.find_bone("upper_arm_r")
	model.set_pose(&"idle")
	var idle_rot: Quaternion = skeleton.get_bone_pose_rotation(arm)
	model.set_pose(&"attack_strike")
	var strike_rot: Quaternion = skeleton.get_bone_pose_rotation(arm)
	assert_bool(idle_rot.is_equal_approx(strike_rot)).is_false()
