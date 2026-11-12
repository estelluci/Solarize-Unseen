@tool
extends RefCounted
## Makes new level scenes from res://levels/level_template.tscn.
## Edit that template to change what every new level starts with; nodes the
## builder doesn't find (StartGround, RightWall, ...) are simply skipped.

const Pieces := preload("res://addons/rift_level_editor/level_pieces.gd")
const TEMPLATE := "res://levels/level_template.tscn"
const LEVEL_DIR := "res://levels/"
const GAP := 300.0


## File path a level name will be saved to.
static func path_for(level_name: String) -> String:
	return LEVEL_DIR + level_name.strip_edges().to_snake_case().validate_filename() + ".tscn"


## options: name (String), length (float, default 2000), style (Ground.Style),
## gap (bool: split the start ground with a water chasm in the middle).
## Returns {"path": String} or {"error": String}.
static func build(options: Dictionary) -> Dictionary:
	var level_name: String = String(options.get("name", "")).strip_edges()
	if level_name == "":
		return {"error": "Give the level a name."}
	var path := path_for(level_name)
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		return {"error": "%s already exists. Pick another name." % path}
	var template := load(TEMPLATE) as PackedScene
	if template == null:
		return {"error": "Couldn't open the template %s." % TEMPLATE}
	# In the editor, keep instance info so the saved scene stays as clean as a hand-made one.
	var root := template.instantiate(PackedScene.GEN_EDIT_STATE_MAIN if Engine.is_editor_hint() else PackedScene.GEN_EDIT_STATE_DISABLED)
	root.name = level_name.to_pascal_case().validate_node_name()
	var length: float = maxf(600.0, float(options.get("length", 2000.0)))
	var style: int = options.get("style", 0)
	var level := root.get_node_or_null("Level")
	var start := root.get_node_or_null("Level/StartGround")
	var right_wall := root.get_node_or_null("Level/RightWall")
	var left_x := -300.0
	if start:
		left_x = start.points[0].x
		start.style = style
		start.points = _slab(left_x, left_x + length)
	if right_wall:
		var p: PackedVector2Array = right_wall.points
		var shift := (left_x + length) - p[0].x
		for i in p.size():
			p[i].x += shift
		right_wall.points = p
	if options.get("gap", false) and start and level:
		var mid := left_x + length * 0.5
		start.points = _slab(left_x, mid - GAP * 0.5)
		var far := Pieces.create("ground_block", Vector2.ZERO)
		far.name = "FarGround"
		far.style = style
		far.points = _slab(mid + GAP * 0.5, left_x + length)
		_add(level, far, root)
		var water := Pieces.create("water", Vector2(mid, 120.0))
		water.from_x = mid - GAP * 0.5 - 20.0
		water.to_x = mid + GAP * 0.5 + 20.0
		_add(root, water, root)
		root.move_child(water, 1)   # behind the level, like main.tscn
		var cps := root.get_node_or_null("Level/Checkpoints")
		if cps:
			var cp := Pieces.create("checkpoint", Vector2(mid - GAP * 0.5 - 150.0, 0))
			cp.name = "BeforeGap"
			_add(cps, cp, root)
	root.scene_file_path = ""   # a fresh scene, not one inheriting the template
	var packed := PackedScene.new()
	var err := packed.pack(root)
	root.free()
	if err != OK:
		return {"error": "Couldn't build the scene (error %d)." % err}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LEVEL_DIR))
	err = ResourceSaver.save(packed, path)
	if err != OK:
		return {"error": "Couldn't save %s (error %d)." % [path, err]}
	return {"path": path}


static func _slab(x0: float, x1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, 400), Vector2(x0, 400)])


static func _add(parent: Node, node: Node, root: Node) -> void:
	parent.add_child(node, true)
	node.owner = root
	for c in node.get_children():
		c.owner = root
