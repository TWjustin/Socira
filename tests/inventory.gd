extends SceneTree

const Inventory = preload("res://scripts/inventory/inventory.gd")
const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const MATERIAL = preload("res://items/testing/test_material.tres")
const TOOL = preload("res://items/testing/test_tool.tres")
var failures := 0
var notifications := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var bag := Inventory.new()
	bag.changed.connect(func(): notifications += 1)
	check(bag.get_slots().size() == 27, "27 個初始空格")
	check(bag.add_item(MATERIAL, 98) == 0, "材料入包")
	check(bag.add_item(MATERIAL, 3) == 0, "補齊既有堆疊並分格")
	var slots := bag.get_slots()
	check(slots[0]["quantity"] == 99 and slots[1]["quantity"] == 2, "99 + 2 分格")
	check(bag.add_item(TOOL, 2) == 0, "兩件工具入包")
	slots = bag.get_slots()
	check(slots[2]["quantity"] == 1 and slots[3]["quantity"] == 1, "工具各佔一格")
	slots[0]["quantity"] = 0
	check(bag.count_item(MATERIAL.item_id) == 101, "外部快照修改不影響背包")
	var before := bag.get_slots()
	check(bag.add_item(null, 5) == 5, "無效物品保留原數量")
	check(bag.add_item(MATERIAL, 0) == 0 and bag.add_item(MATERIAL, -1) == 0, "非正數不操作")
	var conflict := ItemDefinition.new()
	conflict.item_id = MATERIAL.item_id
	conflict.kind = ItemDefinition.Kind.TOOL
	check(bag.add_item(conflict, 3) == 3, "拒絕同 ID 不同堆疊規則")
	check(bag.get_slots() == before and notifications == 3, "拒絕操作不更動資料或發出變更")
	var full := Inventory.new()
	check(full.add_item(TOOL, 28) == 1 and full.count_item(TOOL.item_id) == 27, "滿包工具留一件於來源")
	check(full.add_item(MATERIAL, 10) == 10, "滿包不同物品全部留於來源")
	var partial := Inventory.new()
	check(partial.add_item(MATERIAL, 98) == 0, "部分堆疊建立")
	check(partial.add_item(TOOL, 26) == 0, "其餘格填滿")
	check(partial.add_item(MATERIAL, 5) == 4, "滿格仍能補齊堆疊，餘量保留")
	check(partial.count_item(MATERIAL.item_id) == 99, "補齊後總數")
	var bulk := Inventory.new()
	check(bulk.add_item(MATERIAL, 3000) == 327, "大量入包超出 27×99 保留餘量")
	check(bulk.count_item(MATERIAL.item_id) == 2673, "大量入包數量守恆")
	check(Inventory.new().count_item(MATERIAL.item_id) == 0, "背包實例互相獨立")
	print("PASS: inventory capacity, stacking, tools, overflow, validation, isolation" if failures == 0 else "FAIL: %d" % failures)
	quit(0 if failures == 0 else 1)
