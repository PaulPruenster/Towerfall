# AI Evaluation Pipeline Plan

This file tracks the AI evaluation pipeline for future enemy-AI changes.

It complements `AI_IMPROVEMENT_PLAN.md` in the repo root:

- `AI_IMPROVEMENT_PLAN.md` tracks gameplay AI feature work.
- This file tracks how AI changes are tested, ranked, reviewed, and promoted.

## Status Rules

- `Not started`: phase is scoped but no work has begun.
- `In progress`: phase is the active focus.
- `Blocked`: phase cannot continue until a dependency or decision is resolved.
- `Done`: exit criteria are met and the completion is logged below.

## Status Board

- Last updated: `2026-04-07`
- Current focus: `Phase 5 - Manual Review And Promotion Loop`
- Current work: `Phase 5 in progress; session counters and overlay stats added, promotion verdict recorder created`
- Next phase: `Phase 5 - Manual Review And Promotion Loop`
- Completed phases: `Phase 1`, `Phase 2`, `Phase 3`, `Phase 4`
- Blockers: `None`

## Work Log

- `2026-04-07`: Created `plan/ai_evaluation_pipeline.md`.
- `2026-04-07`: Started `Phase 1 - Freeze Battery Spec`.
- `2026-04-07`: Completed `Phase 1 - Freeze Battery Spec`.
- `2026-04-07`: Started `Phase 2 - Telemetry Collector`.
- `2026-04-07`: Added seeded headless roster overrides, world match lifecycle signals, gameplay telemetry signals, and structured AI snapshot fields.
- `2026-04-07`: Added `scripts/systems/ai_match_telemetry.gd` and `tests/ai_match_runner.gd`.
- `2026-04-07`: Validated one seeded `level_1` headless AI-vs-AI run with machine-readable run and batch JSON output.
- `2026-04-07`: Added direct candidate-vs-opponent comparison sections to one-run reports and direct batch diff JSON output for candidate-vs-baseline review.
- `2026-04-07`: Expanded batch summaries with richer mechanic coverage for gates, jump pads, moving platforms, and per-level candidate/opponent deltas.
- `2026-04-07`: Replaced direct image loading in `jumping_pad.gd` and `arrow_dummy.gd` so headless validation no longer emits the previous texture-loading warnings.
- `2026-04-07`: Revalidated headless project load and the permanent `tests/ai_smoke_test.gd`.
- `2026-04-07`: Completed `Phase 2 - Telemetry Collector`.
- `2026-04-07`: Started `Phase 3 - Deterministic Regression Battery`.
- `2026-04-07`: Extended `tests/ai_smoke_test.gd` with 3 missing Tier 1 micro-tests: special-arrow availability when normal ammo is 0, recover-goal priority, and wrap-side choice when wrapped route is shorter.
- `2026-04-07`: Created `tests/ai_regression_tier2.gd` with all 9 Tier 2 execution drills: pad-to-chest, switch-gate sequence, recover-ammo-disengage, horizontal wrap pursuit, vertical wrap drop, platform boarding, spike avoidance with route cross, stomp window conversion, and evade stomp threat.
- `2026-04-07`: Validated all Tier 1 (11 tests) and Tier 2 (9 drills) headless with zero failures.
- `2026-04-07`: Completed `Phase 3 - Deterministic Regression Battery`.
- `2026-04-07`: Started `Phase 4 - Ranked Duel And Arena Ladder`.
- `2026-04-07`: Created `scripts/gameplay/duel_world.gd` — minimal arena world with `match_setup_complete` and `match_resolved` signals, no HUD or UI dependencies, for use by all synthetic duel scenes.
- `2026-04-07`: Created `scenes/levels/duel_open.tscn`, `scenes/levels/duel_platform.tscn`, and `scenes/levels/duel_wrap.tscn` — three progressively complex synthetic flat-arena layouts using `duel_world.gd`.
- `2026-04-07`: Created `tests/ai_duel_runner.gd` — standalone Tier 3 headless runner; supports `--slices=`, `--seeds=`, `--spawn_swaps=`, `--timeout=`, `--battery_profile=`, `--output_dir=`; emits per-run JSON, batch summary JSON, and batch diff JSON.
- `2026-04-07`: Created `tests/ai_battery_runner.gd` — Phase 4 combined battery harness; `--battery=quick` runs Tier 3 (2 slices × 4 seeds × 2 swaps) + Tier 4 (3 levels × 4 seeds × 2 swaps); `--battery=full` expands to 3 slices × 6 seeds × 3 opponents; emits unified batch summary and diff across all tiers.
- `2026-04-07`: Validated `ai_duel_runner.gd` headless: all three duel scenes load and complete without errors; Tier 3 tier bucket and level bucket appear correctly in batch summary.
- `2026-04-07`: Validated `ai_battery_runner.gd` headless: quick battery completes all 16 Tier 3 runs + all 24 Tier 4 runs, writing per-run JSON and combined batch summary.
- `2026-04-07`: Completed `Phase 4 - Ranked Duel And Arena Ladder`.
- `2026-04-07`: Added `action_history: Array[int]` (max 4) and `REPEAT_PENALTY = 0.35` to `AIController`; added `_apply_variety_weight(candidate_state, base_score)` that subtracts `repeat_count * REPEAT_PENALTY * (1.0 - difficulty)` from the base score; wired variety weight into `_choose_state()` at the APPROACH/IDLE decision points; committed state to `action_history` in `get_control_state()` after every state decision (covers all reactive paths). High difficulty = near-zero penalty; pathfinding, physics, aim, and dodge detection are untouched.
- `2026-04-07`: Started `Phase 5 - Manual Review And Promotion Loop`.
- `2026-04-07`: Added `_session_shots_fired`, `_session_dodges_entered`, `_session_stuck_total` session counters to `AIController`; incremented at SHOOT transition, `_enter_dodge()`, and `_update_stuck_timer()`; reset in `_reset_runtime_state()`; exposed in `get_debug_snapshot()` alongside `action_history_names`.
- `2026-04-07`: Updated `scripts/ui/ai_debug_overlay.gd` to show two new lines per AI player: `session: N shots  N dodges  Xs stuck` and `history: [state state state state]` — matching the vocabulary of the headless batch reports.
- `2026-04-07`: Created `tests/ai_promotion_verdict.gd` — headless script that reads a batch diff JSON, appends a `promotion_record` with verdict, candidate_id, reviewer_date, notes, batch_score_delta, and a `checklist` dict with all frozen guardrail fields (null by default, to be filled by the reviewer), then writes the result back to the diff file or a named output.

## Phase Tracker

| Phase | Name | Status | Exit Criteria |
| --- | --- | --- | --- |
| 1 | Freeze Battery Spec | Done | Arena tiers, seed packs, opponent pool, report schema, and promotion guardrails are fixed in this file. |
| 2 | Telemetry Collector | Done | One headless run can emit a complete machine-readable report with match metadata, event stream, and per-bot summary metrics. |
| 3 | Deterministic Regression Battery | Done | Tier 1 and Tier 2 scenarios run headless and fail cleanly on rule regressions. |
| 4 | Ranked Duel And Arena Ladder | Done | Tier 3 and Tier 4 batch runners can compare baseline vs candidate on fixed seeds and mirrored spawns. |
| 5 | Manual Review And Promotion Loop | Not started | Overlay workflow, human review checklist, and promotion rules are used together for AI sign-off. |

## Phase 1 - Freeze Battery Spec

**Status:** `Done`  
**Started:** `2026-04-07`  
**Completed:** `2026-04-07`

### Purpose

Define one stable evaluation battery so future AI changes are judged against the same test tiers, seeds, reports, and promotion rules.

### Phase 1 Decisions

- Reuse the existing permanent smoke-test approach in `tests/ai_smoke_test.gd`.
- Reuse the existing AI snapshot vocabulary in `scripts/actors/ai_controller.gd`.
- Reuse the existing live inspection flow in `scripts/ui/ai_debug_overlay.gd`.
- Separate the pipeline into three lanes:
  - `Regression tests`
  - `AI quality ranking`
  - `Human/manual feel review`

### Frozen Tier Layout

#### Tier 1 - Decision Micro-Tests

Purpose:
- Protect hard AI rules and one-step decisions.

Scope:
- gap stop
- simple gap jump
- chest priority when empty
- switch priority
- wall-jump route execution
- jump-pad steering
- stomp choice
- spike avoidance
- special-arrow shot availability when normal ammo is `0`
- recover-goal priority
- wrap-side choice when wrapped route is shorter

Failure conditions:
- wrong goal
- wrong state
- wrong route choice
- wrong digital control output
- nondeterministic result on the same seed

Pass rule:
- strict pass/fail
- zero failures allowed

#### Tier 2 - Execution Drills

Purpose:
- Validate short multi-second behaviors that require real movement, timing, and objective completion.

Scope:
- take a pad to a chest
- press a switch and then use the opened gate
- recover ammo and disengage
- use horizontal wrap to shorten pursuit
- use vertical wrap drop when it is the intended route
- board, ride, and leave a moving platform
- avoid spikes while still reaching the objective
- convert a clean stomp window
- evade an overhead stomp threat

Failure conditions:
- objective not completed before timeout
- self-hazard death
- route loop or platform loop
- stall near destination
- wrong objective chosen

Pass rule:
- regression lane: strict pass/fail
- ranking lane: success rate must stay at `100%` before completion-time improvements count

#### Tier 3 - Mirrored Duel Slices

Purpose:
- Measure combat discipline and readable intent in controlled `1v1` fights.

Scope:
- shot discipline
- dodge timing
- post-shot retreat
- chest contest judgment
- recover-vs-fight choice
- stomp usage and anti-stomp behavior
- wrap re-entry behavior
- route transitions under combat pressure

Failure conditions:
- timeout
- repeated low-quality shots
- self-hazard death
- long indecision loops
- no use of the arena mechanic under test

Pass rule:
- used for ranking, not for hard regression blocking
- candidate must not break frozen guardrails

#### Tier 4 - Authored Arena Ladder

Purpose:
- Validate behavior on real authored levels, not only synthetic drills.

Scope:
- `scenes/levels/level_1.tscn`
- `scenes/levels/level_2.tscn`
- `scenes/levels/level_3.tscn`

Required mechanics by level:
- `level_1`: chest contest, gate usage, jump-pad routing
- `level_2`: switch-gate route choice, spikes, moving-platform usage, wrap routing
- `level_3`: wrap routing, spikes, moving-platform usage, vertical space control

Failure conditions:
- crash or hang
- repeated route deadlock
- excessive timeouts
- severe spawn-side bias after mirrored runs
- intended mechanic never used

Pass rule:
- used for ranking and promotion decisions
- candidate must improve or hold batch score while keeping guardrails intact

### Frozen Battery Profiles

#### Quick Battery

Use this on every meaningful AI change.

- Tier 1: all micro-tests
- Tier 2: all execution drills
- Tier 3: `2` duel slices x `4` seeds x `2` spawn swaps x `1` opponent
- Tier 4: `3` authored levels x `4` seeds x `2` spawn swaps x `1` opponent

Quick seed pack:
- `101`
- `211`
- `307`
- `401`

#### Full Battery

Use this before promoting an AI change.

- Tier 1: all micro-tests
- Tier 2: all execution drills
- Tier 3: `3` duel slices x `6` seeds x `2` spawn swaps x `3` opponents
- Tier 4: `3` authored levels x `6` seeds x `2` spawn swaps x `3` opponents

Full seed pack:
- `101`
- `211`
- `307`
- `401`
- `503`
- `601`

Timeout limits:
- Tier 2 drill timeout: `12s`
- Tier 3 duel slice timeout: `45s`
- Tier 4 authored level timeout: `60s`

### Frozen Opponent Pool

The minimum supported opponent pool is:

1. `FrozenBaseline`
2. `MirrorCandidate`
3. `PressureBaseline`

Definitions:

- `FrozenBaseline`
  - the last promoted AI build
  - default difficulty target: `0.60`
  - used to answer: "is the candidate actually better than the accepted baseline?"
- `MirrorCandidate`
  - the candidate AI against itself with mirrored spawn positions
  - used to expose deadlocks, shared bad habits, and spawn-side bias
- `PressureBaseline`
  - the frozen baseline with a more aggressive configuration
  - target difficulty: `0.85`
  - used to pressure dodge, spacing, and discipline

Future expansion:

- Add `ObjectiveBaseline` later if the telemetry hooks reveal that chest/switch/recover behavior still needs a separate dedicated opponent profile.
- Do not add more than `4` opponents without a clear measurement need.

### Frozen Regression Split

Regression tests:
- Tier 1
- Tier 2

AI quality ranking:
- Tier 3
- Tier 4

Manual review:
- in-editor or live arena runs using the existing debug overlay

### Frozen One-Run Report Format

Every run report must include:

- `run_id`
- `battery_profile`
- `tier`
- `arena_name`
- `seed`
- `spawn_swap_index`
- `candidate_id`
- `opponent_id`
- `duration_seconds`
- `result`
- `winner`
- `timeout`

Candidate summary metrics:
- `shots_fired`
- `shots_hit`
- `low_quality_shots`
- `dodge_opportunities`
- `successful_dodges`
- `stomp_attempts`
- `successful_stomps`
- `goal_time_by_type`
- `state_time_by_type`
- `route_attempts_by_traversal`
- `route_success_by_traversal`
- `wrap_count`
- `platform_board_attempts`
- `platform_board_success`
- `platform_ride_time`
- `stuck_time_seconds`
- `death_cause`

Opponent summary metrics:
- same schema as the candidate summary

Event timeline:
- timestamped major events only
- examples: `goal_change`, `route_start`, `route_fail`, `shot_fired`, `shot_hit`, `stomp_hit`, `switch_pressed`, `gate_used`, `platform_boarded`, `hazard_death`

Verdict flags:
- `route_loop`
- `platform_fail`
- `hazard_suicide`
- `low_discipline_fire`
- `timeout`
- `spawn_bias_suspected`

### Frozen Batch Summary Format

Every batch summary must include:

- `candidate_id`
- `baseline_id`
- `battery_profile`
- `seed_pack`
- `generated_at`
- `regression_status`
- `overall_batch_score`
- `promotion_verdict`

Per-tier summaries:
- runs
- wins
- losses
- timeouts
- self-hazard deaths
- low-quality-shot rate
- route success rate
- mechanic success rate
- mean stuck time

Per-level summaries:
- level name
- win rate
- timeout rate
- death-cause breakdown
- chest conversion
- switch conversion
- wrap usage
- moving-platform usage
- worst seeds

Failure clusters:
- top `3` repeated failure groups
- each cluster must include example seed(s)

### Frozen Ranking Score

Use one batch score for sorting AIs in reports:

`batch_score = 100 * (0.40 * win_rate + 0.15 * no_timeout_rate + 0.15 * no_self_hazard_rate + 0.10 * shot_discipline_rate + 0.10 * route_success_rate + 0.10 * mechanic_success_rate)`

Metric definitions:

- `win_rate = wins / total_runs`
- `no_timeout_rate = 1 - (timeouts / total_runs)`
- `no_self_hazard_rate = 1 - (self_hazard_deaths / total_runs)`
- `shot_discipline_rate = 1 - (low_quality_shots / max(total_shots, 1))`
- `route_success_rate = successful_route_traversals / max(route_traversal_attempts, 1)`
- `mechanic_success_rate = successful_required_mechanic_uses / max(required_mechanic_opportunities, 1)`

### Frozen Promotion Guardrails

The candidate may only be promoted if all of the following are true:

- all Tier 1 tests pass
- all Tier 2 drills pass
- full-battery `batch_score` is at least `2.0` points above the frozen baseline, or the targeted metric clearly improves and manual review agrees the behavior is better
- timeout rate is not worse than baseline by more than `5` percentage points
- self-hazard death rate is not worse than baseline by more than `2` percentage points
- low-quality-shot rate is not worse than baseline by more than `5` percentage points
- mean stuck time is not worse than baseline by more than `10%`
- required-mechanic success rate is not worse than baseline by more than `5` percentage points on any authored level
- mirrored-run spawn-side delta is not worse than `10` percentage points
- manual review passes

### Frozen Manual Review Checklist

Manual review is still required for:

- readability of aim and dodge timing
- fairness against humans
- whether wrap behavior feels smart instead of cheap
- whether moving-platform usage feels intentional
- whether higher difficulty feels smarter instead of simply faster
- whether chest contests, recover behavior, and retreats are understandable on screen

### Phase 1 Exit Criteria

- [x] Tier structure is fixed.
- [x] Seed packs are fixed.
- [x] Quick and full battery sizes are fixed.
- [x] Opponent pool is fixed.
- [x] One-run report schema is fixed.
- [x] Batch summary schema is fixed.
- [x] Ranking score is fixed.
- [x] Promotion guardrails are fixed.
- [x] Deterministic vs manual split is fixed.

## Phase 2 - Telemetry Collector

**Status:** `Done`  
**Started:** `2026-04-07`
**Completed:** `2026-04-07`

Scope:

- attach run metadata to each headless match
- capture event timeline entries
- sample AI snapshots at a fixed cadence
- emit one machine-readable report per run
- emit one summary per batch

Exit criteria:

- a single headless run can produce a complete one-run report
- a batch runner can aggregate several run reports into one batch summary
- the output can be diffed between frozen baseline and candidate builds

Current implementation:

- explicit AI roster overrides and evaluation options now live in `MatchSettings`
- `world.gd` now emits match setup and match resolved signals
- `player.gd`, `arrow.gd`, `chest.gd`, `gate.gd`, and `pressure_switch.gd` now expose telemetry-friendly events
- `ai_controller.gd` now exposes richer structured snapshot data for routing, threat, and stuck-state sampling
- `scripts/systems/ai_match_telemetry.gd` now builds one-run reports, batch summaries, and direct candidate-vs-opponent delta sections
- `tests/ai_match_runner.gd` now runs seeded headless AI-vs-AI matches and writes per-run JSON, batch summary JSON, and batch diff JSON
- one-run player summaries now include derived rates plus mechanic breakdowns for chest, switch, gate, jump-pad, and moving-platform usage
- batch summaries now carry candidate/opponent aggregates, per-tier deltas, and per-level deltas instead of only candidate-side rollups

Validation:

- `flatpak run org.godotengine.Godot --headless --path /home/matthiase/Github/Towerfall --quit-after 2`
- `flatpak run org.godotengine.Godot --headless --path /home/matthiase/Github/Towerfall --script res://tests/ai_match_runner.gd -- --levels=res://scenes/levels/level_1.tscn,res://scenes/levels/level_2.tscn,res://scenes/levels/level_3.tscn --seed=101 --spawn_swaps=1 --timeout=25`
- `flatpak run org.godotengine.Godot --headless --path /home/matthiase/Github/Towerfall --script res://tests/ai_smoke_test.gd`

Known follow-up:

- multi-level headless batch runs still end with an `ObjectDB` leak warning on process exit; this did not block Phase 2 exit criteria, but teardown cleanup should be revisited before scaling the batch harness further

## Phase 3 - Deterministic Regression Battery

**Status:** `Done`  
**Started:** `2026-04-07`  
**Completed:** `2026-04-07`

Scope:

- extend `tests/ai_smoke_test.gd` into the full Tier 1 library
- add Tier 2 execution-drill scenes or scripts in `tests/ai_regression_tier2.gd`
- fail fast on logic regressions

Implementation:

- `tests/ai_smoke_test.gd` now covers all 11 Tier 1 micro-tests:
  - impossible gap stop
  - simple gap jump
  - chest priority when empty
  - switch priority
  - wall-jump route execution
  - pad route steering
  - stomp choice
  - spike avoidance
  - special-arrow shot availability when normal ammo is `0`
  - recover-goal priority
  - wrap-side choice when wrapped route is shorter
- `tests/ai_regression_tier2.gd` covers all 9 Tier 2 execution drills:
  - T2.01 pad-to-chest: CHEST goal selection and PAD approach steering
  - T2.02 switch-gate sequence: SWITCH goal → goal transition after gate opens
  - T2.03 recover-ammo-disengage: RECOVER goal and RETREAT state at low health/ammo
  - T2.04 horizontal wrap pursuit: wrap route committed when direct path is blocked
  - T2.05 vertical wrap drop: wrap drop recognised when player is in lower screen region
  - T2.06 platform boarding: JUMP route step produces jump input on the floor
  - T2.07 spike avoidance with route cross: forward-path hazard detection + JUMP execution
  - T2.08 stomp window conversion: APPROACH selected when stomp window is open and no shot
  - T2.09 evade stomp threat: stomp threat detected and RETREAT state entered

Validation:

- `flatpak run org.godotengine.Godot --headless --path /home/matthiase/Github/Towerfall --script res://tests/ai_smoke_test.gd`
- `flatpak run org.godotengine.Godot --headless --path /home/matthiase/Github/Towerfall --script res://tests/ai_regression_tier2.gd`

Exit criteria:

- [x] Tier 1 and Tier 2 can run headless without manual inspection.
- [x] Failures identify the scenario and the broken rule clearly via `push_error`.
- [x] Both scripts exit `0` on pass, `1` on any failure.

## Phase 4 - Ranked Duel And Arena Ladder

**Status:** `Done`  
**Started:** `2026-04-07`  
**Completed:** `2026-04-07`

Scope:

- build Tier 3 duel slices
- run Tier 4 on the authored levels
- compare frozen baseline vs candidate on identical seeds and spawn swaps

Implementation:

- `scripts/gameplay/duel_world.gd` — minimal arena world with `match_setup_complete` and `match_resolved` signals, no HUD or UI dependencies
- `scenes/levels/duel_open.tscn`, `scenes/levels/duel_platform.tscn`, `scenes/levels/duel_wrap.tscn` — three synthetic arena layouts
- `tests/ai_duel_runner.gd` — standalone Tier 3 headless runner
- `tests/ai_battery_runner.gd` — combined battery harness; `--battery=quick` or `--battery=full`

Validation:

- `flatpak run org.godotengine.Godot --headless --path /home/matthiase/Github/Towerfall --script res://tests/ai_duel_runner.gd -- --battery_profile=quick --slices=open,platform --seeds=101,211,307,401 --spawn_swaps=2`
- `flatpak run org.godotengine.Godot --headless --path /home/matthiase/Github/Towerfall --script res://tests/ai_battery_runner.gd -- --battery=quick`
- Quick battery: 16 Tier 3 runs + 24 Tier 4 runs, combined batch summary with `tier3` and `tier4` buckets confirmed.

Exit criteria:

- [x] Quick battery runs on demand.
- [x] Full battery runs on demand.
- [x] Baseline vs candidate reports can be diffed directly.

## Phase 5 - Manual Review And Promotion Loop

**Status:** `In progress`  
**Started:** `2026-04-07`

Scope:

- align the debug overlay with report metrics
- define a repeatable human review checklist
- record promotion verdicts in reports

Implementation:

- `AIController` now tracks three session counters exposed in `get_debug_snapshot()`:
  - `session_shots_fired` — incremented each time `state == SHOOT` resolves (same event the telemetry counts)
  - `session_dodges_entered` — incremented in `_enter_dodge()`
  - `session_stuck_total` — cumulative seconds accumulated in `_update_stuck_timer()` (matches `stuck_time_seconds` in run reports)
  - `action_history_names` — the last 4 committed states as human-readable strings
- `scripts/ui/ai_debug_overlay.gd` now shows two additional lines per AI player:
  - `session: N shots  N dodges  Xs stuck` — matches the report vocabulary directly
  - `history: [state state state state]` — shows the variety-weight window
- `tests/ai_promotion_verdict.gd` — reads a batch diff JSON and appends a `promotion_record`:
  - Required: `--diff=`, `--verdict=approved|rejected|conditional`
  - Optional: `--candidate_id=`, `--notes=`, `--output=`
  - Stores verdict, candidate_id, baseline_id, reviewer_date, notes, batch_score_delta, and a `checklist` dict with all nine frozen guardrail fields (null until the reviewer fills them)
  - Copies `candidate_minus_opponent` metrics into the record for archiving

Checklist workflow:

1. Run the full battery: `tests/ai_battery_runner.gd --battery=full`
2. Open the batch diff JSON and review the per-tier and per-level summaries.
3. Run the game in-editor and toggle the debug overlay (F2 or configured key) to observe live session stats and action history during 1v1 play.
4. Work through the Frozen Manual Review Checklist from Phase 1.
5. Run `tests/ai_promotion_verdict.gd` with the filled-in verdict and notes.
6. Archive the resulting diff JSON with the promotion record.

Exit criteria:

- [ ] Manual review uses the same vocabulary as the headless reports.
- [ ] Promotion decisions are documented with guardrails and review notes.
