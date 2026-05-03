class_name RecipeRules
extends RefCounted

static func can_afford(inventory: InventoryState, recipe_id: int) -> bool:
	assert(inventory != null, "inventory required")
	var recipe: RecipeDefinition = RecipeCatalog.get_recipe(recipe_id)
	for cost in recipe.costs:
		if not inventory.has_at_least(cost.item_id, cost.amount):
			return false
	return true

static func can_craft(state: GameState, recipe_id: int) -> bool:
	assert(state != null, "state required")
	if not can_afford(state.inventory, recipe_id):
		return false
	if recipe_id == RecipeId.Id.SIMPLE_WEAPON:
		return state.inventory.get_count(ItemId.Id.SIMPLE_WEAPON) == 0 \
			and state.player.equipped_weapon == EquippedWeapon.Slot.NONE
	return true

static func try_craft(state: GameState, recipe_id: int) -> bool:
	assert(state != null, "state required")
	if not can_craft(state, recipe_id):
		return false
	var recipe: RecipeDefinition = RecipeCatalog.get_recipe(recipe_id)
	for cost in recipe.costs:
		if not state.inventory.try_remove(cost.item_id, cost.amount):
			return false
	if recipe_id == RecipeId.Id.SIMPLE_WEAPON:
		state.inventory.add(ItemId.Id.SIMPLE_WEAPON, 1)
		state.player.equip_weapon(EquippedWeapon.Slot.SIMPLE_WEAPON)
	return true
