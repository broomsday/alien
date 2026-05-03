class_name GameSession
extends Node

var state: GameState
var step: SimulationStep

func _init(p_random_seed: int = 0x00C0FFEE) -> void:
	state = GameStateFactory.create_new(p_random_seed)
	step = SimulationStep.new()

func update(delta_seconds: float, commands: Array) -> void:
	step.advance(state, delta_seconds, commands)
