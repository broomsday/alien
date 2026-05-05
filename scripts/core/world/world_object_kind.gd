class_name WorldObjectKind
extends RefCounted

enum Kind {
	FRUIT_BUSH,
}

static func display_name(kind: int) -> String:
	match kind:
		Kind.FRUIT_BUSH:
			return "Fruit Bush"
		_:
			return "Unknown"
