# Dragon Quest (working title) - Design Draft v0.1

## Vision
A single-player action RPG about the journey to find the dragon. The world is split into three layers (underground, surface, sky). The combat centers on blade-clash timing, but the twist is that clash windows must be paired with skills to trigger upgrades and elemental resonance.

## Platforms
- PC + Mobile
- One codebase, adaptive UI and controls
- Future-proof for PVE co-op rooms

## Camera and Movement
- 2.5D diagonal/quarter-view (3D space, orthographic camera)
- WASD on PC, virtual joystick + skill buttons on mobile

## Core Loop
1. Enter stage
2. Explore and fight
3. Trigger clash windows
4. Spend spirit power to cast element skills
5. Earn spirit and materials
6. Unlock upgrades
7. Clear stage and move on

## Combat Pillars
- Clash timing replaces pure blocking
- Skill + clash triggers resonance and upgrade progress
- Element identities matter (Fire/Wood/Metal/Earth/Water)

## Clash System
- When melee attacks meet, both sides enter Clash State
- Player sees a short timing window (0.8s default)
- If skill is cast inside the window, it triggers Resonance
- If the window is missed, apply a short cooldown (Spirit lock)

## Spirit System
- LP (Spirit Power): gain via attacks, perfect clash, exploration
- Spirit Tier: unlocked per nation
- Resonance: element-specific bonus when casting inside Clash State

## Nations and Progression
- Underground: Fire Nation (7 stages)
- Surface: Wood, Metal, Earth (7 stages each)
- Sea: Water Nation (7 stages)
- Sky: Dragon Realm (final arc)

## Skill Evolution Rules
- Each new nation upgrades the same core skills
- Prior elements remain as passive marks
- Example evolution path:
  - Fire: burst + burn
  - Wood: delayed burst + sustain
  - Metal: armor break + counter
  - Earth: shield + control
  - Water: chain + slow

## Level Structure Template (7 stages)
1. Intro combat + tutorial
2. Standard enemies
3. Mini-boss
4. Exploration + puzzle
5. Elite encounter
6. Resource challenge
7. Boss fight

## Multiplayer (future)
- PVE co-op via rooms
- Combat logic is deterministic where possible
- Keep player state sync boundaries clear

## Technical Notes (Godot)
- Use data-driven skill configs (JSON or .tres)
- Combat state machine per actor
- Clash window handled by CombatManager
- UI scales with stretch mode
