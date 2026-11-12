@tool
extends VBoxContainer
## The "Level" dock: tools, snapping, the piece palette and a level summary.
## The plugin listens to its signals and reads its settings.

signal tool_changed(tool: String)   # "select", "draw_ground" or a piece id
signal new_level_pressed
signal settings_changed

const Pieces := preload("res://addons/rift_level_editor/level_pieces.gd")

var snap_on := true
var snap_step := 10.0
var stand_on_ground := true
var ground_depth := 300.0
var show_markers := true
var tool := "select"

var _group := ButtonGroup.new()
var _buttons := {}   # tool -> Button
var _hint: Label
var _info: RichTextLabel


func _init() -> void:
	name = "Level"
	custom_minimum_size = Vector2(220, 0)


func _ready() -> void:
	if get_child_count() > 0:
		return
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	var new_btn := Button.new()
	new_btn.text = "New level..."
	new_btn.tooltip_text = "Make a new level scene with both characters, the camera, the backdrop and starting ground already set up."
	new_btn.pressed.connect(func(): new_level_pressed.emit())
	box.add_child(new_btn)

	box.add_child(_header("Tools"))
	var tools := HBoxContainer.new()
	box.add_child(tools)
	var sel := _tool_button("select", "Select", "Normal Godot selection. Select a ground, platform, trigger, plant, water or the Maw to get drag handles.\nOn a ground: drag a corner to move it, click a + to add a corner, right-click a corner to delete it.", Color(0.8, 0.85, 0.95))
	sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(sel)
	var draw := _tool_button("draw_ground", "Draw ground", "Click along the walkable surface, left to right.\nDouble-click, Enter or right-click: finish (fills down to the depth below).\nClick the first point again: finish as a closed shape (floating rock).\nBackspace: undo last point. Esc: cancel.", Color(0.45, 0.32, 0.25))
	draw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(draw)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	_hint.add_theme_font_size_override("font_size", 12)
	box.add_child(_hint)

	box.add_child(_header("Snapping"))
	var snap_row := HBoxContainer.new()
	box.add_child(snap_row)
	var snap_check := CheckBox.new()
	snap_check.text = "Snap to grid"
	snap_check.button_pressed = snap_on
	snap_check.toggled.connect(func(v): snap_on = v; settings_changed.emit())
	snap_row.add_child(snap_check)
	var step := SpinBox.new()
	step.min_value = 1
	step.max_value = 200
	step.value = snap_step
	step.suffix = "px"
	step.tooltip_text = "Grid size for placing pieces, drawing ground and dragging handles."
	step.value_changed.connect(func(v): snap_step = v; settings_changed.emit())
	snap_row.add_child(step)
	var stand := CheckBox.new()
	stand.text = "Stand on ground"
	stand.tooltip_text = "Checkpoints, plants, triggers and the boss arena drop onto the ground under the cursor."
	stand.button_pressed = stand_on_ground
	stand.toggled.connect(func(v): stand_on_ground = v; settings_changed.emit())
	box.add_child(stand)
	var depth_row := HBoxContainer.new()
	box.add_child(depth_row)
	var dl := Label.new()
	dl.text = "Ground depth"
	dl.tooltip_text = "How far drawn ground fills down below its lowest point."
	depth_row.add_child(dl)
	var depth := SpinBox.new()
	depth.min_value = 20
	depth.max_value = 2000
	depth.step = 10
	depth.value = ground_depth
	depth.suffix = "px"
	depth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	depth.value_changed.connect(func(v): ground_depth = v; settings_changed.emit())
	depth_row.add_child(depth)
	var markers := CheckBox.new()
	markers.text = "Show markers"
	markers.tooltip_text = "Draw outlines and names for things that are invisible in the editor (portals, motes, checkpoints, water, the Maw's arena) and the fall line."
	markers.button_pressed = show_markers
	markers.toggled.connect(func(v): show_markers = v; settings_changed.emit())
	box.add_child(markers)

	for cat in Pieces.CATEGORIES:
		box.add_child(_header(cat))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(grid)
		for id in Pieces.ids_in(cat):
			var b := _tool_button(id, Pieces.label(id), Pieces.tooltip(id), Pieces.color(id))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(b)

	box.add_child(_header("This level"))
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.add_theme_font_size_override("normal_font_size", 12)
	box.add_child(_info)
	set_tool("select")


func _header(text: String) -> Control:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	return l


func _tool_button(id: String, text: String, tip: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = _group
	b.tooltip_text = tip
	b.icon = _swatch(col)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.pressed.connect(func(): set_tool(id))
	_buttons[id] = b
	return b


static func _swatch(col: Color) -> Texture2D:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 12:
		for x in 12:
			if Vector2(x - 5.5, y - 5.5).length() <= 5.2:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func set_tool(id: String) -> void:
	tool = id
	if _buttons.has(id) and not _buttons[id].button_pressed:
		_buttons[id].button_pressed = true   # only "toggled" fires, so no loop
	match id:
		"select":
			_hint.text = "Select something to get its handles."
		"draw_ground":
			_hint.text = "Click along the surface. Double-click / Enter: finish. Click the first point: closed shape. Esc: cancel."
		_:
			_hint.text = "Click in the level to place: %s.\nKeep clicking to place more. Right-click or Esc: stop." % Pieces.label(id)
	tool_changed.emit(id)


func set_info(bbcode: String) -> void:
	if _info:
		_info.text = bbcode
