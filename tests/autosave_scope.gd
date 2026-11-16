extends SceneTree

const FIXTURE := "user://autosave_scope_fixture.cfg"
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_check")

func run_check() -> void:
	if FileAccess.file_exists(FIXTURE):
		DirAccess.remove_absolute(FIXTURE)
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = FIXTURE
	root.add_child(scene)
	scene.player.set_physics_process(false)
	var timer: Timer = scene.get_node("AutoSaveTimer")
	check(is_equal_approx(timer.wait_time, 60.0), "正式間隔維持 60 秒")
	# Accelerate the real timer in this fixture only.
	timer.start(0.05)
	scene.storage.selected = 1
	await create_timer(0.15).timeout
	var data := ConfigFile.new()
	check(data.load(FIXTURE) == OK and data.get_value("storage", "contents").selected == 1, "土地定時自動存檔")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.travel()
	check(scene.on_island, "進入外島")
	scene.storage.selected = 2
	var previous := FileAccess.get_file_as_string(FIXTURE)
	await create_timer(0.2).timeout
	check(FileAccess.get_file_as_string(FIXTURE) == previous, "外島計時不寫入存檔")
	scene.travel()
	check(not scene.on_island, "返回本土")
	await create_timer(0.15).timeout
	data.load(FIXTURE)
	check(data.get_value("storage", "contents").selected == 2, "返回後恢復自動存檔")
	scene.travel()
	scene.storage.selected = 3
	check(scene.save_game() == OK, "外島仍允許明確存檔供正常關閉流程使用")
	data.load(FIXTURE)
	check(data.get_value("storage", "contents").selected == 3, "明確存檔保留外島進度")
	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute(FIXTURE)
	print("PASS: home autosave, island skip, return resume, explicit save" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
