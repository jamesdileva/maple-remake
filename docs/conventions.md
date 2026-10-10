# Naming Conventions

## Files and Folders

- Folders: `snake_case` (e.g. `scripts/combat/`)
- Scenes: `snake_case.tscn` (e.g. `test_room.tscn`)
- Scripts: `snake_case.gd`; a script attached to a scene is named after the scene
- Data: `data/**/*.tres`; `snake_case` filenames (e.g. `mage_fire_burst.tres`)

## GDScript

- `class_name` is PascalCase and singular (e.g. `class_name DamageSystem`)
- Signals use past tense (e.g. `mob_died`, `damage_dealt`)
- Private members use a leading underscore (e.g. `_cast_timer`)
- Public functions declare an explicit return type

## Nodes

- Node names inside scenes are PascalCase
- One autoload per system; the autoload is registered in `project.godot`

## Input

- Action names are lowercase snake_case (`move_left`, `attack`, `skill_1`)
- Every gameplay action binds keyboard/mouse AND gamepad before it is considered done

## Debug

- Debug scenes and scripts live under `scenes/debug/` and `scripts/debug/`
- Debug features must be toggleable via `DebugManager` and must never break release mode

## Git

- Conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `chore:`
- One commit per sprint; the message names the sprint
- `main` is the only branch
