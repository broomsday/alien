class_name RecipeCatalog
extends RefCounted

static var _recipes: Dictionary = {}

static func get_recipe(recipe_id: int) -> RecipeDefinition:
	if _recipes.is_empty():
		_build()
	var recipe: RecipeDefinition = _recipes.get(recipe_id, null)
	assert(recipe != null, "unknown recipe_id %d" % recipe_id)
	return recipe

static func _build() -> void:
	_recipes[RecipeId.Id.SCRAP_METAL_WALL] = RecipeDefinition.new(
		RecipeId.Id.SCRAP_METAL_WALL,
		[RecipeCost.new(ItemId.Id.SCRAP_METAL, 1)] as Array[RecipeCost])
	_recipes[RecipeId.Id.FURNACE] = RecipeDefinition.new(
		RecipeId.Id.FURNACE,
		[
			RecipeCost.new(ItemId.Id.SCRAP_METAL, 4),
			RecipeCost.new(ItemId.Id.FUEL, 1),
		] as Array[RecipeCost])
	_recipes[RecipeId.Id.SIMPLE_WEAPON] = RecipeDefinition.new(
		RecipeId.Id.SIMPLE_WEAPON,
		[RecipeCost.new(ItemId.Id.SCRAP_METAL, 3)] as Array[RecipeCost])
