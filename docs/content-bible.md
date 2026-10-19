# MVP Content Bible

## 1. Visual Direction

2D fantasy action RPG.

Target:
- polished enough to feel like a real game
- inexpensive enough for solo development
- visually expressive abilities
- strong silhouettes
- reusable environmental assets

## 2. World Tone

The first continent starts welcoming and gradually reveals horror.

Core contrast:

> Beautiful surface / unsettling reality.

## 3. Continent Structure

Suggested regions:

### Region 1 — Brightwood Village
Purpose:
- tutorial
- shops
- class introduction
- safe hub

Visual:
- warm colors
- flowers
- friendly architecture
- suspicious details

### Region 2 — Sunlit Meadow
Purpose:
- first dense combat zone
- simple mobs
- first chain mob

### Region 3 — Whispering Forest
Purpose:
- increased density
- vertical platforms
- darker enemies

### Region 4 — Hollow Forest
Purpose:
- horror reveal
- corrupted mobs
- stronger chain reactions

### Region 5 — Forgotten Mine
Purpose:
- industrial/mineral environment
- heavier mobs
- environmental hazards

### Region 6 — Ruined Settlement
Purpose:
- narrative/environmental storytelling
- elite enemies

### Region 7 — Haunted Fortress
Purpose:
- late-game combat
- stronger FMA showcase

### Region 8 — Continent Boss
Purpose:
- final MVP encounter

Exact map count is adjustable.

## 4. Mob Philosophy

Mobs should be:
- visually distinct
- mechanically simple
- numerous
- readable

Most mobs only need:
- movement behavior
- attack
- HP
- damage
- XP
- loot table

Some mobs can have one special trait:
- explode
- split
- chase
- jump
- shield
- heal
- teleport

Do not make every mob a complex mini-boss.

## 5. Chain Mob Examples

### Bloom Bomb
Cute flower creature.
Dies → smaller flowers.
Smaller flowers → seed bombs.

### Hollow Rabbit
Appears harmless.
Dies → shadow rabbits.
Shadow rabbits explode.

### Lantern Bug
Dies → swarm.
Swarm dies → sparks.

### Doll
Cracks open on death.
Spawns crawling fragments.

These are concepts, not final content.

## 6. Boss Philosophy

Bosses should contrast the normal mob experience.

Normal:
> player controls the chaos

Boss:
> player must read the chaos

Bosses should have:
- clear phases
- limited mechanics
- recognizable attacks
- large readable telegraphs

## 7. Ability Visual Philosophy

Abilities should be spectacular without requiring unique art for every frame.

Use:
- particles
- reusable impact sprites
- screen effects
- trails
- shaders
- sprite deformation
- layered animations

## 8. Mage Visuals

Base:
- fire explosion
- ice burst
- lightning chain

Advanced:
- hybrid explosions
- elemental combinations
- chain lightning
- large summons

## 9. Archer Visuals

Bow:
- arrow rain
- arrow bombs
- fast projectiles
- unusual projectile summons

Crossbow:
- giant bolts
- piercing attacks
- explosive bolts
- slow heavy impacts

## 10. Warrior Visuals

Base:
- sword strikes
- shield impacts
- swords falling from sky

Advanced:
- shockwaves
- weapon storms
- animal spirit effects
- warrior tribe summon
- giant sword/impact effects

## 11. Assassin Visuals

Base:
- shadow bursts
- dagger trails
- clones

Advanced:
- teleport
- shadow weapons
- simultaneous backstabs
- execution marks
- clone army effects

## 12. Art Production Pipeline

Potential agent workflow:

```text
Design brief
↓
Concept generation
↓
Human selects direction
↓
Blender asset generation/cleanup
↓
Animation creation
↓
Sprite/render export
↓
Godot integration
↓
Combat test
↓
Revision
```

An MCP-connected agent can assist with Blender operations if the chosen toolchain supports it.

This pipeline is implemented and runnable; see `docs/art-pipeline.md` for the
single-command workflow, the human approval gate and how to add a new mob. The
same flow produces the environment kits (one shared prop archetype table, region
variation by palette + placement); see the "Environment kits" section there.

## 13. Asset Reuse

Prioritize reusable:
- trees
- rocks
- buildings
- platforms
- particles
- impact effects
- shadows
- UI components
- monster base rigs

Variation should come from:
- color
- scale
- animation
- accessories
- shaders
- composition

## 14. MVP Content Limit

Do not create content merely because the system can support it.

The first continent should be complete and polished rather than enormous.
