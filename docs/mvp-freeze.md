# MVP Freeze (Sprint 18.4)

The MVP surface is frozen as of this document. The freeze is enforced by
`tests/release/test_mvp_freeze.gd`: any addition or removal to the pinned
content inventories or core values fails the suite, making a freeze break
a deliberate act (bump `FREEZE_VERSION` in the test and note why here).

## Frozen surface

- **Classes**: Mage, Warrior, Archer, Assassin — one advancement each at
  level 20 (`data/classes/`).
- **Continent**: brightwood_outskirts → sunlit_meadow → whispering_forest →
  hollow_forest → forgotten_mine → ruined_settlement → haunted_fortress →
  blightheart_sanctum, plus the thornhollow_ring side arena (`data/maps/`).
- **Bosses**: briarback_boar (12), mawroot (14), forge_warden (18),
  blightheart (28, is_final).
- **Progression**: level cap 50, xp curve base 250 / growth 1.30, chain
  mobs, auto-loot, normalized equipment (weapon/top/bottom/helmet), free
  unlimited skill resets, no AP system, mana + cast time as the only FMA
  constraints (no default cooldown), readable boss telegraphs,
  non-punishing death, controller bindings.
- **Core systems**: damage pipeline, spawn manager with density caps,
  loot tables, save/load (SAVE_VERSION 1), tutorial coach, debug layer,
  pacing/stress QA tools.

## Deferred to post-MVP

multiplayer, additional continents, second advancements, level 60/70/80
systems, accessories, crafting, guilds, PvP, trading, auction house,
equipment consumption, boss checkpoints, complex item affixes, pets,
large quest systems, multiple currencies, live-service systems.

## Deferred to a playtest (Phase 17 findings)

- Feel calibration: hit-stop duration/scale, camera shake magnitude —
  implemented, magnitudes need human feel.
- Class balance: mage clear speed (fast), archer run variance — the
  pacing bot's behavioral variance swamps data tweaks; needs played
  judgment.
- Audio (17.3): needs sound assets (attacks, deaths, loot, advancement,
  bosses, ambient, UI).
- UI visual/layout judgment and tutorial comprehension (17.2/17.4):
  structure contracts are automated; comprehension is human.

## Release validation

- `tools/pacing_report.gd --strict` — all four classes complete the
  continent with no cheats; time/deaths/bugs recorded per class.
- `tools/qa.gd` — the categorized QA gate over the full test suite.
- `tools/stress_qa.gd` — frame budget, load time, memory soak, entity
  ceilings, release readiness.
- `tests/run_tests.gd` — the full functional suite.
