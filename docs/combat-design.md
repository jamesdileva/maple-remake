# Combat Design

## 1. Combat Identity

The game has two deliberately different combat modes.

### Normal combat

The player is powerful.

High mob density exists to create:
- spectacle
- XP
- loot
- movement flow
- satisfying chain reactions

### Boss combat

The player must understand:
- telegraphs
- positioning
- timing
- attack windows
- movement

The boss can still die extremely quickly if the player is sufficiently powerful.

## 2. Normal Mob Loop

Target feeling:

```text
Enter map
→ move into dense pack
→ use ability
→ screen fills with effects
→ mobs die
→ chain mobs spawn
→ chain mobs explode
→ XP appears
→ loot vacuums in
→ move
→ repeat
```

The player should spend very little time picking up items or fighting one weak mob at a time.

## 3. Chain Mobs

Some mobs can have a death payload.

Example:

```text
Bomb Slime
    ↓
dies
    ↓
4 Lesser Slimes
    ↓
die
    ↓
2 Splinters each
    ↓
die
    ↓
chain ends
```

Rules:
- configurable child count
- configurable chain depth
- configurable damage
- configurable visual effect
- global safety cap

A chain reaction should feel like an intentional feature, not a bug.

## 4. Full-Map Attacks

FMA attacks are available from level 1.

They begin as:

> everything in the active visible combat area is hit

and later become:

- wider
- stronger
- multi-platform
- multi-region
- chained
- visually larger

The term "FMA" is an implementation category, not necessarily the literal entire map.

## 5. FMA Constraints

Default FMA balance model:

- no cooldown
- mana cost
- cast time
- possible interruption depending on ability

This avoids:
> press button 10 times in one second

while keeping the ability available whenever the player can afford it.

## 6. Class Power Budget

Do not balance classes around identical DPS.

Instead evaluate:

1. normal-map clear time
2. boss kill time
3. deaths per boss
4. recovery time
5. mobility
6. resource usage
7. mechanical difficulty
8. sustained damage
9. burst damage

### Example desired relationship

A Warrior might be:
- slower
- safer
- more consistent

Mage:
- faster burst
- more resource-sensitive
- moderately fragile

Assassin:
- fastest clear in skilled hands
- high mobility
- higher death rate

Archer:
- stable and flexible
- strong ranged control
- good boss specialization with crossbow

The actual numbers must be determined through testing.

## 7. Boss Balance Metric

The strongest single balance metric should be:

> Time to kill a boss under standardized conditions.

Secondary metric:

> Number of attempts/deaths required.

Example desired relationship:

```text
Warrior
~20 min hypothetical baseline
very low death rate

Mage
~17–19 min
higher execution/resource risk

Assassin
~17–19 min
higher execution/mobility risk

Archer
~18–20 min
balanced
```

These are not final values.

The goal is to prevent extreme outcomes such as:
- one class kills a boss in 5 minutes
- another takes 20 minutes

unless there is a very deliberate reason.

## 8. Class Details

### Mage

Base:
- fire
- ice
- lightning

Possible abilities:
- Fire Burst
- Ice Nova
- Chain Spark
- elemental summon
- screen clear

Advanced:
- hybrid elemental combinations
- chain lightning
- explosive interactions
- larger FMA
- stronger summon

Defense:
- mana shield
- periodic lethal protection party buff

### Warrior

Base:
- sword + shield
- heavy strikes
- shockwave
- weapon rain
- summon

Advanced:
- Juggernaut mode
- damage reduction
- attack speed
- movement speed
- crit
- animal spirit attacks
- warrior tribe/spear summon
- advanced FMA

Defense:
- HP
- mitigation
- resistance to interruption/knockback where appropriate

### Archer

Bow:
- fast
- mob-focused
- rain of arrows
- arrow bombs
- unusual projectile summons

Crossbow:
- slower
- heavy
- piercing
- boss-focused
- large attacks

Weapon switching:
- fast
- visually readable
- no inventory management

Possible summon:
- projectile animal/creature
- autonomous artillery companion

### Assassin

Base:
- daggers
- dash
- dodge
- shadow clone
- shadow explosion

Advanced:
- teleport
- backstab
- execution
- shadow weapons
- multi-target simultaneous attacks
- clone FMA
- advanced summon

Defense:
- mobility
- dodge
- positioning

## 9. Party Buffs

Buffs are always-on while the class is present.

No manual recasting.

### Mage
Periodic automatic lethal protection.

### Warrior
Party HP/MP increase.

### Archer
Critical chance and/or skill range.

### Assassin
Attack speed + movement speed + jump speed.

The final numerical values are balance variables.

## 10. Critical Hits

All classes have reliable access to crit.

Crit should feel:
- impactful
- understandable
- visible

Avoid requiring external calculators.

## 11. Boss Telegraph Standard

Every dangerous boss attack must clearly communicate:

### Warning
What is happening?

### Area
Where will it happen?

### Timing
When will it happen?

### Response
What should the player do?

Possible telegraphs:
- colored ground indicators
- charging animation
- boss pose
- sound cue
- projectile preparation
- visible safe zones

Do not hide required information in obscure animations.

## 12. Boss Learning Loop

```text
Attempt
→ observe attack
→ understand failure
→ adjust
→ retry
→ improve
```

No boss should require:
- wiki research
- external guide
- hidden numerical requirement
- obscure class-specific trick

## 13. Death

Boss failure should be low-friction.

Preferred:
- immediate retry
- no significant loss

Deferred:
- checkpoints
- partial phase restarts

## 14. Visual Combat Language

Mage:
- explosions
- elemental bursts
- lightning
- fire/ice interactions

Archer:
- arrow rain
- bombs
- heavy bolts
- penetration
- artillery

Warrior:
- swords from sky
- shockwaves
- weapon storms
- animal spirit effects
- warrior summons

Assassin:
- shadows
- clones
- teleport flashes
- shadow weapons
- simultaneous backstabs
