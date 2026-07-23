---
type: decision
status: active
tags: [gui, stack, build]
project: spintax-studio
---

# 0002 — GUI on Lazarus / LCL, not Delphi VCL

**Date:** 2026-07-23

## Context

Studio is a native Windows GUI on top of the engine (spec §6). The two realistic toolkits
are Lazarus/LCL and Delphi VCL. The engine compiles under both — it is built with FPC and
already has a UTF-16 Delphi build path (engine `tests/delphi/`, engine decision 0003) — so
this is a product-stack choice, not an engine-compatibility one.

## Decision

**Lazarus / LCL.** SynEdit (available in both) provides the editor with a custom spintax
highlighter.

## Why

- **Same compiler as the engine.** FPC builds both, so there is one toolchain, one language
  dialect, and the engine's source drops in without a compatibility layer.
- **Zero cost, MIT throughout.** This is a solo, local-first, zero-cost product; a Delphi
  licence is a recurring cost for a commercial-use build, and the engine's `REGISTRY.md`
  already records that no Delphi licences are being bought. Delphi Starter cannot ship a
  commercial product.
- **One self-contained `.exe`, native widgets.** Matches the spec's "one .exe, no runtime"
  principle without a bundled framework.

## Consequences

- The GUI layer (LCL forms, SynEdit highlighter) is Lazarus-specific and does not port to
  Delphi for free. The **engine** stays neutral, and the **editor-core** (M0, `SpxStudio.pas`)
  is deliberately GUI-free (spec §5) — so the toolkit choice is contained to the GUI layer
  and could be revisited there without disturbing M0.
- Export uses FPSpreadsheet (Lazarus) for `.xlsx`; HTTP to models uses `fphttpclient` /
  Synapse. Both are FPC-native, keeping the single-toolchain property.
- Revisit only if a hard requirement appears that LCL cannot meet; the contained blast
  radius (GUI layer only) is what makes that safe.
