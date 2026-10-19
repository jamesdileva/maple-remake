# 2D Action RPG Architecture Suite

## Documents

1. `architecture.md` — technical architecture and frozen MVP decisions
2. `sprint-roadmap.md` — detailed implementation roadmap and verification criteria
3. `implementation-guide.md` — practical implementation sequence
4. `game-design.md` — player-facing design philosophy and systems
5. `combat-design.md` — classes, FMAs, mobs, bosses, and balance
6. `debug-and-qa.md` — debug tools, test strategy, and performance QA
7. `content-bible.md` — world, visual direction, mobs, abilities, and art pipeline
8. `art-pipeline.md` — agent-assisted spec → concept → Blender → sprites workflow (mobs and environment kits)

## MVP Freeze

The suite freezes the current MVP as:

- Godot 4.x
- 2D
- single-player first
- 4 classes
- one advancement per class
- advancement around level 20
- level cap around 40–50
- 10–20 hour first continent
- high-density mobs
- chain/splitting mobs
- full-map-style attacks from level 1
- FMA constrained primarily by mana and cast time
- auto-loot/vacuum
- keyboard/mouse + controller support from day one
- simple normalized equipment
- free unlimited skill resets
- no AP system
- readable boss telegraphs
- no punitive death loop
- debug tools from day one
- combat lab
- future 4-player party architecture
- unique-class party XP multiplier
- passive/presence-based party buffs

Multiplayer, additional continents, extra advancements, crafting, accessories, complex affixes, trading, PvP, and other MMO systems are explicitly deferred.
