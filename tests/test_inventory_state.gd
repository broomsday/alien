extends SceneTree

const InventoryStateScript = preload("res://scripts/core/inventory/inventory_state.gd")
const ItemIdScript = preload("res://scripts/core/inventory/item_id.gd")

func _init() -> void:
	_test_add_then_remove_updates_counts()
	_test_remove_with_insufficient_count_fails_and_preserves_inventory()
	print("test_inventory_state: ok")
	quit(0)

func _test_add_then_remove_updates_counts() -> void:
	var inventory: InventoryState = InventoryStateScript.new()
	inventory.add(ItemIdScript.Id.SCRAP_METAL, 5)
	var removed: bool = inventory.try_remove(ItemIdScript.Id.SCRAP_METAL, 2)
	assert(removed, "expected try_remove to succeed")
	assert(inventory.get_count(ItemIdScript.Id.SCRAP_METAL) == 3,
		"expected 3 scrap, got %d" % inventory.get_count(ItemIdScript.Id.SCRAP_METAL))

func _test_remove_with_insufficient_count_fails_and_preserves_inventory() -> void:
	var inventory: InventoryState = InventoryStateScript.new()
	inventory.add(ItemIdScript.Id.FUEL, 1)
	var removed: bool = inventory.try_remove(ItemIdScript.Id.FUEL, 2)
	assert(not removed, "expected try_remove to fail")
	assert(inventory.get_count(ItemIdScript.Id.FUEL) == 1,
		"expected 1 fuel, got %d" % inventory.get_count(ItemIdScript.Id.FUEL))
