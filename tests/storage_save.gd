extends SceneTree

const MAIN = preload("res://scenes/main.tscn")
const PATH := "user://storage_save_test.cfg"
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func new_scene():
	var scene = MAIN.instantiate()
	scene.save_path = PATH
	root.add_child(scene)
	scene.player.set_physics_process(false)
	return scene

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--verify-close" in OS.get_cmdline_user_args():
		var restored = new_scene()
		check(restored.storage.selected == 6, "正常關閉後選取格恢復")
		check(restored.inventory.count_item(&"test_material") == 99, "正常關閉後背包恢復")
		check(restored.get_node_or_null("TestPickups/TestMaterial") == null, "已拾物件不重生")
		check(restored.get_node("TestPickups/TestTool").quantity == 1, "未拾完物件餘量")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		print("PASS: storage normal close and reopen" if failures == 0 else "FAIL")
		quit(0 if failures == 0 else 1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var scene = new_scene()
	check(scene.get_node("TestPickups/TestMaterial").collect(scene.storage) == 120, "測試拾取")
	scene.storage.hotbar.move_to(0, scene.inventory, 10)
	var tool = scene.get_node("TestPickups/TestTool")
	tool.quantity = 1
	check(tool.collect(scene.storage) == 1, "拾取工具")
	# Leave one tool in the world to verify partial persistence.
	await process_frame
	var pickup = load("res://scenes/items/pickup.tscn").instantiate()
	pickup.name = "TestTool"
	pickup.item = scene.ITEMS[1]
	pickup.quantity = 1
	scene.get_node("TestPickups").add_child(pickup)
	scene.storage.selected = 8
	check(scene.save_game() == OK, "新版存檔")
	var restored = new_scene()
	check(restored.storage.selected == 8, "選取格恢復")
	check(restored.inventory.get_slots()[10].quantity == 99, "保留背包格位")
	check(restored.storage.hotbar.count_item(&"test_material") == 21, "保留工具欄材料")
	check(restored.storage.hotbar.count_item(&"test_tool") == 1, "工具恢復")
	check(restored.get_node_or_null("TestPickups/TestMaterial") == null, "全收不重生")
	check(restored.get_node("TestPickups/TestTool").quantity == 1, "餘量恢復")
	scene.queue_free()
	restored.storage.selected = 4
	print("等待 60 秒物品自動存檔…")
	await create_timer(61).timeout
	var persisted := ConfigFile.new()
	check(persisted.load(PATH) == OK, "自動存檔可讀")
	check(persisted.get_value("storage", "contents").selected == 4, "實際計時器保存選取狀態")
	var valid_text := persisted.encode_to_text()
	var invalid: Dictionary = persisted.get_value("storage", "contents")
	invalid.backpack[10].quantity = 100
	persisted.set_value("storage", "contents", invalid)
	persisted.save(PATH)
	var before: Dictionary = restored.storage.snapshot()
	restored.load_game()
	check(restored.load_failed and restored.storage.snapshot() == before, "超量存檔拒絕且不部分套用")
	var corrupt_text := FileAccess.get_file_as_string(PATH)
	check(restored.save_game() != OK and FileAccess.get_file_as_string(PATH) == corrupt_text, "拒絕覆蓋無效原檔")
	var valid := ConfigFile.new()
	valid.parse(valid_text)
	valid.save(PATH)
	restored.load_game()
	check(not restored.load_failed, "修復後可重新讀取")
	var old := ConfigFile.new()
	old.set_value("save", "version", 1)
	old.set_value("player", "position", Vector3(3, 0, 4))
	old.save("user://legacy_storage_test.cfg")
	var legacy = MAIN.instantiate()
	legacy.save_path = "user://legacy_storage_test.cfg"
	root.add_child(legacy)
	check(legacy.player.position.is_equal_approx(Vector3(3, 0, 4)) and not legacy.load_failed, "舊版位置存檔相容")
	legacy.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://legacy_storage_test.cfg"))
	print("PASS: storage round trip, pickup persistence, autosave, invalid data, legacy" if failures == 0 else "FAIL: %d" % failures)
	if failures != 0:
		quit(1)
		return
	restored.storage.selected = 6
	restored.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
