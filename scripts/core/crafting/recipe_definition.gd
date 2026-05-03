class_name RecipeDefinition
extends RefCounted

var recipe_id: int
var costs: Array[RecipeCost]

func _init(p_recipe_id: int, p_costs: Array[RecipeCost]) -> void:
	assert(p_costs != null, "costs required")
	recipe_id = p_recipe_id
	costs = p_costs
