# AI Improvement Plan

## Goal

Make the AI feel intentional instead of reactive:

- Move safely through platforming spaces
- Stop suiciding into hazards and bad drops
- Choose when to fight, reposition, or disengage
- Contest useful pickups and level objectives
- Use arena mechanics such as gates, switches, and jump pads
- Use existing player movement tech such as wall jumps and air steering after pad launches
- Recognize head-stomp attack opportunities and head-stomp danger
- Respect the game's screen-wrap traversal rules instead of assuming every fall is lethal

## Progress Status

- Phase 1: done
- Phase 2: done
- Phase 3: in progress
- Phase 4: in progress
- Phase 5: done

## Current Problems

The current AI now has a usable baseline. It can:

- find the closest opponent
- estimate shot viability and apply basic fire-discipline checks
- dodge incoming arrows
- approach or retreat based on distance and nearby combat space
- score fights, chests, switches, and recovery goals
- follow first-pass authored route links
- recognize simple stomp opportunities and anti-stomp threats

It still struggles to:

- tune wall-slide and wall-jump routes per arena
- tune jump-pad routes that still allow left/right steering after launch
- use moving platforms and other special traversal spaces as intentional route choices
- choose between shots, stomps, and spacing with fully tuned difficulty-specific thresholds
- use richer world-space debug gizmos during tuning

## Architecture Direction

The AI should be split into three layers:

1. `Sense`
   Collect local world facts such as enemy position, incoming arrows, floor ahead, hazards ahead, nearby pickups, usable level mechanics, reachable landing spots, wall-jump surfaces, jump-pad launch windows, and head-stomp opportunities.
2. `Choose Goal`
   Score possible intentions such as fight, reposition, collect chest, activate switch, use pad, escape danger, hold ground, or create/deny a stomp angle.
3. `Execute`
   Convert the chosen goal into digital movement, jump, aim, shoot, dash, pad steering, and wall-jump timing inputs.

The existing aim and dodge logic is a decent base for the execution layer. The missing pieces are sensing and goal selection.

## Phase 1: Terrain Probes And Safer Movement

**Status:** Done

Implemented in `scripts/actors/ai_controller.gd`.

What is already covered:

- forward floor and hazard probes
- jumpable-gap checks
- suppression of obviously bad edge movement
- safer combat-footing checks
- intentional wraparound allowance for valid pursuit routes

What is intentionally deferred:

- authored wall-jump route planning
- jump-pad route planning
- stomp-specific combat logic

### Objective

Stop obvious bad movement:

- do not run straight into hazards or pointless drops
- do not walk into spikes when a better option exists
- jump simple gaps when a safe landing is visible
- stop at edges when the gap is not clearly jumpable and wrap traversal is not useful
- avoid entering combat posture from obviously unsafe footing

### Implementation

- Add forward floor probes in the AI controller.
- Sample the floor directly ahead of the bot and compare it to the current floor height.
- Treat these as blocked movement:
  - spikes ahead
  - a drop that is much larger than a normal step-down
- Treat missing floor as context-sensitive:
  - block it during normal combat footing checks
  - allow it during approach when wraparound traversal is clearly useful
- Scan ahead for a safe landing zone within a conservative jump range.
- If a landing exists, convert forward movement into `run + jump`.
- If no landing exists, suppress movement unless the current goal benefits from the known wraparound rule.
- Refuse to enter or hold an aim/shoot state when the bot is standing on obviously unsafe ground near the target side.

### Success Criteria

- AI no longer walks off the side of level 3 platforms in normal combat pursuit.
- AI jumps obvious flat gaps in simple cases.
- AI stops instead of taking clearly impossible jumps.
- AI does not stand at an edge and immediately start aiming when the next step is unsafe.
- AI can still commit to an intentional wraparound route when the goal is clearly on the other side of the screen or above a wrap drop.

## Phase 2: Goal Selection And Pickup Priority

**Status:** Done

Implemented in `scripts/actors/ai_controller.gd` with helper queries added to chest, gate, and switch scripts.

What is already covered:

- goal scoring for `fight`, `chest`, `switch`, and `recover`
- wrapped-distance scoring
- ammo/health/buff influence on goals
- short goal stickiness to prevent flicker

What is intentionally deferred:

- multi-step routed traversal to those goals
- wall-jump- or pad-specific route scoring
- combat choices such as stomp attempts versus shots

### Objective

Teach the AI to want things besides direct combat.

### Implementation

- Add a goal scoring layer above the current combat states.
- Score at least these goals:
  - fight target
  - collect chest
  - recover from bad position
  - activate pressure switch when it unlocks route progress
- Use wrapped world distances for scoring so object selection matches the game's teleport-across-screen rules.
- Use player state to influence goal weights:
  - low ammo increases chest priority
  - low health increases defensive and chest priority
  - strong buffs can lower pickup urgency and raise aggression
- Add short goal stickiness so the AI does not flicker every frame between chest and opponent.

### Success Criteria

- Low-ammo AI noticeably contests nearby lootable chests.
- AI does not abandon a chest every frame just because an enemy moved slightly.
- AI can prefer a switch when a disabled gate is blocking the route.
- Low-health or unsafe-position AI can choose to disengage before resuming normal combat.

## Phase 3: Arena Routing With Authored AI Links

**Status:** In Progress

What is already covered:

- reusable authored route points and links now exist in the project
- the AI can build a small route over authored links instead of only chasing raw target delta
- the execution layer now supports authored `jump`, `drop`, `pad`, and `gate` traversal behaviors
- wall-jump execution support exists in the controller so authored wall-jump links can drive it
- first-pass route graphs were added to the current arenas

What still needs tuning:

- wall-jump links still need manual per-arena authoring and gameplay tuning
- level 3 still needs deeper routing work around moving-platform usage
- some route-point placements are conservative first passes and should be refined in-editor after playtesting

### Objective

Give the AI reliable traversal through platform-fighter spaces without pretending generic navigation meshes solve jump logic.

### Implementation

- Add lightweight authored arena markers and links:
  - walk nodes
  - jump links
  - wall-jump links
  - drop links
  - jump-pad links
  - switch goal markers
  - chest goal markers
- Build a tiny graph per level instead of a full navmesh.
- Allow the AI to choose a short route toward a goal by following these links.
- Use level authorship to express intended jump arcs, wall-jump chains, and special traversal cases.
- For jump pads, store more than the pad node itself:
  - valid entry direction or approach zone
  - expected launch corridor
  - steering-friendly landing windows, because players can still move left and right after `launch_from_pad()`
- Teach execution to keep steering toward the chosen landing zone after a pad launch instead of treating the pad as a fixed ballistic arc.

### Success Criteria

- AI can intentionally cross multi-platform arenas.
- AI can intentionally use wall slides and wall jumps to recover or climb.
- AI can use gate/switch routes instead of stalling forever at blocked paths.
- AI can use jump pads and steer toward the intended landing area after launch.
- Arena-specific traversal becomes predictable and tuneable.

## Phase 4: Combat Discipline And Positional Play

**Status:** In Progress

Implemented first-pass combat heuristics in `scripts/actors/ai_controller.gd`.

What is already covered:

- fire discipline now checks shot quality, footing stability, and close-range escape space before committing to a shot
- aggression now affects aim hold time, desired approach/retreat distances, and post-shot retreat timing
- close-range movement now scores left/right space instead of always blind-retreating away from the target
- edge pressure is softened by a simple center-space preference in combat movement
- stomp opportunities are now recognized when the bot has a clear downward lane onto the target
- anti-stomp behavior now breaks aim and forces repositioning when an airborne enemy is threatening a drop onto the bot

What still needs tuning:

- stomp windows need gameplay tuning so bots do not overvalue weak vertical opportunities
- air-shot discipline may still need per-difficulty adjustment after manual playtesting
- positional scoring still does not understand special traversal space such as moving platforms or authored wall-jump anchors as combat cover
- the current debug overlay is text-first and could still gain world-space route and landing markers

### Objective

Make the AI less trigger-happy and more readable.

### Implementation

- Add fire discipline checks:
  - stable footing
  - meaningful hit chance
  - no immediate ledge hazard on the firing side
  - no point-blank self-trap after the shot
- Add aggression profiles by difficulty:
  - low difficulty: longer aim hold, worse shot selection, less chase commitment
  - high difficulty: better timing, better dodge timing, cleaner retreat windows
- Add simple positional heuristics:
  - do not over-retreat into cornered ledges
  - prefer center space over bad edge fights
  - peek, fire, and move instead of hard-freezing in aim
- Add vertical combat heuristics for head-stomp play:
  - detect when the enemy head is exposed below the bot
  - allow stomp attempts when the downward path is safe and the payoff is better than a rushed shot
  - avoid lingering directly underneath airborne enemies
  - account for stomp threats when using walls, pads, and high platforms

### Success Criteria

- AI shots feel deliberate instead of automatic.
- Higher difficulty feels smarter, not just faster.
- AI fights for stable space instead of randomly oscillating at edges.
- AI can capitalize on obvious stomp opportunities and avoids feeding free head-stomp hits.

## Phase 5: Debugging And Validation

**Status:** Done

Implemented a toggleable arena debug overlay and a permanent headless smoke test.

What is already covered:

- `F8` now toggles an in-game AI debug overlay during arena play
- the overlay shows goal, action state, target, forward-probe result, landing point, current route step, shot decision, and stomp decision
- a permanent headless smoke test now lives at `tests/ai_smoke_test.gd`
- the smoke test covers impossible gaps, simple gaps, chest priority, switch priority, wall-jump execution, pad steering, stomp choice, and spike avoidance

What can still be expanded later:

- world-space debug gizmos such as lines or markers for landing points and route focus
- broader arena-specific smoke coverage once phase 3 routing is tuned further for all authored links

### Objective

Make AI tuning observable and regression-resistant.

### Implementation

- Add an AI debug overlay showing:
  - current goal
  - current action state
  - target actor
  - forward probe results
  - chosen landing point
  - chosen route link such as jump, wall-jump, or jump-pad traversal
  - why a shot was rejected
  - why a stomp attempt was accepted or rejected
- Add temporary or permanent smoke tests for:
  - safe stop at impossible gap
  - jump across simple gap
  - prefer chest when empty
  - use switch to open route
  - use wall-jump route when required
  - use jump pad and continue steering toward landing
  - choose or reject stomp in a simple vertical duel
  - avoid spikes in common layouts

### Success Criteria

- AI failures are explainable from debug output.
- Core traversal and objective behavior can be checked headlessly.

## Recommended Order

1. Phase 1: Terrain probes and safer movement
2. Phase 2: Goal selection and pickup priority
3. Phase 3: Arena routing with authored AI links
4. Phase 4: Combat discipline and positional play
5. Phase 5: Debugging and validation

## Notes For This Repository

- The current AI lives in [scripts/actors/ai_controller.gd](/home/matthiase/Github/Towerfall/scripts/actors/ai_controller.gd).
- Player movement wraps in both axes through [player.gd](/home/matthiase/Github/Towerfall/scripts/actors/player.gd), so falling off-screen is traversal, not death.
- Players can wall-slide and wall-jump in [player.gd](/home/matthiase/Github/Towerfall/scripts/actors/player.gd).
- Chests already expose lootable state in [scripts/gameplay/chest.gd](/home/matthiase/Github/Towerfall/scripts/gameplay/chest.gd).
- Gate and switch interaction already exists in [scripts/gameplay/gate.gd](/home/matthiase/Github/Towerfall/scripts/gameplay/gate.gd) and [scripts/gameplay/pressure_switch.gd](/home/matthiase/Github/Towerfall/scripts/gameplay/pressure_switch.gd).
- Jump-pad traversal already exists in [scripts/gameplay/jumping_pad.gd](/home/matthiase/Github/Towerfall/scripts/gameplay/jumping_pad.gd).
- Jump pads launch through `launch_from_pad()` in [player.gd](/home/matthiase/Github/Towerfall/scripts/actors/player.gd), and normal directional control continues afterward.
- Player heads are damageable via the head `Area2D` in [player.gd](/home/matthiase/Github/Towerfall/scripts/actors/player.gd), so stomps count as hits.
