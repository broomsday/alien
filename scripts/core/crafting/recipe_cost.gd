class_name RecipeCost
extends RefCounted

var item_id: int
var amount: int

func _init(p_item_id: int, p_amount: int) -> void:
	assert(p_amount > 0, "amount must be positive")
	item_id = p_item_id
	amount = p_amount
