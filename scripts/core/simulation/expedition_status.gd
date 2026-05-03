class_name ExpeditionStatus
extends RefCounted

enum Kind {
	NONE,
	AWAY,
	RETURNED,
	INTERRUPTED,
}

static func display_name(kind: int) -> String:
	match kind:
		Kind.NONE:
			return "Idle"
		Kind.AWAY:
			return "Away"
		Kind.RETURNED:
			return "Returned"
		Kind.INTERRUPTED:
			return "Interrupted"
		_:
			return "?"
