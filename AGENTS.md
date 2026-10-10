# AGENTS.md

## Project

Maple Remake — a fast, high-density 2D action RPG inspired by classic platform MMORPGs.
Godot 4.x (GDScript only, no C# in MVP), 2D renderer, single-player first.

`docs/` is the source of truth. Read the relevant documents before implementing anything.

## Sprint Workflow (mandatory for every sprint)

1. **Plan + scope** — restate the sprint objective, scope, and exit criteria from
   `docs/sprint-roadmap.md` before writing code. Confirm scope fits the freeze rules below.
2. **Implement** — shared, data-driven systems. No per-class forks of core systems.
   Debug-first: every new system must be observable.
3. **Verify with tests** — run the verification commands below. A sprint is not done when code
   exists; it is done when the sprint's behavior is verified.
4. **Commit + push** — one commit per sprint, conventional commit message
   (`feat:`, `fix:`, `docs:`, `test:`), then push to origin.

## Verification Commands

- Smoke test (import + run a frame, headless):
  `godot --headless --quit`
- Test suite:
  `godot --headless --script tests/run_tests.gd`
- Open editor: `godot -e`

There is no separate linter/typechecker — parser and load errors surface in both commands above.
Both must pass before every commit and push.

## Debug-First Rule

The debug layer (`scripts/debug/`, `scenes/debug/`) exists from Sprint 0.2 and grows with every
sprint. Any system that misbehaves must be inspectable through:

- the debug overlay (FPS, frame time, entity counts, combat telemetry),
- `DebugManager` flags (god mode, infinite mana, show hitboxes, force crit, disable AI),
- structured debug log + `DebugManager.export_debug_data()` JSON snapshot
  (`user://debug/`).

When something breaks: reproduce, export debug data, then fix, then add a regression test.

## Conventions

- Files and folders: `snake_case`. Scenes: `*.tscn`. Scripts: `*.gd`. Data: `data/**/*.tres`.
- Assign `class_name` in PascalCase for scripts that need one.
- Input: use input actions only, never raw key polling. Every action binds keyboard/mouse AND
  gamepad. UI must be fully joypad-navigable.
- All damage flows through the centralized pipeline in `scripts/combat/`.
- Content is data-driven via Resources (`AbilityDefinition`, `MobDefinition`, `ItemDefinition`, ...).
- Avoid comments; only explain non-obvious "why".

## MVP Freeze

Frozen: Godot 4.x, 2D, single-player, 4 classes (Mage/Warrior/Archer/Assassin), one advancement
each at ~level 20, level cap 40–50, 10–20 hour first continent, high mob density, chain mobs,
full-map attacks from level 1, mana + cast time as FMA constraints (no default cooldown),
auto-loot, normalized equipment (weapon/top/bottom/helmet), free unlimited skill resets, no AP
system, readable boss telegraphs, non-punishing death, controller support, debug tools + combat
lab from day one.

Deferred: multiplayer, extra continents, second advancements, accessories, crafting, complex
affixes, trading, PvP, pets, guilds, boss checkpoints, multiple currencies. See `docs/README.md`.
