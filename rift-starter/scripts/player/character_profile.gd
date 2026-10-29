class_name CharacterProfile
extends Resource
## Everything that makes one playable character feel different from another.
## Designers tune these in the Inspector (profiles/*.tres) — no code changes.

enum Look { MAFIA, FAIRY }

## Stable id used by upgrades, cutscenes and saves (&"mafia", &"fairy").
@export var id: StringName = &""
@export var display_name := "Character"
## Which eye this character has: &"Solar" (reality) or &"Lunar" (fantasy).
@export var sight_eye: StringName = &"Solar"

@export_group("Movement")
@export var run_speed := 260.0
@export var ground_accel := 2200.0
@export var ground_friction := 2600.0
@export var air_accel := 1400.0

@export_group("Jumping")
@export var jump_velocity := 620.0
@export var gravity := 1800.0
## Falling feels snappier when gravity is stronger on the way down.
@export var fall_gravity_multiplier := 1.5
## Extra gravity while rising with jump released (short hops).
@export var jump_cut_gravity_multiplier := 2.5
@export var max_fall_speed := 900.0
## Grace period to still jump after walking off a ledge.
@export var coyote_time := 0.1
## Jump pressed slightly before landing still counts.
@export var jump_buffer_time := 0.12
@export var air_jumps := 0

@export_group("Abilities")
## Named abilities code can check with Player.has_ability(). Upgrades add more
## (e.g. &"wall_jump").
@export var abilities: Array[StringName] = []
@export var can_aim := false
@export var can_glide := false
@export var glide_fall_speed := 90.0

## Damage per shot against portals.
@export var shot_power := 1
## How much each jump press weakens a tendril's grip.
@export var struggle_strength := 1
## Wall jump tuning (only used with the &"wall_jump" ability).
@export var wall_jump_push := 320.0
@export var wall_slide_speed := 140.0

@export_group("Carrying (Pix energy)")
## Can pick up the partner and fly with them (the Fairy).
@export var can_carry := false
@export var pix_max := 100.0
## Pix spent per second just holding the partner.
@export var pix_carry_drain := 30.0
## Extra Pix per second while flying upward (holding jump).
@export var pix_lift_drain := 25.0
@export var pix_regen := 28.0
## Pause after a carry before Pix starts refilling.
@export var pix_regen_delay := 0.6
## Need at least this much Pix to start a carry.
@export var pix_min_to_grab := 30.0
@export var carry_rise_speed := 170.0
@export var carry_sink_speed := 70.0
@export var carry_vertical_accel := 1000.0
## Horizontal speed multiplier while carrying.
@export var carry_speed_multiplier := 0.7
## How far below the carrier the partner hangs (pixels, unscaled).
@export var carry_hang_distance := 128.0
## Pix motes drift toward the party from this far away (0 = off).
@export var mote_magnet_radius := 0.0

@export_group("Look")
## Overall size. 1.0 = Mafia size; the Fairy is small.
@export_range(0.3, 1.5, 0.05) var body_scale := 1.0
@export var look: Look = Look.MAFIA
@export var body_color := Color(0.149, 0.149, 0.18, 1.0)
@export var accent_color := Color(0.75, 0.15, 0.2)
@export var accent_color2 := Color(0.75, 0.15, 0.2)
@export var skin_color := Color(0.93, 0.78, 0.66)
## Skin name to use when this character is drawn by a SpineRig.
@export var spine_skin := ""
