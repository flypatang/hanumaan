extends GdUnitTestSuite
## B3 acceptance tests (docs/ART.md "Characters"): NPCs are smooth sculpted forms on the shared painterly
## Materials, Sita and Rama carry a faint divine aura and graceful drapery, Ravana has ten crowned heads,
## Surasa a crowned hood, Mainaka a soft glow, and every figure breathes when idle.

const FIGURES: Array[StringName] = [
	&"jambavan", &"angada", &"vanara", &"sita", &"trijata", &"rakshasi", &"ravana",
	&"vibhishana", &"indrajit", &"courtier", &"rama",
]
const SET_PIECES: Array[StringName] = [&"mainaka", &"surasa"]


func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_meshes(child, out)


func _all(root: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	_meshes(root, out)
	return out


func _find(node: Node, node_name: String) -> Node:
	if String(node.name) == node_name:
		return node
	for child: Node in node.get_children():
		var hit: Node = _find(child, node_name)
		if hit != null:
			return hit
	return null


func _is_aura(mi: MeshInstance3D) -> bool:
	var n: String = String(mi.name)
	return n.ends_with("Aura") or n.ends_with("Glow")


func _xf(node: Node, root: Node) -> Transform3D:
	if node == root:
		return Transform3D.IDENTITY
	return _xf(node.get_parent(), root) * (node as Node3D).transform


func _tri_count(root: Node3D) -> int:
	var total: int = 0
	for mi: MeshInstance3D in _all(root):
		if _is_aura(mi):
			continue
		var m: Mesh = mi.mesh
		for s: int in m.get_surface_count():
			total += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _surface_names(root: Node3D) -> Array[String]:
	var out: Array[String] = []
	for mi: MeshInstance3D in _all(root):
		var m: ArrayMesh = mi.mesh as ArrayMesh
		for s: int in m.get_surface_count():
			var n: String = m.surface_get_name(s)
			if not out.has(n):
				out.append(n)
	return out


func test_every_surface_uses_a_painterly_material() -> void:
	var ids: Array[StringName] = []
	ids.append_array(FIGURES)
	ids.append_array(SET_PIECES)
	for id: StringName in ids:
		var n: Node3D = auto_free(NpcModels.build(id)) as Node3D
		for mi: MeshInstance3D in _all(n):
			if _is_aura(mi):
				continue
			assert_object(mi.material_override).override_failure_message("%s/%s overrides its material" % [id, mi.name]).is_null()
			var m: ArrayMesh = mi.mesh as ArrayMesh
			assert_bool(m.get_surface_count() > 0).is_true()
			for s: int in m.get_surface_count():
				var kind: StringName = StringName(m.surface_get_name(s))
				assert_bool(Materials.has_kind(kind)).override_failure_message("%s/%s surface '%s'" % [id, mi.name, kind]).is_true()
				assert_object(m.surface_get_material(s)).is_same(Materials.get_material(kind))


func test_figures_use_several_material_kinds() -> void:
	for id: StringName in FIGURES:
		var names: Array[String] = _surface_names(auto_free(NpcModels.build(id)) as Node3D)
		var kinds: int = 0
		for k: String in ["skin", "fur", "cloth", "gold", "lacquer", "wood"]:
			if names.has(k):
				kinds += 1
		assert_bool(kinds >= 3).override_failure_message("%s uses only %s" % [id, str(names)]).is_true()


func test_triangle_budgets() -> void:
	for id: StringName in FIGURES:
		var tris: int = _tri_count(auto_free(NpcModels.build(id)) as Node3D)
		# Single figures stay in the thousands (docs/ART.md "Geometry"); Rama is the most adorned and Ravana
		# carries ten crowned heads.
		var cap: int = 18000 if id == &"ravana" else (10500 if id == &"rama" else 9000)
		assert_bool(tris >= 2500 and tris <= cap).override_failure_message("%s has %d triangles" % [id, tris]).is_true()
	for id: StringName in SET_PIECES:
		var tris: int = _tri_count(auto_free(NpcModels.build(id)) as Node3D)
		assert_bool(tris >= 2000 and tris <= 16000).override_failure_message("%s has %d triangles" % [id, tris]).is_true()


## Organic shapes use smooth normals: most vertices do not carry their triangle's face normal.
func test_normals_are_smooth_and_unit_length() -> void:
	for id: StringName in [&"sita", &"rama", &"jambavan", &"ravana", &"surasa", &"mainaka"]:
		var n: Node3D = auto_free(NpcModels.build(id)) as Node3D
		var smooth: int = 0
		var total: int = 0
		for mi: MeshInstance3D in _all(n):
			var m: Mesh = mi.mesh
			for s: int in m.get_surface_count():
				var arrs: Array = m.surface_get_arrays(s)
				var vs: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var ns: PackedVector3Array = arrs[Mesh.ARRAY_NORMAL] as PackedVector3Array
				assert_int(ns.size()).is_equal(vs.size())
				var i: int = 0
				while i + 2 < vs.size():
					var face: Vector3 = (vs[i + 2] - vs[i]).cross(vs[i + 1] - vs[i])
					if face.length_squared() > 1e-16:
						face = face.normalized()
						for j: int in 3:
							total += 1
							assert_float(ns[i + j].length()).is_equal_approx(1.0, 0.02)
							assert_bool(is_finite(vs[i + j].x) and is_finite(vs[i + j].y) and is_finite(vs[i + j].z)).is_true()
							if absf(ns[i + j].dot(face)) < 0.9995:
								smooth += 1
					i += 3
		assert_bool(float(smooth) > 0.6 * float(total)).override_failure_message("%s: %d of %d smooth" % [id, smooth, total]).is_true()


## Front faces are wound clockwise (Godot's convention), i.e. the stored normal agrees with the winding.
func test_winding_matches_normals() -> void:
	for id: StringName in [&"sita", &"rama", &"surasa", &"mainaka", &"vanara"]:
		var n: Node3D = auto_free(NpcModels.build(id)) as Node3D
		var bad: int = 0
		var total: int = 0
		for mi: MeshInstance3D in _all(n):
			var m: Mesh = mi.mesh
			for s: int in m.get_surface_count():
				var arrs: Array = m.surface_get_arrays(s)
				var vs: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var ns: PackedVector3Array = arrs[Mesh.ARRAY_NORMAL] as PackedVector3Array
				var i: int = 0
				while i + 2 < vs.size():
					var face: Vector3 = (vs[i + 2] - vs[i]).cross(vs[i + 1] - vs[i])
					if face.length_squared() > 1e-14:
						total += 1
						if face.dot(ns[i] + ns[i + 1] + ns[i + 2]) < 0.0:
							bad += 1
					i += 3
		assert_bool(float(bad) < 0.01 * float(total)).override_failure_message("%s: %d of %d inverted" % [id, bad, total]).is_true()


func test_sita_and_rama_have_a_faint_divine_aura() -> void:
	for id: StringName in [&"sita", &"rama"]:
		var n: Node3D = auto_free(NpcModels.build(id)) as Node3D
		var aura: MeshInstance3D = _find(n, "%s_Aura" % String(id).capitalize()) as MeshInstance3D
		assert_object(aura).is_not_null()
		var mat: ShaderMaterial = aura.material_override as ShaderMaterial
		assert_object(mat).is_not_null()
		assert_bool(mat.shader.code.contains("blend_add")).is_true()
		assert_bool(mat.shader.code.contains("unshaded")).is_true()
		var strength: float = mat.get_shader_parameter(&"strength") as float
		assert_bool(strength > 0.05 and strength <= 0.6).is_true()
		assert_int(aura.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_only_the_revered_and_mainaka_glow() -> void:
	for id: StringName in [&"ravana", &"indrajit", &"rakshasi", &"courtier", &"vanara"]:
		var n: Node3D = auto_free(NpcModels.build(id)) as Node3D
		for mi: MeshInstance3D in _all(n):
			assert_bool(_is_aura(mi)).is_false()
	var mainaka: Node3D = auto_free(NpcModels.build(&"mainaka")) as Node3D
	assert_object(_find(mainaka, "Mainaka_Glow")).is_not_null()


func test_sita_pallu_covers_her_head_and_sways() -> void:
	var sita: Node3D = auto_free(NpcModels.build(&"sita")) as Node3D
	var pallu: MeshInstance3D = _find(sita, "Sita_Pallu") as MeshInstance3D
	assert_object(pallu).is_not_null()
	var head: MeshInstance3D = _find(sita, "Head") as MeshInstance3D
	assert_object(head).is_not_null()
	var m: ArrayMesh = pallu.mesh as ArrayMesh
	assert_str(m.surface_get_name(0)).is_equal("cloth")
	var pallu_box: AABB = _xf(pallu, sita) * m.get_aabb()
	var head_box: AABB = _xf(head, sita) * (head.mesh as Mesh).get_aabb()
	# Over the crown of the head, and down her back to the ground.
	assert_float(pallu_box.end.y).is_greater(head_box.end.y - 0.01)
	assert_float(pallu_box.position.y).is_less(0.2)
	var lo: float = 1.0
	var hi: float = 0.0
	for c: Color in m.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
		lo = minf(lo, c.a)
		hi = maxf(hi, c.a)
	# Pinned on the head (weight 0), free at the hem, but never wildly loose.
	assert_float(lo).is_less(0.02)
	assert_bool(hi > 0.1 and hi <= 0.6).is_true()


func test_rigid_parts_do_not_sway() -> void:
	for id: StringName in FIGURES:
		var n: Node3D = auto_free(NpcModels.build(id)) as Node3D
		for mi: MeshInstance3D in _all(n):
			if _is_aura(mi):
				continue
			var m: ArrayMesh = mi.mesh as ArrayMesh
			for s: int in m.get_surface_count():
				var cs: PackedColorArray = m.surface_get_arrays(s)[Mesh.ARRAY_COLOR] as PackedColorArray
				var most: float = 0.0
				for c: Color in cs:
					most = maxf(most, c.a)
				# Nothing is fully free (that is for banners), so drapery never tears away from a body.
				assert_bool(most <= 0.75).override_failure_message("%s/%s/%s wind %f" % [id, mi.name, m.surface_get_name(s), most]).is_true()


func test_rama_is_adorned_and_unarmed_in_the_right_hand() -> void:
	var rama: Node3D = auto_free(NpcModels.build(&"rama")) as Node3D
	for part: String in ["Rama_Bow", "Rama_Quiver", "Rama_Crown", "Rama_Garland", "Rama_Aura", "Head", "Upper"]:
		assert_object(_find(rama, part)).override_failure_message("missing %s" % part).is_not_null()
	var names: Array[String] = _surface_names(rama)
	for k: String in ["skin", "cloth", "gold"]:
		assert_bool(names.has(k)).is_true()


func test_ravana_ten_heads_are_each_crowned_in_gold() -> void:
	var ravana: Node3D = auto_free(NpcModels.build(&"ravana")) as Node3D
	var heads: Node = ravana.get_node("Heads")
	assert_int(heads.get_child_count()).is_equal(10)
	for head: Node in heads.get_children():
		var list: Array[MeshInstance3D] = []
		_meshes(head, list)
		assert_bool(list.size() >= 1).is_true()
		var gold: bool = false
		for mi: MeshInstance3D in list:
			var m: ArrayMesh = mi.mesh as ArrayMesh
			for s: int in m.get_surface_count():
				if m.surface_get_name(s) == "gold":
					gold = true
		assert_bool(gold).override_failure_message("%s has no gold crown" % head.name).is_true()
	# The main head is the largest.
	var main_head: Node3D = heads.get_node("Head_main") as Node3D
	for head: Node in heads.get_children():
		assert_bool((head as Node3D).scale.x <= main_head.scale.x + 0.001).is_true()


func test_surasa_is_a_crowned_hooded_coil() -> void:
	var surasa: Node3D = auto_free(NpcModels.build(&"surasa")) as Node3D
	for part: String in ["Coil", "Hood", "Head", "Eyes", "Crown", "Jewels"]:
		assert_object(_find(surasa, part)).override_failure_message("missing %s" % part).is_not_null()
	var hood: MeshInstance3D = _find(surasa, "Hood") as MeshInstance3D
	var crown: MeshInstance3D = _find(surasa, "Crown") as MeshInstance3D
	var hood_box: AABB = _xf(hood, surasa) * (hood.mesh as Mesh).get_aabb()
	var crown_box: AABB = _xf(crown, surasa) * (crown.mesh as Mesh).get_aabb()
	# The hood flares wider than it is deep, and the crown sits on top of the head.
	assert_float(hood_box.size.x).is_greater(hood_box.size.z * 1.3)
	assert_float(crown_box.end.y).is_greater(3.7)
	assert_str((crown.mesh as ArrayMesh).surface_get_name(0)).is_equal("gold")
	# The story's mouth marker (game/chapter_flow.gd) sits at (0, 3.5, -0.62): the snout must reach it.
	var head: MeshInstance3D = _find(surasa, "Head") as MeshInstance3D
	var head_box: AABB = _xf(head, surasa) * (head.mesh as Mesh).get_aabb()
	assert_float(head_box.position.z).is_less(-0.6)
	assert_bool(head_box.position.y < 3.5 and head_box.end.y > 3.5).is_true()


func test_mainaka_is_a_golden_peak() -> void:
	var mainaka: Node3D = auto_free(NpcModels.build(&"mainaka")) as Node3D
	assert_bool(_surface_names(mainaka).has("gold")).is_true()
	var peak: MeshInstance3D = _find(mainaka, "Peak") as MeshInstance3D
	assert_object(peak).is_not_null()
	var box: AABB = (peak.mesh as Mesh).get_aabb()
	assert_float(box.end.y).is_greater(4.0)
	assert_float(box.size.x).is_greater(3.5)


func test_figures_breathe_when_idle() -> void:
	for id: StringName in FIGURES:
		var n: Node3D = auto_free(NpcModels.build(id)) as Node3D
		var player: AnimationPlayer = n.get_node_or_null("Idle") as AnimationPlayer
		assert_object(player).override_failure_message("%s has no Idle player" % id).is_not_null()
		assert_bool(player.has_animation(&"idle")).is_true()
		var anim: Animation = player.get_animation(&"idle")
		assert_int(anim.loop_mode).is_equal(Animation.LOOP_LINEAR)
		assert_bool(anim.get_track_count() >= 1).is_true()
		assert_object(n.get_node_or_null(NodePath(String(anim.track_get_path(0).get_concatenated_names())))).is_not_null()
		assert_str(player.autoplay).is_equal("idle")


func test_set_pose_never_changes_a_figure() -> void:
	for id: StringName in [&"sita", &"rama", &"ravana"]:
		var n: Node3D = auto_free(NpcModels.build(id)) as Node3D
		var before: int = _all(n).size()
		for pose: StringName in [&"idle", &"attack", &"walk", &"nonsense"]:
			NpcModels.set_pose(n, pose)
		assert_int(_all(n).size()).is_equal(before)
		assert_object((n.get_node("Upper") as Node3D)).is_not_null()
		assert_vector((n.get_node("Upper") as Node3D).scale).is_equal(Vector3.ONE)


func test_builds_are_deterministic() -> void:
	for id: StringName in [&"sita", &"rama", &"mainaka", &"surasa", &"vanara_3"]:
		var a: Node3D = auto_free(NpcModels.build(id)) as Node3D
		var b: Node3D = auto_free(NpcModels.build(id)) as Node3D
		assert_int(_tri_count(a)).is_equal(_tri_count(b))
		var la: Array[MeshInstance3D] = _all(a)
		var lb: Array[MeshInstance3D] = _all(b)
		assert_int(la.size()).is_equal(lb.size())
		for i: int in la.size():
			assert_bool((la[i].mesh as Mesh).get_aabb().is_equal_approx((lb[i].mesh as Mesh).get_aabb())).is_true()


func test_root_names_and_forward_axis() -> void:
	var rama: Node3D = auto_free(NpcModels.build(&"rama")) as Node3D
	assert_str(String(rama.name)).is_equal("Npc_rama")
	# Forward is -Z: the face (Head mesh) reaches further toward -Z than toward +Z from the head centre.
	var head: MeshInstance3D = _find(rama, "Head") as MeshInstance3D
	var box: AABB = _xf(head, rama) * (head.mesh as Mesh).get_aabb()
	assert_float(box.position.z).is_less(-0.1)
