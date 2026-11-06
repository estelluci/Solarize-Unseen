extends Node
## Rebuilds the art guide templates (res://art/templates/) and the slot list
## (res://art/SLOTS.md) from the slot registry in scripts/art/art.gd.
##
## Run it from the editor: open tools/build_art_templates.tscn and press F6.
## (It renders, so it needs a window - it won't work with --headless.)

const FILL := Color(0.55, 0.62, 0.75, 0.28)
const EDGE := Color(0.3, 0.35, 0.45, 0.9)
const PIVOT := Color(0.95, 0.2, 0.25)
const TEXT := Color(0.12, 0.14, 0.2)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Art.TEMPLATE_DIR))
	var count := 0
	for slot in Art.registry().keys():
		var spec := Art.spec(slot)
		var vp := SubViewport.new()
		vp.size = spec.template
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var drawer := TemplateDrawer.new()
		drawer.slot = slot
		drawer.spec = spec
		vp.add_child(drawer)
		add_child(vp)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("%s%s.png" % [Art.TEMPLATE_DIR, slot]))
		vp.queue_free()
		count += 1
	_write_slot_list()
	print("Wrote %d templates and art/SLOTS.md" % count)
	get_tree().quit()


func _write_slot_list() -> void:
	var lines := PackedStringArray()
	lines.append("# Art slots")
	lines.append("")
	lines.append("Every visual in Solarize: Unseen has a slot. To replace one, save your image as `art/slots/<slot>.png` (PNG, WebP, JPG or SVG). Its guide template is `art/templates/<slot>.png`; paint over a copy of it. Press **F3** in the game to see every template in place, and **F4** to reload art while the game is running.")
	lines.append("")
	lines.append("**Size:** the game scales your image so its height matches the slot's size (\"wide\" slots match width instead). Only the proportions matter; paint at 2-4x the in-game size. In-game sizes are in game units (the Mafia is 100 units tall).")
	lines.append("")
	lines.append("**Pivot:** where the image attaches, as a fraction across and down the image (0,0 = top-left). It's the red cross on the template.")
	lines.append("")
	lines.append("Nothing needs to be set up in Godot. If something doesn't line up, add an entry for the slot in `art/art_tweaks.tres` (size, nudge, rotation, flip, pivot, tint).")
	var groups := {}
	for slot in Art.registry().keys():   # registry order keeps related slots together
		var g: String = Art.spec(slot).group
		if not groups.has(g):
			groups[g] = []
		groups[g].append(slot)
	for g in groups.keys():
		lines.append("")
		lines.append("## %s" % g)
		lines.append("")
		lines.append("| Slot (file name) | What to paint | In-game size | Pivot | Template size | Animation it keeps |")
		lines.append("| --- | --- | --- | --- | --- | --- |")
		for slot in groups[g]:
			var s := Art.spec(slot)
			var pv: Vector2 = s.pivot
			var pivot_text := "%.2f, %.2f" % [pv.x, pv.y] if s.kind in ["point", "bone"] else "-"
			lines.append("| `%s` | %s | %s | %s | %d x %d | %s |" % [slot, s.what, s.size, pivot_text, s.template.x, s.template.y, s.keeps])
	var f := FileAccess.open(ProjectSettings.globalize_path("res://art/SLOTS.md"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")


## Draws one guide: the shape area, the pivot, the direction, and labels.
class TemplateDrawer extends Node2D:
	var slot: StringName
	var spec: Dictionary

	func _draw() -> void:
		var size := Vector2(spec.template)
		var kind: String = spec.kind
		var font := ThemeDB.fallback_font
		var fs := int(clampf(minf(size.x, size.y) / 12.0, 9.0, 28.0))
		var inset := maxf(2.0, minf(size.x, size.y) * 0.04)
		var body := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		# Canvas edge, so artists see the full frame.
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color(EDGE, 0.5), false, 1.0)
		match kind:
			"point", "bone":
				if spec.points == "round":
					var r := minf(body.size.x, body.size.y) * 0.5
					draw_circle(body.get_center(), r, FILL)
					draw_arc(body.get_center(), r, 0, TAU, 64, EDGE, 2.0)
				elif kind == "bone":
					var w := body.size.x * 0.7
					var cap := Rect2(Vector2(size.x * 0.5 - w * 0.5, inset), Vector2(w, size.y - inset * 2.0))
					draw_rect(cap, FILL)
					draw_rect(cap, EDGE, false, 2.0)
					_label(font, "joint A (top)", Vector2(size.x * 0.5, inset + fs * 1.2), fs * 0.8, true)
					_label(font, "joint B (bottom)", Vector2(size.x * 0.5, size.y - inset - fs * 0.4), fs * 0.8, true)
				else:
					draw_rect(body, FILL)
					draw_rect(body, EDGE, false, 2.0)
				_arrow(spec.points, size, fs)
				var pv: Vector2 = spec.pivot
				var p := pv * size
				var cr := maxf(4.0, fs * 0.5)
				draw_circle(p, cr * 0.4, PIVOT)
				draw_arc(p, cr, 0, TAU, 24, PIVOT, 2.0)
				draw_line(p - Vector2(cr * 1.8, 0), p + Vector2(cr * 1.8, 0), PIVOT, 2.0)
				draw_line(p - Vector2(0, cr * 1.8), p + Vector2(0, cr * 1.8), PIVOT, 2.0)
			"tile":
				draw_rect(body, FILL)
				draw_rect(body, EDGE, false, 2.0)
				_label(font, "repeats in every direction: make the edges match", Vector2(size.x * 0.5, size.y - inset - fs * 0.5), fs * 0.75, true)
			"strip":
				draw_rect(body, FILL)
				var pv: Vector2 = spec.pivot
				var edge_y := size.y * pv.y
				draw_line(Vector2(0, edge_y), Vector2(size.x, edge_y), PIVOT, 2.0)
				_label(font, "repeats left to right; red line = the edge it hangs from", Vector2(size.x * 0.5, minf(edge_y + fs * 1.1, size.y - 2)), fs * 0.7, true)
			"layer":
				draw_rect(body, Color(FILL, 0.12))
				draw_line(Vector2(0, size.y * 0.6), Vector2(size.x, size.y * 0.6), EDGE, 2.0)
				_label(font, "screen height; transparent above your shapes; left and right edges must match", Vector2(size.x * 0.5, size.y * 0.6 + fs * 1.4), fs * 0.8, true)
			"screen":
				draw_rect(body, FILL)
				_label(font, "stretched over the whole screen", Vector2(size.x * 0.5, size.y * 0.5), fs * 0.8, true)
			"nine":
				draw_rect(body, FILL)
				draw_rect(body, EDGE, false, 2.0)
				var m := 24.0 if String(slot) in ["ui_dialogue_panel", "ui_menu_panel"] else 12.0
				for x in [m, size.x - m]:
					draw_line(Vector2(x, 0), Vector2(x, size.y), PIVOT, 1.0)
				for y in [m, size.y - m]:
					draw_line(Vector2(0, y), Vector2(size.x, y), PIVOT, 1.0)
				_label(font, "corners stay sharp; middle stretches", Vector2(size.x * 0.5, size.y * 0.5 + fs * 0.4), fs * 0.75, true)
			_:
				draw_rect(body, FILL)
				draw_rect(body, EDGE, false, 2.0)
		# Name and size, top-left.
		_label(font, String(slot), Vector2(inset + 4, inset + fs + 2), fs, false)
		_label(font, String(spec.size), Vector2(inset + 4, inset + fs * 2.1 + 4), fs * 0.7, false)

	func _label(font: Font, text: String, at: Vector2, size: float, centered: bool) -> void:
		var fsz := int(maxf(size, 8.0))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var pos := at - Vector2(w * 0.5, 0) if centered else at
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, TEXT)

	func _arrow(points: String, size: Vector2, fs: int) -> void:
		var c := size * 0.5
		var length := minf(size.x, size.y) * 0.3
		var dir := Vector2.ZERO
		match points:
			"down": dir = Vector2.DOWN
			"up": dir = Vector2.UP
			"faces right", "toes right", "barrel right": dir = Vector2.RIGHT
		if dir == Vector2.ZERO:
			return
		var a := c - dir * length * 0.5
		var b := c + dir * length * 0.5
		draw_line(a, b, EDGE, maxf(2.0, fs * 0.15))
		draw_line(b, b - dir.rotated(0.5) * fs * 0.8, EDGE, maxf(2.0, fs * 0.15))
		draw_line(b, b - dir.rotated(-0.5) * fs * 0.8, EDGE, maxf(2.0, fs * 0.15))
