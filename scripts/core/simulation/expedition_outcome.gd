class_name ExpeditionOutcome
extends RefCounted

var scrap_metal: int
var fuel: int
var canned_food: int
var encounter_kind: int

func _init(p_scrap_metal: int, p_fuel: int, p_canned_food: int, p_encounter_kind: int) -> void:
	assert(p_scrap_metal >= 0, "scrap_metal must be non-negative")
	assert(p_fuel >= 0, "fuel must be non-negative")
	assert(p_canned_food >= 0, "canned_food must be non-negative")
	scrap_metal = p_scrap_metal
	fuel = p_fuel
	canned_food = p_canned_food
	encounter_kind = p_encounter_kind

func total_items() -> int:
	return scrap_metal + fuel + canned_food

func apply_to(inventory: InventoryState) -> void:
	assert(inventory != null, "inventory required")
	if scrap_metal > 0:
		inventory.add(ItemId.Id.SCRAP_METAL, scrap_metal)
	if fuel > 0:
		inventory.add(ItemId.Id.FUEL, fuel)
	if canned_food > 0:
		inventory.add(ItemId.Id.CANNED_FOOD, canned_food)
