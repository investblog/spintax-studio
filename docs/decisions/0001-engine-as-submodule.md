---
type: decision
status: active
tags: [engine, dependency, build]
project: spintax-studio
---

# 0001 — The engine is a git submodule, pinned to a tag

**Date:** 2026-07-23

## Context

Studio is built on `spintax-win` and must compile its source in-process (spec §5). Three
ways to bring it in: a git submodule, a vendored copy of the source, or a Delphi package
manager (DPM / Boss).

## Decision

A git **submodule** at `engine/`, pinned to a released tag — `v0.1.0` at bootstrap.
Updating the engine is a deliberate `git submodule update --remote` + re-pin to the next
tag, reviewed like any other change.

## Why

- **A vendored copy drifts.** The whole family avoids this with the golden corpus for
  exactly this reason (engine decision 0001, "a drifting contract is not a contract"). A
  copied `Spintax.pas` would silently fall behind the engine's releases; a submodule pin is
  an explicit, visible version.
- **DPM / Boss is infrastructure nobody here needs.** The engine's own `REGISTRY.md`
  records that no consumer in this use case installs through a package manager, so a package
  step would be weight for no one. Studio is the only consumer, and it builds from source.
- **A tag pin, not a floating branch.** Studio always builds against a known engine state
  (168/172 corpus at `v0.1.0`), and the preview's parity claim is anchored to a specific
  release, not to whatever `main` happens to be.

## Consequences

- Clone with `--recurse-submodules` (or `git submodule update --init` after a plain clone);
  CI must do the same before building.
- The engine's `unit Spintax` is on the unit search path from `engine/src/`.
- Bumping the engine is a small, auditable commit that moves the submodule pointer to a new
  tag — never an implicit pull.
