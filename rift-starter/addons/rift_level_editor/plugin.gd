@tool
extends EditorPlugin
## Rift level editor: a "Level" dock with a piece palette, ground drawing,
## drag handles for level pieces, markers for things that are invisible in
## the editor, and a New level wizard. Everything it does can be undone.

const Pieces := preload("res://addons/rift_level_editor/level_pieces.gd")
const Dock := preload("res://addons/rift_level_editor/dock.gd")
const NewLevelDialog := preload("res://addons/rift_level_editor/new_level_dialog.gd")

const HANDLE := 6.0          # handle half-size in screen pixels
const PICK := 9.0            # how close (screen px) a click must be to a handle
const CLOSE_PICK := 12.0     # how close to the first point closes a drawn shape
const C_HANDLE := Color(1, 1, 1)
const C_HANDLE_EDGE := Color(0.1, 0.12, 0.2)
const C_ADD := Color(0.5, 1.0, 0.6)
const C_DRAW := Color(0.55, 0.95, 0.5)
const C_FALL := Color(1.0, 0.3, 0.3, 0.7)

var dock: Dock
var dialog: NewLevelDialog
var _mouse := Vector2.ZERO          # cursor in scene (global) space
var _mouse_screen := Vector2.ZERO
var _have_mouse := false
var _draw_pts := PackedVector2Array()   # ground being drawn, global space
var _drag := {}                     # {node, handle, before}
var _ghosts := {}                   # piece id -> sample node (never in the tree)


func _enter_tree() -> void:
	dock = Dock.new()
	dock.tool_changed.connect(_on_tool_changed)
	dock.new_level_pressed.connect(func(): dialog.popup_centered())
	dock.settings_changed.connect(update_overlays)
	add_control_to_dock(DOCK_SLOT_LEFT_BR, dock)
	dialog = NewLevelDialog.new()
	dialog.created.connect(_on_level_created)
	EditorInterface.get_base_control().add_child(dialog)
	scene_changed.connect(func(_r): _cancel_draw(); _refresh_info())
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	get_undo_redo().version_changed.connect(_refresh_info)
	_refresh_info.call_deferred()
	# Developer check: RIFT_EDITOR_SELFTEST=1 godot -e runs tests/editor_selftest.gd.
	if OS.get_environment("RIFT_EDITOR_SELFTEST") != "" and ResourceLoader.exists("res://tests/editor_selftest.gd"):
		var t: Node = load("res://tests/editor_selftest.gd").new()
		t.plugin = self
		EditorInterface.get_base_control().add_child.call_deferred(t)


func _exit_tree() -> void:
	remove_control_from_docks(dock)
	dock.queue_free()
	dialog.queue_free()
	for g in _ghosts.values():
		if is_instance_valid(g):
			g.free()
	_ghosts.clear()


func _get_plugin_name() -> String:
	return "Rift Level Editor"


## We look at every node, so the overlay and handles work whatever is selected.
func _handles(object: Object) -> bool:
	return object is Node or (object != null and object.get_class() == "MultiNodeEdit")


func _edit(_object: Object) -> void:
	update_overlays()


# ---------------------------------------------------------------- helpers
func _root() -> Node:
	return EditorInterface.get_edited_scene_root()


func _xf() -> Transform2D:
	var r := _root()
	if r == null or not r.is_inside_tree():
		return Transform2D.IDENTITY
	return r.get_viewport().global_canvas_transform


func _to_screen(p: Vector2) -> Vector2:
	return _xf() * p


func _snapped(p: Vector2) -> Vector2:
	return Pieces.snap(p, dock.snap_step) if dock.snap_on else p


func _selected() -> Node:
	var s := EditorInterface.get_selection().get_selected_nodes()
	return s[0] if s.size() == 1 else null


## Nodes saved in the open scene (not the insides of instanced scenes).
func _all_nodes(n: Node, r: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children():
		if c.owner == r:
			_all_nodes(c, r, out)
	return out


func _scene_nodes() -> Array:
	var r := _root()
	return _all_nodes(r, r, []) if r else []


func _ground_polys() -> Array:
	var out := []
	for n in _scene_nodes():
		if n is Ground:
			var pts := PackedVector2Array()
			for p in n.points:
				pts.append(n.to_global(p))
			out.append(pts)
	return out


func _kill_y() -> float:
	for n in _scene_nodes():
		if n is Player:
			return n.kill_y
	return 200.0


func _level_name() -> String:
	var r := _root()
	if r == null:
		return "level"
	var f := r.scene_file_path.get_file().get_basename()
	return f if f != "" else String(r.name)


# ---------------------------------------------------------------- tools
func _on_tool_changed(tool: String) -> void:
	_cancel_draw()
	_drag.clear()
	if tool != "select":
		_ensure_editing()
	update_overlays()


func _on_selection_changed() -> void:
	if dock and dock.tool != "select":
		_ensure_editing.call_deferred()
	update_overlays()


## The editor only forwards viewport input to us while something is being
## edited, so placing tools make sure at least the scene root is.
func _ensure_editing() -> void:
	var r := _root()
	if r and EditorInterface.get_selection().get_selected_nodes().is_empty():
		EditorInterface.edit_node(r)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	var r := _root()
	if r == null or dock == null:
		return false
	if event is InputEventMouse:
		_mouse_screen = event.position
		_mouse = _xf().affine_inverse() * event.position
		_have_mouse = true
	match dock.tool:
		"select":
			return _input_select(event)
		"draw_ground":
			return _input_draw(event)
		_:
			return _input_place(event)


# ---------------------------------------------------------------- placing
func _input_place(e: InputEvent) -> bool:
	if e is InputEventMouseMotion:
		update_overlays()
		return false
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			place(dock.tool, placement_point(dock.tool))
			return true
		if e.button_index == MOUSE_BUTTON_RIGHT:
			dock.set_tool("select")
			return true
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		dock.set_tool("select")
		return true
	return false


## Where a piece would land for the current cursor: snapped, and dropped onto
## the ground below for pieces that stand on it.
func placement_point(id: String) -> Vector2:
	var p := _snapped(_mouse)
	if dock.stand_on_ground and Pieces.stands_on_ground(id):
		var y := Pieces.ground_y_below(_ground_polys(), Vector2(p.x, _mouse.y))
		if not is_nan(y):
			p.y = y
	return p


## Place a piece at a global position, creating its folder (Level/Portals...)
## if needed. One undo step.
func place(id: String, global_p: Vector2) -> Node:
	var r := _root()
	if r == null:
		return null
	var ur := get_undo_redo()
	ur.create_action("Place %s" % Pieces.label(id), UndoRedo.MERGE_DISABLE, r)
	var parent := _folder(id, r, ur)
	var shard_ids := []
	for n in _scene_nodes():
		if n is ShardPickup:
			shard_ids.append(n.shard_id)
	var local := _global_to(parent, global_p)
	var node := Pieces.create(id, local, {"level_name": _level_name(), "shard_ids": shard_ids, "global_at": global_p})
	if node == null:
		ur.commit_action(false)
		return null
	_add_with_undo(ur, parent, node, r)
	ur.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)
	return node


## The parent a piece goes in. Missing folders are created inside the action.
func _folder(id: String, r: Node, ur: EditorUndoRedoManager) -> Node:
	var f := Pieces.folder(id)
	var chain: Array
	if f.begins_with("/"):
		chain = [f.substr(1)]
	else:
		chain = ["Level"] if f == "" else ["Level", f]
	var parent := r
	for part in chain:
		var next := parent.get_node_or_null(NodePath(part))
		if next == null:
			next = Node2D.new()
			next.name = part
			_add_with_undo(ur, parent, next, r)
			# Make it exist right now so the piece can be positioned inside it.
			parent.add_child(next)
			next.owner = r
		parent = next
	return parent


func _global_to(parent: Node, p: Vector2) -> Vector2:
	if parent is Node2D:
		return parent.global_transform.affine_inverse() * p
	return p


func _add_with_undo(ur: EditorUndoRedoManager, parent: Node, node: Node, r: Node) -> void:
	ur.add_do_method(self, "_attach", parent, node, r)
	ur.add_undo_method(self, "_detach", parent, node)
	ur.add_do_reference(node)


func _attach(parent: Node, node: Node, r: Node) -> void:
	if node.get_parent() != parent:
		parent.add_child(node, true)
	_own(node, r)


func _own(n: Node, r: Node) -> void:
	n.owner = r
	for c in n.get_children():
		_own(c, r)


func _detach(parent: Node, node: Node) -> void:
	if node.get_parent() == parent:
		parent.remove_child(node)


# ---------------------------------------------------------------- drawing ground
func _input_draw(e: InputEvent) -> bool:
	if e is InputEventMouseMotion:
		update_overlays()
		return false
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			var p := _snapped(_mouse)
			if e.double_click:
				finish_ground(false)
			elif _draw_pts.size() >= 3 and _mouse_screen.distance_to(_to_screen(_draw_pts[0])) < CLOSE_PICK:
				finish_ground(true)
			elif _draw_pts.is_empty() or _draw_pts[_draw_pts.size() - 1].distance_to(p) > 0.5:
				_draw_pts.append(p)
			update_overlays()
			return true
		if e.button_index == MOUSE_BUTTON_RIGHT:
			if _draw_pts.size() >= 2:
				finish_ground(false)
			else:
				dock.set_tool("select")
			return true
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				finish_ground(false)
				return true
			KEY_BACKSPACE:
				if not _draw_pts.is_empty():
					_draw_pts.remove_at(_draw_pts.size() - 1)
					update_overlays()
				return true
			KEY_ESCAPE:
				if _draw_pts.is_empty():
					dock.set_tool("select")
				else:
					_cancel_draw()
				return true
	return false


func add_draw_point(global_p: Vector2) -> void:
	_draw_pts.append(global_p)


func _cancel_draw() -> void:
	_draw_pts.clear()
	update_overlays()


## Turn the drawn points into a Ground. closed = use them as the outline;
## otherwise they're the walkable top and the shape fills down below.
func finish_ground(closed: bool) -> Node:
	if _draw_pts.size() < (3 if closed else 2):
		_cancel_draw()
		return null
	var drawn := _draw_pts.duplicate()   # packed arrays are shared, and we clear this next
	var poly := Pieces.clockwise(drawn) if closed else Pieces.surface_to_polygon(drawn, dock.ground_depth)
	_draw_pts.clear()
	if absf(Pieces.signed_area(poly)) < 4.0:
		update_overlays()
		return null
	var r := _root()
	var ur := get_undo_redo()
	ur.create_action("Draw ground", UndoRedo.MERGE_DISABLE, r)
	var parent := _folder("ground_block", r, ur)
	var local := PackedVector2Array()
	for p in poly:
		local.append(_global_to(parent, p))
	var origin := local[0]
	for i in local.size():
		local[i] -= origin
	var g := Pieces.create("floating_rock" if closed else "ground_block", origin)
	g.name = "Rock" if closed else "Ground"
	g.points = local
	_add_with_undo(ur, parent, g, r)
	ur.commit_action()
	update_overlays()
	return g


# ---------------------------------------------------------------- handles
## Drag handles for a node, in global space: [{pos, kind, i}].
func handles_of(n: Node) -> Array:
	var out := []
	if n is Ground:
		var pts: PackedVector2Array = n.points
		for i in pts.size():
			out.append({"pos": n.to_global(pts[i]), "kind": "corner", "i": i})
		for i in pts.size():
			var mid := (pts[i] + pts[(i + 1) % pts.size()]) * 0.5
			out.append({"pos": n.to_global(mid), "kind": "add", "i": i})
	elif n is SightPlatform:
		out.append({"pos": n.to_global(n.size * 0.5), "kind": "size"})
	elif n is CutsceneTrigger or n is ArenaGate:
		out.append({"pos": n.to_global(Vector2(n.size.x * 0.5, -n.size.y)), "kind": "size"})
	elif n is JunglePlant:
		out.append({"pos": n.to_global(Vector2(0, -n.height)), "kind": "height"})
	elif n is Ocean:
		out.append({"pos": n.to_global(Vector2(n.from_x, n.surface_y)), "kind": "left"})
		out.append({"pos": n.to_global(Vector2(n.to_x, n.surface_y)), "kind": "right"})
	elif n is MawBoss:
		out.append({"pos": Vector2(n.arena_left, n.floor_y), "kind": "left"})
		out.append({"pos": Vector2(n.arena_right, n.floor_y), "kind": "right"})
	elif n is Portal or n is PixMote:
		out.append({"pos": n.to_global(Vector2(n.radius, 0)), "kind": "radius"})
	return out


func _props_of(n: Node) -> Array:
	if n is Ground:
		return ["points"]
	if n is SightPlatform or n is CutsceneTrigger or n is ArenaGate:
		return ["size"]
	if n is JunglePlant:
		return ["height"]
	if n is Ocean:
		return ["from_x", "to_x", "surface_y"]
	if n is MawBoss:
		return ["arena_left", "arena_right", "floor_y"]
	if n is Portal or n is PixMote:
		return ["radius"]
	return []


func _snapshot(n: Node) -> Dictionary:
	var d := {}
	for p in _props_of(n):
		var v = n.get(p)
		d[p] = v.duplicate() if v is PackedVector2Array else v
	return d


## Move one handle to a global position.
func apply_handle(n: Node, h: Dictionary, gp: Vector2) -> void:
	var lp: Vector2 = n.to_local(gp) if n is Node2D else gp
	if n is Ground:
		var pts: PackedVector2Array = n.points.duplicate()
		pts[h.i] = lp
		n.points = pts
	elif n is SightPlatform:
		n.size = (lp.abs() * 2.0).max(Vector2(10, 6))
	elif n is CutsceneTrigger or n is ArenaGate:
		n.size = Vector2(maxf(10.0, absf(lp.x) * 2.0), maxf(10.0, -lp.y))
	elif n is JunglePlant:
		n.height = maxf(10.0, -lp.y)
	elif n is Ocean:
		if h.kind == "left":
			n.from_x = minf(lp.x, n.to_x - 20.0)
		else:
			n.to_x = maxf(lp.x, n.from_x + 20.0)
		n.surface_y = lp.y
	elif n is MawBoss:
		if h.kind == "left":
			n.arena_left = minf(gp.x, n.arena_right - 300.0)
		else:
			n.arena_right = maxf(gp.x, n.arena_left + 300.0)
		n.floor_y = gp.y
	elif n is Portal or n is PixMote:
		n.radius = maxf(4.0, lp.length())
	if n is CanvasItem:
		n.queue_redraw()
	update_overlays()


func _hit_handle(n: Node, screen: Vector2) -> Dictionary:
	var best := {}
	var best_d := PICK
	for h in handles_of(n):
		var d := screen.distance_to(_to_screen(h.pos))
		# Corners win over the "+" midpoints when they overlap.
		if d < best_d or (d <= PICK and h.kind == "corner" and best.get("kind", "") == "add"):
			best = h
			best_d = d
	return best


func _input_select(e: InputEvent) -> bool:
	var n := _selected()
	if e is InputEventMouseMotion:
		if not _drag.is_empty():
			apply_handle(_drag.node, _drag.handle, _snapped(_mouse))
			return true
		return false
	if not e is InputEventMouseButton:
		return false
	if e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and n:
			var h := _hit_handle(n, e.position)
			if h.is_empty():
				return false
			var before := _snapshot(n)
			if h.kind == "add":
				insert_point(n, h.i, _snapped(_mouse), false)
				h = {"pos": h.pos, "kind": "corner", "i": h.i + 1}
			_drag = {"node": n, "handle": h, "before": before}
			return true
		if not e.pressed and not _drag.is_empty():
			commit_drag()
			return true
	if e.button_index == MOUSE_BUTTON_RIGHT and e.pressed and n is Ground:
		var h := _hit_handle(n, e.position)
		if h.get("kind", "") == "corner":
			delete_point(n, h.i)
			return true
	return false


## Finish a handle drag as one undo step (the change is already applied).
func commit_drag() -> void:
	var n: Node = _drag.node
	var before: Dictionary = _drag.before
	_drag.clear()
	var after := _snapshot(n)
	if after == before:
		return
	var ur := get_undo_redo()
	ur.create_action("Drag %s" % n.name, UndoRedo.MERGE_DISABLE, n)
	for p in after.keys():
		ur.add_do_property(n, p, after[p])
		ur.add_undo_property(n, p, before[p])
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action(false)


func start_drag(n: Node, h: Dictionary) -> void:
	_drag = {"node": n, "handle": h, "before": _snapshot(n)}


func insert_point(g: Node, after_index: int, gp: Vector2, with_undo := true) -> void:
	var pts: PackedVector2Array = g.points.duplicate()
	pts.insert(after_index + 1, g.to_local(gp))
	_set_points(g, pts, "Add ground corner", with_undo)


func delete_point(g: Node, i: int) -> void:
	if g.points.size() <= 3:
		return
	var pts: PackedVector2Array = g.points.duplicate()
	pts.remove_at(i)
	_set_points(g, pts, "Delete ground corner", true)


func _set_points(g: Node, pts: PackedVector2Array, action: String, with_undo: bool) -> void:
	if not with_undo:
		g.points = pts
		update_overlays()
		return
	var ur := get_undo_redo()
	ur.create_action(action, UndoRedo.MERGE_DISABLE, g)
	ur.add_do_property(g, "points", pts)
	ur.add_undo_property(g, "points", g.points.duplicate())
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action()


# ---------------------------------------------------------------- overlay
func _forward_canvas_draw_over_viewport(ov: Control) -> void:
	var r := _root()
	if r == null or dock == null:
		return
	var xf := _xf()
	var font := ov.get_theme_default_font()
	if dock.show_markers:
		_draw_fall_line(ov, xf, font)
		for n in _scene_nodes():
			_draw_marker(ov, xf, font, n)
	match dock.tool:
		"select":
			var n := _selected()
			if n:
				_draw_handles(ov, xf, n)
		"draw_ground":
			_draw_ground_preview(ov, xf)
		_:
			if _have_mouse:
				_draw_ghost(ov, xf, font, dock.tool)


func _text(ov: Control, font: Font, at: Vector2, s: String, col: Color, size := 12) -> void:
	ov.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.8))
	ov.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_fall_line(ov: Control, xf: Transform2D, font: Font) -> void:
	var y := (xf * Vector2(0, _kill_y())).y
	if y < 0 or y > ov.size.y:
		return
	ov.draw_dashed_line(Vector2(0, y), Vector2(ov.size.x, y), C_FALL, 2.0, 12.0)
	_text(ov, font, Vector2(28, y - 6), "fall line: anyone below here respawns (Player kill_y)", C_FALL)


func _draw_marker(ov: Control, xf: Transform2D, font: Font, n: Node) -> void:
	var zoom := xf.get_scale().x
	if n is Portal:
		var c := Color(0.8, 0.35, 1.0)
		var p: Vector2 = xf * n.global_position
		ov.draw_arc(p, n.radius * zoom, 0, TAU, 40, c, 2.0)
		ov.draw_arc(p, n.radius * zoom * 0.5, 0.5, TAU * 0.8, 24, Color(c, 0.6), 2.0)
		var eye := "" if n.for_eye == &"" else " (%s only)" % n.for_eye
		_text(ov, font, p + Vector2(n.radius * zoom + 4, 4), "%s%s - %d shots" % [n.name, eye, n.shots_to_seal], c)
	elif n is PortalTendril:
		var p: Vector2 = xf * n.global_position
		var dir := Vector2.RIGHT.rotated(deg_to_rad(n.angle_degrees))
		ov.draw_line(p, p + dir * n.segments * n.segment_length * zoom, Color(0.9, 0.3, 0.75, 0.7), 3.0)
	elif n is PixMote:
		var p: Vector2 = xf * n.global_position
		ov.draw_arc(p, n.radius * zoom, 0, TAU, 24, Color(0.5, 0.95, 1.0), 2.0)
		ov.draw_circle(p, 3.0, Color(0.5, 0.95, 1.0))
	elif n is Checkpoint:
		var p: Vector2 = xf * n.global_position
		var top: Vector2 = xf * (n.global_position + Vector2(0, -80))
		ov.draw_line(p, top, Color(1.0, 0.75, 0.4), 3.0)
		ov.draw_circle(top, 6.0 * maxf(zoom, 0.5), Color(1.0, 0.75, 0.4))
		_text(ov, font, top + Vector2(8, 4), String(n.name), Color(1.0, 0.8, 0.5))
	elif n is Ocean:
		var a: Vector2 = xf * n.to_global(Vector2(n.from_x, n.surface_y))
		var b: Vector2 = xf * n.to_global(Vector2(n.to_x, n.surface_y + 60))
		ov.draw_rect(Rect2(a, b - a), Color(0.2, 0.55, 0.7, 0.3))
		ov.draw_line(a, Vector2(b.x, a.y), Color(0.6, 0.9, 1.0), 2.0)
		_text(ov, font, a + Vector2(4, 16), "%s (water)" % n.name, Color(0.7, 0.95, 1.0))
	elif n is MawBoss:
		var c := Color(0.95, 0.25, 0.5)
		var p: Vector2 = xf * n.global_position
		ov.draw_arc(p, n.radius * zoom, 0, TAU, 48, c, 3.0)
		var a := xf * Vector2(n.arena_left, n.floor_y)
		var b := xf * Vector2(n.arena_right, n.floor_y)
		ov.draw_line(a, b, c, 3.0)
		var h := 700.0 * zoom
		ov.draw_dashed_line(a, a - Vector2(0, h), Color(c, 0.6), 2.0, 10.0)
		ov.draw_dashed_line(b, b - Vector2(0, h), Color(c, 0.6), 2.0, 10.0)
		_text(ov, font, p + Vector2(-60, -n.radius * zoom - 8), "%s (boss)" % n.display_name, c, 14)
		_text(ov, font, a + Vector2(6, -8), "arena floor", c)
	elif n is Player and n.get_parent() == _root():
		var p: Vector2 = xf * n.global_position
		var tall := 100.0 * (0.55 if n.name.to_lower().contains("fairy") else 1.0) * zoom
		ov.draw_rect(Rect2(p - Vector2(12 * zoom, tall), Vector2(24 * zoom, tall)), Color(0.9, 0.9, 1.0, 0.7), false, 2.0)
		_text(ov, font, p - Vector2(12 * zoom, tall + 6), "%s start" % n.name, Color(0.9, 0.9, 1.0))


func _square(ov: Control, p: Vector2, col: Color) -> void:
	var r := Rect2(p - Vector2(HANDLE, HANDLE), Vector2(HANDLE, HANDLE) * 2)
	ov.draw_rect(r, col)
	ov.draw_rect(r, C_HANDLE_EDGE, false, 1.5)


func _draw_handles(ov: Control, xf: Transform2D, n: Node) -> void:
	var hs := handles_of(n)
	if n is Ground:
		var pts := PackedVector2Array()
		for h in hs:
			if h.kind == "corner":
				pts.append(xf * h.pos)
		if pts.size() > 1:
			pts.append(pts[0])
			ov.draw_polyline(pts, Color(1, 1, 1, 0.6), 1.5)
	for h in hs:
		var p: Vector2 = xf * h.pos
		if h.kind == "add":
			ov.draw_circle(p, 5.0, Color(C_ADD, 0.85))
			ov.draw_line(p - Vector2(3, 0), p + Vector2(3, 0), C_HANDLE_EDGE, 1.5)
			ov.draw_line(p - Vector2(0, 3), p + Vector2(0, 3), C_HANDLE_EDGE, 1.5)
		else:
			_square(ov, p, C_HANDLE)


func _draw_ground_preview(ov: Control, xf: Transform2D) -> void:
	if not _have_mouse:
		return
	var cursor := _snapped(_mouse)
	ov.draw_circle(xf * cursor, 4.0, C_DRAW)
	if _draw_pts.is_empty():
		return
	var line := _draw_pts.duplicate()
	line.append(cursor)
	if line.size() >= 2:
		var fill := Pieces.surface_to_polygon(line, dock.ground_depth)
		var screen := PackedVector2Array()
		for p in fill:
			screen.append(xf * p)
		if Geometry2D.triangulate_polygon(screen).size() > 0:
			ov.draw_colored_polygon(screen, Color(0.45, 0.32, 0.25, 0.35))
	var sl := PackedVector2Array()
	for p in line:
		sl.append(xf * p)
	ov.draw_polyline(sl, C_DRAW, 3.0)
	for i in _draw_pts.size():
		_square(ov, xf * _draw_pts[i], C_DRAW if i > 0 else Color(1, 0.9, 0.4))
	if _draw_pts.size() >= 3 and _mouse_screen.distance_to(xf * _draw_pts[0]) < CLOSE_PICK:
		ov.draw_arc(xf * _draw_pts[0], 12.0, 0, TAU, 24, Color(1, 0.9, 0.4), 2.0)


func _ghost(id: String) -> Node:
	if not _ghosts.has(id) or not is_instance_valid(_ghosts[id]):
		_ghosts[id] = Pieces.create(id, Vector2.ZERO, {"global_at": Vector2.ZERO})
	return _ghosts[id]


func _draw_ghost(ov: Control, xf: Transform2D, font: Font, id: String) -> void:
	var at := placement_point(id)
	var p := xf * at
	var zoom := xf.get_scale().x
	var col := Pieces.color(id)
	var g := _ghost(id)
	if g is Ground:
		var pts := PackedVector2Array()
		for q in g.points:
			pts.append(xf * (at + q))
		ov.draw_colored_polygon(pts, Color(col, 0.35))
		pts.append(pts[0])
		ov.draw_polyline(pts, Color(col.lightened(0.4), 0.9), 2.0)
	elif g is SightPlatform:
		var r := Rect2(p - g.size * 0.5 * zoom, g.size * zoom)
		ov.draw_rect(r, Color(col, 0.35))
		ov.draw_rect(r, col, false, 2.0)
	elif g is CutsceneTrigger:
		var r := Rect2(p - Vector2(g.size.x * 0.5, g.size.y) * zoom, g.size * zoom)
		ov.draw_rect(r, Color(col, 0.2))
	elif g is Portal or g is PixMote:
		ov.draw_arc(p, g.radius * zoom, 0, TAU, 32, col, 2.0)
	elif g is JunglePlant:
		ov.draw_line(p, p - Vector2(0, g.height * zoom), col, 3.0)
	elif id == "boss_arena":
		ov.draw_line(p - Vector2(630, 0) * zoom, p + Vector2(630, 0) * zoom, col, 3.0)
		ov.draw_arc(p - Vector2(0, 320) * zoom, 120 * zoom, 0, TAU, 40, col, 2.0)
	elif id == "water":
		ov.draw_rect(Rect2(p - Vector2(200, 0) * zoom, Vector2(400, 60) * zoom), Color(col, 0.35))
	ov.draw_line(p - Vector2(8, 0), p + Vector2(8, 0), Color.WHITE, 1.5)
	ov.draw_line(p - Vector2(0, 8), p + Vector2(0, 8), Color.WHITE, 1.5)
	_text(ov, font, p + Vector2(10, -10), Pieces.label(id), col.lightened(0.3))


# ---------------------------------------------------------------- level info
func _refresh_info() -> void:
	if dock == null:
		return
	var r := _root()
	if r == null:
		dock.set_info("[i]Open or make a level scene.[/i]")
		return
	dock.set_info(level_report(r))


## Counts and plain-English warnings for the open level (BBCode).
func level_report(r: Node) -> String:
	var counts := {"Ground": 0, "Checkpoint": 0, "Shard": 0, "Portal": 0, "Pix mote": 0, "Cutscene trigger": 0}
	var warnings := []
	var shard_ids := {}
	var has_party := false
	var mawes := []
	var gates := []
	var kill_y := _kill_y()
	for n in _scene_nodes():
		if n is Ground:
			counts["Ground"] += 1
			if n.points.size() >= 3 and Pieces.signed_area(n.points) < 0.0:
				warnings.append("%s is drawn the wrong way round: its grass ends up underneath. Redraw it, or reverse its points." % n.name)
		elif n is Checkpoint:
			counts["Checkpoint"] += 1
			if n.global_position.y > kill_y:
				warnings.append("Checkpoint %s is below the fall line." % n.name)
		elif n is ShardPickup:
			counts["Shard"] += 1
			if shard_ids.has(n.shard_id):
				warnings.append("Shards %s and %s share the id \"%s\": only one can be collected." % [shard_ids[n.shard_id], n.name, n.shard_id])
			shard_ids[n.shard_id] = n.name
		elif n is Portal:
			counts["Portal"] += 1
		elif n is PixMote:
			counts["Pix mote"] += 1
		elif n is CutsceneTrigger:
			counts["Cutscene trigger"] += 1
			if n.cutscene == "":
				warnings.append("Cutscene trigger %s has no cutscene file chosen." % n.name)
		elif n is Party:
			has_party = true
		elif n is MawBoss:
			mawes.append(n)
		elif n is ArenaGate:
			gates.append(n)
	if not has_party:
		warnings.append("No Party node, so this scene can't be played. Start levels with [b]New level...[/b]")
	if counts["Checkpoint"] == 0:
		warnings.append("No checkpoints: falling sends players back to where they started.")
	for m in mawes:
		var linked := false
		for g in gates:
			linked = linked or g.get_node_or_null(g.boss_path) == m
		if not linked:
			warnings.append("The Maw (%s) has no gate pointing at it, so the arena won't seal." % m.name)
	var lines := []
	for k in counts.keys():
		lines.append("%s: %d" % [k, counts[k]])
	var out := ", ".join(lines)
	if warnings.is_empty():
		out += "\n[color=#8f8]No problems found.[/color]"
	else:
		for w in warnings:
			out += "\n[color=#fc6]! %s[/color]" % w
	return out


# ---------------------------------------------------------------- new level
func _on_level_created(path: String, make_main: bool) -> void:
	EditorInterface.get_resource_filesystem().scan()
	if make_main:
		ProjectSettings.set_setting("application/run/main_scene", path)
		ProjectSettings.save()
	EditorInterface.open_scene_from_path(path)
	print("Rift Level Editor: created %s" % path)
