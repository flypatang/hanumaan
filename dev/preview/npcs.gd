extends SceneTree
## Dev-only: renders every NpcModels id in a row (plus Simhika and the chariot). Usage: godot --path . -s dev/preview/npcs.gd -- out.png

func _initialize() -> void:
	var root3d: Node3D = Node3D.new()
	get_root().add_child(root3d)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Palette.SKY_DUSK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.8)
	e.ambient_light_energy = 0.6
	env.environment = e
	root3d.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 150, 0)
	root3d.add_child(sun)
	var ids: Array[StringName] = [&"rama", &"sita", &"jambavan", &"angada", &"vanara", &"ravana", &"vibhishana", &"indrajit", &"trijata", &"rakshasi", &"courtier"]
	if OS.get_cmdline_user_args().size() > 1:
		ids = [&"rama", &"sita", &"jambavan"]
	var x: float = 0.0
	for id: StringName in ids:
		var n: Node3D = NpcModels.build(id)
		n.position = Vector3(x, 0, 0)
		n.rotation_degrees.y = 200.0
		root3d.add_child(n)
		x += 2.4
	var big: Array[StringName] = [&"mainaka", &"surasa"]
	for i: int in big.size():
		var b: Node3D = NpcModels.build(big[i])
		b.position = Vector3(4.0 + i * 12.0, 0, -14)
		root3d.add_child(b)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var close: bool = OS.get_cmdline_user_args().size() > 1
	cam.size = 5.0 if close else 30.0
	cam.rotation_degrees = Vector3(-20, 0, 0)
	cam.position = Vector3(2.4, 2.5, 30) if close else Vector3(12, 6, 30)
	root3d.add_child(cam)
	cam.make_current()
	if close:
		cam.look_at_from_position(Vector3(2.4, 2.0, 30), Vector3(2.4, 0.9, 0))
	for i: int in 8:
		await process_frame
	get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
