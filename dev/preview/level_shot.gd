extends SceneTree
## Dev-only: loads a level through LevelRuntime (player, camera, HUD, enemies) and screenshots it.
## Usage: godot --path . -s dev/preview/level_shot.gd -- <level_id> <lang en|hi> <out.png>

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var rt: LevelRuntime = LevelRuntime.new()
	get_root().add_child(rt)
	await process_frame
	(get_root().get_node("/root/Locale") as Node).call("set_language", StringName(args[1] if args.size() > 1 else "en"))
	rt.load_level(StringName(args[0] if args.size() > 0 else "mahendra"))
	for i: int in 45:
		await process_frame
	get_root().get_texture().get_image().save_png(args[2] if args.size() > 2 else "/tmp/level_shot.png")
	quit()
