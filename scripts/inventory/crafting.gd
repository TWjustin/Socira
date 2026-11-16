extends RefCounted

const Storage = preload("res://scripts/inventory/player_storage.gd")
const MATERIAL = preload("res://items/testing/test_material.tres")
const TOOL = preload("res://items/testing/test_tool.tres")
const PICKAXE = preload("res://items/testing/test_pickaxe.tres")
const STONE = preload("res://items/testing/test_stone.tres")

static func catalog() -> Dictionary:
	return {MATERIAL.item_id: MATERIAL, TOOL.item_id: TOOL, PICKAXE.item_id: PICKAXE, STONE.item_id: STONE}

static func material_count(storage) -> int:
	return storage.hotbar.count_item(MATERIAL.item_id) + storage.backpack.count_item(MATERIAL.item_id)

# Work on a copy, including the slots freed by ingredient consumption.
static func plan(storage) -> Dictionary:
	if material_count(storage) < 2:
		return {"ok": false, "reason": "測試材料不足（需要 2 個）"}
	var preview := Storage.new()
	if not preview.restore(storage.snapshot(), catalog()):
		return {"ok": false, "reason": "物品資料無效"}
	var remaining := preview.hotbar.remove_item(MATERIAL.item_id, 2)
	preview.backpack.remove_item(MATERIAL.item_id, remaining)
	if preview.add_pickup(TOOL, 1) != 0:
		return {"ok": false, "reason": "空間不足，未扣除材料"}
	return {"ok": true, "contents": preview.snapshot(), "reason": ""}

static func craft(storage) -> Dictionary:
	var result := plan(storage)
	if result.ok:
		storage.restore(result.contents, catalog())
	return result

static func craftable_count(storage) -> int:
	var preview := Storage.new()
	if not preview.restore(storage.snapshot(), catalog()):
		return 0
	var count := 0
	# Each result is an unstackable tool, so at most 36 can fit.
	for index in range(36):
		if not craft(preview).ok:
			break
		count += 1
	return count
