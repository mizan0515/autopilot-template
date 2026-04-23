# Integration Checklist

## Purpose

This template is the outer control loop.
Use this checklist when adapting it into a real project or when deciding whether
production lessons should be upstreamed here.

## What This Template Should Own

- wake/sleep pacing
- active-task dispatch
- decision-PR operator flow
- compact status surfaces
- compact done markers
- doctor / audit wrapper behavior
- retry budgets and bounded waits
- stale-signal detection and cleanup

If a lesson is about one of these and is product-agnostic, it probably belongs
here.

## What This Template Should Not Own

- DAD packet schema
- DAD handoff semantics
- product-specific dashboards
- product route heuristics
- product prompts
- Unity/card-game-only diagnostics
- domain evidence wording

Those belong in `dad-v2-system-template` or the downstream product repo.

## Compact Status Contract

Every downstream adoption should define three small artifacts:

1. one machine-readable live signal
2. one human-readable status summary
3. one bounded done marker

Operators and LLMs should be able to decide the next action from those artifacts
without tailing raw logs by default.

## Doctor Contract

`project.ps1` / `project.sh` should expose a cheap `doctor` command that checks:

- environment readiness
- stale lock or stale signal state
- test-only override leakage
- missing compact status artifacts
- peer-tool or dependency drift when the project depends on external peers
- any bounded wait condition that would otherwise trap the operator

The doctor check should fail on real operator-facing risk, not on narrative drift.

## Managed Path Pattern

Prefer one obvious bounded operator path over multiple low-level controls.

Good pattern:

- prepare
- run one bounded cycle
- emit compact status
- stop with a clear next action

Bad pattern:

- ask the operator to inspect raw logs
- ask the operator to edit state files
- expose several near-duplicate scripts with unclear ownership

## Upstream Decision Rules

Promote a lesson to this template only if all statements are true:

1. the rule is about loop control or operator interaction
2. the rule is reusable across products
3. the rule does not depend on one product's names, dashboards, or directory
   layout
4. the rule can be implemented through the example wrapper surface or README
   guidance

## Minimum Downstream Adoption Steps

1. copy `.autopilot/`
2. implement `project.ps1` or `project.sh`
3. define compact live-signal, status, and done-marker artifacts
4. customize doctor/test/audit commands
5. confirm decision-PR flow matches the host repo's real operator path
6. confirm the operator never needs raw logs for routine status

## Review Trigger

Revisit this template when a live repo shows repeated failures in:

- missed reschedules
- stale status surfaces
- operator confusion about next action
- hidden override leakage
- unbounded waits
- repeated manual file edits to unblock the loop
