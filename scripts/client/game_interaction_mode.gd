class_name GameInteractionMode
extends RefCounted

enum Kind { EXCAVATE, BUILD_WALL, BUILD_FURNACE }

static func to_action_kind(mode: int) -> int:
	match mode:
		Kind.EXCAVATE:
			return GameActionKind.Kind.EXCAVATE
		Kind.BUILD_WALL:
			return GameActionKind.Kind.BUILD_WALL
		Kind.BUILD_FURNACE:
			return GameActionKind.Kind.BUILD_FURNACE
		_:
			assert(false, "unknown interaction mode")
			return GameActionKind.Kind.EXCAVATE

static func display_name(mode: int) -> String:
	match mode:
		Kind.EXCAVATE:
			return "Excavate"
		Kind.BUILD_WALL:
			return "Build Wall"
		Kind.BUILD_FURNACE:
			return "Build Furnace"
		_:
			return "?"
