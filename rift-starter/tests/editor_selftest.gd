@tool
extends Node
## Drives the level editor plugin inside the real Godot editor.
##   RIFT_EDITOR_SELFTEST=1 godot -e --path .     (needs a window, e.g. xvfb-run)
## Prints PASS/FAIL lines, saves docs/level_editor.png and quits.

const Builder := preload("res://addons/rift_level_editor/level_builder.gd")
const NAME := "Editor Selftest"

var plugin: EditorPlugin
var _fails := 0


func check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func wait(n := 10) -> void:
	for i in n:
		await get_tree().process_frame


## Zoom, then pan the 2D view (like a trackpad) until `target` is centred.
func _center_view(target: Vector2, zoom: float) -> void:
	var cie := EditorInterface.get_base_control().find_children("*", "CanvasItemEditor", true, false)
	if cie.is_empty():
		return
	var vps := cie[0].find_children("*", "CanvasItemEditorViewport", true, false)
	if vps.is_empty():
		return
	var vp: Control = vps[0]
	var mag := InputEventMagnifyGesture.new()
	mag.factor = zoom
	mag.position = vp.size * 0.5
	vp.gui_input.emit(mag)
	for i in 300:
		await get_tree().process_frame
		var c: Vector2 = plugin._xf().affine_inverse() * (vp.size * 0.5)
		var d := target - c
		if d.length() < 15.0:
			break
		var p := InputEventPanGesture.new()
		p.delta = d.normalized() * minf(1.0, d.length() / 40.0)
		p.position = vp.size * 0.5
		vp.gui_input.emit(p)


func _view(pan: Vector2, zoom: float) -> void:
	var cie := EditorInterface.get_base_control().find_children("*", "CanvasItemEditor", true, false)
	if cie.is_empty():
		return
	var vps := cie[0].find_children("*", "CanvasItemEditorViewport", true, false)
	if vps.is_empty():
		return
	var vp: Control = vps[0]
	var mag := InputEventMagnifyGesture.new()
	mag.factor = zoom
	mag.position = vp.size * 0.5
	vp.gui_input.emit(mag)
	var p := InputEventPanGesture.new()
	p.delta = pan
	p.position = vp.size * 0.5
	vp.gui_input.emit(p)


func _ready() -> void:
	await wait(60)
	var path := Builder.path_for(NAME)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var res := Builder.build({"name": NAME, "length": 2000.0})
	check(res.has("path"), "wizard builds a level in the editor %s" % [res])
	var text := FileAccess.get_file_as_string(path)
	check(text.contains("first_path = NodePath(\"../Mafia\")") and not text.contains("collision_layer"),
		"saved level keeps links and doesn't copy the player scene's settings")
	plugin._on_level_created(path, false)
	await wait(30)
	var root := EditorInterface.get_edited_scene_root()
	check(root != null and root.name == "EditorSelftest", "the new level opens in the editor")
	EditorInterface.set_main_screen_editor("2D")
	await wait(10)
	var dock = plugin.dock
	var ur: EditorUndoRedoManager = plugin.get_undo_redo()
	var history := ur.get_history_undo_redo(ur.get_object_history_id(root))

	# Palette placement, with folders and undo.
	dock.set_tool("portal")
	var portal: Node = plugin.place("portal", Vector2(500, -120))
	check(portal != null and portal.get_parent().name == "Portals" and portal.owner == root and portal is Portal,
		"placing a portal puts it in Level/Portals, saved with the scene")
	history.undo()
	check(not is_instance_valid(portal) or portal.get_parent() == null, "undo removes a placed piece")
	history.redo()
	check(portal.get_parent() != null, "redo puts it back")
	var s1: Node = plugin.place("shard", Vector2(300, -80))
	var s2: Node = plugin.place("shard", Vector2(340, -80))
	check(s1.shard_id != s2.shard_id and s1.shard_id.begins_with("editor_selftest_shard"), "each shard gets its own id (%s, %s)" % [s1.shard_id, s2.shard_id])
	plugin._mouse = Vector2(700, -300)
	var cp_at: Vector2 = plugin.placement_point("checkpoint")
	check(is_equal_approx(cp_at.y, 0.0), "checkpoints drop onto the ground below the cursor (y=%.0f)" % cp_at.y)

	# Clicking in the viewport goes through the real input path.
	dock.set_tool("pix_mote")
	await wait(2)
	var screen: Vector2 = plugin._xf() * Vector2(800, -150)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	plugin._forward_canvas_gui_input(motion)
	var used: bool = plugin._forward_canvas_gui_input(click)
	var motes := root.find_children("*", "", true, false).filter(func(n): return n is PixMote)
	check(used and motes.size() == 1 and motes[0].global_position.distance_to(Vector2(800, -150)) < 1.0,
		"a click in the 2D view places the piece where you clicked")

	# Drawing ground.
	dock.set_tool("draw_ground")
	for p in [Vector2(1000, -100), Vector2(1200, -100), Vector2(1400, -220)]:
		plugin.add_draw_point(p)
	var g: Ground = plugin.finish_ground(false)
	check(g != null and g.owner == root and g.top_edges().size() == 2, "drawn ground becomes a solid Ground with a grassy top")
	var rock: Node
	for p in [Vector2(600, -400), Vector2(700, -440), Vector2(760, -380)]:
		plugin.add_draw_point(p)
	rock = plugin.finish_ground(true)
	check(rock != null and rock.points.size() == 3, "closing a drawn shape makes a floating rock (%s)" % [rock.points if rock else null])

	# Handles.
	dock.set_tool("select")
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(g)
	await wait(2)
	var before: PackedVector2Array = g.points.duplicate()
	var hs: Array = plugin.handles_of(g)
	check(hs.filter(func(h): return h.kind == "corner").size() == g.points.size(), "a selected ground shows a handle per corner")
	plugin.start_drag(g, hs[1])
	plugin.apply_handle(g, hs[1], Vector2(1220, -140))
	plugin.commit_drag()
	check(g.to_global(g.points[1]).is_equal_approx(Vector2(1220, -140)), "dragging a corner moves it")
	history.undo()
	check(g.points == before, "undo puts the corner back")
	plugin.insert_point(g, 0, Vector2(1100, -130))
	check(g.points.size() == before.size() + 1, "clicking a + adds a corner")
	plugin.delete_point(g, 1)
	check(g.points.size() == before.size(), "right-clicking a corner deletes it")
	var plat: Node = plugin.place("platform_true", Vector2(900, -260))
	plugin.apply_handle(plat, plugin.handles_of(plat)[0], plat.global_position + Vector2(100, 15))
	check(plat.size == Vector2(200, 30), "platform size handle resizes it")
	var arena: Node = plugin.place("boss_arena", Vector2(1600, 0))
	var maw: Node = arena.get_node("TheMaw")
	plugin.apply_handle(maw, plugin.handles_of(maw)[1], Vector2(2400, 0))
	check(maw.arena_right == 2400.0, "the Maw's arena handles move its edges")

	var report: String = plugin.level_report(root)
	check(report.contains("Portal: 1") and report.contains("Shard: 2"), "level summary counts pieces")
	check(not report.contains("no gate"), "boss arena comes linked, so no warning")

	# Screenshots, in a fresh level so they're tidy.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var shot_path := Builder.path_for("Editor Showcase")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(shot_path))
	Builder.build({"name": "Editor Showcase", "length": 2000.0})
	plugin._on_level_created(shot_path, false)
	await wait(30)
	EditorInterface.set_main_screen_editor("2D")
	if dock.get_parent() is TabContainer:
		dock.get_parent().current_tab = dock.get_index()
	await _center_view(Vector2(420, -230), 0.8)
	for p in [Vector2(120, -110), Vector2(330, -110), Vector2(480, -190), Vector2(640, -190)]:
		plugin.add_draw_point(p)
	var shown: Node = plugin.finish_ground(false)
	plugin.place("platform_true", Vector2(230, -280))
	plugin.place("platform_illusion", Vector2(400, -330))
	plugin.place("tendril_portal", Vector2(600, -420))
	plugin.place("pix_mote", Vector2(760, -330))
	plugin.place("shard", Vector2(230, -340))
	plugin._mouse = Vector2(560, -300)
	plugin.place("checkpoint", plugin.placement_point("checkpoint"))
	plugin.place("plant_palm", Vector2(700, -190))
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(shown)
	dock.set_tool("select")
	plugin.update_overlays()
	await wait(30)
	EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/level_editor.png"))
	dock.set_tool("draw_ground")
	for p in [Vector2(-120, -420), Vector2(40, -470)]:
		plugin.add_draw_point(p)
	plugin._mouse = Vector2(160, -440)
	plugin._mouse_screen = plugin._xf() * plugin._mouse
	plugin._have_mouse = true
	plugin.update_overlays()
	await wait(20)
	check(dock._buttons["draw_ground"].button_pressed and not dock._buttons["select"].button_pressed, "the dock highlights the active tool")
	EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/level_editor_draw.png"))
	dock.set_tool("portal")
	plugin._mouse = Vector2(160, -440)
	plugin._have_mouse = true
	plugin.update_overlays()
	await wait(10)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(shot_path))

	print("\n%s (%d failures)" % ["EDITOR ALL PASSED" if _fails == 0 else "EDITOR FAILED", _fails])
	get_tree().quit(1 if _fails else 0)
