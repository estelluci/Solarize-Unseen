extends SceneTree
## Regenerates the starter upgrade files in res://upgrades/.
##   godot --headless -s res://tools/build_upgrades.gd
##
## You don't need this to make upgrades: designers can create them in the
## editor (FileSystem > New Resource > Upgrade). It's here as a readable list
## of the starter tree and so the files can be rebuilt after big changes.

const Up := preload("res://scripts/upgrades/upgrade.gd")
const Mod := preload("res://scripts/upgrades/stat_modifier.gd")

# id, name, target, cost, requires, flags, [[stat, op, value]...], abilities, order, description
const TREE := [
	# --- Mafia --------------------------------------------------------------
	["sure_footing", "Sure Footing", &"mafia", 1, [], [],
		[["run_speed", Mod.Op.ADD, 30.0], ["ground_accel", Mod.Op.MULTIPLY, 1.15]], [], 10,
		"Years of drills pay off. Runs faster and gets up to speed quicker."],
	["wall_jump", "Wall Jump", &"mafia", 2, ["sure_footing"], [],
		[], [&"wall_jump"], 11,
		"Kick off walls: jump while touching a wall in mid-air. Slide down walls slowly."],
	["heavy_rounds", "Heavy Rounds", &"mafia", 2, [], [],
		[["shot_power", Mod.Op.ADD, 1.0]], [], 12,
		"Each shot does double damage to portals."],
	# --- Fairy --------------------------------------------------------------
	["deep_pix", "Deep Pix", &"fairy", 1, [], [],
		[["pix_max", Mod.Op.ADD, 40.0]], [], 20,
		"A bigger well of Pix: +40 maximum."],
	["efficient_wings", "Efficient Wings", &"fairy", 2, ["deep_pix"], [],
		[["pix_carry_drain", Mod.Op.MULTIPLY, 0.75], ["pix_lift_drain", Mod.Op.MULTIPLY, 0.75]], [], 21,
		"Carrying the Mafia costs 25% less Pix."],
	["mote_magnet", "Mote Magnet", &"fairy", 1, ["deep_pix"], [],
		[["mote_magnet_radius", Mod.Op.SET, 140.0]], [], 22,
		"Pix motes drift toward the party from up to 140 px away."],
	["quick_recovery", "Quick Recovery", &"fairy", 1, [], [],
		[["pix_regen", Mod.Op.MULTIPLY, 1.5], ["pix_regen_delay", Mod.Op.SET, 0.2]], [], 23,
		"Pix refills 50% faster and starts refilling almost immediately."],
	["second_wind", "Second Wind", &"fairy", 3, ["quick_recovery"], [],
		[["air_jumps", Mod.Op.ADD, 1.0]], [], 24,
		"One more air jump."],
	# --- Party --------------------------------------------------------------
	["strong_will", "Strong Will", &"party", 1, [], [&"seen_tendrils"],
		[["struggle_strength", Mod.Op.ADD, 1.0]], [], 30,
		"Break free of tendrils with half the struggling. Unlocked after meeting the tendril portal."],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://upgrades")
	for row in TREE:
		var u = Up.new()
		u.id = StringName(row[0])
		u.display_name = row[1]
		u.target = row[2]
		u.cost = row[3]
		for r in row[4]:
			u.requires.append(StringName(r))
		for f in row[5]:
			u.requires_flags.append(StringName(f))
		for m in row[6]:
			var mod = Mod.new()
			mod.stat = StringName(m[0])
			mod.op = m[1]
			mod.value = m[2]
			u.modifiers.append(mod)
		for a in row[7]:
			u.grants_abilities.append(StringName(a))
		u.sort_order = row[8]
		u.description = row[9]
		var path := "res://upgrades/%s.tres" % row[0]
		var err := ResourceSaver.save(u, path)
		print("%s -> %s" % [path, "ok" if err == OK else error_string(err)])
	quit()
