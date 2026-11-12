@tool
extends RefCounted
## The level editor's palette: every piece you can place, how to build it, and
## the geometry helpers (snapping, standing on ground, turning a drawn line
## into a Ground shape). No editor code here, so the tests can use it too.
##
## To add a piece: add an entry to CATALOG and a branch in create().

const GroundScript := preload("res://scripts/world/ground.gd")
const PlatformScript := preload("res://scripts/world/sight_platform.gd")
const PortalScript := preload("res://scripts/world/portal.gd")
const TendrilScript := preload("res://scripts/world/portal_tendril.gd")
const MoteScript := preload("res://scripts/world/pix_mote.gd")
const ShardScript := preload("res://scripts/world/shard_pickup.gd")
const CheckpointScript := preload("res://scripts/world/checkpoint.gd")
const TriggerScript := preload("res://scripts/cutscene/cutscene_trigger.gd")
const PlantScript := preload("res://scripts/world/decor/jungle_plant.gd")
const OceanScript := preload("res://scripts/world/decor/ocean.gd")
const MawScript := preload("res://scripts/boss/maw_boss.gd")
const GateScript := preload("res://scripts/boss/arena_gate.gd")

## id: [label, category, folder under Level ("" = Level itself, "/X" = scene
## root), stands on ground, colour, tooltip]
const CATALOG := {
	"ground_block": ["Ground block", "Terrain", "", false, Color(0.45, 0.32, 0.25),
		"A 400-wide slab of jungle ground. Click to drop it with its top edge at the cursor.\nSelect it afterwards to drag its corners."],
	"ground_slope": ["Slope", "Terrain", "", false, Color(0.45, 0.32, 0.25),
		"A ramp rising to the right. The click point is the bottom-left of the slope."],
	"floating_rock": ["Floating rock", "Terrain", "", false, Color(0.4, 0.3, 0.3),
		"A small floating island (no flowers). Good stepping stone."],
	"basalt_wall": ["Basalt wall", "Terrain", "", false, Color(0.3, 0.28, 0.3),
		"A tall dark-rock wall. Click where its base should be. Wall Jump works on it."],
	"water": ["Water gap", "Terrain", "/Water", false, Color(0.2, 0.55, 0.65),
		"Sea water for the bottom of a gap. Click on the surface level; drag its end handles to the gap's edges.\nWater is only visual: falling past the fall line respawns you."],
	"platform_true": ["True path", "Sight", "Platforms", false, Color(1.0, 0.8, 0.3),
		"Invisible and not solid until a player opens their eyes (E). Hidden truth."],
	"platform_illusion": ["Illusion", "Sight", "Platforms", false, Color(0.7, 0.5, 1.0),
		"Looks solid with eyes closed, but you fall straight through it."],
	"platform_solar": ["Solar only", "Sight", "Platforms", false, Color(1.0, 0.65, 0.2),
		"Only the Solar eye can see (and stand on) it."],
	"platform_lunar": ["Lunar only", "Sight", "Platforms", false, Color(0.6, 0.75, 1.0),
		"Only the Lunar eye can see (and stand on) it."],
	"portal": ["Portal", "Enemies", "Portals", false, Color(0.75, 0.3, 0.9),
		"An enemy portal: touching it respawns you. Visible only with eyes open; 3 shots seal it."],
	"tendril_portal": ["Tendril portal", "Enemies", "Portals", false, Color(0.85, 0.25, 0.7),
		"A small portal with three IK tendrils that grab whoever comes close. 5 shots seal it.\nPlace it above where players walk."],
	"boss_arena": ["Boss arena", "Enemies", "", true, Color(0.95, 0.2, 0.45),
		"The Maw, its vine gate and its intro cutscene, set up and linked.\nClick on the arena floor (draw the floor first). Drag the arena handles to fit."],
	"pix_mote": ["Pix mote", "Pickups", "Pickups", false, Color(0.5, 0.95, 1.0),
		"Refills the Fairy's Pix. Place along long carries."],
	"shard": ["Lumen shard", "Pickups", "Shards", false, Color(1.0, 0.9, 0.4),
		"Upgrade currency. Each one gets its own id automatically, so it's only collected once."],
	"checkpoint": ["Checkpoint", "Pickups", "Checkpoints", true, Color(1.0, 0.75, 0.4),
		"Walk past it to set the respawn point for both players."],
	"cutscene_trigger": ["Cutscene", "Story", "Cutscenes", true, Color(1.0, 0.6, 0.9),
		"Plays a .cutscene file when a player walks into it. Pick the file in the Inspector."],
	"sign": ["Sign", "Story", "Signs", false, Color(0.85, 0.82, 0.95),
		"A floating text hint. Edit the text in the Inspector."],
	"plant_palm": ["Palm", "Decor", "Plants", true, Color(0.3, 0.6, 0.3), "Decoration only (no collision)."],
	"plant_banana": ["Banana", "Decor", "Plants", true, Color(0.4, 0.7, 0.3), "Decoration only (no collision)."],
	"plant_bamboo": ["Bamboo", "Decor", "Plants", true, Color(0.55, 0.65, 0.3), "Decoration only (no collision)."],
	"plant_monstera": ["Monstera", "Decor", "Plants", true, Color(0.25, 0.55, 0.3), "Decoration only (no collision)."],
	"plant_fern": ["Fern", "Decor", "Plants", true, Color(0.35, 0.6, 0.35), "Decoration only (no collision)."],
	"plant_hibiscus": ["Hibiscus", "Decor", "Plants", true, Color(0.9, 0.3, 0.4), "Decoration only (no collision)."],
}

const CATEGORIES := ["Terrain", "Sight", "Enemies", "Pickups", "Story", "Decor"]
const PLANTS := {
	"plant_palm": [0, 210.0], "plant_monstera": [1, 65.0], "plant_fern": [2, 34.0],
	"plant_banana": [3, 130.0], "plant_hibiscus": [4, 60.0], "plant_bamboo": [5, 190.0],
}


static func label(id: String) -> String:
	return CATALOG[id][0]


static func category(id: String) -> String:
	return CATALOG[id][1]


static func folder(id: String) -> String:
	return CATALOG[id][2]


static func stands_on_ground(id: String) -> bool:
	return CATALOG[id][3]


static func color(id: String) -> Color:
	return CATALOG[id][4]


static func tooltip(id: String) -> String:
	return CATALOG[id][5]


static func ids_in(cat: String) -> Array:
	var out := []
	for id in CATALOG.keys():
		if category(id) == cat:
			out.append(id)
	return out


## Build a piece. `at` is where the user clicked in the parent's space. The
## returned node is not in the tree yet. `ctx` gives scene facts some pieces
## need: {"level_name": String, "shard_ids": Array, "global_at": Vector2}.
static func create(id: String, at: Vector2, ctx := {}) -> Node:
	var n: Node
	match id:
		"ground_block":
			n = _ground("Ground", [Vector2(-200, 0), Vector2(200, 0), Vector2(200, 100), Vector2(-200, 100)])
		"ground_slope":
			n = _ground("Slope", [Vector2(0, 0), Vector2(240, -120), Vector2(240, 100), Vector2(0, 100)])
		"floating_rock":
			n = _ground("FloatingRock", [Vector2(-70, 0), Vector2(70, 0), Vector2(50, 30), Vector2(0, 46), Vector2(-50, 30)])
			n.flowers = false
		"basalt_wall":
			n = _ground("BasaltWall", [Vector2(-40, -360), Vector2(40, -360), Vector2(40, 0), Vector2(-40, 0)])
			n.style = GroundScript.Style.BASALT
		"water":
			n = Node2D.new()
			n.set_script(OceanScript)
			n.name = "Water"
			n.surface_y = at.y
			n.from_x = at.x - 200.0
			n.to_x = at.x + 200.0
			return n   # Ocean draws in its parent's space, so it stays at the origin
		"platform_true", "platform_illusion", "platform_solar", "platform_lunar":
			n = StaticBody2D.new()
			n.set_script(PlatformScript)
			n.name = {"platform_true": "TruePath", "platform_illusion": "Illusion",
				"platform_solar": "SolarPlatform", "platform_lunar": "LunarPlatform"}[id]
			n.kind = PlatformScript.Kind.ILLUSION if id == "platform_illusion" else PlatformScript.Kind.TRUE_PATH
			n.size = Vector2(120, 20)
			if id == "platform_solar":
				n.for_eye = &"Solar"
			elif id == "platform_lunar":
				n.for_eye = &"Lunar"
		"portal":
			n = Area2D.new()
			n.set_script(PortalScript)
			n.name = "Portal"
		"tendril_portal":
			n = Area2D.new()
			n.set_script(PortalScript)
			n.name = "TendrilPortal"
			n.radius = 28.0
			n.shots_to_seal = 5
			for angle in [60.0, 90.0, 120.0]:
				var t := Node2D.new()
				t.set_script(TendrilScript)
				t.name = "Tendril%d" % int(angle)
				t.angle_degrees = angle
				n.add_child(t)
		"boss_arena":
			n = _boss_arena(ctx.get("global_at", at))
		"pix_mote":
			n = Area2D.new()
			n.set_script(MoteScript)
			n.name = "PixMote"
		"shard":
			n = Area2D.new()
			n.set_script(ShardScript)
			n.name = "Shard"
			n.shard_id = unique_shard_id(ctx.get("level_name", "level"), ctx.get("shard_ids", []))
		"checkpoint":
			n = Area2D.new()
			n.set_script(CheckpointScript)
			n.name = "Checkpoint"
		"cutscene_trigger":
			n = Area2D.new()
			n.set_script(TriggerScript)
			n.name = "CutsceneTrigger"
		"sign":
			var l := Label.new()
			l.name = "Sign"
			l.text = "Type your hint here"
			l.add_theme_font_size_override("font_size", 14)
			l.add_theme_color_override("font_color", Color(0.85, 0.82, 0.95))
			l.position = at - Vector2(0, 30)
			l.size = Vector2(360, 60)
			return l
		_:
			if PLANTS.has(id):
				n = Node2D.new()
				n.set_script(PlantScript)
				n.name = label(id).replace(" ", "")
				n.kind = PLANTS[id][0]
				n.height = PLANTS[id][1]
			else:
				push_error("Unknown level piece: %s" % id)
				return null
	n.position = at
	return n


static func _ground(node_name: String, pts: Array) -> Node:
	var g := StaticBody2D.new()
	g.set_script(GroundScript)
	g.name = node_name
	g.points = PackedVector2Array(pts)
	return g


## Arena holder at the clicked floor point with the Maw hovering above, a
## gate at the left edge (linked to the Maw) and the intro trigger just inside.
static func _boss_arena(global_floor: Vector2) -> Node:
	var arena := Node2D.new()
	arena.name = "BossArena"
	var maw := Area2D.new()
	maw.set_script(MawScript)
	maw.name = "TheMaw"
	maw.position = Vector2(0, -320)
	maw.floor_y = global_floor.y
	maw.arena_left = global_floor.x - 630.0
	maw.arena_right = global_floor.x + 630.0
	arena.add_child(maw)
	var gate := StaticBody2D.new()
	gate.set_script(GateScript)
	gate.name = "Gate"
	gate.position = Vector2(-660, 0)
	gate.boss_path = NodePath("../TheMaw")
	arena.add_child(gate)
	var trig := Area2D.new()
	trig.set_script(TriggerScript)
	trig.name = "BossIntro"
	trig.position = Vector2(-430, 0)
	trig.cutscene = "res://cutscenes/boss_intro.cutscene"
	trig.skip_if_flag = &"maw_defeated"
	arena.add_child(trig)
	return arena


static func unique_shard_id(level_name: String, taken: Array) -> String:
	var base := level_name.to_snake_case()
	var i := 1
	while ("%s_shard_%d" % [base, i]) in taken:
		i += 1
	return "%s_shard_%d" % [base, i]


# ---------------------------------------------------------------- geometry
static func snap(p: Vector2, step: float) -> Vector2:
	if step <= 0.0:
		return p
	return p.snapped(Vector2(step, step))


## Twice the signed area. Positive = clockwise on screen (y down), which is
## the winding Ground expects (tops run left to right).
static func signed_area(pts: PackedVector2Array) -> float:
	var s := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		s += a.x * b.y - b.x * a.y
	return s


static func clockwise(pts: PackedVector2Array) -> PackedVector2Array:
	if signed_area(pts) < 0.0:
		var r := pts.duplicate()
		r.reverse()
		return r
	return pts.duplicate()


## A drawn walkable line (any direction) becomes a solid shape: the line is
## the top, and the shape drops straight down to `depth` below its lowest point.
static func surface_to_polygon(line: PackedVector2Array, depth: float) -> PackedVector2Array:
	var top := line.duplicate()
	if top.size() >= 2 and top[0].x > top[top.size() - 1].x:
		top.reverse()   # always left to right
	var bottom := -INF
	for p in top:
		bottom = maxf(bottom, p.y)
	bottom += depth
	var out := top.duplicate()
	out.append(Vector2(top[top.size() - 1].x, bottom))
	out.append(Vector2(top[0].x, bottom))
	return clockwise(out)


## Height of the nearest walkable top at or just below `p` (global space), or
## NAN. `grounds` is a list of global-space point arrays.
static func ground_y_below(grounds: Array, p: Vector2, look_above := 40.0) -> float:
	var best := NAN
	for pts in grounds:
		var n: int = pts.size()
		for i in n:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % n]
			if b.x - a.x <= 1.0 or absf(rad_to_deg((b - a).angle())) > 50.0:
				continue   # only upward-facing edges, like Ground.top_edges()
			if p.x < a.x or p.x > b.x:
				continue
			var y := lerpf(a.y, b.y, (p.x - a.x) / (b.x - a.x))
			if y >= p.y - look_above and (is_nan(best) or y < best):
				best = y
	return best
