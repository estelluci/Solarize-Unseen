# Art slots

Every visual in Solarize: Unseen has a slot. To replace one, save your image as `art/slots/<slot>.png` (PNG, WebP, JPG or SVG). Its guide template is `art/templates/<slot>.png`; paint over a copy of it. Press **F3** in the game to see every template in place, and **F4** to reload art while the game is running.

**Size:** the game scales your image so its height matches the slot's size ("wide" slots match width instead). Only the proportions matter; paint at 2-4x the in-game size. In-game sizes are in game units (the Mafia is 100 units tall).

**Pivot:** where the image attaches, as a fraction across and down the image (0,0 = top-left). It's the red cross on the template.

Nothing needs to be set up in Godot. If something doesn't line up, add an entry for the slot in `art/art_tweaks.tres` (size, nudge, rotation, flip, pivot, tint).

## Character: Mafia

| Slot (file name) | What to paint | In-game size | Pivot | Template size | Animation it keeps |
| --- | --- | --- | --- | --- | --- |
| `mafia_head` | Head, facing right | 24 tall | 0.50, 0.50 | 256 x 256 | mirrors when turning; follows the body's lean and bob |
| `mafia_accessory` | Hat or hair, sitting on top of the head | 18 tall | 0.50, 1.00 | 256 x 192 | rides on the head |
| `mafia_torso` | Body from neck (top) to hips (bottom) | shoulder-to-hip length | 0.50, 0.00 | 128 x 256 | leans with speed; drops when feet plant on slopes |
| `mafia_upper_arm` | Upper arm, shoulder at top | shoulder-to-elbow length | 0.50, 0.00 | 64 x 192 | IK arm swing and aiming |
| `mafia_forearm` | Forearm, elbow at top | elbow-to-wrist length | 0.50, 0.00 | 64 x 192 | IK arm swing and aiming |
| `mafia_hand` | Hand, fingers pointing down | 9 tall | 0.50, 0.30 | 96 x 96 | follows the forearm |
| `mafia_thigh` | Thigh, hip at top | hip-to-knee length | 0.50, 0.00 | 64 x 192 | IK walking, foot planting, tucking in jumps |
| `mafia_shin` | Shin, knee at top | knee-to-ankle length | 0.50, 0.00 | 64 x 192 | IK walking, foot planting, tucking in jumps |
| `mafia_foot` | Foot, toes pointing right; pivot at the ankle | 14 wide | 0.30, 0.25 | 160 x 96 | planted on slopes by IK; mirrors when turning |
| `mafia_gun` | Gun, barrel pointing right; pivot at the grip | 22 wide | 0.15, 0.50 | 256 x 96 | aims at the mouse; recoils |

## Character: Fairy

| Slot (file name) | What to paint | In-game size | Pivot | Template size | Animation it keeps |
| --- | --- | --- | --- | --- | --- |
| `fairy_head` | Head, facing right | 24 tall | 0.50, 0.50 | 256 x 256 | mirrors when turning; follows the body's lean and bob |
| `fairy_accessory` | Hair, sitting on top of the head | 18 tall | 0.50, 1.00 | 256 x 192 | rides on the head |
| `fairy_torso` | Body from neck (top) to hips (bottom) | shoulder-to-hip length | 0.50, 0.00 | 128 x 256 | leans with speed; drops when feet plant on slopes |
| `fairy_upper_arm` | Upper arm, shoulder at top | shoulder-to-elbow length | 0.50, 0.00 | 64 x 192 | IK arm swing and aiming |
| `fairy_forearm` | Forearm, elbow at top | elbow-to-wrist length | 0.50, 0.00 | 64 x 192 | IK arm swing and aiming |
| `fairy_hand` | Hand, fingers pointing down | 9 tall | 0.50, 0.30 | 96 x 96 | follows the forearm |
| `fairy_thigh` | Thigh, hip at top | hip-to-knee length | 0.50, 0.00 | 64 x 192 | IK walking, foot planting, tucking in jumps |
| `fairy_shin` | Shin, knee at top | knee-to-ankle length | 0.50, 0.00 | 64 x 192 | IK walking, foot planting, tucking in jumps |
| `fairy_foot` | Foot, toes pointing right; pivot at the ankle | 14 wide | 0.30, 0.25 | 160 x 96 | planted on slopes by IK; mirrors when turning |
| `fairy_wing` | One wing, pointing up; pivot at its root (used for both wings, mirrored) | 44 tall | 0.50, 1.00 | 160 x 384 | flaps (faster in the air), spreads when gliding |

## Portals

| Slot (file name) | What to paint | In-game size | Pivot | Template size | Animation it keeps |
| --- | --- | --- | --- | --- | --- |
| `portal_swirl` | Portal swirl (round) | portal diameter | 0.50, 0.50 | 512 x 512 | spins; fades in with sight; reddens as it's damaged |
| `portal_core` | Portal centre | 36% of the portal radius, as a diameter | 0.50, 0.50 | 128 x 128 | fades with sight |
| `tendril_segment` | One tendril segment, root end at top (repeated along the tendril, thinning toward the tip) | segment length | 0.50, 0.00 | 64 x 128 | FABRIK reaching, curling, grabbing |
| `tendril_tip` | Tendril tip/claw, pointing down | 14 tall | 0.50, 0.00 | 96 x 128 | follows the last segment |

## Boss: the Maw

| Slot (file name) | What to paint | In-game size | Pivot | Template size | Animation it keeps |
| --- | --- | --- | --- | --- | --- |
| `maw_swirl` | Outer swirl (round) | boss diameter | 0.50, 0.50 | 1024 x 1024 | spins; grows in when it emerges, collapses when it dies |
| `maw_mouth` | Dark mouth (round) | mouth diameter (half the boss) | 0.50, 0.50 | 512 x 512 | emerge/collapse scale |
| `maw_teeth` | Ring of teeth around the mouth | mouth diameter | 0.50, 0.50 | 512 x 512 | slow wobble |
| `maw_core_solar` | The eye when its core is gold (Solar) | 42% of the mouth diameter | 0.50, 0.50 | 256 x 256 | tracks the nearest player; dims when shielded; flashes when hit |
| `maw_core_lunar` | The eye when its core is silver-blue (Lunar) | 42% of the mouth diameter | 0.50, 0.50 | 256 x 256 | tracks the nearest player; dims when shielded; flashes when hit |
| `maw_shield` | Shield bubble over the mouth | 95% of the mouth diameter | 0.50, 0.50 | 512 x 512 | pulses while shielded |
| `maw_cracks` | Cracks overlay | boss diameter | 0.50, 0.50 | 1024 x 1024 | fades in as health drops |
| `maw_beam` | Rift beam column (stretched to fit) | stretched | - | 128 x 512 | fires for half a second |
| `maw_beam_warning` | Beam warning line (stretched to fit) | stretched | - | 32 x 512 | blinks before the beam fires |
| `rift_orb` | Rift orb projectile | 28 tall | 0.50, 0.50 | 256 x 256 | pulses and spins while homing |
| `gate_vines` | Arena gate vines (stretched to the gate) | stretched | - | 128 x 512 | sways and glows while the fight is on |
| `gate_post` | Stone post beside the gate; pivot at its base | gate height | 0.50, 1.00 | 64 x 512 | static |

## Pickups

| Slot (file name) | What to paint | In-game size | Pivot | Template size | Animation it keeps |
| --- | --- | --- | --- | --- | --- |
| `pix_mote` | Pix mote | 26 tall | 0.50, 0.50 | 256 x 256 | bobs; drifts with Mote Magnet |
| `pix_sparkle` | Small sparkle (motes and the carry strand) | 5 tall | 0.50, 0.50 | 64 x 64 | orbits and drifts |
| `shard` | Lumen Shard crystal | 34 tall | 0.50, 0.50 | 256 x 256 | bobs and rocks |
| `checkpoint_unlit` | Checkpoint before it's reached; pivot at its base | 92 tall | 0.50, 1.00 | 128 x 384 | swaps to lit when touched |
| `checkpoint_lit` | Checkpoint once reached; pivot at its base | 92 tall | 0.50, 1.00 | 128 x 384 | static |

## Level

| Slot (file name) | What to paint | In-game size | Pivot | Template size | Animation it keeps |
| --- | --- | --- | --- | --- | --- |
| `ground_fill` | Soil/rock inside every ground shape (repeats) | one repeat = 128 tall | - | 256 x 256 | static |
| `ground_top` | Grass edge along the walkable tops (repeats along the edge) | 20 thick | - | 512 x 80 | follows every slope |
| `platform_true_path` | Hidden true-path platform (stretched) | stretched | - | 512 x 96 | appears with sight; tinted gold or blue by the eye |
| `platform_illusion` | Illusion platform as it looks with sight closed (stretched) | stretched | - | 512 x 96 | becomes a flicker outline with sight open |
| `water` | Chasm water (repeats) | one repeat = 96 tall | - | 256 x 256 | drifts sideways |
| `water_surface` | Water surface edge (repeats) | 12 thick | - | 512 x 48 | drifts sideways |

## Plants

| Slot (file name) | What to paint | In-game size | Pivot | Template size | Animation it keeps |
| --- | --- | --- | --- | --- | --- |
| `plant_palm` | Palm tree; pivot at the base | the plant's height (set per plant) | 0.50, 1.00 | 512 x 1024 | sways; randomly mirrored |
| `plant_banana` | Banana plant; pivot at the base | the plant's height (set per plant) | 0.50, 1.00 | 512 x 768 | sways; randomly mirrored |
| `plant_bamboo` | Bamboo cluster; pivot at the base | the plant's height (set per plant) | 0.50, 1.00 | 256 x 1024 | sways; randomly mirrored |
| `plant_monstera` | Monstera bush; pivot at the base | the plant's height (set per plant) | 0.50, 1.00 | 512 x 384 | sways; randomly mirrored |
| `plant_fern` | Fern; pivot at the base | the plant's height (set per plant) | 0.50, 1.00 | 384 x 256 | sways; randomly mirrored |
| `plant_hibiscus` | Hibiscus bush; pivot at the base | the plant's height (set per plant) | 0.50, 1.00 | 512 x 384 | sways; randomly mirrored |

## Backdrop

| Slot (file name) | What to paint | In-game size | Pivot | Template size | Animation it keeps |
| --- | --- | --- | --- | --- | --- |
| `backdrop_sky` | Sky (stretched over the screen) | full screen | - | 256 x 720 | static |
| `backdrop_far` | Far layer (volcano, sea): transparent where the sky shows; repeats sideways | screen height | - | 2048 x 720 | slowest parallax scroll |
| `backdrop_mid` | Middle layer (hills, palms); repeats sideways | screen height | - | 2048 x 720 | medium parallax scroll |
| `backdrop_near` | Near layer (jungle line); repeats sideways | screen height | - | 2048 x 720 | fastest parallax scroll |

## Effects

| Slot (file name) | What to paint | In-game size | Pivot | Template size | Animation it keeps |
| --- | --- | --- | --- | --- | --- |
| `carry_tether` | Glowing strand while the Fairy carries the Mafia (repeats) | 8 thick | - | 512 x 32 | dims and flickers as Pix runs out |
| `shot_tracer` | Gunshot trail (repeats) | 3 thick | - | 256 x 32 | flashes for a moment |
| `pix_meter_frame` | Pix meter background over the Fairy (stretched) | 38 x 5 | - | 256 x 48 | fades when full |
| `pix_meter_fill` | Pix meter fill (cropped to the amount left) | 38 x 5 | - | 256 x 48 | shrinks; turns pink when low |

## UI

| Slot (file name) | What to paint | In-game size | Pivot | Template size | Animation it keeps |
| --- | --- | --- | --- | --- | --- |
| `ui_dialogue_panel` | Dialogue box background (corners stay sharp) | stretched; 24 px corners | - | 384 x 192 | typewriter text appears on top |
| `ui_letterbox` | Cinematic bar (top and bottom) | stretched | - | 512 x 96 | slides in and out |
| `ui_menu_panel` | Upgrade menu background | stretched; 24 px corners | - | 384 x 256 | static |
| `ui_button` | Menu button | stretched; 12 px corners | - | 192 x 64 | static |
| `ui_button_hover` | Menu button under the mouse / selected | stretched; 12 px corners | - | 192 x 64 | static |
| `ui_button_disabled` | Locked or owned upgrade button | stretched; 12 px corners | - | 192 x 64 | static |
| `ui_boss_bar_frame` | Boss health bar background | 606 x 22 | - | 512 x 48 | static |
| `ui_boss_bar_fill` | Boss health bar fill (cropped to health; tinted by the core) | 600 x 16 | - | 512 x 32 | shrinks with damage; gold, blue or purple |
