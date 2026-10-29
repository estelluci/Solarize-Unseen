extends CanvasLayer
## Screen tint for Solar/Lunar sight + a small status/controls readout.

const SOLAR_TINT := Color(1.0, 0.72, 0.3, 0.13)
const LUNAR_TINT := Color(0.4, 0.5, 1.0, 0.16)

var _tint: ColorRect
var _label: Label
var _party: Party
var _last_pix := -1
var _toast: Label
var _toast_time := 0.0
var _last_shards := -1


func _ready() -> void:
	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.visible = false
	add_child(_tint)

	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	add_child(_label)

	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	_toast.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.position = Vector2(16, 110)
	add_child(_toast)

	# Hide the readout during cutscenes; show notices and shard pickups.
	Cutscenes.started.connect(func(_n): _label.visible = false)
	Cutscenes.finished.connect(func(_n, _s): _label.visible = true)
	GameState.notice.connect(show_toast)
	GameState.changed.connect(_on_state_changed)
	_last_shards = GameState.shards
	Sight.changed.connect(func(_a, _e): _refresh())
	_party = get_tree().get_first_node_in_group("party")
	if _party:
		_party.changed.connect(_refresh)
	_refresh()


func show_toast(text: String, seconds := 2.0) -> void:
	_toast.text = text
	_toast_time = seconds


func _on_state_changed() -> void:
	if GameState.shards > _last_shards:
		show_toast("+%d Lumen Shard%s  (U: upgrades)" % [GameState.shards - _last_shards,
			"" if GameState.shards - _last_shards == 1 else "s"])
	_last_shards = GameState.shards
	_refresh()


func _process(delta: float) -> void:
	_toast_time -= delta
	_toast.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
	# Pix changes every frame while carrying; only rebuild text when it moves.
	if _party:
		var pix := roundi(_party.carrier_of_party().pix)
		if pix != _last_pix:
			_last_pix = pix
			_refresh()


func _refresh() -> void:
	_tint.visible = Sight.active
	_tint.color = SOLAR_TINT if Sight.eye == Sight.SOLAR else LUNAR_TINT
	var eye_state := "%s eye %s" % [Sight.eye, "open" if Sight.active else "closed"]
	if _party == null:
		_label.text = eye_state
		return
	var coop := _party.mode == Party.Mode.COOP
	var lines := PackedStringArray()
	var fairy := _party.carrier_of_party()
	lines.append("%s  —  P1: %s  ·  %s: %s  |  %s  |  Pix %d%%%s  |  Shards %d" % [
		"Co-op" if coop else "Solo", _party.leader.profile.display_name,
		"P2" if coop else "AI", _party.partner.profile.display_name, eye_state,
		roundi(fairy.pix_ratio() * 100.0), "  (carrying)" if fairy.cargo else "", GameState.shards])
	lines.append("P1: A/D move · Space jump · E sight · Click shoot · F carry · Tab swap · U upgrades · F5/F9 save/load")
	if coop:
		lines.append("P2: ←/→ move · ↑ jump · / sight · Enter shoot (auto-aim) · . carry · F2 back to AI partner")
	else:
		lines.append("Player 2: press ← → ↑ or use gamepad 2 to join  (F2 toggles co-op)")
	_label.text = "\n".join(lines)
