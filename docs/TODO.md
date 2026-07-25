---
type: note
status: active
tags: [backlog]
project: spintax-studio
---

# Backlog

The single list of open work. Full design in [spec.md](spec.md); this is the sequence and
the decisions still owed.

## Open decisions (spec §10)

Everything that gates M0/M1 is settled. What is left is not one tier: the architecture
question lands with Pre-M0 (b), the Partner Center account type before the first submission
(see *Publish prep*), the rest at M3/M4.

- [x] **GUI framework — Lazarus/LCL** ([ADR 0002](decisions/0002-gui-lazarus-lcl.md)). Same
      FPC as the engine, MIT, native Win widgets, one self-contained `.exe`, zero cost.
- [x] **Engine pull — git submodule** ([ADR 0001](decisions/0001-engine-as-submodule.md)),
      at `engine/`, pinned to tag `v0.1.0`. Clone with `--recurse-submodules`.
- [x] **`#include` resolution + the on-disk template set**
      ([ADR 0003](decisions/0003-include-resolution-and-template-set.md), 2026-07-25). The
      engine renders the directive verbatim — resolution is a host duty — so editor-core
      expands it **by the occurrence spans the engine reports**, and a set is the flat folder
      of `*.spintax` files beside the document (slug = filename, matched case-insensitively,
      which is what the engine's own `knownIncludes` check does; a case-collision inside one
      set is a workspace error, not a coin toss). Not an M3/M4 question after all: until it is
      settled the preview shows a raw directive and `knownIncludes` has nothing to be built
      from.
- [ ] **Target architecture for the shipped `.exe`** — x86_64 (the Store target) with i386
      kept in the CI matrix as the engine does, or something else. Settle when `build.sh`
      lands; the installed FPC 3.2.2 cross-builds both (`ppcrossx64`, verified 2026-07-25).
- [ ] **Thesaurus for the synonym feature** — a local base (which one?) or LLM-only. (M4)
- [ ] **Persistence** — keep the LLM-loop history and generated variant sets between
      sessions, or treat them as session-only. (M4 / M3)

## Milestones (spec §9)

M0 is reused whole; the GUI (M1–M2) and the LLM loop (M4) are independent; M3/M4 order is
interchangeable. **R0 (the first Store release) = M0–M3, offline, no AI** (spec §9); M4 and
the managed tier are later releases.

- [ ] **Pre-M0 (a) — release the engine as `v0.2.0`, then bump the submodule.** Two additive
      public-API pieces ride that tag: `TSpDiag` positions (already on the engine's `main`)
      and `SpExtractDirectives` (still to write, spec §4.2) — every `#set` / `#def` /
      `#include` the renderer sees, each with its source span (the `TSpDiag` position
      contract), its source text and, for macros, its value. Three M0 consumers need it and
      none of them can be served by `SpExtract`:
      - the **include resolver** substitutes occurrences by span. A target *list* is not
        enough — it is deduplicated, so the same slug commented out and live is one entry
        (measured), and expanding both leaks the commented copy's text plus a stray `#/`,
        because comments do not nest. A fragment that documents itself is all it takes.
      - the **fragment preview** needs the `#set`/`#def` prelude, which the engine parses
        only after stripping comments and across five line terminators;
      - the **variables panel** needs macro *values*, which `SpExtract` does not return.

      Bump as soon as the tag exists, not at M2, or M0 is written against an API the `v0.1.0`
      pin lacks (spec §9).
- [ ] **Pre-M0 (b) — repo scaffolding for Pascal code.** `build.sh` in the engine's shape (a
      clean unit dir, build the test binary, a warnings-are-errors pass with `-Sew -vm4046`),
      CI on ubuntu + windows with `submodules: recursive`, `.gitignore` for `lib/`, built
      binaries and Lazarus artefacts, and the `quality-pascal` chain + git hooks (pre-commit /
      pre-push run the build and the tests) — the deployment the charter defers until M0
      brings real code, recorded in `.agents/REGISTRY.md`.
- [ ] **M0 — editor-core (`SpxStudio.pas`).** `ExpandIncludes` / `RenderSample` /
      `RenderFragment` / `RenderBatch` / `ExtractModel` / `HealthReport` over the engine.
      Pure Pascal, GUI- and network-free,
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

      Three more contracts, from measuring the engine on 2026-07-25:
      - **`#include` expansion is a render-path step only, and it goes by span** (ADR 0003).
        Every render goes through `ExpandIncludes`, which substitutes the occurrences
        `SpExtractDirectives` reports, last one first; validation stays on the *unexpanded*
        document, because a position inside substituted text has nowhere to point in the
        editor. The set arrives as an in-memory `slug → text` map — editor-core does no I/O,
        so M0's tests need no filesystem.
      - **Validation covers the include closure.** Every file the document pulls in is
        validated separately, in its own coordinates, grouped by file, with
        `knownVariables` = runtime vars ∪ all `#set`/`#def` names in the closure and
        `knownIncludes` = the set's slugs. Without the closure a document is green while the
        export degrades on a broken fragment; without the union a fragment using a parent's
        macro reports a false `variable.undefined` (measured). Any `error` anywhere in the
        closure makes the verdict red.
      - **One engine thread, warmed at startup.** The engine's post-process builds a lazy
        global (`GAbbrevs`) with no synchronisation, so two first renders on two threads
        race; and post-process is 0.7 s on a 237 KB template, too slow for the UI thread on
        every debounce. editor-core therefore keeps no state of its own — a single worker can
        own every engine call, "latest wins" (spec §5).
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
- [x] **`#include` and the template set settled** as [ADR 0003](decisions/0003-include-resolution-and-template-set.md)
      (2026-07-25), after measuring the engine rather than assuming: the directive survives
      render verbatim and slugs match case-insensitively. The first draft let Studio find the
      lines itself and leaned on `SpExtract`'s target list to skip commented-out includes;
      review pushed back, and the measurement agreed — the list is deduplicated, so it cannot
      separate a commented occurrence from a live one, and expanding both leaks text and a
      stray `#/` (comments do not nest). The contract is now occurrence-level, which is what
      pulled `SpExtractDirectives` into the `v0.2.0` scope. The same session pinned closure
      validation, the single-engine-thread rule and the slug-collision rule into spec
      §4.2 / §4.3 / §5 / §7 / §8.
