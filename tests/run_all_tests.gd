extends SceneTree

const TESTS: Array[Dictionary] = [
	{"name": "Step 1: Regions & Texture Arrays", "path": "res://tests/verify_step1_regions.gd", "gpu": false},
	{"name": "Step 2: Terrain & Walkable Passes", "path": "res://tests/verify_step2_terrain.gd", "gpu": false},
	{"name": "Step 3: Shader & Frame Time", "path": "res://tests/verify_step3_shader.gd", "gpu": true},
	{"name": "Step 4: Object Scattering & Colliders", "path": "res://tests/verify_step4_scattering.gd", "gpu": false},
	{"name": "Step 5: Landmarks & A* Roads", "path": "res://tests/verify_step5_landmarks.gd", "gpu": true},
	{"name": "Step 6a: Navigation, Player & Gameplay Zoom", "path": "res://tests/verify_step6a_navigation.gd", "gpu": true},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var godot_bin := OS.get_executable_path()
	var project_dir := ProjectSettings.globalize_path("res://")
	var use_gpu_for_shader_tests: bool = (DisplayServer.get_name() != "headless")

	print("=== RUN ALL WORLD GENERATOR TESTS ===")
	for t in TESTS:
		var t_name: String = t["name"]
		var t_path: String = t["path"]
		var args: Array[String] = []
		if not (bool(t["gpu"]) and use_gpu_for_shader_tests):
			args.append("--headless")
		args.append("--path")
		args.append(project_dir)
		args.append("--script")
		args.append(t_path)

		var out: Array = []
		var exit_code := OS.execute(godot_bin, PackedStringArray(args), out, true)
		var out_str := "\n".join(out)
		print("[%s] exit=%d\n%s" % [t_name, exit_code, out_str.strip_edges()])
		if exit_code != 0:
			push_error("Test failed: %s (exit=%d)" % [t_name, exit_code])
			quit(exit_code)
			return

	print("ALL_WORLD_GEN_TESTS_PASSED (6/6)")
	quit(0)
