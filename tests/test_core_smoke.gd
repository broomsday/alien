extends SceneTree

# Enforces the core/client split: every script under res://scripts/core/
# must (a) load cleanly from a bare SceneTree and (b) inherit from
# RefCounted, not Node. If a core file accidentally `extends Node` or
# pulls in a Node-shaped dep that breaks parsing in a no-scene-graph
# context, this test fails.
#
# New core files are picked up automatically by walking the directory.

const CORE_ROOT: String = "res://scripts/core"

func _init() -> void:
	var failures: Array[String] = []
	var visited: int = _visit(CORE_ROOT, failures)
	if failures.size() > 0:
		for msg in failures:
			push_error(msg)
		quit(1)
	else:
		print("test_core_smoke: ok (%d files)" % visited)
		quit(0)

func _visit(path: String, failures: Array[String]) -> int:
	var count: int = 0
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		failures.append("could not open dir: %s" % path)
		return 0
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var sub: String = path.path_join(name)
		if dir.current_is_dir():
			count += _visit(sub, failures)
		elif name.ends_with(".gd"):
			count += 1
			_check_script(sub, failures)
	dir.list_dir_end()
	return count

func _check_script(script_path: String, failures: Array[String]) -> void:
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		failures.append("failed to load: %s" % script_path)
		return
	var base: StringName = script.get_instance_base_type()
	if base == &"Node" or _inherits_from_node(base):
		failures.append("%s extends %s — core scripts must extend RefCounted" % [script_path, base])

func _inherits_from_node(base: StringName) -> bool:
	# get_instance_base_type returns the native base only. RefCounted /
	# Resource / Object / Node are the relevant roots; anything that
	# resolves to Node (or a Node subclass like Node2D) is a violation.
	if base == &"RefCounted" or base == &"Resource" or base == &"Object":
		return false
	if base == &"":
		return false
	# ClassDB tells us if the native class derives from Node.
	return ClassDB.is_parent_class(base, &"Node")
