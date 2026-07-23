---
type: note
status: active
tags: [backlog]
project: spintax-studio
---

# Backlog

The single list of open work. Full design in [spec.md](spec.md); this is the sequence and
the decisions still owed.

## Decisions to settle first (spec §10)

These gate everything below — especially the first, which sets the whole tech direction.

- [ ] **GUI framework — Lazarus/LCL vs Delphi VCL.** The spec recommends Lazarus: same FPC
      that builds the engine, MIT, native Win widgets, one self-contained `.exe`, zero cost.
      Delphi VCL is possible (the engine already compiles there) but is a licence and weight.
      → record as ADR 0002 once chosen.
- [ ] **How Studio pulls the engine** — git submodule (recommended), source-vendor, or a
      Delphi package (DPM/Boss). → ADR 0001.
- [ ] **Thesaurus for the synonym feature** — a local base (which one?) or LLM-only.
- [ ] **Persistence** — keep the LLM-loop history and generated variant sets between
      sessions, or treat them as session-only.
- [ ] **On-disk "template set" format** — feeds `#include` resolution and `knownIncludes`.

## Milestones (spec §9)

M0 is reused whole; the GUI (M1–M2) and the LLM loop (M4) are independent; M3/M4 order is
interchangeable.

- [ ] **M0 — editor-core (`SpxStudio.pas`).** `RenderSample` / `RenderBatch` /
      `ExtractModel` / `HealthReport` over the engine. Pure Pascal, GUI- and network-free,
      fully tested — verifiable without a window. The layer both the GUI and the LLM loop
      hang off.
- [ ] **M1 — GUI shell.** Two panes, SynEdit + a spintax highlighter, live preview, bracket
      matching, validity indicator. The DeepL skeleton.
- [ ] **M2 — panels.** Variables (`SpExtract`), diagnostics (`SpValidate`) with
      jump-to-error, partial preview of a selection, select-and-wrap, hotkeys on every key
      action.
- [ ] **M3 — export.** Generate N with distinct seeds, shingle dedup, `.xlsx` / `.txt` /
      per-file.
- [ ] **M4 — LLM loop.** `TLlmProvider` + adapters + `TAuthoringLoop` (Generate / Verify /
      Fix), the authoring-prompt as system, a local model via localhost, synonyms through
      the same layer. Keys local, zero telemetry.

## Non-negotiable, carried from the engine's experience (spec §7)

Each of these has already cost the engine a real debugging session — they are not
theoretical:

- Host sets `DefaultSystemCodePage := CP_UTF8` at startup, or Cyrillic becomes `'?'` before
  the engine sees it.
- `TSpContext` defaults `PostProcess := False`; Studio must set `True` explicitly, or the
  right pane diverges from the production engines.
- RNG: `TMulberry32Rng` for seeded preview, a fresh instance on reroll; `TFirstRng` /
  `TLastRng` are for deterministic checks, never the UI.
- The engine stays pure — no network, no GUI is added to it. The golden corpus is
  referenced, never vendored.

## Done

- [x] Repository bootstrapped; the spec homed as the source of truth (2026-07-23).
