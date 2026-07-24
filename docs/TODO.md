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

The two that gate M0/M1 are settled; the rest are M3/M4-level and can wait.

- [x] **GUI framework — Lazarus/LCL** ([ADR 0002](decisions/0002-gui-lazarus-lcl.md)). Same
      FPC as the engine, MIT, native Win widgets, one self-contained `.exe`, zero cost.
- [x] **Engine pull — git submodule** ([ADR 0001](decisions/0001-engine-as-submodule.md)),
      at `engine/`, pinned to tag `v0.1.0`. Clone with `--recurse-submodules`.
- [ ] **Thesaurus for the synonym feature** — a local base (which one?) or LLM-only. (M4)
- [ ] **Persistence** — keep the LLM-loop history and generated variant sets between
      sessions, or treat them as session-only. (M4 / M3)
- [ ] **On-disk "template set" format** — feeds `#include` resolution and `knownIncludes`.

## Milestones (spec §9)

M0 is reused whole; the GUI (M1–M2) and the LLM loop (M4) are independent; M3/M4 order is
interchangeable. **R0 (the first Store release) = M0–M3, offline, no AI** (spec §9); M4 and
the managed tier are later releases.

- [ ] **Pre-M0 — bump the engine submodule to `v0.2.0`** once `spintax-win` is tagged.
      Diagnostic positions (`TSpDiag.Line/Column/…`) exist only from v0.2.0, and M0's
      `HealthReport` already carries them — so bump before M0 touches positions, not at M2,
      or M0 is written against an API the `v0.1.0` pin lacks (spec §9).
- [ ] **M0 — editor-core (`SpxStudio.pas`).** `RenderSample` / `RenderBatch` /
      `ExtractModel` / `HealthReport` over the engine. Pure Pascal, GUI- and network-free,
      fully tested — verifiable without a window. The layer both the GUI and the LLM loop
      hang off. **This is where the Studio-context ↔ pure-engine boundary lives**, and the
      review pinned four contracts M0 must carry (spec §§4.2–4.6, 5):
      - `HealthReport`/validation pass **both** `knownIncludes` and `knownVariables`
        (engine has the overload) — else panel-declared vars flag false `variable.undefined`;
      - partial preview renders the selection in **full-document context** (directives +
        runtime ctx + locale in scope), not isolated;
      - batch seeds are `seedBase + i`, recorded, with a dedup retry budget and a
        requested/generated/dropped report;
      - diagnostics are **consumed with their `TSpDiag` positions** (`Line`/`Column`/`End*`,
        engine ≥ `v0.2.0`) — Studio does NOT reimplement the validator scan; `Line = 0`
        means unknown → panel-only, no squiggle, and positions never alter the verdict.
- [ ] **M1 — GUI shell.** Two panes, SynEdit + a spintax highlighter, live preview, bracket
      matching, validity indicator. The DeepL skeleton.
- [ ] **M2 — panels.** Variables (`SpExtract`), diagnostics (`SpValidate`) with squiggles
      and jump-to-error driven by `TSpDiag` positions (engine ≥ `v0.2.0` — bumped in Pre-M0,
      not here), partial preview of a selection, select-and-wrap, hotkeys on every key action.
- [ ] **M3 — export.** Generate N with distinct seeds, shingle dedup, `.xlsx` / `.txt` /
      per-file.
- [ ] **M4 — LLM loop.** `TLlmProvider` + adapters + `TAuthoringLoop` (Generate / Verify /
      Fix), the authoring-prompt as system, a local model via localhost, synonyms through
      the same layer. Keys local, zero telemetry.

## Publish prep — Microsoft Store (spec §11)

Distribution target is the Store via MSIX. Some of these are **constraints on M0/M1** (bake
them in, don't retrofit); the submission tasks come once M1/M2 give a demoable product.

Constraints (design into the app from the start):
- [ ] **No admin, known-folder storage.** Settings / templates / keys go to the user profile
      via known-folder APIs (`%APPDATA%` / `LocalAppData` / Credential Manager), never next to
      the `.exe` — required for the MSIX container and to avoid elevation (spec §7, §11).
- [ ] **Stable app identity.** Package name + publisher (must match Partner Center), 4-part
      MSIX version that only increases, an icon/asset set for Store tiles.
- [ ] **Offline baseline is the review keystone.** Editor / validation / render / export must
      work with no key and no network; AI stays opt-in — so a reviewer verifies the product
      without any setup (spec §1, §11).

Submission tasks (after a demoable build):
- [ ] **MSIX packaging** of the Lazarus `.exe` (Store re-signs; fallback EXE/MSI only if MSIX
      won't do — then versioned HTTPS URL + silent install + our own signing/hosting/updates).
- [ ] **Privacy policy — even for R0.** R0 is offline, so a short page is trivially true and
      builds Store trust: *no telemetry, no account, no network, local files only.* Expand it
      when BYOK AI (R1) adds network, and again for a managed tier (data transits our
      zero-retention proxy).
- [ ] **No purchases in R0** — no paywall, trial, or IAP; a free offline app keeps the first
      submission out of financial policy too.
- [ ] **AI disclosure + report path** — **R1+ only** (once live generative AI ships): disclose
      in listing + Partner Center, and give an in-app/listing contact for reporting problematic
      AI output. R0 ships no AI, so this obligation does not apply to the first submission.
- [ ] **Listing** = a real product (clear screenshots: template → preview → export), not a
      dev-tool stub.

Decisions owed **before the relevant submission** (not switchable later):
- Partner Center account type — individual vs company (company for commercial), before R0.
- **Paid managed-AI tier needs its own ADR** before any billing (R2+): Store IAP vs
  third-party purchase API (Stripe/…), prices/terms, cancellation, Partner Center disclosure.
  See spec §10/§11.

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
- [x] Engine wired in as a submodule at `engine/`, pinned to `v0.1.0` (2026-07-23).
- [x] The two gating decisions settled — Lazarus/LCL and submodule — recorded as ADRs
      0002 and 0001 (2026-07-23).
