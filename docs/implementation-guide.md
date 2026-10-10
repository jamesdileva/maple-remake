# Implementation Guide

## 1. Implementation Philosophy

Build one vertical slice at a time.

Never create a giant amount of infrastructure before proving the gameplay.

Recommended sequence:

```text
Movement
→ one mob
→ one attack
→ one FMA
→ XP
→ loot
→ one complete class
→ combat lab
→ class advancement
→ all classes
→ maps
→ bosses
→ polish
```

## 2. Step 1 — Godot Project

Create:
- Godot 4.x project
- 2D renderer
- input actions (keyboard/mouse + controller, bound from day one)
- basic folder structure
- debug build configuration

Verification:
- project launches
- player scene loads
- no errors

## 3. Step 2 — Player Controller

Implement:
- horizontal movement
- acceleration/deceleration
- jump
- gravity
- platform collision
- basic animation states
- controller input mapping (keyboard/mouse + gamepad parity)

Verification:
- player can traverse a test room
- movement feels responsive
- no stuck states
- movement verified with both keyboard/mouse and controller

## 4. Step 3 — Combat Foundation

Create centralized:
- DamageEvent
- DamageResult
- TargetQuery
- CriticalRoll
- DeathEvent

Do not create four separate combat implementations.

Verification:
- player damages mob
- crit works
- mob dies
- XP event fires

## 5. Step 4 — First FMA

Implement one screen-area attack.

Requirements:
- mana cost
- cast time
- no cooldown
- visual effect
- multi-target hit
- kill handling

Verification:
- 1 mob dies
- 50 mobs can be hit
- mana decreases
- casting cannot be spammed instantly

## 6. Step 5 — Mob Pool

Implement object pooling.

Verification:
- spawn 100 mobs
- kill 100 mobs
- respawn 100 mobs
- monitor FPS and memory

## 7. Step 6 — Chain Mob

Implement configurable child spawning.

Verification:
- parent dies
- children appear
- children can die
- chain ends at configured depth
- no runaway spawning

## 8. Step 7 — XP / Leveling

Implement:
- XP table
- level-up
- stat progression
- ability unlock

Keep the level formula data-driven.

Verification:
- XP gains
- level-up
- save/load preserves level

## 9. Step 8 — Skills

Implement generic skill definitions.

Each skill should specify:
- cost
- cast time
- damage
- range
- targeting
- effect
- unlock level

Verification:
- skills can be upgraded
- skill points work
- reset returns points
- no irreversible mistake

## 10. Step 9 — Equipment

Implement:
- weapon
- top
- bottom
- helmet

Use normalized stats.

Verification:
- equip
- unequip
- compare
- save/load

## 11. Step 10 — Auto-Loot

Drops should automatically travel to the player or inventory.

Verification:
- kill mobs
- drops generate
- loot is vacuumed
- inventory updates
- no manual pickup loop

## 12. Step 11 — Mage Vertical Slice

Complete Mage from level 1 through advancement.

Include:
- elemental attacks
- FMA
- mana shield
- summon
- party buff implementation
- advancement
- hybrid attacks

Only proceed when Mage feels good.

## 13. Step 12 — Combat Lab

Expand debug scene.

Add:
- mob counts
- boss spawning
- damage meter
- performance stats
- class switching

This becomes the primary balance environment.

## 14. Step 13 — Warrior

Reuse shared systems.

Add:
- sword/shield
- juggernaut mechanics
- summon
- FMA
- advancement

Do not fork the combat engine.

## 15. Step 14 — Archer

Add:
- bow
- crossbow
- fast switching
- mob/boss specialization
- summon
- advancement

## 16. Step 15 — Assassin

Add:
- dagger
- shadow mechanics
- dodge
- clone
- execution
- summon
- advancement

## 17. Step 16 — Party Architecture

Implement data structures and modifiers even though multiplayer is disabled.

Test with simulated party members.

Example:

```text
Simulated Party:
Mage
Warrior
Archer
Assassin
```

Verify:
- all buffs apply
- unique XP multiplier = 4x
- duplicate classes do not stack unique-class bonus

## 18. Step 17 — World

Build one complete map first.

Then expand to the continent.

Each map should have:
- spawn zones
- platform layout
- portal
- enemy set
- loot table
- debug spawn points

## 19. Step 18 — Boss Framework

Create reusable boss components:

- phase manager
- attack scheduler
- telegraph
- hitbox
- damage
- recovery
- death/reset

Then create the first boss.

## 20. Step 19 — First Boss

Use a small number of highly readable attacks.

Test:
- telegraph
- safe zone
- damage
- movement
- phase transition
- retry

## 21. Step 20 — Full Continent

Add remaining maps and bosses.

Do not add new systems unless necessary.

## 22. Step 21 — Art Production

Once mechanics are proven, run dedicated art production passes.

Agent-assisted:
- concept generation
- Blender automation
- sprite preparation
- animation assistance
- VFX iteration

Human approval remains required.

## 23. Step 22 — Polish

Polish:
- hit effects
- sound
- UI
- animation
- transitions
- map composition
- tutorials
- boss telegraphs

## 24. Step 23 — Final QA

Run:
- fresh-player test
- complete playthrough
- save/load
- all classes
- all bosses
- stress tests
- regression suite

## 25. Implementation Rules

1. Prefer shared systems.
2. Avoid class-specific duplicated combat code.
3. Make content data-driven.
4. Add debug controls before complex content.
5. Profile high-density combat.
6. Never hide important mechanics.
7. Avoid unnecessary systems.
8. Preserve save compatibility.
9. Test each vertical slice before expanding.
10. Do not implement multiplayer before the single-player game is fun.
