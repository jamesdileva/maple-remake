# Maple Remake

A fast, high-density 2D action RPG inspired by classic platform MMORPGs.
Godot 4.x (GDScript only), 2D renderer, single-player first.

**Core fantasy:** the player is powerful from level 1 — full-map-style attacks, high mob density,
chain-mob reactions, auto-loot, generous progression, readable bosses.

## Status

Sprint 0.1 — Project Foundation.

## Documentation

- `docs/` — architecture and design suite (source of truth)
  - `docs/architecture.md` — technical architecture and frozen MVP decisions
  - `docs/sprint-roadmap.md` — sprint-by-sprint roadmap with exit criteria
  - `docs/game-design.md`, `docs/combat-design.md`, `docs/ultimates.md` — design
  - `docs/debug-and-qa.md` — debug tools and QA strategy
  - `docs/conventions.md` — naming and repo conventions
- `AGENTS.md` — agent workflow, verification commands, conventions

## Commands

```sh
godot --headless --quit                  # smoke test (import + run one frame)
godot --headless --script tests/run_tests.gd   # test suite
godot -e                                 # open editor
```

## Project Structure

```text
assets/    art, animation, effects, audio, ui
data/      classes, abilities, mobs, bosses, items, maps, loot, progression
scenes/    bootstrap, player, mobs, bosses, maps, ui, debug
scripts/   core, player, combat, entities, loot, progression, world, save, ui, debug
tests/     combat, progression, loot, bosses, performance
tools/     developer setup scripts
docs/      architecture suite
```
