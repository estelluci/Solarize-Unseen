# Writing cutscenes

Cutscenes are plain text files in this folder, ending in `.cutscene`. You don't need to touch code to write or change one. Open the file in any text editor (or Godot's script editor), edit it, and run the game.

## The basics

Each line is one command: the command name first, then its arguments, separated by spaces. Put anything with spaces inside "double quotes".

```
# Lines starting with # are notes for the team; the game ignores them.
letterbox on
camera mafia 1.8
say fairy "You nearly got swallowed by a portal."
say mafia "I remember a very small person yelling."
move fairy 300
emote fairy "!"
set_flag met_fairy
letterbox off
```

- **Indentation doesn't matter**, but it makes `if` blocks easier to read.
- **Quotes inside a line:** write `\"`, as in `say mafia "She said \"run\"."`
- **Actors:** `mafia`, `fairy`, `leader` (whoever player 1 is playing) and `partner`. With `say`, the speaker can also be any name, like `Boss` or `Radio`, and it's simply shown as written.

## Commands

| Command | What it does |
|---|---|
| `say <speaker> "text"` | A line of dialogue. The player presses Space or Enter to continue. |
| `narrate "text"` | A dialogue line with no speaker. |
| `wait <seconds>` | Pause. |
| `move <actor> <x> [speed]` | Walk to a spot. Speed goes from 0.2 to 1.0 and defaults to 0.6. |
| `face <actor> <left / right / actor>` | Turn around, or turn toward someone. |
| `jump <actor>` | Jump. |
| `teleport <actor> <x> <y>` | Put someone somewhere instantly. |
| `emote <actor> "text" [seconds]` | A floating bubble over their head: `"!"`, `"?"`, `"..."`. |
| `camera <actor> [zoom]` | Point the camera at someone. 1.5 is normal zoom; bigger is closer. |
| `camera <x> <y> [zoom]` | Point the camera at a spot in the level. |
| `camera_reset` | Give the camera back to the game. |
| `letterbox <on / off>` | Cinematic black bars. |
| `fade_out [seconds]` / `fade_in [seconds]` | Fade to black and back. |
| `sight <on / off> [Solar / Lunar]` | Open or close the sight. |
| `set_flag <name>` / `clear_flag <name>` | Remember or forget something. Flags are saved with the game. |
| `give_shards <amount>` | Give Lumen Shards. |
| `give_upgrade <id>` | Give an upgrade for free. The ids are the file names in `res://upgrades/`. |
| `emit <event>` | Tell the level something happened. Objects listen for their own event names: `emit maw_wake` wakes the Maw. It still fires when the cutscene is skipped. |

## Logic: if / else / end

```
if not flag met_fairy
    say fairy "Who are you?"
    set_flag met_fairy
else
    say fairy "You again."
end
```

You can check:

- `flag <name>`: was this flag set?
- `upgrade <id>`: does the party own this upgrade?
- `eye Solar` or `eye Lunar`: is that eye open right now?
- `sight`: is any eye open?

Put `not` in front of any of these to flip it. Blocks can be nested.

## Skipping

Players can press **Esc** to skip any cutscene. Skipping never breaks the story:

- Flags, shards, upgrades, sight and positions still change exactly as written. A skipped `move` puts the character on their mark.
- Only dialogue, waits, fades and camera moves are dropped.

## Playing a cutscene in the level

1. Add an `Area2D` to the level and attach `scripts/cutscene/cutscene_trigger.gd`.
2. Pick the `.cutscene` file and set `size`.
3. Optionally set:
   - `require_flag`: only plays after something else happened.
   - `skip_if_flag`: never plays once something happened.
   - `once`: on by default; it remembers that it played.
   - `autoplay`: plays as soon as the level loads, like the intro.

From code: `await Cutscenes.play_file("res://cutscenes/my_scene.cutscene")`.

## Mistakes are caught for you

If a command is misspelled, has the wrong number of arguments, or names an unknown actor or upgrade, the game prints an error with the file and line number (for example `intro.cutscene:12: unknown actor 'mafie'`) and doesn't play that cutscene. The automated test also checks every file in this folder.

## Exporting the game

`.cutscene` files aren't Godot resources. When you set up an export, open **Project > Export > Resources** and add `*.cutscene` under **Filters to export non-resource files**.
