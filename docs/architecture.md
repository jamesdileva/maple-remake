# 2D Action RPG — MVP Architecture

## 1. Project Definition

Working description:

> A fast, high-density 2D action RPG inspired by classic platform MMORPGs, where the player becomes powerful immediately, full-screen attacks are available from level 1, progression is generous, systems are intentionally simple, and bosses reward readable mechanical play rather than external guides.

MVP is **single-player first**. Multiplayer is a future layer built only after the single-player game has been extensively tested.

### MVP boundaries

- 1 continent / compact world slice
- 4 base classes
- 1 advancement per class
- Advancement at approximately level 20
- Level cap approximately 40–50
- Approximately 10–20 hours of first-playthrough content
- 4-player party architecture planned, but not enabled for MVP
- High-density normal mobs
- Full-map-style attacks from level 1
- Generous XP and drop rates
- Auto-loot / vacuum loot
- Simple equipment
- Free and unlimited skill resets
- Every ability can ultimately be maxed
- Bosses with readable telegraphs and mechanically understandable attacks
- Debug tools from the beginning
- Combat test arena from the beginning
- Art pipeline designed to work with agent-assisted Blender/Godot workflows

## 2. Core Design Principles

1. **Power starts at level 1.**
2. **Normal mobs exist to be destroyed in large quantities.**
3. **Bosses are mechanical encounters.**
4. **If a player dies, the reason should be obvious.**
5. **No character can be permanently ruined by a build decision.**
6. **Loot should never become inventory-management homework.**
7. **A player should understand the game without external websites.**
8. **Four classes should feel different without creating a "bad" class.**
9. **The game should be generous with time and rewards.**
10. **The number of systems is intentionally small.**
11. **Debugging is a first-class development feature.**
12. **Single-player is the authoritative MVP architecture.**
13. **Content should be data-driven wherever practical.**
14. **Visual spectacle should come from abilities and density, not enormous asset requirements.**
15. **Avoid copying specific MapleStory assets, characters, maps, names, UI, or proprietary content.**

## 3. Recommended Technology

### Engine

**Godot 4.x**

Reasoning:

- Excellent fit for 2D
- Open-source
- Strong animation and particle support
- Good scene/node workflow
- GDScript is fast to iterate
- C# can remain an option for performance-critical systems
- Easy local builds
- Suitable for solo development
- Good fit for agent-assisted development

### Language

Primary:
- GDScript

Optional later:
- C# or GDExtension only if profiling proves it necessary

Do not prematurely optimize by splitting the project across languages.

### Art

- Blender for procedural/3D-assisted source work where useful
- 2D sprite/animation pipeline
- Godot AnimatedSprite2D / AnimationPlayer / particles / shaders
- Agent-assisted concept generation
- Agent-assisted Blender automation through MCP or equivalent development tooling
- Human approval gate before assets enter the game

### Persistence

MVP:
- Local save files
- JSON or Godot Resource-based save data
- Versioned save format

No server database for MVP.

### Input

- Keyboard/mouse and controller support are day-one requirements, not a post-MVP port.
- All gameplay actions route through Godot input actions defined in `project.godot`.
- Gameplay code must not poll raw key states directly.
- Every player-facing action needs both keyboard/mouse and gamepad bindings.
- Menus, HUD, and debug tools must be fully navigable with a controller.
- Analog input requires configured deadzones.
- UI must display prompts for the active input device and support live device switching.
- Debug and combat-lab controls must be usable with a controller.

## 4. High-Level Architecture

```text
Game
├── Bootstrap
├── Game State
├── Player
│   ├── Character
│   ├── Class
│   ├── Stats
│   ├── Abilities
│   ├── Equipment
│   ├── Inventory
│   └── Progression
├── Combat
│   ├── Damage
│   ├── Critical
│   ├── Status
│   ├── Hit Detection
│   ├── Skills
│   ├── Summons
│   └── Mob Chains
├── World
│   ├── Maps
│   ├── Platforms
│   ├── Spawn Zones
│   ├── Portals
│   └── Boss Arenas
├── Entities
│   ├── Mobs
│   ├── Elites
│   └── Bosses
├── Loot
│   ├── Drops
│   ├── Auto Loot
│   └── Equipment
├── UI
├── Audio
├── Debug
├── Save
└── Content Data
```

## 5. Suggested Project Structure

```text
project/
├── project.godot
├── assets/
│   ├── art/
│   ├── animation/
│   ├── effects/
│   ├── audio/
│   └── ui/
├── data/
│   ├── classes/
│   ├── abilities/
│   ├── mobs/
│   ├── bosses/
│   ├── items/
│   ├── maps/
│   ├── loot/
│   └── progression/
├── scenes/
│   ├── bootstrap/
│   ├── player/
│   ├── mobs/
│   ├── bosses/
│   ├── maps/
│   ├── ui/
│   └── debug/
├── scripts/
│   ├── core/
│   ├── player/
│   ├── combat/
│   ├── entities/
│   ├── loot/
│   ├── progression/
│   ├── world/
│   ├── save/
│   ├── ui/
│   └── debug/
├── tests/
│   ├── combat/
│   ├── progression/
│   ├── loot/
│   ├── bosses/
│   └── performance/
└── docs/
```

## 6. Combat Architecture

Combat should be driven by events/data rather than hard-coded class-specific logic.

Core concepts:

```text
AbilityDefinition
├── id
├── class
├── mana_cost
├── cast_time
├── cooldown
├── damage_profile
├── crit_behavior
├── targeting
├── hit_behavior
├── visual_effect
├── summon_behavior
└── progression_requirements
```

Important MVP rule:

**Full-map attacks do not require cooldowns.**

Their limiting factors are:

- mana
- cast time
- positioning
- interruption/risk where appropriate

A future ability can still have a cooldown if a specific mechanic truly needs one, but cooldowns should not be the default answer to balance.

## 7. Damage Pipeline

Recommended flow:

```text
Ability Started
      ↓
Cast Validation
      ↓
Mana Cost
      ↓
Cast / Animation
      ↓
Target Query
      ↓
Damage Calculation
      ↓
Critical Roll
      ↓
Defense / Mitigation
      ↓
Damage Applied
      ↓
Death Check
      ↓
On-Kill Effects
      ↓
Loot / XP
      ↓
Visual / Audio Feedback
```

Damage calculation should be centralized so that class abilities do not implement their own incompatible formulas.

## 8. Mob Density Architecture

The game intentionally supports very high entity counts.

Use:

- object pooling
- lightweight mob state
- centralized or efficient target queries
- limited expensive per-frame behavior
- pooled projectiles/effects
- controlled spawn budgets
- profiling tools

Mobs should not each perform expensive searches every frame.

### Mob chain mechanic

Some mobs can die into additional mobs:

```text
Parent Mob
   ↓ death
3–6 Lesser Mobs
   ↓ death
additional Lesser Mobs
   ↓ death
chain ends
```

The chain should be configured as data so different monsters can use different patterns.

This creates the desired:

> kill one mob → chain reaction → entire group explodes

effect.

The system must include a configurable chain-depth and entity-budget cap to prevent accidental runaway spawning.

## 9. Full-Map Attack Architecture

"Full-map" is a gameplay category rather than one implementation.

MVP tiers:

### Tier 1
Screen-wide or large visible-area attacks.

### Tier 2
Expanded-area attacks.

### Tier 3
Multi-platform / multi-region attacks.

### Future
Multi-map or world-scale effects.

A map can be architected around combat regions rather than assuming the entire world is always loaded.

This preserves the fantasy while allowing the MVP to use compact platform maps.

## 10. Class Architecture

All classes implement the same high-level contract:

```text
Class
├── primary attacks
├── FMA
├── defensive/mobility mechanic
├── party buff
├── summon
├── advancement
└── progression tree
```

### Mage

Identity:
- elemental destruction
- mana shield
- high burst

Base:
- fire
- ice
- lightning
- early screen-clear attacks
- summon

Advancement:
- elemental hybrids
- chain lightning
- combination attacks
- stronger FMA
- advanced summon

Party buff:
- automatic lethal-damage prevention on a periodic timer
- leaves player at 1 HP
- brief invulnerability window

### Warrior

Identity:
- high HP
- mitigation
- reliable damage
- juggernaut transformation

Base:
- sword + shield
- heavy strikes
- shockwave/FMA
- summon

Advancement:
- mobility
- damage reduction
- attack speed
- movement speed
- crit
- spirit/weapon spectacle
- advanced summon

Party buff:
- increased party HP/MP while Warrior is present

### Archer

Identity:
- range
- precision
- balanced survivability
- bow/crossbow weapon switching

Bow:
- faster
- better mob clearing
- rain of arrows
- arrow bombs
- projectile/summon variants

Crossbow:
- slower
- heavier
- penetration
- boss-focused damage
- large projectile attacks

Visual concept:
- character can visibly carry the alternate weapon
- fast swap animation

Party buff:
- increased critical chance and/or skill range
- exact values tuned during combat testing

### Assassin

Identity:
- speed
- mobility
- dodge
- execution
- shadows

Base:
- daggers
- shadow attacks
- clone
- mobility
- early FMA

Advancement:
- execution mechanics
- teleport/backstab effects
- shadow weapons
- clone-based FMA
- advanced summon

Party buff:
- attack speed
- movement speed
- jump speed

## 11. Crit

Every class must have reliable access to critical chance.

Crit is a meaningful combat stat, not a spreadsheet optimization puzzle.

Avoid designing the game around requiring near-100% crit.

## 12. Defensive Design

### Mage

Mana can function as a secondary survivability layer.

### Warrior

HP and mitigation.

### Archer

Balanced baseline.

### Assassin

Mobility, dodge, positioning.

No class should be designed around routinely being one-shot by ordinary mobs.

## 13. Progression

MVP target:

```text
Level 1
  ↓
Early class identity
  ↓
Level ~20
  ↓
Class advancement
  ↓
Advanced class progression
  ↓
Level 40–50
  ↓
End of first continent
```

All abilities can eventually be maxed.

Skill resets:
- free
- unlimited
- immediate
- no permanent mistakes

No AP/stat allocation panel is required.

## 14. Equipment

MVP equipment:

- Weapon
- Armor top
- Armor bottom
- Helmet

No accessory system required.

Equipment should be normalized and readable.

Example:

```text
Level 20 Sword
+100 Power
```

means exactly what it says.

No hidden:
- decimal stat rolls
- random affix soup
- mandatory external calculators

### Equipment progression idea

A possible "equipment consumption" system may allow old equipment to feed a small amount of power into the current item.

This is **deferred**.

It should not be included unless playtesting shows that normal drops become too meaningless.

## 15. Loot

Auto-loot/vacuum is enabled.

The player should not manually walk over every item.

Loot philosophy:

> Kill → rewards are collected → continue playing.

Drops should be generous.

Bosses may provide desirable equipment and/or valuable currency, but there should be no mandatory hundreds-of-hours chase item.

## 16. Currency

MVP should use one primary currency.

NPC shops can sell relevant equipment/items.

Player-to-player trading is deferred until multiplayer exists.

The system should still leave room for bosses to provide valuable drops so currency and equipment retain meaning.

## 17. Party Architecture

Party size target:
- 4 players

MVP:
- architecture-compatible
- multiplayer disabled

Party buffs are **presence-based**, not cast-based.

No party member should need to remember:

> "I need to rebuff everyone."

### Unique-class XP

Example:

```text
1 unique class: 1x party bonus
2 unique classes: 2x
3 unique classes: 3x
4 unique classes: 4x
```

Four identical classes only receive the benefit associated with one unique class.

The exact XP formula is tunable, but the rule is fixed:

> Unique class diversity is rewarded.

## 18. Boss Architecture

Bosses use:

- telegraphed attacks
- readable hit zones
- explicit safe zones
- phase transitions
- recovery windows
- deterministic or controlled patterns where practical

A boss may be killed extremely quickly by an overpowered player.

That is intentional.

Boss design tests:
- Can a player understand every attack?
- Is the telegraph unambiguous?
- Is the failure reason obvious?
- Can the player improve without a wiki?
- Can overleveling still meaningfully reduce the fight?

## 19. Death

Normal death is not intended to be punishing.

Boss death:
- immediate retry
- no significant XP loss
- no item destruction
- no lengthy recovery loop

Boss checkpoints are deferred.

## 20. World Architecture

Maps should be compact and platform-based.

Preferred traversal:
- jumps
- platforms
- portals
- simple vertical navigation

Ropes/ladders are not required for MVP.

Because FMA attacks are powerful, normal traversal does not need to be a large part of mob clearing.

Bosses restore the importance of movement.

## 21. Save Architecture

Save:

- character level
- XP
- currency
- abilities
- equipment
- inventory
- world progress
- settings

Use save versioning from day one.

Never assume the save format will remain unchanged.

## 22. Debug Architecture

Debug mode is a required MVP system.

Minimum tools:

- god mode
- kill mobs
- spawn mobs
- spawn boss
- add XP
- add currency
- add skill points
- reset skills
- equip test gear
- teleport
- reset encounter
- performance overlay
- entity count
- damage meter
- skill cast telemetry

## 23. Combat Lab

A dedicated test scene should support:

- 1 / 10 / 50 / 100 / 250 mobs
- selected mob type
- selected class
- selected ability
- infinite mana
- controlled stats
- boss spawn
- damage measurement
- clear/reset
- performance metrics

This scene should exist before the world is content-complete.

## 24. Multiplayer Future Boundary

Do not build networking into every gameplay class during MVP.

Instead:
- centralize game state
- keep combat data-driven
- avoid hidden global state
- keep player actions explicit
- isolate persistence
- keep authoritative calculations in centralized systems

After MVP:
1. local co-op/prototype
2. network simulation
3. synchronization
4. server authority
5. persistence
6. matchmaking

No commitment to a specific backend yet.

## 25. Art Pipeline

Development pipeline:

```text
Design prompt
   ↓
Agent concept generation
   ↓
Human approval
   ↓
Agent/Blender production
   ↓
Sprite/animation/effect export
   ↓
Godot import
   ↓
In-game test
   ↓
QA
```

A dedicated art-production sprint can use an agent connected to Blender through MCP-style tooling where practical.

MCP is treated as a development integration layer, not as part of the game runtime.

## 26. Performance Targets

Initial target:
- stable 60 FPS on a reasonable integrated-GPU PC during normal combat

Stress target:
- high mob density
- many simultaneous effects
- chained mob explosions
- FMA
- summons

Do not define a final entity count until profiling exists.

Measure first.

## 27. Architecture Decisions to Freeze

Frozen for MVP:

- Godot 4.x
- 2D
- single-player
- 4 classes
- one advancement per class
- advancement around level 20
- level cap approximately 40–50
- 10–20 hour first continent
- generous progression
- free unlimited skill resets
- no AP system
- simple equipment
- auto-loot
- high mob density
- full-map-style attacks from level 1
- no default cooldown on FMA
- mana + cast time as primary FMA constraints
- boss mechanics based on readable telegraphs
- debug tools from day one
- combat test lab
- party size 4 as future architecture
- unique-class party XP scaling
- passive/presence-based party buffs

Deferred:

- multiplayer
- additional continents
- second class advancements
- accessories
- crafting
- complex item affixes
- elaborate talent systems
- trading
- boss checkpoints
- equipment consumption
- multiple currencies
- guilds
- pets
- PvP
- endgame live-service systems
