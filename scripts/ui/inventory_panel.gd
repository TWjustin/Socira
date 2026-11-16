extends CanvasLayer

signal open_changed(is_open: bool)

const Inventory = preload("res://scripts/inventory/inventory.gd")
const PlayerStorage = preload("res://scripts/inventory/player_storage.gd")
const Crafting = preload("res://scripts/inventory/crafting.gd")
var storage := PlayerStorage.new()
var hotbar_labels: Array[Label] = []
var hotbar_buttons: Array[Button] = []
var held_inventory: Inventory
var held_index := -1
var carried: Label
var hotbar_row: HBoxContainer
var inventory: Inventory
var item_names: Dictionary = {}
var is_open := false
var slot_labels: Array[Label] = []
@onready var overlay: ColorRect = $Overlay
@onready var grid: GridContainer = $Overlay/Center/Panel/Margin/Content/Grid
@onready var summary: Label = $Overlay/Center/Panel/Margin/Content/Summary
@onready var content: VBoxContainer = $Overlay/Center/Panel/Margin/Content
@onready var craft_panel: VBoxContainer = $Overlay/Center/Panel/Margin/Content/Crafting
@onready var craft_button: Button = $Overlay/Center/Panel/Margin/Content/Crafting/Make

func _ready() -> void:
	content.get_node("Tabs/Bag").pressed.connect(show_crafting.bind(false))
	content.get_node("Tabs/Craft").pressed.connect(show_crafting.bind(true))
	craft_button.pressed.connect(_craft_one)
	for index in range(Inventory.CAPACITY):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(64, 64)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("23313d")
		style.content_margin_left = 4
		style.content_margin_right = 4
		panel.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.custom_minimum_size = Vector2(56, 56)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(label)
		var button := Button.new()
		button.flat = true
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.pressed.connect(_click_slot.bind(false, index))
		panel.add_child(button)
		grid.add_child(panel)
		slot_labels.append(label)
	var anchor := CenterContainer.new()
	anchor.anchor_top = 1.0
	anchor.anchor_bottom = 1.0
	anchor.anchor_right = 1.0
	anchor.offset_top = -78
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	hotbar_row = HBoxContainer.new()
	hotbar_row.add_theme_constant_override("separation", 6)
	anchor.add_child(hotbar_row)
	for index in range(9):
		var button := Button.new()
		button.custom_minimum_size = Vector2(64, 64)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_click_slot.bind(true, index))
		var label := Label.new()
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		hotbar_row.add_child(button)
		hotbar_buttons.append(button)
		hotbar_labels.append(label)
	carried = Label.new()
	carried.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carried.z_index = 100
	add_child(carried)
	storage.hotbar.changed.connect(refresh)
	refresh()

func bind_inventory(value: Inventory, definitions: Array = []) -> void:
	if inventory != null and inventory.changed.is_connected(refresh):
		inventory.changed.disconnect(refresh)
	inventory = value
	storage.backpack = value
	if not storage.hotbar.changed.is_connected(refresh):
		storage.hotbar.changed.connect(refresh)
	item_names.clear()
	for definition in definitions:
		item_names[definition.item_id] = definition.display_name
	inventory.changed.connect(refresh)
	if is_node_ready():
		refresh()

func refresh() -> void:
	if inventory == null:
		return
	var slots := inventory.get_slots()
	var occupied := 0
	for index in range(slot_labels.size()):
		var slot := slots[index]
		if slot.is_empty():
			slot_labels[index].text = "—"
			slot_labels[index].modulate = Color(0.6, 0.65, 0.7)
		else:
			occupied += 1
			var id: StringName = slot["item_id"]
			slot_labels[index].text = "%s\n× %d" % [_slot_name(id), slot["quantity"]]
			slot_labels[index].modulate = Color.WHITE
	summary.text = "%d / 27 格" % occupied
	var bar := storage.hotbar.get_slots()
	for index in range(9):
		var slot := bar[index]
		hotbar_labels[index].text = "—" if slot.is_empty() else "%s\n× %d" % [_slot_name(slot.item_id), slot.quantity]
		var style := StyleBoxFlat.new()
		style.bg_color = Color("344b5b") if index == storage.selected else Color("1b2832")
		style.set_border_width_all(2 if index == storage.selected else 0)
		style.border_color = Color("e9b76b")
		hotbar_buttons[index].add_theme_stylebox_override("normal", style)
	carried.text = ""
	if held_inventory != null:
		var held := held_inventory.get_slots()[held_index]
		if not held.is_empty():
			carried.text = "%s × %d" % [item_names.get(held.item_id, str(held.item_id)), held.quantity]
			if held_inventory == inventory:
				slot_labels[held_index].modulate.a = 0.25
			else:
				hotbar_labels[held_index].modulate.a = 0.25
	_refresh_crafting()

func _slot_name(id: StringName) -> String:
	# Development labels need not enlarge the compact item cells.
	return str(item_names.get(id, str(id))).trim_suffix("（開發用）")

func show_crafting(value: bool) -> void:
	grid.visible = not value
	summary.visible = not value
	craft_panel.visible = value
	content.get_node("Title").text = "隨身合成" if value else "背包"
	_refresh_crafting()

func _refresh_crafting() -> void:
	if storage == null or not is_node_ready():
		return
	var result := Crafting.plan(storage)
	craft_panel.get_node("Available").text = "持有材料：%d　｜　目前可合成：%d 個" % [Crafting.material_count(storage), Crafting.craftable_count(storage)]
	craft_button.disabled = not result.ok or held_inventory != null
	craft_panel.get_node("Message").text = "請先回背包放下手上物品" if held_inventory != null else result.reason

func _craft_one() -> void:
	if not is_open or held_inventory != null:
		return
	var result := Crafting.craft(storage)
	refresh()
	craft_panel.get_node("Message").text = "已合成 1 個測試工具" if result.ok else result.reason

func _process(_delta: float) -> void:
	if carried != null:
		carried.position = get_viewport().get_mouse_position() + Vector2(16, 16)

func _click_slot(is_hotbar: bool, index: int) -> void:
	if not is_open:
		return
	var target: Inventory = storage.hotbar if is_hotbar else inventory
	if held_inventory == null:
		if not target.get_slots()[index].is_empty():
			held_inventory = target
			held_index = index
	else:
		if held_inventory == target and held_index == index:
			held_inventory = null
		else:
			held_inventory.move_to(held_index, target, index)
			if held_inventory.get_slots()[held_index].is_empty():
				held_inventory = null
		if held_inventory == null:
			held_index = -1
	for label in hotbar_labels:
		label.modulate = Color.WHITE
	refresh()

func _input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not event.echo:
			set_open(false)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and (is_open or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			storage.cycle(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			refresh()
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		set_open(not is_open)
		get_viewport().set_input_as_handled()

func set_open(value: bool) -> void:
	if is_open == value:
		return
	is_open = value
	if not value:
		held_inventory = null
		held_index = -1
		for label in hotbar_labels:
			label.modulate = Color.WHITE
		refresh()
	overlay.visible = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	open_changed.emit(value)
