# Ultimate Environmental Skills

## Purpose

Ultimate Environmental Skills are the game's third layer of full-map attacks.

They are intentionally different from normal and advanced FMAs. A normal FMA is a frequent combat tool. An advanced FMA is a stronger and more sophisticated version unlocked through progression. An Ultimate temporarily changes the state of the world itself.

The goal is not simply:

> "Press a bigger attack button."

The goal is:

> **"This is my map now."**

An Ultimate should make the player feel that their class has temporarily taken control of the battlefield.

These skills are strong enough to remain worthwhile even if the game's normal FMAs are already spectacular. They are a separate spectacle and progression layer rather than a replacement for the core FMA system.

---

## 1. Three Levels of Full-Map Attacks

### Normal FMA

- Available from level 1.
- No cooldown.
- Costs mana.
- Has a casting time so it cannot be spammed repeatedly in a few seconds.
- Initially affects everything currently visible/on-screen.
- As the character progresses, its effective scope and sophistication increase.
- It is a normal part of combat and should be used frequently.

### Advanced FMA

Unlocked through class advancement.

Advanced FMAs retain the normal combat philosophy but become substantially more impressive:

- Larger areas.
- More simultaneous attacks.
- More complex visual effects.
- Multiple platforms or map regions affected.
- Stronger class identity.
- More interesting combinations with the class's normal kit.

They still belong to the normal combat loop and do not need a long cooldown.

### Ultimate / Environmental FMA

Ultimates are fundamentally different.

They:

- Have a long cooldown.
- Remain active for a long duration.
- Temporarily transform the battlefield.
- Can continue operating autonomously.
- Use the environment, summoned forces, persistent hazards, or world-state changes as the attack.
- Are intended to be spectacular enough that activating one feels like an event.

Initial prototype values:

- **~5 minutes active**
- **~10 minutes cooldown**

These are starting points for testing, not final balance numbers.

A successful 5-minute / 10-minute design would create approximately five minutes of downtime between activations while still allowing the Ultimate to be powerful enough for AFK or semi-AFK farming.

---

## 2. Ultimate Design Principles

### 2.1 The Ultimate Changes the World

The defining characteristic is environmental transformation.

Examples:

- The sky changes.
- The background changes.
- Platforms become hazardous.
- New autonomous attackers appear.
- Shadows spread across the map.
- Weather or elemental effects begin.
- Music changes.
- The battlefield becomes a war zone.
- Projectiles continuously enter the map.

The environment should communicate the Ultimate before the player even understands every mechanical detail.

### 2.2 Autonomous Operation Is Allowed

An Ultimate does not need constant player input.

The player may activate it and allow the environmental effect to continue killing mobs.

This deliberately permits AFK or semi-AFK leveling.

However, the intended balance target is:

> **AFK should work, but active play should be more efficient.**

The Ultimate should not turn normal gameplay into a meaningless spectator mode.

Potential balance outcomes to test:

**Full AFK:** The Ultimate kills everything efficiently with no player interaction. This may be too strong if it becomes the optimal leveling method.

**AFK but Inefficient:** The Ultimate continuously kills mobs, but active movement and combat increase spawn coverage, kill speed, loot collection, mob density, and overall XP/hour. This is the preferred starting hypothesis.

**Semi-Active:** The Ultimate handles the environment but requires occasional player interaction to reach maximum effectiveness.

No model should be locked before testing.

---

## 3. Ultimate Framework

Ultimates should use a shared, data-driven framework rather than four completely independent systems.

Conceptually, each Ultimate contains:

- `ultimate_id`
- `class_id`
- `duration`
- `cooldown`
- `activation_effect`
- `world_state_effect`
- `damage_behavior`
- `autonomous_entities`
- `environment_visuals`
- `audio_state`
- `cleanup_behavior`

The exact implementation can differ between classes, but the framework should provide a consistent lifecycle:

1. Player activates Ultimate.
2. Activation/telegraph plays.
3. World-state changes begin.
4. Autonomous/environmental effects start.
5. Ultimate remains active for its configured duration.
6. Effects continue without requiring repeated activation.
7. Duration expires.
8. World state is restored deterministically.
9. Cooldown proceeds according to the final cooldown model.
10. Ultimate becomes available again.

The system should be built so new environmental Ultimates can be added without rewriting the core combat architecture.

---

# 4. Mage Ultimate — Elemental Cataclysm

## Fantasy

The Mage temporarily turns the entire battlefield into an elemental disaster.

The sky can fill with a gigantic magical orb or supernova-like object while the terrain and atmosphere become saturated with the Mage's chosen element.

The feeling should be:

> **"The elements themselves are attacking the map."**

## Visual Concept

A large elemental orb appears in the sky.

Depending on the Mage's elemental state, the battlefield can become:

### Fire

- Burning platforms.
- Fire raining from above.
- Explosions across the map.
- Large meteor-like impacts.
- Constant elemental damage zones.

### Ice

- Frozen platforms.
- Ice shards falling from above.
- Frost spreading through the environment.
- Enemies freezing or being struck by repeated ice attacks.

### Lightning

- Continuous lightning strikes.
- Electrified platforms.
- Chain lightning jumping between mobs.
- Large atmospheric electrical effects.

The Mage can potentially cycle or combine elements later, allowing the Ultimate to become even more spectacular.

## Mechanical Behavior

The environment continuously damages enemies for the duration.

Possible sources:

- Sky orb attacks.
- Elemental weather.
- Platform hazards.
- Explosions.
- Lightning strikes.
- Elemental zones.

The Mage does not need to manually target every enemy.

## Identity

The Mage Ultimate is primarily:

**Environmental destruction.**

The world itself becomes a magical disaster.

---

# 5. Archer Ultimate — Arrowstorm

## Fantasy

The Archer summons an autonomous army of archers and turns the entire battlefield into a continuous storm of projectiles.

The feeling should be:

> **"There are arrows everywhere."**

## Visual Concept

Multiple spectral or summoned archers appear throughout the environment.

They can:

- Fire continuously.
- Leap between platforms.
- Fire through the background.
- Shoot upward and rain arrows down.
- Fire explosive arrows.
- Shoot arrows that seek nearby enemies.
- Create enormous waves of projectiles.

Some arrows can visually travel through the environment before striking targets, making the entire map feel occupied by the Archer's attack.

## Autonomous Archers

The summoned archers should not necessarily be full traditional NPCs.

They can be lightweight autonomous combat entities or visual attack emitters.

This is important for performance.

A large number of visible archers should not require hundreds of fully simulated AI characters.

## Mechanical Behavior

Arrowstorm continuously attacks mobs across the map.

Potential behaviors include:

- Target-seeking arrows.
- Area explosions.
- Arrow rain.
- Penetrating shots.
- Rapid-fire volleys.
- Background artillery.

Active Archer gameplay can improve the Ultimate by positioning the player where more mobs can be exposed to both the environmental attack and the player's normal attacks.

## Identity

The Archer Ultimate is primarily:

**Overwhelming projectile coverage.**

The entire map becomes a firing range.

---

# 6. Warrior Ultimate — War of the Damned

## Fantasy

The Warrior does not simply destroy the map.

The Warrior starts a war.

The battlefield transforms into a massive temporary war zone while summoned warriors attack everything around the player.

The feeling should be:

> **"Come fight me."**

## Visual Concept

The background changes into a battlefield.

Possible environmental elements:

- War banners.
- Darkened battlefield sky.
- Distant armies.
- Fires.
- Moving silhouettes.
- Weapon impacts.
- Flying swords.
- Massive battle effects.

The Warrior summons a gang/army of warriors that leap around the map.

They can:

- Charge enemies.
- Smash platforms.
- Throw or launch weapons.
- Leap between platforms.
- Perform large area attacks.
- Follow the player's general location.

## Aggro Identity

Unlike the Mage, who turns the environment into an elemental disaster, the Warrior actively draws enemies into the fight.

The Ultimate can cause enemies to strongly aggro toward the Warrior.

This reinforces the Warrior's identity as the durable frontline class.

The player can become the center of the battle while the summoned warriors create chaos around them.

## Advanced Evolution

Later versions can incorporate the Warrior's broader fantasy:

- Animal spirits.
- Giant weapons.
- Warrior tribes.
- Spear throwers.
- Massive sword attacks.
- Juggernaut-style movement.
- Rapid battlefield charges.

The first implementation does not need all of these.

## Mechanical Behavior

The Warrior Ultimate should be more active than the Mage or Archer.

It can still operate autonomously, but player positioning should meaningfully improve results.

Potential advantages from active play:

- Keeping enemies grouped.
- Pulling enemies into summoned attacks.
- Moving between high-density areas.
- Personally attacking priority targets.
- Maintaining pressure on bosses.

## Identity

The Warrior Ultimate is primarily:

**A temporary war state.**

The Warrior doesn't merely attack the map. The Warrior turns the map into a battlefield.

---

# 7. Assassin Ultimate — Shadow Realm

## Fantasy

The Assassin temporarily takes the battlefield into darkness.

The environment becomes a shadow world where attacks come from everywhere simultaneously.

The feeling should be:

> **"You cannot hide from me."**

## Visual Concept

The background becomes almost completely black or heavily obscured.

Shadow effects appear throughout the map.

Possible effects:

- Shadows spreading across platforms.
- Shadow clones appearing.
- Shadow weapons materializing.
- Teleporting silhouettes.
- Dark explosions.
- Multiple assassins appearing simultaneously.
- Enemies being attacked from behind.
- Brief flashes of the Assassin appearing around the battlefield.

## Mechanical Behavior

The Assassin's Ultimate attacks enemies from multiple directions simultaneously.

Possible behaviors:

- Shadows appear underneath enemies and explode.
- Shadow blades strike targets.
- Clones teleport between enemies.
- Multiple targets are assassinated simultaneously.
- Shadow projectiles travel through the environment.
- Enemies can be attacked regardless of their position on the map.

The Ultimate should feel exceptionally fast.

## Execution Identity

The Assassin Ultimate can potentially interact with weakened enemies.

For example, enemies below a health threshold could receive stronger shadow attacks or execution-style effects.

This should remain simple and readable rather than becoming another complicated combat system.

## Identity

The Assassin Ultimate is primarily:

**Speed, darkness, simultaneous assassination, and environmental control.**

The map itself becomes the Assassin's shadow realm.

---

# 8. Ultimate Comparison

| Class | Ultimate | Core Fantasy | Environmental Identity |
|---|---|---|---|
| Mage | Elemental Cataclysm | Magical disaster | Elements destroy the battlefield |
| Archer | Arrowstorm | Total projectile coverage | The map becomes a firing range |
| Warrior | War of the Damned | Start a massive battle | The map becomes a war zone |
| Assassin | Shadow Realm | Attack from everywhere | The map becomes a shadow realm |

Each Ultimate should therefore have a clearly different visual and mechanical identity.

They should not simply be:

- Mage = big explosion
- Archer = big arrow
- Warrior = big sword
- Assassin = big dagger

The environment itself must communicate the class.

---

# 9. Boss Interaction

Ultimates should remain useful against bosses, but bosses must not become unreadable.

Important rules:

- Boss attacks retain clear telegraphs.
- Environmental effects cannot permanently obscure critical warning animations.
- Boss mechanics should still make sense while an Ultimate is active.
- An appropriately powerful character may still destroy a boss extremely quickly.
- Ultimate damage should be balanced around boss kill time rather than arbitrary damage equality.
- Bosses may have controlled resistances or phase interactions if testing shows that an Ultimate trivializes every boss.

The Ultimate should enhance the spectacle without turning boss encounters into visual noise.

---

# 10. Performance Requirements

This system is potentially one of the game's largest performance risks.

A five-minute autonomous environmental attack cannot be allowed to create an uncontrolled number of entities.

The implementation should favor:

- Object/entity pooling.
- Lightweight autonomous attack emitters.
- Shared projectiles where possible.
- Area queries instead of hundreds of individual collision objects.
- Batched visual effects.
- Hard limits on simultaneous active effects.
- Deterministic cleanup.
- No permanent entity accumulation.

For example, Arrowstorm should not require 500 fully simulated AI archers just because 500 archers are visible.

Visual scale and simulation scale should be separate.

The same principle applies to:

- Shadow clones.
- Warrior summons.
- Lightning strikes.
- Elemental explosions.
- Environmental hazards.

---

# 11. AFK and Active-Play Balance Testing

The initial 5-minute active / 10-minute cooldown concept should be treated as a prototype.

Testing should measure:

- XP/hour while fully AFK.
- XP/hour while semi-active.
- XP/hour during optimal active play.
- Loot/hour.
- Mob kill rate.
- Boss kill time.
- Player deaths.
- Performance/FPS.
- Peak entity count.
- Memory usage.
- Effect cleanup after expiration.

The target is not necessarily to make AFK weak.

A healthy result could be:

**AFK:** viable and rewarding  
**Semi-active:** noticeably better  
**Fully active:** best overall efficiency

This would allow players to activate an Ultimate before stepping away while still preserving a reason to actively play the game.

---

# 12. World-State Restoration

Every Ultimate must have a deterministic cleanup process.

When the Ultimate ends:

- Temporary environmental visuals disappear.
- Summoned entities are removed or returned to their pool.
- Temporary hazards stop damaging enemies.
- Background changes are reverted.
- Music transitions back.
- Temporary world-state flags are cleared.
- No Ultimate effects remain on the map.

The player should never be able to accidentally leave the game in a partially transformed state.

This is especially important for:

- Map transitions.
- Death.
- Re-entering a map.
- Saving/loading.
- Disconnecting in a future multiplayer version.
- Multiple Ultimates being active simultaneously.

---

# 13. Multiplayer Considerations

Multiplayer is not part of the initial MVP, but the Ultimate framework should avoid making future multiplayer impossible.

Potential future behavior:

### Different classes together

A party containing multiple classes could have multiple environmental effects.

This could create spectacular combinations:

- Mage creates elemental destruction.
- Archer fills the sky with arrows.
- Warrior starts a battlefield.
- Assassin darkens the map.

However, the system should not assume that four simultaneous full-power world transformations are automatically acceptable.

Future multiplayer testing may require:

- Effect priority.
- Effect stacking rules.
- Shared environmental limits.
- Reduced visual intensity.
- Shared cooldown interactions.
- Performance caps.

The architecture should therefore treat the Ultimate as a world-state layer rather than hardcoding a single-player-only effect.

---

# 14. Audio and Presentation

Ultimates should feel like events.

A major part of this can come from audio rather than additional gameplay complexity.

Potential direction:

### Mage

Elemental/orchestral escalation with magical impact sounds.

### Archer

Fast percussion, rapid impacts, and continuous projectile audio.

### Warrior

War drums, battlefield ambience, weapon impacts, and large combat sounds.

### Assassin

Dark, eerie, reduced ambience with sharp shadow/teleport effects.

The music can transition when the Ultimate starts and fade back when it ends.

This is optional polish, but potentially one of the cheapest ways to make the Ultimate feel substantially more powerful.

---

# 15. Development Order

The Ultimate system should be implemented only after the core FMA/combat architecture is already stable.

Recommended order:

1. Build the shared Ultimate lifecycle.
2. Implement duration/cooldown handling.
3. Implement world-state activation/deactivation.
4. Implement pooling and performance limits.
5. Prototype one Ultimate, preferably Mage or Archer.
6. Validate autonomous five-minute operation.
7. Add the remaining class Ultimates.
8. Test AFK versus active efficiency.
9. Test boss interactions.
10. Add environmental art and audio polish.
11. Test map transitions, death, saving/loading, and cleanup.
12. Test future multiplayer compatibility without requiring multiplayer to exist.

The four Ultimates should be mechanically distinct, but they should all use the same underlying lifecycle and safety framework.

---

# 16. Final Design Goal

The normal FMA should make the player think:

> **"I just destroyed the entire screen."**

The advanced FMA should make the player think:

> **"My class has become ridiculous."**

The Ultimate should make the player think:

> **"This is my map now."**

That distinction is the reason the Ultimate system is worth keeping even if the game's normal FMAs are already spectacular.
