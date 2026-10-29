class_name JungleBackdrop
extends CanvasLayer
## Sunset-over-the-island background: sky gradient, sun, a smoking volcano
## and the sea on the horizon, then layers of jungle hills and palms that
## scroll slower than the level (parallax). Drawn in code — swap any layer
## for painted art later by replacing its _draw.
##
## Parallax is done by hand: each layer is offset by the camera position times
## its `depth` (0 = fixed to the screen, 1 = moves with the level) and tiled
## horizontally, so the backdrop works for any level length.

const SKY_TOP := Color(0.11, 0.09, 0.24)
const SKY_MID := Color(0.45, 0.2, 0.38)
const SKY_LOW := Color(0.9, 0.46, 0.36)
const SKY_HORIZON := Color(0.98, 0.74, 0.45)

## Screen y of the horizon when the camera is at `reference_y`.
@export var horizon := 420.0
@export var reference_y := -150.0

var _layers: Array[Node2D] = []


func _ready() -> void:
	layer = -10
	var sky := TextureRect.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 0.78, 1.0])
	grad.colors = PackedColorArray([SKY_TOP, SKY_MID, SKY_LOW, SKY_HORIZON])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	sky.texture = tex
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	for spec in [["far", 0.06, 2600.0], ["mid", 0.22, 1900.0], ["near", 0.45, 1500.0]]:
		var l := BackdropLayer.new()
		l.kind = spec[0]
		l.depth = spec[1]
		l.tile_width = spec[2]
		l.horizon = horizon
		add_child(l)
		_layers.append(l)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var pos := cam.get_screen_center_position()
	for l in _layers:
		l.position = Vector2(-fposmod(pos.x * l.depth, l.tile_width),
			-(pos.y - reference_y) * l.depth * 0.6)


## One horizontal strip of scenery, drawn three times side by side so it tiles.
class BackdropLayer extends Node2D:
	var kind := "far"
	var depth := 0.1
	var tile_width := 2000.0
	var horizon := 420.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		if kind == "far":
			queue_redraw()  # sea shimmer + smoke

	func _draw() -> void:
		for i in 3:
			match kind:
				"far": _far(i * tile_width)
				"mid": _mid(i * tile_width)
				"near": _near(i * tile_width)

	func _far(x0: float) -> void:
		var h := horizon
		# Sun + glow
		if true:
			var sun := Vector2(x0 + tile_width * 0.62, h - 70.0)
			for r in [120.0, 90.0, 66.0]:
				draw_circle(sun, r, Color(1.0, 0.82, 0.5, 0.08))
			draw_circle(sun, 48.0, Color(1.0, 0.86, 0.58))
		# Sea
		draw_rect(Rect2(x0, h, tile_width, 900.0), Color(0.36, 0.25, 0.42))
		draw_rect(Rect2(x0, h, tile_width, 6.0), Color(0.98, 0.7, 0.5, 0.8))
		for k in 22:
			var y := h + 10.0 + k * 9.0
			var xx := x0 + fposmod(k * 137.0 + _time * (8.0 + k), tile_width)
			draw_line(Vector2(xx, y), Vector2(xx + 40.0 + k * 2.0, y), Color(1.0, 0.75, 0.55, 0.35 - k * 0.012), 2.0)
		# Distant ridge
		var ridge := PackedVector2Array([Vector2(x0, h)])
		for k in 13:
			ridge.append(Vector2(x0 + k * tile_width / 12.0, h - 40.0 - 30.0 * absf(sin(k * 1.7))))
		ridge.append(Vector2(x0 + tile_width, h))
		draw_colored_polygon(ridge, Color(0.33, 0.22, 0.38))
		# Volcano with a glowing crater and a drifting smoke plume
		var vx := x0 + tile_width * 0.25
		var cone := PackedVector2Array([Vector2(vx - 420, h + 2), Vector2(vx - 70, h - 230),
			Vector2(vx - 30, h - 236), Vector2(vx + 30, h - 236), Vector2(vx + 70, h - 230), Vector2(vx + 440, h + 2)])
		draw_colored_polygon(cone, Color(0.24, 0.15, 0.27))
		draw_colored_polygon(PackedVector2Array([Vector2(vx - 30, h - 236), Vector2(vx + 30, h - 236),
			Vector2(vx + 18, h - 228), Vector2(vx - 18, h - 228)]), Color(1.0, 0.5, 0.25, 0.9))
		draw_circle(Vector2(vx, h - 238), 34.0, Color(1.0, 0.45, 0.2, 0.12))
		for k in 7:
			var t := fposmod(_time * 0.05 + k / 7.0, 1.0)
			var p := Vector2(vx + t * 160.0 + sin(t * 6.0 + k) * 12.0, h - 250.0 - t * 170.0)
			draw_circle(p, 14.0 + t * 30.0, Color(0.55, 0.45, 0.55, 0.28 * (1.0 - t)))

	func _mid(x0: float) -> void:
		var h := horizon + 30.0
		var hills := PackedVector2Array([Vector2(x0, h + 400)])
		for k in 25:
			var x := x0 + k * tile_width / 24.0
			hills.append(Vector2(x, h - 30.0 - 45.0 * (0.5 + 0.5 * sin(k * 0.9 + 1.0)) - 20.0 * sin(k * 2.3)))
		hills.append(Vector2(x0 + tile_width, h + 400))
		draw_colored_polygon(hills, Color(0.17, 0.27, 0.27))
		for k in 7:
			var base := Vector2(x0 + 120.0 + k * tile_width / 7.0, h - 40.0 - 25.0 * sin(k * 1.3))
			_palm(base, 120.0 + 40.0 * sin(k * 2.1), Color(0.11, 0.18, 0.19), k)

	func _near(x0: float) -> void:
		var h := horizon + 110.0
		var line := PackedVector2Array([Vector2(x0, h + 400)])
		for k in 41:
			var x := x0 + k * tile_width / 40.0
			line.append(Vector2(x, h - 20.0 * absf(sin(k * 1.1)) - 12.0 * sin(k * 3.7)))
		line.append(Vector2(x0 + tile_width, h + 400))
		draw_colored_polygon(line, Color(0.08, 0.16, 0.13))
		for k in 16:
			var c := Vector2(x0 + k * tile_width / 16.0 + 30.0, h - 6.0)
			draw_circle(c, 28.0 + 10.0 * sin(k * 1.9), Color(0.09, 0.18, 0.14))
		for k in 5:
			_palm(Vector2(x0 + 60.0 + k * tile_width / 5.0, h), 190.0 + 30.0 * sin(k * 1.4), Color(0.06, 0.12, 0.1), k + 3)

	func _palm(base: Vector2, height: float, color: Color, seed_i: int) -> void:
		var bend := 26.0 * sin(seed_i * 1.7)
		var pts := PackedVector2Array()
		for i in 9:
			var t := i / 8.0
			pts.append(base + Vector2(bend * t * t, -height * t))
		draw_polyline(pts, color, 7.0)
		var top := pts[pts.size() - 1]
		for f in 7:
			var ang := -PI * 0.5 + (f - 3) * 0.48 + sin(seed_i + f) * 0.1
			var dir := Vector2.RIGHT.rotated(ang)
			var tip := top + dir * height * 0.42 + Vector2(0, height * 0.12)
			var mid := top + dir * height * 0.24 + Vector2(0, -height * 0.03)
			draw_polyline(PackedVector2Array([top, mid, tip]), color, 5.0)
