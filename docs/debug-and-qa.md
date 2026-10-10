# Debug and QA Plan

## 1. Philosophy

Debugging begins on day one.

Every major gameplay system should be testable without replaying the entire game.

## 2. Debug Overlay

Display:

```text
FPS
Frame time
Entity count
Mob count
Projectile count
Effect count
Current map
Player level
HP / MP
XP
Currency
Current ability
Cast time
Mana cost
Targets hit
Targets killed
Damage dealt
Crit count
```

## 3. Debug Commands

Minimum:

- Toggle God Mode
- Kill all mobs
- Spawn mob
- Spawn 10 mobs
- Spawn 50 mobs
- Spawn 100 mobs
- Spawn boss
- Add XP
- Add currency
- Add skill points
- Reset skills
- Equip test gear
- Teleport
- Reset map
- Reset boss
- Infinite mana
- Force crit
- Disable AI
- Show hitboxes
- Show telegraphs
- Export debug data (JSON snapshot + structured event log)

## 4. Combat Lab

Required before content completion.

Scenarios:

1. 1 mob
2. 10 mobs
3. 50 mobs
4. 100 mobs
5. 250 mobs stress test
6. chain mob stress test
7. FMA stress test
8. summon stress test
9. boss test
10. mixed combat stress test

## 5. Automated Tests

### Progression

- XP thresholds
- level-up
- advancement
- skill unlock
- skill reset
- max skill level

### Combat

- damage
- crit
- death
- mana consumption
- cast time
- target selection
- FMA coverage
- summon damage

### Loot

- drop generation
- auto-loot
- inventory
- equipment replacement
- save/load

### Bosses

- phase transition
- telegraph timing
- hit zones
- death/reset
- reward generation

## 6. Regression Rule

Every fixed bug gets a regression test when practical.

Example:

Bug:
> Chain mobs could spawn infinitely.

Test:
> Chain depth never exceeds configured maximum.

## 7. Performance Tests

Record:
- FPS
- frame time
- entity count
- memory
- effect count

Test on:
- normal map
- dense map
- 100 mobs
- 250 mobs
- chain explosion
- FMA
- summons
- boss

## 8. Balance Test Harness

Each class should be tested against the same:

- character level
- equipment level
- boss
- consumables
- encounter conditions

Record:
- boss kill time
- deaths
- attempts
- mana/resource usage
- damage
- uptime

## 9. Boss QA Checklist

For every attack:

- Is the telegraph visible?
- Is it understandable?
- Is the hitbox correct?
- Is the timing consistent?
- Is the safe area clear?
- Can the player react?
- Does death communicate why it happened?
- Can the player learn the mechanic through repeated attempts?

## 10. Save QA

Test:
- save
- load
- level-up
- equipment
- skills
- currency
- progression
- corrupted/incompatible version handling

Save data should be versioned.

## 11. Player QA

Use a fresh-player test.

Ask the tester to play without documentation.

Observe:
- where they get confused
- which tooltip they ignore
- whether they understand FMA
- whether equipment is obvious
- whether boss deaths are understandable
- whether they know where to go

Repeat the core observations using a controller only.

The game should be improved rather than explained externally.
