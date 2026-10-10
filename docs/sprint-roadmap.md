# Sprint Roadmap

## Roadmap Philosophy

This roadmap intentionally prioritizes the **playable game loop** over MMO infrastructure.

The most important milestone is not:
> "We have four classes."

It is:
> "Running through a dense map, destroying huge groups of enemies, collecting rewards automatically, and advancing feels great."

Each sprint has:
- objective
- scope
- implementation targets
- verification
- exit criteria

Do not move forward merely because code exists. Move forward when the sprint's behavior has been verified.

---

# Phase 0 — Project Foundation

## Sprint 0.1 — Repository and Godot Foundation

### Goal
Create a clean, reproducible Godot project.

### Work
- initialize repository
- create Godot project
- configure 2D renderer
- create folder structure
- establish input actions (keyboard/mouse + gamepad from day one)
- establish naming conventions
- establish debug build
- add README
- add docs folder

### Verification
- project launches
- blank test scene loads
- no parser errors
- repository is clean
- debug build launches
- every gameplay/UI action works with keyboard/mouse and controller

### Exit
Project can be cloned and opened without manual repair.

---

## Sprint 0.2 — Debug Foundation

### Goal
Make debugging a first-class system.

### Work
Create:
- debug overlay
- FPS
- frame time
- entity count
- player coordinates
- current map
- debug toggle

Add initial commands:
- God mode
- teleport
- reload scene

### Verification
- debug overlay can be toggled
- values update live
- commands work
- debug code does not break release mode

### Exit
Every later sprint has a basic debugging surface.

---

# Phase 1 — Movement and Combat Core

## Sprint 1.1 — Player Movement

### Goal
Make basic platform movement feel good.

### Work
- player scene
- collision
- horizontal movement
- acceleration
- deceleration
- jump
- gravity
- animation state machine

### Verification
- movement feels responsive
- no wall sticking
- no infinite jumping
- no falling through platforms

### Exit
A player can comfortably traverse a simple test room.

---

## Sprint 1.2 — First Mob

### Goal
Create the smallest possible enemy.

### Work
- mob scene
- HP
- contact/attack behavior
- death
- XP event
- basic animation

### Verification
- mob spawns
- mob approaches player
- player can damage mob
- mob dies
- XP event fires

### Exit
There is a functioning player-vs-mob loop.

---

## Sprint 1.3 — Centralized Damage System

### Goal
Prevent combat logic from becoming fragmented.

### Work
Implement:
- DamageEvent
- damage calculation
- defense
- crit
- death
- kill event

### Verification
Test:
- normal hit
- critical hit
- lethal hit
- overkill
- invalid target

### Exit
All damage travels through one predictable pipeline.

---

## Sprint 1.4 — First Ability

### Goal
Create a real skill.

### Work
- ability data definition
- mana cost
- cast time
- animation
- damage
- targeting
- VFX

### Verification
- ability consumes mana
- cast time is enforced
- target is hit
- animation matches timing

### Exit
A player can intentionally cast a meaningful combat skill.

---

# Phase 2 — The Game's Signature Combat

## Sprint 2.1 — First FMA

### Goal
Prove the central fantasy.

### Work
Create:
- large-area attack
- no cooldown
- mana cost
- cast time
- visual spectacle

### Verification
Spawn:
- 1 mob
- 10 mobs
- 50 mobs
- 100 mobs

Cast FMA.

Verify:
- correct targets hit
- mana deducted once
- cast cannot be repeated instantly
- all expected enemies die

### Exit
The game already feels different from a traditional early-level RPG.

---

## Sprint 2.2 — Mob Density

### Goal
Make dense combat performant.

### Work
- object pooling
- spawn manager
- configurable spawn zones
- mob caps
- mass death handling

### Verification
- 100 mobs
- 250 mobs
- mass simultaneous death
- respawn

Measure:
- FPS
- frame time
- memory

### Exit
Dense combat is stable enough to build around.

---

## Sprint 2.3 — Chain Mobs

### Goal
Create chain-reaction spectacle.

### Work
- death-spawn payload
- child mob definition
- chain depth
- child count
- global entity safety cap
- explosion VFX

### Verification
Example:
- parent
- 5 children
- each creates 3
- final generation stops

Verify:
- no infinite loop
- no runaway entity count
- XP is awarded correctly
- loot is reasonable

### Exit
A single death can create a satisfying controlled chain reaction.

---

## Sprint 2.4 — Auto Loot

### Goal
Remove pickup friction.

### Work
- loot generation
- vacuum
- inventory
- currency collection
- pickup VFX

### Verification
Kill dense mob pack.

Verify:
- drops appear
- items automatically collect
- currency updates
- player never has to individually click each item

### Exit
The combat loop remains uninterrupted by loot management.

---

# Phase 3 — Progression

## Sprint 3.1 — XP and Leveling

### Work
- XP table
- level thresholds
- level-up
- basic stat scaling
- level UI

### Verification
- XP accumulation
- level-up
- overflow XP
- save/load

---

## Sprint 3.2 — Skill Point System

### Work
- skill points
- ability levels
- unlock requirements
- unlimited reset

### Verification
- spend points
- reset
- spend again differently
- max skill
- no permanent damage to character

### Exit
The player cannot ruin their character.

---

## Sprint 3.3 — Equipment

### Work
Implement:
- weapon
- top
- bottom
- helmet
- normalized stats
- equip/replace

### Verification
- equipment comparison is obvious
- equip works
- save/load works
- no hidden stat calculations

### Exit
A player can understand whether equipment is better by reading it.

---

## Sprint 3.4 — Save System

### Work
Save:
- level
- XP
- skills
- equipment
- inventory
- currency
- world progress

Add save version.

### Verification
- save
- close
- reopen
- load
- confirm identical state

Test version mismatch behavior.

---

# Phase 4 — Mage Vertical Slice

## Sprint 4.1 — Mage Base Class

### Goal
Complete one class before multiplying complexity.

### Work
- staff
- elemental attacks
- fire
- ice
- lightning
- FMA
- mana shield
- basic summon
- class UI

### Verification
Mage can:
- clear dense mobs
- survive normal content
- use multiple elemental abilities
- summon
- use FMA

### Exit
Mage feels like a complete character.

---

## Sprint 4.2 — Mage Advancement

### Work
- advancement quest/interaction
- elemental hybrids
- stronger FMA
- chain lightning
- advanced summon
- visual transformation

### Verification
Compare pre/post advancement.

The player should immediately feel:
> "My character changed."

---

## Sprint 4.3 — Mage Party Buff

### Work
Implement automatic lethal protection.

Rules:
- triggers automatically
- leaves player at 1 HP
- temporary invulnerability
- recovery window

### Verification
- lethal hit
- protection triggers
- player survives
- repeated trigger waits appropriate duration
- no manual casting

---

# Phase 5 — Combat Lab

## Sprint 5.1 — Combat Lab Foundation

### Goal
Create the primary balance tool.

### Work
Controls:
- class selector
- level selector
- equipment selector
- mob selector
- spawn count
- boss selector

Buttons:
- spawn
- kill
- reset
- infinite mana
- god mode

### Verification
Can switch between classes without restarting.

---

## Sprint 5.2 — Damage Meter

### Work
Track:
- total damage
- DPS
- crits
- skill usage
- targets hit
- targets killed
- boss time

### Verification
Run identical encounters for each class.

---

## Sprint 5.3 — Stress Testing

### Work
Test:
- 100 mobs
- 250 mobs
- chain reactions
- FMA
- summons
- effects

### Exit
Performance bottlenecks are known before large-scale content production.

---

# Phase 6 — Warrior

## Sprint 6.1 — Warrior Base

### Work
- sword/shield
- HP identity
- heavy attacks
- early FMA
- summon

### Verification
Warrior clears equivalent content.

---

## Sprint 6.2 — Juggernaut Advancement

### Work
- mobility
- damage reduction
- attack speed
- movement speed
- crit
- large attacks
- spirit/weapon effects
- summon

### Verification
Warrior feels substantially transformed without becoming objectively superior.

---

## Sprint 6.3 — Warrior Party Buff

Implement always-on HP/MP party modifier.

Test simulated parties.

---

# Phase 7 — Archer

## Sprint 7.1 — Bow

### Work
- fast attacks
- mob-focused attacks
- arrow rain
- arrow bombs
- summon

### Verification
Bow clears dense packs effectively.

---

## Sprint 7.2 — Crossbow

### Work
- heavy projectiles
- slower attacks
- penetration
- boss damage
- large effects

### Verification
Crossbow clearly feels different from Bow.

---

## Sprint 7.3 — Weapon Switching

### Work
- visible alternate weapon
- fast swap
- animation
- ability compatibility

### Verification
Player can switch during normal combat without inventory interruption.

---

## Sprint 7.4 — Archer Advancement and Buff

Implement:
- advancement
- expanded artillery
- advanced summon
- crit/range party buff

---

# Phase 8 — Assassin

## Sprint 8.1 — Assassin Base

### Work
- dagger
- dash
- dodge
- shadow attack
- clone
- early FMA
- summon

### Verification
Mobility feels immediately different.

---

## Sprint 8.2 — Assassin Advancement

### Work
- execution
- teleport
- backstab
- shadow weapons
- multi-target effects
- clone FMA
- advanced summon

### Verification
Advanced Assassin feels like an evolution rather than a stat upgrade.

---

## Sprint 8.3 — Assassin Party Buff

Implement:
- attack speed
- movement speed
- jump speed

Presence-based.

---

# Phase 9 — Four-Class Balance

## Sprint 9.1 — Shared Power Budget

### Goal
Ensure no class is accidentally dominant.

Test identical:
- level
- equipment
- boss
- conditions

Measure:
- mob clear
- boss time
- deaths
- resource consumption

### Exit
No catastrophic class imbalance.

---

## Sprint 9.2 — Boss Benchmark

Create standardized boss benchmark.

Target philosophy:

Warrior:
- slower
- safest

Mage:
- faster
- resource-sensitive

Assassin:
- fast
- mechanically demanding

Archer:
- flexible
- stable

Do not lock numerical targets yet.

---

## Sprint 9.3 — Party Simulation

Simulate:
- 4x Mage
- 4x Warrior
- 4x Archer
- 4x Assassin
- Mage/Warrior/Archer/Assassin

Verify:
- unique-class XP behavior
- buff behavior
- no duplicate-class XP inflation

---

# Phase 10 — World Foundation

## Sprint 10.1 — Map Framework

Implement:
- map loading
- portals
- spawn zones
- platform collision
- map transitions

---

## Sprint 10.2 — First Finished Map

Create one polished map.

Include:
- art
- mobs
- portals
- loot
- music
- basic NPC

### Exit
One map is fully playable from start to finish.

---

## Sprint 10.3 — Tutorial

Teach:
- movement
- attacks
- FMA
- mana
- skills
- equipment
- loot
- advancement concept

No giant tutorial wall.

---

# Phase 11 — Boss Framework

## Sprint 11.1 — Boss Framework

Implement:
- phases
- attacks
- telegraphs
- hitboxes
- recovery
- reset

---

## Sprint 11.2 — First Boss

Build a boss with:
- 3–5 attacks
- 1–2 phases
- obvious telegraphs
- clear safe zones

### Verification

Fresh player should be able to learn it through repeated attempts.

---

## Sprint 11.3 — Boss Balance

Test:
- underleveled
- expected level
- overleveled

Confirm:
- overpowered player can destroy boss
- boss does not become impossible
- mechanics remain readable

---

# Phase 12 — Content Production

## Sprint 12.1 — Continent Blockout

Build all planned maps with placeholder art.

Focus on:
- flow
- density
- platform layout
- portals
- encounter placement

---

## Sprint 12.2 — Mob Roster

Create a limited but reusable roster.

Target:
- 10–15 normal mob types
- several variants
- 2–4 elites
- several chain mobs

Avoid creating 50 unique enemies.

---

## Sprint 12.3 — Boss Roster

Create MVP bosses.

Each should introduce a small number of new mechanics.

---

# Phase 13 — Art Production Pipeline

## Sprint 13.1 — Art Agent Workflow

### Goal
Prove agent-assisted art production.

Pipeline:
```text
Prompt/spec
→ concept
→ human approval
→ Blender automation
→ animation
→ export
→ Godot
```

### Tools
Potentially:
- Blender
- MCP-connected agent
- image generation
- Godot

### Verification
Produce one complete:
- mob
- animation
- attack
- effect

without manually performing every intermediate step.

---

## Sprint 13.2 — Environment Production

Produce:
- town kit
- meadow kit
- forest kit
- corrupted forest kit
- mine kit
- ruins kit
- fortress kit

Reuse aggressively.

---

## Sprint 13.3 — Class VFX

Produce final:
- Mage effects
- Warrior effects
- Archer effects
- Assassin effects

---

# Phase 14 — Full Continent

## Sprint 14.1 — Map Integration

Connect:
- all maps
- portals
- NPCs
- progression

---

## Sprint 14.2 — Content Integration

Connect:
- mobs
- loot
- XP
- bosses
- equipment
- quests/tutorial guidance

---

## Sprint 14.3 — Final Boss

Create final MVP boss.

The final encounter should demonstrate the game's core philosophy:

> A powerful player can kill it quickly, but the mechanics remain readable enough that a weaker player can learn the encounter.

---

# Phase 15 — Player Experience

## Sprint 15.1 — Fresh Player Test

Give the game to a player with no documentation.

Observe:
- confusion
- progression
- skill understanding
- equipment decisions
- map navigation
- boss deaths

Fix problems in-game rather than writing explanations.

---

## Sprint 15.2 — Full Playthrough

Complete:
- new character
- level 1 → end
- equipment
- all advancement content
- bosses

Record:
- time
- friction
- boring sections
- overpowered sections

---

## Sprint 15.3 — Progression Tuning

Tune:
- XP
- loot
- equipment
- currency
- ability costs
- boss health
- mob health
- advancement timing

The goal remains:
> 10–20 hours for first continent.

---

# Phase 16 — QA and Optimization

## Sprint 16.1 — Automated QA

Run:
- combat tests
- progression tests
- save tests
- loot tests
- boss tests

---

## Sprint 16.2 — Stress QA

Run:
- 100 mobs
- 250 mobs
- chain explosions
- summons
- FMA
- boss effects

Profile bottlenecks.

---

## Sprint 16.3 — Save/Load QA

Test:
- fresh save
- old save
- corrupted save
- version upgrade
- interrupted save

---

# Phase 17 — Final Polish

## Sprint 17.1 — Combat Feel

Improve:
- hit stop
- impact
- sound
- particles
- camera
- animation
- damage feedback

---

## Sprint 17.2 — UI

Keep UI:
- clean
- readable
- minimal

Avoid MMO clutter.

---

## Sprint 17.3 — Audio

Add:
- attacks
- deaths
- loot
- advancement
- bosses
- ambient world
- UI

---

## Sprint 17.4 — Tutorial/Guidance Polish

Verify every major system can be understood without external sources.

---

# Phase 18 — MVP Release Candidate

## Sprint 18.1 — Complete Playthrough

Fresh character.

No cheats.

Record:
- total time
- deaths
- class
- progression
- bugs

---

## Sprint 18.2 — All-Class Playthrough

Run enough of the game with:
- Mage
- Warrior
- Archer
- Assassin

Check:
- class identity
- balance
- progression
- bugs

---

## Sprint 18.3 — Final Performance Pass

Target:
- stable 60 FPS on reasonable hardware
- no runaway entity counts
- no major memory leaks
- acceptable load times

---

## Sprint 18.4 — MVP Freeze

Freeze:
- classes
- continent
- bosses
- progression
- equipment
- core systems

Create a list of deferred ideas.

Do not add new systems during final stabilization.

---

# Deferred Post-MVP

Explicitly do not add during MVP unless a fundamental problem requires it:

- multiplayer
- additional continents
- additional class advancements
- level 60/70/80 systems
- accessories
- crafting
- guilds
- PvP
- trading
- auction house
- equipment consumption
- boss checkpoints
- complex item affixes
- pets
- large quest systems
- multiple currencies
- live-service systems

Potential future advancement:

```text
Level 50/60/70
→ second advancement
→ new ability layer
→ stronger FMA
→ new summon
```

But only after the MVP has proven the core loop.

---

# Final MVP Verification

The MVP is successful if a new player can:

1. Start playing quickly.
2. Understand movement without external help.
3. Kill large groups of mobs immediately.
4. Use an FMA from early levels.
5. Watch chain mobs create satisfying explosions.
6. Automatically collect loot.
7. Level quickly.
8. Never permanently ruin their build.
9. Understand equipment by reading it.
10. Reach class advancement in a reasonable time.
11. Feel dramatically stronger after advancement.
12. Understand every boss attack.
13. Understand why they died.
14. Retry quickly.
15. Finish the continent in approximately 10–20 hours.
16. Feel that all four classes are viable.
17. Experience a distinct dark-fairytale atmosphere.
18. Never need a wiki to understand the game's basic systems.

The strongest success criterion remains:

> **Is it fun to move through a dense map and obliterate enormous groups of enemies?**

If yes, the rest of the game has something worth building on.
