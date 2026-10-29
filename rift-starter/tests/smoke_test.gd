extends Node
## Headless smoke test:  godot --headless res://tests/smoke_test.tscn
## Exits with code 0 if everything passes, 1 otherwise.

var _fails := 0
var main: Node
var party: Party
var player: Player   # the current leader (player 1's character)


func check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func place(pos: Vector2, with_partner := true) -> void:
	player.teleport(pos)
	if with_partner:
		party.partner.teleport(pos + Vector2(-50, 0))
	await frames(40)


func _ready() -> void:
	seed(20260925)  # tendril sway uses randomness; keep runs repeatable
	# Gameplay tests run without story interruptions; cutscenes get their own section.
	Cutscenes.enabled = false
	GameState.reset()
	# --- pure IK math ----------------------------------------------------
	var leg := TwoBoneIK.solve(Vector2(0, -40), Vector2(0, 0), 22, 22, -1)
	check(leg[0].x > 0.0, "knee bends forward when facing right (knee=%s)" % leg[0])
	var arm := TwoBoneIK.solve(Vector2.ZERO, Vector2(30, 0), 17, 16, 1)
	check(arm[0].y > 0.0, "elbow hangs below an arm aimed right (elbow=%s)" % arm[0])
	var far := TwoBoneIK.solve(Vector2.ZERO, Vector2(500, 0), 17, 16, 1)
	check(far[1].length() < 33.0 and far[1].x > 32.0, "out-of-reach target stretches limb straight")
	check(absf(leg[0].distance_to(Vector2(0, -40)) - 22.0) < 0.01, "bone lengths preserved")
	var chain := PackedVector2Array()
	for i in 8:
		chain.append(Vector2(i * 18.0, 0))
	var solved := Fabrik.solve(chain, Vector2.ZERO, Vector2(60, 70))
	var lengths_ok := true
	for i in 7:
		lengths_ok = lengths_ok and absf(solved[i].distance_to(solved[i + 1]) - 18.0) < 0.05
	check(solved[7].distance_to(Vector2(60, 70)) < 1.0 and lengths_ok and solved[0] == Vector2.ZERO,
		"FABRIK chain reaches its target, keeps its base and bone lengths")
	solved = Fabrik.solve(chain, Vector2.ZERO, Vector2(0, 500))
	check(absf(solved[7].y - 126.0) < 0.1 and absf(solved[7].x) < 0.1, "FABRIK stretches straight toward an out-of-reach target")
	var limit := deg_to_rad(30.0)
	solved = Fabrik.solve(chain, Vector2.ZERO, Vector2(-20, 10), 12, 0.5, limit, Vector2.RIGHT)
	check(max_bend(solved, Vector2.RIGHT) <= limit + 0.001, "FABRIK joint limits: no joint bends more than 30° (max %.1f°)" % rad_to_deg(max_bend(solved, Vector2.RIGHT)))

	# --- input map -------------------------------------------------------
	for a in ["move_left", "move_right", "jump", "swap", "sight", "shoot",
			"p2_move_left", "p2_move_right", "p2_jump", "p2_sight", "p2_shoot", "coop_toggle"]:
		check(InputMap.has_action(a) and InputMap.action_get_events(a).size() > 0, "input action '%s' has bindings" % a)

	# --- load level ------------------------------------------------------
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	party = main.get_node("Party")
	player = party.leader
	await frames(60)
	check(player.is_on_floor(), "player lands on the training ground")
	check(player.profile.display_name == "Mafia" and player.input is HumanInput, "P1 starts as Mafia")
	check(party.partner.profile.display_name == "Fairy" and party.partner.input is CompanionAI, "Fairy starts as AI companion")

	# --- foot IK on slope --------------------------------------------------
	await place(Vector2(1200, -170))
	var pose: Dictionary = player.rig.get_debug_pose()
	var f0: Vector2 = pose.feet[0]
	var f1: Vector2 = pose.feet[1]
	var g0: float = player.rig.probe_ground_local_y(f0.x)
	var g1: float = player.rig.probe_ground_local_y(f1.x)
	check(absf(f0.y - g0) < 2.0 and absf(f1.y - g1) < 2.0, "both feet planted on the slope")
	check(absf(f0.y - f1.y) > 1.5, "feet at different heights on slope")
	check(pose.hip.y > -40.0, "hips drop to let the downhill foot reach")

	# --- AI companion follows a run across the training ground -----------------
	await place(Vector2(-300, -2))
	var warps := [0]
	var count_warp := func(): warps[0] += 1
	party.partner.warped.connect(count_warp)
	var max_gap := 0.0
	Input.action_press("move_right")
	for i in 400:
		await frames(1)
		max_gap = maxf(max_gap, player.global_position.distance_to(party.partner.global_position))
		if player.global_position.x > 1600.0:
			break
	Input.action_release("move_right")
	await frames(60)
	var gap := player.global_position.distance_to(party.partner.global_position)
	check(gap < 120.0, "companion catches up after the run (gap=%.0f)" % gap)
	check(max_gap < 260.0 and warps[0] == 0, "companion keeps pace on slopes without warping (max gap=%.0f, warps=%d)" % [max_gap, warps[0]])
	check(party.partner.is_on_floor() and absf(player.global_position.x - party.partner.global_position.x) > 20.0,
		"companion stops beside the leader, not on top of it")

	# --- companion copies jumps ------------------------------------------------
	await place(Vector2(-300, -2))
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	var partner_jumped := false
	for i in 40:
		await frames(1)
		if not party.partner.is_on_floor() and party.partner.velocity.y < 0.0:
			partner_jumped = true
	check(partner_jumped, "companion replays the leader's jump")
	await frames(40)

	# --- catch-up warp ---------------------------------------------------------
	player.teleport(Vector2(2150, -222))
	await frames(10)
	gap = player.global_position.distance_to(party.partner.global_position)
	check(gap < 100.0 and warps[0] >= 1, "companion warps to a far-away leader (gap=%.0f)" % gap)

	# --- swap ---------------------------------------------------------------
	await place(Vector2(-300, -2))
	party.swap()
	player = party.leader
	check(player.profile.display_name == "Fairy" and player.input is HumanInput and Sight.eye == Sight.LUNAR,
		"Tab swap -> P1 plays Fairy with Lunar eye")
	check(party.partner.profile.display_name == "Mafia" and party.partner.input is CompanionAI, "Mafia becomes the AI companion")
	Input.action_press("move_right")
	await frames(30)
	check(player.velocity.x > 200.0 and player.facing == 1, "runs right at speed (vx=%.0f)" % player.velocity.x)
	var fx_min := INF
	var fx_max := -INF
	for i in 30:
		await frames(1)
		var fx: float = player.rig.get_debug_pose().feet[0].x
		fx_min = minf(fx_min, fx)
		fx_max = maxf(fx_max, fx)
	check(fx_max - fx_min > 12.0, "gait swings the feet while running (range=%.1f)" % (fx_max - fx_min))
	Input.action_release("move_right")
	await frames(40)

	# --- jumps ---------------------------------------------------------------
	var fairy_rise := await measure_jump(true)
	check(fairy_rise > 170.0, "Fairy double jump clears the ledge height (rise=%.0f)" % fairy_rise)
	party.swap()
	player = party.leader
	await frames(20)
	var mafia_rise := await measure_jump(false)
	check(mafia_rise > 90.0 and mafia_rise < 150.0, "Mafia single jump is shorter (rise=%.0f)" % mafia_rise)

	# --- sight platforms ------------------------------------------------------
	var true_path: SightPlatform = main.get_node("Level/TruePathPlatform")
	check(true_path._shape.disabled, "true path is not solid with sight closed")
	await place(Vector2(1790, -300), false)
	check(player.global_position.y > -200.0 or player.global_position.x < 0.0, "illusion platform can't hold you")
	Sight.set_active(true)
	await frames(2)
	check(not true_path._shape.disabled, "true path becomes solid with sight open")
	await place(Vector2(1885, -320), false)
	check(player.is_on_floor() and absf(player.global_position.y - (-272.0)) < 3.0, "can stand on the true path (y=%.1f)" % player.global_position.y)
	Sight.set_active(false)

	# --- AI Mafia shoots a portal the Fairy reveals ------------------------------
	party.swap()   # P1 = Fairy, AI = Mafia
	player = party.leader
	var portal := main.get_node("Level/PathPortal")
	await place(Vector2(2360, -246))
	check(is_instance_valid(portal), "portal still open before sight")
	Sight.toggle_eye(player.profile.sight_eye)   # Fairy opens her Lunar eye
	for i in 180:
		await frames(1)
		if not is_instance_valid(portal):
			break
	check(not is_instance_valid(portal), "AI Mafia seals the portal once the Fairy reveals it")
	Sight.set_active(false)
	party.swap()
	player = party.leader

	# --- respawn ---------------------------------------------------------------
	player.global_position = Vector2(1880, 720)
	await frames(5)
	check(player.global_position.y < 0.0, "leader falling into the pit respawns at a checkpoint")
	await place(Vector2(1550, -222))
	party.partner.global_position = Vector2(1880, 720)
	await frames(5)
	gap = player.global_position.distance_to(party.partner.global_position)
	check(gap < 100.0, "fallen companion reappears next to the leader (gap=%.0f)" % gap)

	# --- small fairy -------------------------------------------------------------
	var fairy: Player = party.carrier_of_party()
	var mafia: Player = party.partner if fairy == party.leader else party.leader
	var fairy_cap := fairy.collision.shape as CapsuleShape2D
	var mafia_cap := mafia.collision.shape as CapsuleShape2D
	check(fairy_cap.height < mafia_cap.height * 0.6 and is_equal_approx(fairy.rig.scale.x, 0.55),
		"Fairy is small (capsule %.0f vs %.0f px)" % [fairy_cap.height, mafia_cap.height])
	await place(Vector2(1200, -170))
	pose = party.partner.rig.get_debug_pose()
	var fg: float = party.partner.rig.probe_ground_local_y(pose.feet[0].x)
	check(party.partner == fairy and absf(pose.feet[0].y - fg) < 2.0, "small Fairy's feet still plant on the slope")

	# --- Fairy carries the Mafia up to the fairy ledge --------------------------
	party.swap()   # P1 = Fairy, AI = Mafia
	player = party.leader
	await place(Vector2(2920, -252))
	await tap("carry")
	check(fairy.cargo == mafia and mafia.carrier == fairy, "F near the Mafia picks him up")
	await frames(10)
	check(absf(mafia.global_position.y - fairy.global_position.y - fairy.profile.carry_hang_distance) < 12.0,
		"Mafia hangs below the Fairy")
	var pix_before := fairy.pix
	Input.action_press("jump")
	for i in 150:
		await frames(1)
		if mafia.global_position.y < -445.0 or fairy.cargo == null:
			break
	check(mafia.global_position.y < -445.0 and fairy.pix < pix_before, "holding jump lifts him (Pix %.0f -> %.0f)" % [pix_before, fairy.pix])
	Input.action_press("move_right")
	for i in 120:
		# Keep him just above ledge height while flying over it.
		if mafia.global_position.y > -450.0:
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		await frames(1)
		if mafia.global_position.x > 3010.0 or fairy.cargo == null:
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	check(fairy.cargo == mafia, "still carrying over the ledge (Pix left %.0f)" % fairy.pix)
	await tap("carry")
	await frames(40)
	check(fairy.cargo == null and mafia.is_on_floor() and absf(mafia.global_position.y - (-420.0)) < 3.0,
		"let go: the Mafia lands on the fairy-only ledge (y=%.0f)" % mafia.global_position.y)

	# --- Pix runs out --------------------------------------------------------------
	await place(Vector2(-300, -2))
	await frames(300)   # let Pix refill
	check(is_equal_approx(fairy.pix, fairy.profile.pix_max), "Pix refills when not carrying")
	await tap("carry")
	var hold_time := 0.0
	Input.action_press("jump")
	for i in 600:
		await frames(1)
		if fairy.cargo == null:
			break
		hold_time += 1.0 / 60.0
	Input.action_release("jump")
	var expected := fairy.profile.pix_max / (fairy.profile.pix_carry_drain + fairy.profile.pix_lift_drain)
	check(fairy.cargo == null and absf(hold_time - expected) < 0.2,
		"Pix empties and she drops him after %.1fs (expected %.1fs)" % [hold_time, expected])
	check(mafia.carrier == null and mafia.velocity.y >= 0.0 or not mafia.is_on_floor(), "dropped Mafia falls")
	await frames(30)
	await tap("carry")
	check(fairy.cargo == null, "can't grab again with too little Pix")
	for i in 240:
		await frames(1)
		if fairy.pix >= fairy.profile.pix_min_to_grab:
			break
	await place(Vector2(-300, -2))
	await tap("carry")
	check(fairy.cargo == mafia, "can grab again once Pix passes the minimum")
	await tap("carry")
	await frames(30)

	# --- solo lift when playing the Mafia --------------------------------------
	party.swap()   # P1 = Mafia, AI = Fairy
	player = party.leader
	await place(Vector2(-300, -2))
	await frames(150)
	await tap("carry")
	check(fairy.cargo == mafia and fairy.input is HumanInput, "Mafia calls for a lift; P1 steers the AI Fairy")
	var y0 := mafia.global_position.y
	Input.action_press("jump")
	await frames(30)
	Input.action_release("jump")
	check(mafia.global_position.y < y0 - 40.0, "P1 flies the pair while hanging on")
	await tap("carry")
	await frames(5)
	check(fairy.cargo == null and fairy.input is CompanionAI, "let go: the Fairy goes back to the AI")
	await frames(60)

	# --- portal tendrils ------------------------------------------------------------
	var tportal := main.get_node("Level/TendrilPortal")
	var tendrils: Array = tportal.get_children().filter(func(c): return c is PortalTendril)
	var idle_input := PlayerInput.new()
	party.partner.set_input(idle_input)          # keep the partner out of the way
	party.partner.teleport(Vector2(-300, -2))
	player = party.leader
	check(player.profile.display_name == "Mafia", "tendril tests run as the Mafia")
	await place(Vector2(2640, -268), false)
	var grabbed := false
	for i in 180:
		await frames(1)
		if player.grabbed_by != null:
			grabbed = true
			break
	check(grabbed and not Sight.active, "a tendril reaches for and grabs you, even with sight closed")
	var d0 := player.global_position.distance_to(tportal.global_position)
	await frames(20)
	check(player.global_position.distance_to(tportal.global_position) < d0 - 10.0, "grabbed: dragged toward the portal")
	for i in 5:
		await tap("jump")
	check(player.grabbed_by == null, "mashing jump breaks free")
	await frames(10)
	check(player.global_position.distance_to(tportal.global_position) > d0 - 10.0, "breaking free flings you clear")
	check(tendrils[0].hit_distance(Vector2(2500, -350), Vector2(2800, -350)) < 0.0 and tendrils[1].hit_distance(player.global_position + Vector2(0, -60), tendrils[1].tip()) < 0.0,
		"with sight closed, tendrils can't be hit")

	# Shoot the tendril holding you (sight open).
	Sight.toggle_eye(Sight.SOLAR)
	await place(Vector2(2640, -268), false)
	for i in 180:
		await frames(1)
		if player.grabbed_by != null:
			break
	var holder: PortalTendril = player.grabbed_by
	check(holder != null, "grabbed again once the tendril recovers")
	if holder:
		check(max_bend(holder._points, holder._rest_dir()) <= deg_to_rad(holder.max_bend_degrees) + 0.01,
			"tendril joints stay within their bend limit while holding someone")
		# Another tendril may be in the line of fire; keep shooting along the holder.
		for k in range(holder._points.size() - 2, 0, -2):
			if holder.state == PortalTendril.State.SEVERED:
				break
			player.shoot(holder._points[k])
		check(player.grabbed_by == null and holder.state == PortalTendril.State.SEVERED, "a shot severs the visible tendril and frees you")
		await frames(2)
	Sight.set_active(false)

	# Dragged all the way in = death.
	await place(Vector2(2640, -268), false)
	var was_grabbed := false
	var got_pulled := false
	for k in 600:
		await frames(1)
		was_grabbed = was_grabbed or player.grabbed_by != null
		if was_grabbed and player.global_position.distance_to(tportal.global_position) > 400.0:
			got_pulled = true
			break
	check(got_pulled and player.grabbed_by == null, "if nobody helps, you're pulled into the portal and respawn")

	# The AI Mafia frees the Fairy.
	party.swap()          # P1 = Fairy, AI = Mafia
	player = party.leader
	var ai_mafia := party.partner
	await place(Vector2(2640, -268), false)
	ai_mafia.teleport(Vector2(2470, -246))
	Sight.toggle_eye(Sight.LUNAR)
	var freed_by_shot := false
	for i in 300:
		await frames(1)
		for t in tendrils:
			if t.state == PortalTendril.State.SEVERED and t.victim == null:
				freed_by_shot = true
		if freed_by_shot:
			break
	check(freed_by_shot, "the AI Mafia shoots tendrils that grab his partner")

	# Sealing the portal releases everyone.
	player.teleport(Vector2(2640, -268))
	for i in 240:
		await frames(1)
		if player.grabbed_by != null:
			break
	for i in 5:
		tportal.on_shot()
	await frames(40)
	check(not is_instance_valid(tportal) and player.grabbed_by == null and ai_mafia.grabbed_by == null,
		"sealing the portal frees anyone its tendrils held")
	Sight.set_active(false)
	party.swap()
	player = party.leader

	# --- Pix motes -------------------------------------------------------------------
	var fairy_p: Player = party.carrier_of_party()
	var mafia_p: Player = party.partner if fairy_p == party.leader else party.leader
	var ledge_mote: PixMote = main.get_node("Level/LongCrossing/MoteLedge")
	fairy_p.pix = 10.0
	fairy_p._pix_regen_wait = 99.0
	mafia_p.teleport(Vector2(3060, -422))
	await frames(3)
	check(absf(fairy_p.pix - 45.0) < 0.5 and not ledge_mote.is_available(),
		"a Pix mote touched by the Mafia refills the Fairy (+35)")
	fairy_p._pix_regen_wait = 0.0

	# --- Solar-only rest platform ----------------------------------------------------
	var solar_rest: SightPlatform = main.get_node("Level/LongCrossing/SolarRest")
	Sight.toggle_eye(Sight.LUNAR)
	await frames(2)
	check(solar_rest._shape.disabled, "the Solar-only platform stays hidden to a Lunar eye")
	Sight.set_active(false)

	# --- The Long Crossing: Mafia calls a lift, rests on the Solar platform ----------
	player = party.leader
	check(player == mafia_p, "crossing runs as the Mafia")
	await place(Vector2(3420, -252))
	await frames(200)   # full Pix
	await tap("sight")
	await frames(2)
	check(Sight.active and Sight.eye == Sight.SOLAR and not solar_rest._shape.disabled, "E as the Mafia opens the Solar eye; the rest platform appears")
	await tap("carry")
	check(fairy_p.cargo == mafia_p, "Mafia calls the Fairy for a lift at the chasm")
	await tap("sight")
	await tap("sight")
	check(Sight.active and Sight.eye == Sight.SOLAR, "during the lift, E still toggles the Mafia's Solar eye (not the Fairy's)")
	var min_pix := [fairy_p.pix]
	var landed := await fly_to(mafia_p, fairy_p, 3800.0, 3760.0, 3840.0, min_pix)
	check(landed and absf(mafia_p.global_position.y - (-250.0)) < 3.0, "leg 1: set down on the Solar rest platform (y=%.0f)" % mafia_p.global_position.y)
	check(not main.get_node("Level/LongCrossing/MoteA").is_available(), "picked up the first Pix mote on the way")
	await frames(240)   # rest: Pix refills
	check(fairy_p.pix > 90.0, "resting on the platform refills Pix (%.0f)" % fairy_p.pix)
	await tap("carry")
	check(fairy_p.cargo == mafia_p, "lift again from the rest platform")
	landed = await fly_to(mafia_p, fairy_p, 4260.0, 4200.0, 4400.0, min_pix)
	check(landed and mafia_p.global_position.x > 4150.0 and absf(mafia_p.global_position.y - (-250.0)) < 3.0,
		"leg 2: made it across The Long Crossing (x=%.0f)" % mafia_p.global_position.x)
	check(min_pix[0] > 0.0, "never ran out of Pix on the way (lowest %.0f)" % min_pix[0])
	Sight.set_active(false)
	await frames(30)

	# --- co-op -----------------------------------------------------------------
	await place(Vector2(-300, -2))
	Input.action_press("p2_move_right")
	await frames(3)
	check(party.mode == Party.Mode.COOP and party.partner.input is HumanInput, "pressing a P2 key drops player 2 in")
	var p2_start := party.partner.global_position.x
	await frames(30)
	Input.action_release("p2_move_right")
	check(party.partner.global_position.x - p2_start > 60.0 and absf(player.velocity.x) < 1.0,
		"P2 moves their character independently")
	Input.action_press("p2_jump")
	await frames(4)
	Input.action_release("p2_jump")
	check(party.partner.velocity.y < 0.0 and player.is_on_floor(), "P2 jump only moves P2")
	await frames(60)
	party.partner.teleport(player.global_position + Vector2(1500, -400))
	await frames(3)
	check(player.global_position.distance_to(party.partner.global_position) < 100.0, "co-op tether pulls a far-away P2 back")
	var cam: PartyCamera = main.get_node("Camera")
	party.partner.teleport(player.global_position + Vector2(700, 0))
	await frames(90)
	check(cam.frame_everyone and cam.zoom.x < 1.2, "co-op camera zooms out to frame both (zoom=%.2f)" % cam.zoom.x)
	party.set_mode(Party.Mode.SOLO)
	check(party.partner.input is CompanionAI, "F2 hands P2's character back to the AI")

	await upgrade_tests()
	await cutscene_tests()
	await boss_tests()

	print("\n%s (%d failures)" % ["ALL PASSED" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)


## Largest bend (radians) between consecutive bones of a chain.
func max_bend(points: PackedVector2Array, root_dir: Vector2) -> float:
	var worst := 0.0
	var prev := root_dir.normalized()
	for i in points.size() - 1:
		var d := points[i].direction_to(points[i + 1])
		worst = maxf(worst, absf(prev.angle_to(d)))
		prev = d
	return worst


## Scripted lift: fly the Mafia (hanging under the Fairy) to `target_x`, keep
## him around y=-300, then sink and let go once he's over [land_min, land_max].
func fly_to(mafia: Player, fairy: Player, target_x: float, land_min: float, land_max: float, min_pix: Array) -> bool:
	for i in 600:
		var x := mafia.global_position.x
		var over_landing := x > land_min and x < land_max
		if over_landing and absf(x - target_x) < 40.0:
			Input.action_release("move_right")
			Input.action_release("jump")
			if mafia.is_on_floor():
				break
		else:
			Input.action_press("move_right")
			if mafia.global_position.y > -305.0:
				Input.action_press("jump")
			else:
				Input.action_release("jump")
		await frames(1)
		min_pix[0] = minf(min_pix[0], fairy.pix)
		if fairy.cargo == null:
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	var ok := fairy.cargo == mafia and mafia.is_on_floor()
	await tap("carry")
	await frames(20)
	return ok and mafia.is_on_floor()


func tap(action: String) -> void:
	Input.action_press(action)
	await frames(1)
	Input.action_release(action)
	await frames(1)


func measure_jump(double: bool) -> float:
	await place(Vector2(-300, -2))
	var start_y := player.global_position.y
	var min_y := start_y
	Input.action_press("jump")
	await frames(2)
	for i in 120:
		await frames(1)
		min_y = minf(min_y, player.global_position.y)
		if double and i == 16:
			Input.action_release("jump")
			await frames(1)
			Input.action_press("jump")
		if player.is_on_floor() and i > 5:
			break
	Input.action_release("jump")
	await frames(10)
	return start_y - min_y


# =============================================================================
# Upgrades
# =============================================================================
func upgrade_tests() -> void:
	party.set_mode(Party.Mode.SOLO)
	var mafia: Player = Cutscenes.actor("mafia")
	var fairy: Player = Cutscenes.actor("fairy")
	check(Upgrades.all_upgrades().size() == 9, "9 starter upgrades load from res://upgrades/")
	check(Upgrades.validate().is_empty(), "all upgrade files are valid (stats exist, prerequisites exist, no cycles)")

	# The validator catches authoring mistakes.
	var bad := Upgrade.new()
	bad.id = &"test_bad"
	bad.target = &"mafia"
	bad.requires.append(&"does_not_exist")
	var bad_mod := StatModifier.new()
	bad_mod.stat = &"jump_heigth"
	bad.modifiers.append(bad_mod)
	Upgrades._by_id[bad.id] = bad
	Upgrades._ordered.append(bad)
	var errs := Upgrades.validate()
	check(errs.size() == 2 and "jump_heigth" in errs[0] + errs[1] and "does_not_exist" in errs[0] + errs[1],
		"validator reports a misspelled stat and a missing prerequisite")
	Upgrades._by_id.erase(bad.id)
	Upgrades._ordered.erase(bad)

	# Logic: prerequisites, story flags, cost.
	GameState.shards = 0
	check(Upgrades.status(&"wall_jump")[0] == Upgrades.State.LOCKED and "Sure Footing" in Upgrades.status(&"wall_jump")[1],
		"Wall Jump is locked until Sure Footing is owned")
	GameState.clear_flag(&"seen_tendrils")
	check(Upgrades.status(&"strong_will")[0] == Upgrades.State.LOCKED, "Strong Will is hidden until the tendril cutscene's flag")
	check(not Upgrades.buy(&"sure_footing") and Upgrades.status(&"sure_footing")[0] == Upgrades.State.TOO_EXPENSIVE,
		"can't buy without enough shards")

	var base_speed := mafia.base_profile.run_speed
	GameState.add_shards(20)
	check(Upgrades.buy(&"sure_footing") and GameState.shards == 19, "buying spends shards")
	check(is_equal_approx(mafia.profile.run_speed, base_speed + 30.0)
		and is_equal_approx(mafia.profile.ground_accel, mafia.base_profile.ground_accel * 1.15)
		and is_equal_approx(fairy.profile.run_speed, fairy.base_profile.run_speed),
		"Sure Footing changes only the Mafia's stats (run %.0f -> %.0f)" % [base_speed, mafia.profile.run_speed])
	check(not Upgrades.buy(&"sure_footing"), "can't buy the same upgrade twice")
	check(Upgrades.status(&"wall_jump")[0] == Upgrades.State.AVAILABLE, "owning Sure Footing unlocks Wall Jump")

	Upgrades.buy(&"deep_pix")
	Upgrades.buy(&"efficient_wings")
	check(is_equal_approx(fairy.profile.pix_max, 140.0) and is_equal_approx(fairy.profile.pix_carry_drain, 22.0 * 0.75),
		"Deep Pix + Efficient Wings stack (Pix 140, carry drain %.1f)" % fairy.profile.pix_carry_drain)
	Upgrades.buy(&"quick_recovery")
	Upgrades.buy(&"second_wind")
	check(fairy.profile.air_jumps == 2 and typeof(fairy.profile.air_jumps) == TYPE_INT, "Second Wind: whole-number stat stays an int (air jumps 2)")

	# Modifier order: SET, then ADD, then MULTIPLY, whatever the purchase order.
	var t1 := _temp_upgrade(&"test_mul", [[&"jump_velocity", StatModifier.Op.MULTIPLY, 2.0]], 0)
	var t2 := _temp_upgrade(&"test_add", [[&"jump_velocity", StatModifier.Op.ADD, 10.0]], 1)
	var t3 := _temp_upgrade(&"test_set", [[&"jump_velocity", StatModifier.Op.SET, 100.0]], 2)
	var built := Upgrades.build_profile(mafia.base_profile)
	check(is_equal_approx(built.jump_velocity, 220.0), "modifiers combine SET -> ADD -> MULTIPLY ((100 + 10) x 2 = %.0f)" % built.jump_velocity)
	for t in [t1, t2, t3]:
		Upgrades._by_id.erase(t.id)
		Upgrades._ordered.erase(t)
		GameState.owned_upgrades.erase(t.id)

	# Wall jump ability.
	await _wall_test(mafia, false)
	var no_kick := mafia.velocity.x
	Upgrades.buy(&"wall_jump")
	check(mafia.has_ability(&"wall_jump"), "Wall Jump grants the wall_jump ability")
	await _wall_test(mafia, true)
	check(mafia.velocity.x > 150.0 and no_kick < 50.0, "with Wall Jump, jumping against a wall kicks away from it (vx %.0f, before %.0f)" % [mafia.velocity.x, no_kick])

	# Heavy Rounds: a 3-hit portal falls in 2 shots, and pays a shard.
	Upgrades.buy(&"heavy_rounds")
	var test_portal := Portal.new()
	test_portal.position = Vector2(-200, -600)
	main.add_child(test_portal)
	Sight.set_active(true)
	var shards_before := GameState.shards
	test_portal.on_shot(mafia.profile.shot_power)
	test_portal.on_shot(mafia.profile.shot_power)
	check(test_portal.is_sealing() and GameState.shards == shards_before + 1, "Heavy Rounds seal a 3-hit portal in 2 shots (+1 shard)")
	Sight.set_active(false)

	# Strong Will needs the flag.
	GameState.set_flag(&"seen_tendrils")
	check(Upgrades.buy(&"strong_will") and mafia.profile.struggle_strength == 2 and fairy.profile.struggle_strength == 2,
		"Strong Will (after its flag) helps both characters struggle")

	# Mote Magnet pulls motes in.
	Upgrades.buy(&"mote_magnet")
	var mote: PixMote = main.get_node("Level/LongCrossing/MoteLedge")
	mote._hidden_for = 0.0
	mote.monitoring = true
	mote.global_position = mote._home
	fairy.set_input(PlayerInput.new())   # hold still (no AI catch-up)
	fairy.pix = 20.0
	fairy._pix_regen_wait = 99.0
	fairy.teleport(Vector2(3150, -422))
	var magnet_ok := false
	for i in 60:
		await frames(1)
		if not mote.is_available():
			magnet_ok = true
			break
	check(magnet_ok and fairy.pix > 50.0, "Mote Magnet: a mote 90px away drifts to the Fairy")
	fairy._pix_regen_wait = 0.0
	party.reassign()

	# Shard pickups are one-time, remembered by flag.
	var shard: ShardPickup = main.get_node("Level/Shards/ChimneyTop")
	GameState.clear_flag(shard.flag_name())
	await frames(2)
	var before := GameState.shards
	mafia.teleport(shard.global_position + Vector2(0, 50))
	await frames(3)
	check(GameState.shards == before + 1 and GameState.has_flag(shard.flag_name()), "picking up a shard adds it and remembers it")
	mafia.teleport(shard.global_position + Vector2(0, 50))
	await frames(3)
	check(GameState.shards == before + 1, "a collected shard can't be collected again")

	# Save / load round trip.
	var snapshot := GameState.to_dict()
	GameState.save_game("user://test_save.json")
	GameState.reset()
	Upgrades.changed.emit()
	check(is_equal_approx(mafia.profile.run_speed, base_speed), "after a reset, upgrades are gone from the stats")
	check(GameState.load_game("user://test_save.json") and GameState.to_dict() == snapshot
		and is_equal_approx(mafia.profile.run_speed, base_speed + 30.0) and not shard.monitoring == true,
		"loading restores flags, shards, upgrades and the characters' stats")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))

	# The menu pauses the game and buys on click.
	var menu = main.get_node("UpgradeMenu")
	GameState.owned_upgrades.erase(&"deep_pix")
	GameState.owned_upgrades.erase(&"efficient_wings")
	GameState.owned_upgrades.erase(&"mote_magnet")
	Upgrades.changed.emit()
	GameState.add_shards(1)
	menu.open()
	await frames(2)
	check(menu.is_open and get_tree().paused, "U opens the upgrade menu and pauses the game")
	var button: Button = menu.find_child("deep_pix", true, false)
	check(button != null and not button.disabled, "menu lists Deep Pix as buyable")
	if button:
		button.pressed.emit()
	await frames(2)
	check(Upgrades.is_owned(&"deep_pix") and is_equal_approx(fairy.profile.pix_max, 140.0), "clicking an upgrade in the menu buys it")
	menu.close()
	check(not get_tree().paused, "closing the menu unpauses")


func _temp_upgrade(id: StringName, mods: Array, order: int) -> Upgrade:
	var u := Upgrade.new()
	u.id = id
	u.target = &"mafia"
	u.sort_order = -100 + order
	for m in mods:
		var sm := StatModifier.new()
		sm.stat = m[0]
		sm.op = m[1]
		sm.value = m[2]
		u.modifiers.append(sm)
	Upgrades._by_id[id] = u
	Upgrades._ordered.push_front(u)
	GameState.own_upgrade(id)
	return u


## Drop the Mafia next to the left wall, press into it mid-air, then jump.
func _wall_test(mafia: Player, _expect: bool) -> void:
	mafia.teleport(Vector2(-580, -300))
	if mafia != party.leader:
		party.swap()
		player = party.leader
	Input.action_press("move_left")
	await frames(12)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	Input.action_release("move_left")


# =============================================================================
# Cutscenes
# =============================================================================
func cutscene_tests() -> void:
	# --- parser ---------------------------------------------------------------
	var toks := CutsceneScript.tokenize('say fairy "Hi, \\"you\\"!"   extra')
	check(toks.size() == 4 and toks[2] == 'Hi, "you"!', "tokenizer keeps quoted text together and handles \\\" escapes")
	var nested := Cutscenes.parse("if flag a\n  if not eye Solar\n    set_flag b\n  else\n    set_flag c\n  end\nend\nset_flag d")
	check(nested.is_valid() and nested.commands[0].end_index == 6 and nested.commands[1].else_index == 3
		and nested.commands[1].end_index == 5, "nested if/else/end blocks are matched")
	var broken := Cutscenes.parse("say mafia\nflail mafia\nif flag x\nmove mafie 10\ngive_upgrade nope\nelse\nelse\nend\nend", "broken")
	var joined := "\n".join(broken.errors)
	check(broken.errors.size() == 6 and "broken:1" in joined and "unknown command 'flail'" in joined
		and "unknown actor 'mafie'" in joined and "unknown upgrade 'nope'" in joined
		and "second 'else'" in joined and "'end' without 'if'" in joined,
		"parser reports mistakes with file:line (%d errors)" % broken.errors.size())
	check(not Cutscenes.parse("if flag a\nset_flag b").is_valid(), "an 'if' without 'end' is an error")
	var all_ok := true
	for f in DirAccess.get_files_at("res://cutscenes"):
		if not f.ends_with(".cutscene"):
			continue
		var sc := Cutscenes.load_script("res://cutscenes/" + f)
		if not sc.is_valid():
			all_ok = false
			print("      ", sc.errors)
	check(all_ok, "every shipped .cutscene file parses cleanly")

	# --- running ------------------------------------------------------------------
	# The level's own triggers count as already seen, so they don't interrupt.
	for t in ["intro", "tendrils", "crossing_end", "the_gap", "boss_intro"]:
		GameState.set_flag(StringName("cutscene:" + t))
	Cutscenes.enabled = true
	Cutscenes.auto_advance = 0.0
	Cutscenes.chars_per_second = 5000.0
	if party.leader.profile.id != &"mafia":
		party.swap()
	player = party.leader
	var mafia: Player = Cutscenes.actor("mafia")
	var fairy: Player = Cutscenes.actor("fairy")
	await place(Vector2(-300, -2))
	GameState.clear_flag(&"test_a")
	var shards_before := GameState.shards
	var start_x := mafia.global_position.x
	var finished_info := []
	var on_finish := func(n, skipped): finished_info.append(skipped)
	Cutscenes.finished.connect(on_finish)
	var script_text := """
		set_flag test_a
		if flag test_a
			move mafia %d
			say mafia "Moving on."
		else
			set_flag wrong_branch
		end
		if not upgrade test_never
			give_shards 2
		end
		emote fairy "!"
		camera fairy 2.0
	""" % int(start_x + 200)
	var during := [false, false]
	var spy := func():
		await frames(5)
		during[0] = Cutscenes.is_playing and mafia.input is ScriptedInput
		during[1] = Cutscenes.ui.is_line_visible() or mafia.global_position.x > start_x
	spy.call()
	var ok := await Cutscenes.play(Cutscenes.parse(script_text, "inline"))
	check(ok and during[0], "while playing, characters are driven by the cutscene")
	check(GameState.has_flag(&"test_a") and not GameState.has_flag(&"wrong_branch"), "if/else picks the right branch")
	check(absf(mafia.global_position.x - (start_x + 200)) < 8.0, "move walks the actor to its mark (x=%.0f)" % mafia.global_position.x)
	check(GameState.shards == shards_before + 2, "give_shards inside 'if not upgrade' ran")
	check(party.leader.input is HumanInput and party.partner.input is CompanionAI and not Cutscenes.camera().is_focused(),
		"control and camera return to the players afterwards")
	check(finished_info == [false], "finished signal reports a normal ending")

	# Skipping still applies everything that changes the game.
	finished_info.clear()
	GameState.owned_upgrades.erase(&"quick_recovery")
	GameState.clear_flag(&"after_skip")
	start_x = mafia.global_position.x
	var skip_text := """
		say fairy "This line would take a while."
		wait 5
		move mafia %d
		set_flag after_skip
		give_upgrade quick_recovery
		fade_out 2
	""" % int(start_x - 150)
	Cutscenes.auto_advance = -1.0
	var t0 := Time.get_ticks_msec()
	var runner := func(): await Cutscenes.play(Cutscenes.parse(skip_text, "skippable"))
	runner.call()
	await frames(10)
	check(Cutscenes.ui.is_line_visible(), "dialogue waits for the player")
	Input.action_press("cutscene_skip")
	await frames(2)
	Input.action_release("cutscene_skip")
	for i in 30:
		if not Cutscenes.is_playing:
			break
		await frames(1)
	check(not Cutscenes.is_playing and Time.get_ticks_msec() - t0 < 2000, "Esc skips the cutscene")
	check(GameState.has_flag(&"after_skip") and Upgrades.is_owned(&"quick_recovery"), "skipping still sets flags and grants upgrades")
	check(absf(mafia.global_position.x - (start_x - 150)) < 2.0, "skipped moves put the actor on its mark")
	check(is_equal_approx(Cutscenes.ui.get_fade(), 0.0) and finished_info == [true], "skipping never leaves the screen faded")

	# Dialogue advances with Space / Enter.
	var line_runner := func(): await Cutscenes.play(Cutscenes.parse('say fairy "Press a key."', "advance"))
	line_runner.call()
	await frames(5)
	await tap("cutscene_advance")
	await frames(2)
	check(not Cutscenes.is_playing, "Space/Enter advances dialogue")
	Cutscenes.auto_advance = 0.0

	# Triggers: flags gate them, `once` remembers them.
	var gap: CutsceneTrigger = main.get_node("Level/Cutscenes/TheGap")
	GameState.clear_flag(&"intro_done")
	GameState.clear_flag(gap.played_flag())
	check(not gap.can_play(), "The Gap waits for the intro's flag")
	GameState.set_flag(&"intro_done")
	check(gap.can_play(), "...and is ready once the intro has played")
	await place(Vector2(1440, -222))
	mafia.teleport(Vector2(1500, -222))
	await frames(4)
	check(Cutscenes.is_playing and GameState.has_flag(gap.played_flag()), "walking into a trigger plays its cutscene")
	Cutscenes.skip()
	await frames(5)
	mafia.teleport(Vector2(1300, -180))
	await frames(3)
	mafia.teleport(Vector2(1500, -222))
	await frames(4)
	check(not Cutscenes.is_playing, "a 'once' trigger doesn't replay")
	check(not main.get_node("UpgradeMenu").is_open, "menu stays closed")

	# Autoplay triggers (like the intro) start by themselves.
	var auto := CutsceneTrigger.new()
	auto.cutscene = "res://cutscenes/intro.cutscene"
	auto.autoplay = true
	auto.once = false
	main.add_child(auto)
	await frames(4)
	check(Cutscenes.is_playing, "an autoplay trigger starts its cutscene on load")
	main.get_node("UpgradeMenu").open()
	check(not main.get_node("UpgradeMenu").is_open, "the upgrade menu can't open during a cutscene")
	Cutscenes.skip()
	await frames(5)
	check(GameState.has_flag(&"intro_done"), "skipped intro still sets intro_done")
	auto.queue_free()
	Cutscenes.finished.disconnect(on_finish)
	Cutscenes.enabled = false


# =============================================================================
# The Maw (boss)
# =============================================================================
func boss_tests() -> void:
	var maw: MawBoss = main.get_node("Level/Arena/TheMaw")
	var gate: ArenaGate = main.get_node("Level/Arena/Gate")
	var cam: PartyCamera = main.get_node("Camera")
	Sight.set_active(false)
	party.set_mode(Party.Mode.SOLO)
	if party.leader.profile.id != &"mafia":
		party.swap()
	player = party.leader
	var mafia: Player = Cutscenes.actor("mafia")
	var fairy: Player = Cutscenes.actor("fairy")
	check(maw.state == MawBoss.State.SLEEPING and not maw.visible and not gate.closed,
		"the Maw sleeps, unseen, and the arena gate is open")

	# The intro cutscene wakes it with `emit maw_wake`.
	GameState.clear_flag(&"cutscene:boss_intro")
	Cutscenes.enabled = true
	Cutscenes.auto_advance = 0.0
	Cutscenes.chars_per_second = 5000.0
	await place(Vector2(4900, -252))
	mafia.teleport(Vector2(5000, -252))
	for i in 600:
		await frames(1)
		if not Cutscenes.is_playing and maw.state == MawBoss.State.FIGHT:
			break
	Cutscenes.enabled = false
	check(maw.state == MawBoss.State.FIGHT and maw.phase == 1 and maw.core_eye == Sight.SOLAR,
		"boss_intro's 'emit maw_wake' wakes the Maw: phase 1, Solar core")
	await frames(3)
	check(gate.closed and maw._bar.visible and cam.boss == maw, "the gate seals, the health bar shows, the camera frames the fight")
	check(maw._tendrils.size() == 4, "phase 1 grows four IK tendrils")

	# Can't walk out.
	mafia.teleport(Vector2(4830, -252))
	Input.action_press("move_left")
	await frames(40)
	Input.action_release("move_left")
	check(mafia.global_position.x > 4780.0, "the sealed gate blocks the way out (x=%.0f)" % mafia.global_position.x)

	# Core rules.
	maw._timers.clear()            # pause attacks for the rules checks
	await frames(100)              # wait out the phase-start invulnerability
	var hp0 := maw.hp
	maw.on_shot(1)
	check(maw.hp == hp0 and not maw.is_targetable(), "eyes closed: shots glance off")
	Sight.toggle_eye(Sight.LUNAR)
	maw.on_shot(1)
	check(maw.hp == hp0 and not maw.is_targetable(), "wrong eye (Lunar vs a Solar core): no damage")
	Sight.toggle_eye(Sight.SOLAR)
	check(maw.is_targetable(), "Solar eye open: the Solar core is exposed")
	await place(Vector2(5330, -252), false)   # clear line of fire (not under a ledge)
	maw._timers.clear()
	mafia.shoot(maw.global_position)
	check(maw.hp == hp0 - mafia.profile.shot_power, "the Mafia's shot hits the open core (hp %d -> %d)" % [hp0, maw.hp])

	# Phase 2: Lunar core, shielded by two small portals.
	await boss_damage_to(maw, maw.max_hp * 2 / 3)
	await frames(2)
	check(maw.phase == 2 and maw.core_eye == Sight.LUNAR and maw.shielded and maw._adds.size() == 2,
		"phase 2: Lunar core, shielded by two small portals")
	var hp1 := maw.hp
	Sight.toggle_eye(Sight.LUNAR)
	await frames(100)
	maw.on_shot(1)
	check(maw.hp == hp1, "the shield holds while the small portals are open")
	for add in maw._adds:
		add.on_shot(1)
		add.on_shot(1)
	await frames(30)
	check(maw._adds.is_empty() and not maw.shielded, "sealing both small portals drops the shield")

	# Teamwork: P1 plays the Fairy and holds the Lunar eye; the AI Mafia shoots.
	party.swap()
	player = party.leader
	maw._timers.clear()
	maw._beams.clear()
	for o in maw._orbs:
		if is_instance_valid(o):
			o.queue_free()
	await place(Vector2(5250, -252))
	Sight.set_active(false)
	Sight.toggle_eye(fairy.profile.sight_eye)
	hp1 = maw.hp
	for i in 400:
		await frames(1)
		maw._timers.clear()
		if maw.hp < hp1:
			break
	check(maw.hp < hp1, "the AI Mafia shoots the Lunar core while the Fairy holds her eye open")
	party.swap()
	player = party.leader

	# Rift beam: telegraphed, then deadly in its column only.
	maw._timers.clear()
	await place(Vector2(5100, -252))
	fairy.set_input(PlayerInput.new())
	fairy.teleport(Vector2(5450, -252))
	await frames(10)
	var mafia_x := mafia.global_position.x
	maw.fire_beam(mafia_x)
	await frames(30)
	check(absf(mafia.global_position.x - mafia_x) < 2.0, "the beam is only a warning line at first")
	await frames(50)
	check(absf(mafia.global_position.x - mafia_x) > 50.0, "then it fires and sends anyone in it back")
	check(absf(fairy.global_position.x - 5450.0) < 20.0, "someone outside the column is safe")

	# Rift orbs: touching one sends you back; a shot pops it.
	maw._timers.clear()
	await place(Vector2(5330, -252))
	fairy.set_input(PlayerInput.new())
	fairy.teleport(Vector2(6000, -252))   # far away, so the orb homes on the Mafia
	var start := mafia.global_position
	maw._fire_orb(maw.global_position.direction_to(mafia.global_position))
	var hit := false
	for i in 300:
		await frames(1)
		maw._timers.clear()
		if mafia.global_position.distance_to(start) > 100.0:
			hit = true
			break
	check(hit, "a rift orb homes in and sends you back")
	maw._fire_orb(Vector2.UP)
	await frames(2)
	var orb: RiftOrb = maw._orbs.back()
	orb.on_shot(1)
	await frames(20)
	check(not is_instance_valid(orb), "shooting an orb pops it")

	# Phase 3: alternating core and inhaling.
	await boss_damage_to(maw, maw.max_hp / 3)
	await frames(2)
	check(maw.phase == 3, "phase 3 at a third health")
	var eye_before := maw.core_eye
	maw._swap_t = 0.01
	await frames(2)
	check(maw.core_eye != eye_before, "phase 3: the core flips between Solar and Lunar")
	maw._timers.clear()
	maw._suction_t = 0.0
	await place(Vector2(maw.global_position.x - 300.0, -252), false)
	fairy.set_input(PlayerInput.new())
	fairy.teleport(Vector2(maw.global_position.x + 500.0, -252))
	var x0 := mafia.global_position.x
	for i in 50:
		maw._timers.clear()
		await frames(1)
	check(maw.is_inhaling() and mafia.global_position.x - x0 > 40.0,
		"phase 3 inhale drags the party toward the Maw (+%.0f px)" % (mafia.global_position.x - x0))
	party.reassign()

	# Defeat: collapse, flag, gate opens, cutscene pays out.
	Cutscenes.enabled = true
	GameState.clear_flag(&"slice_complete")
	var shards_before := GameState.shards
	await boss_damage_to(maw, 0)
	check(maw.state == MawBoss.State.DYING and GameState.has_flag(&"maw_defeated"), "at zero health the Maw collapses (flag saved)")
	for i in 600:
		await frames(1)
		if maw.state == MawBoss.State.DEAD and not Cutscenes.is_playing:
			break
	Cutscenes.enabled = false
	await frames(3)
	check(maw.state == MawBoss.State.DEAD and not gate.closed and cam.boss == null and not maw._bar.visible,
		"afterwards the gate opens, the bar hides and the camera returns")
	check(get_tree().get_nodes_in_group("tendrils").filter(func(t): return t.get_parent() == maw).is_empty(),
		"its tendrils are gone")
	check(GameState.has_flag(&"slice_complete") and GameState.shards == shards_before + 5,
		"boss_defeated cutscene plays: +5 shards, slice complete")

	# A save made after the fight keeps it dead.
	var ghost := MawBoss.new()
	main.add_child(ghost)
	await frames(1)
	check(ghost.state == MawBoss.State.DEAD and not ghost.visible, "loading after victory: the Maw stays defeated")
	ghost.queue_free()
	Sight.set_active(false)
	party.reassign()


## Hit the Maw the "right" way until its health reaches `target`: open the
## eye its core needs, seal any shielding portals, wait out invulnerability.
func boss_damage_to(maw: MawBoss, target: int) -> void:
	for i in 900:
		if maw.hp <= target or maw.state != MawBoss.State.FIGHT:
			return
		maw._timers.clear()
		for add in maw._adds:
			if is_instance_valid(add):
				Sight.set_active(true)
				add.on_shot(5)
		Sight.set_eye(maw.core_eye)
		Sight.set_active(true)
		maw.on_shot(1)
		await frames(1)
