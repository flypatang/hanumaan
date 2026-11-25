extends SceneTree
## Dev-only: builds a level with LevelBuilder and renders a top iso view. Usage: godot --path . -s dev/preview/level.gd -- <level_id> <out.png>

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var lid: String = args[0] if args.size() > 0 else "mahendra"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/%s.json" % lid)) as Dictionary
	var root3d: Node3D = Node3D.new()
	get_root().add_child(root3d)
	var level: Node3D = LevelBuilder.build(data)
	root3d.add_child(level)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Palette.SKY_DUSK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.8)
	e.ambient_light_energy = 0.5
	env.environment = e
	root3d.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	root3d.add_child(sun)
	var tiles: Array = data["tiles"] as Array
	var w: float = 0.0
	var h: float = 0.0
	for t: Variant in tiles:
		w = maxf(w, ((t as Dictionary)["x"] as float) * 2.0 + 2.0)
		h = maxf(h, ((t as Dictionary)["z"] as float) * 2.0 + 2.0)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(w, h) * 1.15
	cam.rotation_degrees = Vector3(-35.264, 45, 0)
	var centre: Vector3 = Vector3(w * 0.5, 0, h * 0.5)
	cam.position = centre + cam.basis.z * 200.0
	cam.far = 1000.0
	root3d.add_child(cam)
	cam.make_current()
	for i: int in 10:
		await process_frame
	get_root().get_texture().get_image().save_png(args[1] if args.size() > 1 else "/tmp/level.png")
	quit()
