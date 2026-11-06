class_name Art
extends RefCounted
## DROP-IN ART for every visual in the game.
##
## Each visual has a named SLOT (e.g. "mafia_head", "portal_swirl",
## "plant_palm"). To replace the drawn placeholder, save an image named after
## the slot into res://art/slots/ - e.g. res://art/slots/portal_swirl.png.
## That's all: the game finds it, draws it in place of the placeholder, and
## keeps every animation (IK poses, spins, bobs, sways, pulses, parallax...),
## because animation moves the slot, not the drawing.
##
## Each slot has a guide image in res://art/templates/ showing its shape,
## attach point (pivot) and direction, and art/SLOTS.md lists them all.
## Press F3 in-game to preview every template in place.
## Fine-tuning (size, nudge, pivot, tint) lives in res://art/art_tweaks.tres.
##
## HOW SIZE WORKS: the game scales your image so its HEIGHT matches the slot's
## standard size (some slots use width - see SLOTS.md). Any resolution works;
## only the proportions matter. Paint at 2-4x the in-game size for crisp art.

const SLOT_DIR := "res://art/slots/"
const TEMPLATE_DIR := "res://art/templates/"
const TWEAKS_PATH := "res://art/art_tweaks.tres"
const EXTENSIONS := ["png", "webp", "jpg", "svg"]
const CHARACTERS := ["mafia", "fairy"]

## Kinds of slot - how the image is placed.
##   point  : at a spot, can rotate/bob/flip; height = standard size
##   bone   : stretched from joint A to joint B; image points DOWN, top = joint A
##   rect   : stretched to fill a rectangle
##   tile   : repeats to fill an area; one repeat = standard size tall
##   strip  : repeats along a line; height = standard thickness
##   layer  : backdrop strip, as tall as the screen, repeats sideways
##   screen : stretched over the whole screen
##   nine   : UI panel/button; corners keep their size, middle stretches

## Set by F3 (or code): draw the guide templates instead of the placeholders.
static var preview_templates := false

static var _registry: Dictionary = {}
static var _cache: Dictionary = {}
static var _template_cache: Dictionary = {}
static var _drawn: Dictionary = {}
static var _overrides: Dictionary = {}
static var _tweaks: ArtTweaks
static var _tweaks_loaded := false


# ---------------------------------------------------------------- registry
## Every slot, with how it's placed and how to paint it.
static func registry() -> Dictionary:
	if _registry.is_empty():
		_build_registry()
	return _registry


static func slots() -> Array:
	var keys := registry().keys()
	keys.sort()
	return keys


static func spec(slot: StringName) -> Dictionary:
	return registry().get(slot, {})


static func _add(slot: String, kind: String, group: String, what: String, size_text: String,
		template: Vector2i, pivot: Vector2, points: String, keeps: String, fit := "height") -> void:
	_registry[StringName(slot)] = {"kind": kind, "group": group, "what": what, "size": size_text,
		"template": template, "pivot": pivot, "points": points, "keeps": keeps, "fit": fit}


static func _build_registry() -> void:
	# ---- characters (one set per character id) ----
	for c in CHARACTERS:
		var g := "Character: %s" % c.capitalize()
		_add(c + "_head", "point", g, "Head, facing right", "24 tall", Vector2i(256, 256), Vector2(0.5, 0.5), "faces right", "mirrors when turning; follows the body's lean and bob")
		_add(c + "_accessory", "point", g, "Hat or hair, sitting on top of the head" if c == "mafia" else "Hair, sitting on top of the head", "18 tall", Vector2i(256, 192), Vector2(0.5, 1.0), "faces right", "rides on the head")
		_add(c + "_torso", "bone", g, "Body from neck (top) to hips (bottom)", "shoulder-to-hip length", Vector2i(128, 256), Vector2(0.5, 0.0), "down", "leans with speed; drops when feet plant on slopes")
		_add(c + "_upper_arm", "bone", g, "Upper arm, shoulder at top", "shoulder-to-elbow length", Vector2i(64, 192), Vector2(0.5, 0.0), "down", "IK arm swing and aiming")
		_add(c + "_forearm", "bone", g, "Forearm, elbow at top", "elbow-to-wrist length", Vector2i(64, 192), Vector2(0.5, 0.0), "down", "IK arm swing and aiming")
		_add(c + "_hand", "point", g, "Hand, fingers pointing down", "9 tall", Vector2i(96, 96), Vector2(0.5, 0.3), "down", "follows the forearm")
		_add(c + "_thigh", "bone", g, "Thigh, hip at top", "hip-to-knee length", Vector2i(64, 192), Vector2(0.5, 0.0), "down", "IK walking, foot planting, tucking in jumps")
		_add(c + "_shin", "bone", g, "Shin, knee at top", "knee-to-ankle length", Vector2i(64, 192), Vector2(0.5, 0.0), "down", "IK walking, foot planting, tucking in jumps")
		_add(c + "_foot", "point", g, "Foot, toes pointing right; pivot at the ankle", "14 wide", Vector2i(160, 96), Vector2(0.3, 0.25), "toes right", "planted on slopes by IK; mirrors when turning", "width")
		if c == "mafia":
			_add("mafia_gun", "point", g, "Gun, barrel pointing right; pivot at the grip", "22 wide", Vector2i(256, 96), Vector2(0.15, 0.5), "barrel right", "aims at the mouse; recoils", "width")
		else:
			_add("fairy_wing", "point", g, "One wing, pointing up; pivot at its root (used for both wings, mirrored)", "44 tall", Vector2i(160, 384), Vector2(0.5, 1.0), "up", "flaps (faster in the air), spreads when gliding")
	# ---- portals and tendrils ----
	_add("portal_swirl", "point", "Portals", "Portal swirl (round)", "portal diameter", Vector2i(512, 512), Vector2(0.5, 0.5), "round", "spins; fades in with sight; reddens as it's damaged")
	_add("portal_core", "point", "Portals", "Portal centre", "36% of the portal radius, as a diameter", Vector2i(128, 128), Vector2(0.5, 0.5), "round", "fades with sight")
	_add("tendril_segment", "bone", "Portals", "One tendril segment, root end at top (repeated along the tendril, thinning toward the tip)", "segment length", Vector2i(64, 128), Vector2(0.5, 0.0), "down", "FABRIK reaching, curling, grabbing")
	_add("tendril_tip", "point", "Portals", "Tendril tip/claw, pointing down", "14 tall", Vector2i(96, 128), Vector2(0.5, 0.0), "down", "follows the last segment")
	# ---- the Maw ----
	_add("maw_swirl", "point", "Boss: the Maw", "Outer swirl (round)", "boss diameter", Vector2i(1024, 1024), Vector2(0.5, 0.5), "round", "spins; grows in when it emerges, collapses when it dies")
	_add("maw_mouth", "point", "Boss: the Maw", "Dark mouth (round)", "mouth diameter (half the boss)", Vector2i(512, 512), Vector2(0.5, 0.5), "round", "emerge/collapse scale")
	_add("maw_teeth", "point", "Boss: the Maw", "Ring of teeth around the mouth", "mouth diameter", Vector2i(512, 512), Vector2(0.5, 0.5), "round", "slow wobble")
	_add("maw_core_solar", "point", "Boss: the Maw", "The eye when its core is gold (Solar)", "42% of the mouth diameter", Vector2i(256, 256), Vector2(0.5, 0.5), "round", "tracks the nearest player; dims when shielded; flashes when hit")
	_add("maw_core_lunar", "point", "Boss: the Maw", "The eye when its core is silver-blue (Lunar)", "42% of the mouth diameter", Vector2i(256, 256), Vector2(0.5, 0.5), "round", "tracks the nearest player; dims when shielded; flashes when hit")
	_add("maw_shield", "point", "Boss: the Maw", "Shield bubble over the mouth", "95% of the mouth diameter", Vector2i(512, 512), Vector2(0.5, 0.5), "round", "pulses while shielded")
	_add("maw_cracks", "point", "Boss: the Maw", "Cracks overlay", "boss diameter", Vector2i(1024, 1024), Vector2(0.5, 0.5), "round", "fades in as health drops")
	_add("maw_beam", "rect", "Boss: the Maw", "Rift beam column (stretched to fit)", "stretched", Vector2i(128, 512), Vector2(0.5, 0.0), "down", "fires for half a second")
	_add("maw_beam_warning", "rect", "Boss: the Maw", "Beam warning line (stretched to fit)", "stretched", Vector2i(32, 512), Vector2(0.5, 0.0), "down", "blinks before the beam fires")
	_add("rift_orb", "point", "Boss: the Maw", "Rift orb projectile", "28 tall", Vector2i(256, 256), Vector2(0.5, 0.5), "round", "pulses and spins while homing")
	_add("gate_vines", "rect", "Boss: the Maw", "Arena gate vines (stretched to the gate)", "stretched", Vector2i(128, 512), Vector2(0.5, 1.0), "up", "sways and glows while the fight is on")
	_add("gate_post", "point", "Boss: the Maw", "Stone post beside the gate; pivot at its base", "gate height", Vector2i(64, 512), Vector2(0.5, 1.0), "up", "static")
	# ---- pickups and markers ----
	_add("pix_mote", "point", "Pickups", "Pix mote", "26 tall", Vector2i(256, 256), Vector2(0.5, 0.5), "round", "bobs; drifts with Mote Magnet")
	_add("pix_sparkle", "point", "Pickups", "Small sparkle (motes and the carry strand)", "5 tall", Vector2i(64, 64), Vector2(0.5, 0.5), "round", "orbits and drifts")
	_add("shard", "point", "Pickups", "Lumen Shard crystal", "34 tall", Vector2i(256, 256), Vector2(0.5, 0.5), "up", "bobs and rocks")
	_add("checkpoint_unlit", "point", "Pickups", "Checkpoint before it's reached; pivot at its base", "92 tall", Vector2i(128, 384), Vector2(0.5, 1.0), "up", "swaps to lit when touched")
	_add("checkpoint_lit", "point", "Pickups", "Checkpoint once reached; pivot at its base", "92 tall", Vector2i(128, 384), Vector2(0.5, 1.0), "up", "static")
	# ---- level ----
	_add("ground_fill", "tile", "Level", "Soil/rock inside every ground shape (repeats)", "one repeat = 128 tall", Vector2i(256, 256), Vector2(0, 0), "tiles", "static")
	_add("ground_top", "strip", "Level", "Grass edge along the walkable tops (repeats along the edge)", "20 thick", Vector2i(512, 80), Vector2(0, 0.3), "along the edge", "follows every slope")
	_add("platform_true_path", "rect", "Level", "Hidden true-path platform (stretched)", "stretched", Vector2i(512, 96), Vector2(0, 0), "flat", "appears with sight; tinted gold or blue by the eye")
	_add("platform_illusion", "rect", "Level", "Illusion platform as it looks with sight closed (stretched)", "stretched", Vector2i(512, 96), Vector2(0, 0), "flat", "becomes a flicker outline with sight open")
	_add("water", "tile", "Level", "Chasm water (repeats)", "one repeat = 96 tall", Vector2i(256, 256), Vector2(0, 0), "tiles", "drifts sideways")
	_add("water_surface", "strip", "Level", "Water surface edge (repeats)", "12 thick", Vector2i(512, 48), Vector2(0, 0.5), "along the edge", "drifts sideways")
	for p in [["palm", "Palm tree", Vector2i(512, 1024)], ["banana", "Banana plant", Vector2i(512, 768)], ["bamboo", "Bamboo cluster", Vector2i(256, 1024)],
			["monstera", "Monstera bush", Vector2i(512, 384)], ["fern", "Fern", Vector2i(384, 256)], ["hibiscus", "Hibiscus bush", Vector2i(512, 384)]]:
		_add("plant_" + p[0], "point", "Plants", "%s; pivot at the base" % p[1], "the plant's height (set per plant)", p[2], Vector2(0.5, 1.0), "up", "sways; randomly mirrored")
	_add("backdrop_sky", "screen", "Backdrop", "Sky (stretched over the screen)", "full screen", Vector2i(256, 720), Vector2(0, 0), "screen", "static")
	_add("backdrop_far", "layer", "Backdrop", "Far layer (volcano, sea): transparent where the sky shows; repeats sideways", "screen height", Vector2i(2048, 720), Vector2(0, 1), "screen", "slowest parallax scroll")
	_add("backdrop_mid", "layer", "Backdrop", "Middle layer (hills, palms); repeats sideways", "screen height", Vector2i(2048, 720), Vector2(0, 1), "screen", "medium parallax scroll")
	_add("backdrop_near", "layer", "Backdrop", "Near layer (jungle line); repeats sideways", "screen height", Vector2i(2048, 720), Vector2(0, 1), "screen", "fastest parallax scroll")
	# ---- effects ----
	_add("carry_tether", "strip", "Effects", "Glowing strand while the Fairy carries the Mafia (repeats)", "8 thick", Vector2i(512, 32), Vector2(0, 0.5), "along the line", "dims and flickers as Pix runs out")
	_add("shot_tracer", "strip", "Effects", "Gunshot trail (repeats)", "3 thick", Vector2i(256, 32), Vector2(0, 0.5), "along the line", "flashes for a moment")
	_add("pix_meter_frame", "rect", "Effects", "Pix meter background over the Fairy (stretched)", "38 x 5", Vector2i(256, 48), Vector2(0, 0), "flat", "fades when full")
	_add("pix_meter_fill", "rect", "Effects", "Pix meter fill (cropped to the amount left)", "38 x 5", Vector2i(256, 48), Vector2(0, 0), "flat", "shrinks; turns pink when low")
	# ---- UI ----
	_add("ui_dialogue_panel", "nine", "UI", "Dialogue box background (corners stay sharp)", "stretched; 24 px corners", Vector2i(384, 192), Vector2(0, 0), "panel", "typewriter text appears on top")
	_add("ui_letterbox", "rect", "UI", "Cinematic bar (top and bottom)", "stretched", Vector2i(512, 96), Vector2(0, 0), "flat", "slides in and out")
	_add("ui_menu_panel", "nine", "UI", "Upgrade menu background", "stretched; 24 px corners", Vector2i(384, 256), Vector2(0, 0), "panel", "static")
	_add("ui_button", "nine", "UI", "Menu button", "stretched; 12 px corners", Vector2i(192, 64), Vector2(0, 0), "panel", "static")
	_add("ui_button_hover", "nine", "UI", "Menu button under the mouse / selected", "stretched; 12 px corners", Vector2i(192, 64), Vector2(0, 0), "panel", "static")
	_add("ui_button_disabled", "nine", "UI", "Locked or owned upgrade button", "stretched; 12 px corners", Vector2i(192, 64), Vector2(0, 0), "panel", "static")
	_add("ui_boss_bar_frame", "rect", "UI", "Boss health bar background", "606 x 22", Vector2i(512, 48), Vector2(0, 0), "flat", "static")
	_add("ui_boss_bar_fill", "rect", "UI", "Boss health bar fill (cropped to health; tinted by the core)", "600 x 16", Vector2i(512, 32), Vector2(0, 0), "flat", "shrinks with damage; gold, blue or purple")


# ---------------------------------------------------------------- loading
## The image for a slot, or null if nobody has dropped one in yet.
static func texture(slot: StringName) -> Texture2D:
	if _overrides.has(slot):
		return _overrides[slot]
	if preview_templates:
		if not _template_cache.has(slot):
			_template_cache[slot] = _find(TEMPLATE_DIR, slot)
		if _template_cache[slot]:
			return _template_cache[slot]
	if Engine.is_editor_hint():
		return _find(SLOT_DIR, slot)   # always fresh in the editor
	if not _cache.has(slot):
		_cache[slot] = _find(SLOT_DIR, slot)
	return _cache[slot]


static func has_art(slot: StringName) -> bool:
	return texture(slot) != null


static func _find(dir: String, slot: StringName) -> Texture2D:
	for ext in EXTENSIONS:
		var path := "%s%s.%s" % [dir, slot, ext]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


## Use an image for a slot at runtime (skins, tests). null removes it.
static func set_override(slot: StringName, tex: Texture2D) -> void:
	if tex == null:
		_overrides.erase(slot)
	else:
		_overrides[slot] = tex


static func clear_overrides() -> void:
	_overrides.clear()


## Forget cached files (after adding art while the game runs).
static func reload() -> void:
	_cache.clear()
	_template_cache.clear()
	_drawn.clear()
	_tweaks_loaded = false


## Load every slot's image up front (avoids a blank first frame).
static func preload_all() -> void:
	for slot in registry().keys():
		texture(slot)


## A texture loaded in the middle of drawing can show blank for that one
## draw, so the first time each slot is drawn we ask for one more redraw.
static func _first_draw(ci: CanvasItem, slot: StringName) -> void:
	var key := "%s|%d|%s" % [slot, ci.get_instance_id(), preview_templates]
	if not _drawn.has(key):
		_drawn[key] = true
		ci.queue_redraw.call_deferred()


static func tweak(slot: StringName) -> ArtTweak:
	if not _tweaks_loaded:
		_tweaks_loaded = true
		_tweaks = load(TWEAKS_PATH) as ArtTweaks if ResourceLoader.exists(TWEAKS_PATH) else null
	if _tweaks == null:
		return null
	return _tweaks.tweaks.get(slot)


static func _pivot(slot: StringName, t: ArtTweak) -> Vector2:
	if t and t.pivot.x >= 0.0:
		return t.pivot
	return spec(slot).get("pivot", Vector2(0.5, 0.5))


# ---------------------------------------------------------------- drawing
# Each returns true if it drew art, false if the caller should draw its
# placeholder instead:   if not Art.draw_point(self, &"shard", ...): <placeholder>

## A piece at `at`, scaled so its height (or width, per the slot) = `size`.
## `mirror` flips it (x = -1 faces left).
static func draw_point(ci: CanvasItem, slot: StringName, at: Vector2, size: float, rot := 0.0,
		tint := Color.WHITE, mirror := Vector2.ONE) -> bool:
	var tex := texture(slot)
	if tex == null:
		return false
	_first_draw(ci, slot)
	var t := tweak(slot)
	var sz := tex.get_size()
	var by_width: bool = spec(slot).get("fit", "height") == "width"
	var k := size / maxf(sz.x if by_width else sz.y, 1.0) * (t.scale if t else 1.0)
	_place(ci, tex, slot, t, at, rot, Vector2(k * mirror.x, k * mirror.y), tint)
	return true


## A piece stretched from joint `a` to joint `b` (image points down, top = a).
## `width_scale` makes it thinner/thicker (tendrils taper).
static func draw_bone(ci: CanvasItem, slot: StringName, a: Vector2, b: Vector2, tint := Color.WHITE,
		mirror_x := 1.0, width_scale := 1.0) -> bool:
	var tex := texture(slot)
	if tex == null:
		return false
	_first_draw(ci, slot)
	var length := a.distance_to(b)
	if length < 0.01:
		return true
	var t := tweak(slot)
	var k := length / maxf(tex.get_size().y, 1.0) * (t.scale if t else 1.0)
	_place(ci, tex, slot, t, a, (b - a).angle() - PI * 0.5, Vector2(k * mirror_x * width_scale, k), tint)
	return true


static func _place(ci: CanvasItem, tex: Texture2D, slot: StringName, t: ArtTweak, at: Vector2,
		rot: float, scl: Vector2, tint: Color) -> void:
	var sz := tex.get_size()
	if t:
		rot += deg_to_rad(t.rotation_degrees)
		if t.flip_h:
			scl.x = -scl.x
		tint *= t.tint
	ci.draw_set_transform(at, rot, scl)
	ci.draw_texture(tex, -_pivot(slot, t) * sz + (t.offset if t else Vector2.ZERO), tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Stretched to fill `rect`. `crop` (0-1) shows only the left part (meters).
static func draw_rect(ci: CanvasItem, slot: StringName, rect: Rect2, tint := Color.WHITE, crop := 1.0) -> bool:
	var tex := texture(slot)
	if tex == null:
		return false
	_first_draw(ci, slot)
	var t := tweak(slot)
	if t:
		tint *= t.tint
	if crop >= 0.999:
		ci.draw_texture_rect(tex, rect, false, tint)
	else:
		var sz := tex.get_size()
		var part := Rect2(rect.position, Vector2(rect.size.x * clampf(crop, 0.0, 1.0), rect.size.y))
		ci.draw_texture_rect_region(tex, part, Rect2(Vector2.ZERO, Vector2(sz.x * clampf(crop, 0.0, 1.0), sz.y)), tint)
	return true


## Repeats over a polygon; one repeat is `tile_height` tall. `scroll` slides it.
static func draw_tiled(ci: CanvasItem, slot: StringName, points: PackedVector2Array, tile_height: float,
		tint := Color.WHITE, scroll := Vector2.ZERO) -> bool:
	var tex := texture(slot)
	if tex == null or points.size() < 3:
		return tex != null
	_first_draw(ci, slot)
	var t := tweak(slot)
	if t:
		tint *= t.tint
		tile_height *= t.scale
	_enable_repeat(ci)
	var sz := tex.get_size()
	var tile := Vector2(tile_height * sz.x / maxf(sz.y, 1.0), tile_height)
	var uvs := PackedVector2Array()
	for p in points:
		uvs.append((p + scroll) / tile)
	ci.draw_colored_polygon(points, tint, uvs, tex)
	return true


## Repeats along the line a -> b, `thickness` thick, hanging below the line
## by default (`above` = how much of the thickness sits above it).
static func draw_strip(ci: CanvasItem, slot: StringName, a: Vector2, b: Vector2, thickness: float,
		tint := Color.WHITE, scroll := 0.0, above := -1.0) -> bool:
	var tex := texture(slot)
	if tex == null:
		return false
	_first_draw(ci, slot)
	var length := a.distance_to(b)
	if length < 0.01:
		return true
	var t := tweak(slot)
	if t:
		tint *= t.tint
		thickness *= t.scale
	if above < 0.0:
		above = thickness * float(spec(slot).get("pivot", Vector2(0, 0)).y)
	_enable_repeat(ci)
	var dir := (b - a) / length
	var down := Vector2(-dir.y, dir.x)
	if down.y < 0.0:
		down = -down
	var sz := tex.get_size()
	var tile_w := thickness * sz.x / maxf(sz.y, 1.0)
	var u0 := scroll / tile_w
	var u1 := (scroll + length) / tile_w
	var pts := PackedVector2Array([a - down * above, b - down * above, b + down * (thickness - above), a + down * (thickness - above)])
	var uvs := PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)])
	ci.draw_polygon(pts, PackedColorArray([tint]), uvs, tex)
	return true


static func _enable_repeat(ci: CanvasItem) -> void:
	if ci.texture_repeat != CanvasItem.TEXTURE_REPEAT_ENABLED:
		ci.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


## UI: a nine-slice StyleBox for a slot, or null if there's no art.
static func stylebox(slot: StringName, default_margin := 12) -> StyleBoxTexture:
	var tex := texture(slot)
	if tex == null:
		return null
	var t := tweak(slot)
	var m := t.nine_slice_margin if t and t.nine_slice_margin >= 0 else default_margin
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = m
	box.texture_margin_right = m
	box.texture_margin_top = m
	box.texture_margin_bottom = m
	box.content_margin_left = m
	box.content_margin_right = m
	box.content_margin_top = m * 0.75
	box.content_margin_bottom = m * 0.75
	if t:
		box.modulate_color = t.tint
	return box
