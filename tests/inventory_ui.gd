extends SceneTree

const MATERIAL = preload("res://items/testing/test_material.tres")
const TOOL = preload("res://items/testing/test_tool.tres")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = "user://inventory_ui_fixture.cfg"
	root.add_child(scene)
	var panel = scene.get_node("InventoryPanel")
	check(not panel.is_open and panel.slot_labels.size() == 27, "初始關閉，27 格")
	panel.bind_inventory(scene.inventory, [MATERIAL, TOOL])
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	check(panel.is_open and panel.overlay.visible, "E 開啟")
	check(not scene.player.controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "開啟停用控制並顯示游標")
	var yaw: float = scene.player.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 100)
	scene.player._unhandled_input(motion)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	scene.player._unhandled_input(click)
	check(is_equal_approx(scene.player.yaw, yaw) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "背包不轉向、不因左鍵捕捉")
	scene.inventory.add_item(MATERIAL, 101)
	scene.inventory.add_item(TOOL, 2)
	check(panel.slot_labels[0].text.contains("99") and panel.slot_labels[1].text.contains("2"), "資料改動自動更新數量")
	check(panel.slot_labels[2].text.contains("測試工具") and panel.summary.text == "4 / 27 格", "名稱與占用格數")
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.godot/inventory_ui.png") == OK, "介面截圖")
	var repeat_key := key.duplicate() as InputEventKey
	repeat_key.echo = true
	panel._input(repeat_key)
	check(panel.is_open, "忽略按鍵重複")
	panel._input(key.duplicate())
	check(not panel.is_open and scene.player.controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "E 關閉恢復控制")
	panel.set_open(true)
	panel._click_slot(false, 0)
	var before: Dictionary = scene.storage.snapshot()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	check(not panel.is_open and panel.held_inventory == null, "Esc 關閉並取消拿取")
	check(scene.storage.snapshot() == before, "Esc 取消不遺失物品")
	check(scene.player.controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Esc 關閉不再被角色處理為釋放游標")
	Input.parse_input_event(escape.duplicate())
	Input.flush_buffered_events()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "背包已關閉時 Esc 仍釋放游標")
	for label in panel.slot_labels:
		var cell_size: Vector2 = label.get_parent().size
		check(is_equal_approx(cell_size.x, cell_size.y), "背包格子為正方形")
	scene.queue_free()
	await process_frame
	print("PASS: inventory UI toggle, input isolation, live data, layout capture" if failures == 0 else "FAIL: %d" % failures)
	quit(0 if failures == 0 else 1)
