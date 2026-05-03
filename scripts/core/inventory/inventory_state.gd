class_name InventoryState
extends RefCounted

# Keys are ItemId.Id (int); values are int counts. Empty entries are
# removed on full take so get_count returns 0 cleanly.
var _item_counts: Dictionary = {}

func get_count(item_id: int) -> int:
	return _item_counts.get(item_id, 0)

func has_at_least(item_id: int, amount: int) -> bool:
	assert(amount >= 0, "amount must be non-negative")
	return get_count(item_id) >= amount

func add(item_id: int, amount: int) -> void:
	assert(amount > 0, "add amount must be positive")
	_item_counts[item_id] = get_count(item_id) + amount

func try_remove(item_id: int, amount: int) -> bool:
	assert(amount > 0, "remove amount must be positive")
	var current_count: int = get_count(item_id)
	if current_count < amount:
		return false
	var new_count: int = current_count - amount
	if new_count == 0:
		_item_counts.erase(item_id)
	else:
		_item_counts[item_id] = new_count
	return true
