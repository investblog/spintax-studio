---
type: decision
status: active
tags: [engine, editor-core, workspace]
project: spintax-studio
---

# 0003 — The engine resolves `#include`; Studio supplies the resolver and the set

**Date:** 2026-07-25 (revised twice the same day — see *Revision history*)

## Context

`#include` resolution is a host concern in every engine of the family, but only for the
*lookup*. The **semantics** belong to the engine, and they are not what splicing text into a
document produces: the child is parsed and rendered on its own and its OUTPUT is substituted,
it inherits the runtime context but not the parent's `#set`/`#def`, an unknown target or a
cycle or a depth overflow resolves to the empty string, and the child's output is never
re-parsed by the parent.

`spintax-win` had the recognition and not the seam. It grew one in **`v0.3.0`**
([engine ADR 0004](../../engine/docs/decisions/0004-include-resolver-seam.md)), which is what
this decision now builds on:

```pascal
TSpIncludeResolver = class
public
  function Resolve(const Ref: string; out Text: string): Boolean; virtual; abstract;
end;
```

with `TSpContext.IncludeResolver` (nil — the default — leaves every `#include` verbatim) and
`TSpContext.MaxIncludeDepth` (0 selects the family's 20). Caller-owned, shaped like the
existing `TSpRng` seam.

Two engine facts from the same week set the rest of this decision:

- **Targets are compared exactly** since `v0.2.2`. `TStringList.IndexOf` had been matching
  case-insensitively where every other engine compares byte for byte, which moved verdicts.
  The first version of this ADR had built a case-insensitive slug rule on that bug.
- **The `#include` anchor is the family's** since `v0.2.1`: line-anchored, whitespace
  required, nothing else on the line.

## Decision

1. **Studio owns the lookup, and nothing else.** `TSpxSetResolver` implements the engine's
   seam over an in-memory `slug → text` map; `TSpxContext.Templates` carries the map and the
   render path builds the resolver per call. No expansion, no substitution by span, no depth
   or cycle bookkeeping, no shape checks — all of that is the engine's, and reproducing any
   of it host-side is how a preview stops matching the family.
2. **A template set is a flat folder** — the `*.spintax` files beside the current document
   (`.spintax` is the family's extension; the VS Code and Sublime packages already claim it).
   The slug is the filename without its extension.
3. **Lookup is exact, and the filesystem is not consulted.** `#include "Intro"` does not find
   `intro.spintax`. Studio matches the slug against its own map, never through a file open:
   on NTFS the filesystem would resolve the wrong case happily, and the preview would then
   disagree with every other engine about the same document. A case-only near-miss is worth a
   panel hint (spec §4.3) — silence would be honest and useless, because Windows users will
   assume case does not matter.
4. **editor-core never touches the disk.** The host builds the map from the folder listing and
   hands it in whole. M0 stays verifiable without a filesystem, and the folder rules live in
   the loader.
5. **`MaxIncludeDepth` stays at the engine's default.** Studio has no reason to want a
   different cap, and a different one would make this preview disagree with the engines that
   ship the text.
6. **Validation still walks the closure.** The engine validates one document at a time, so
   deciding *which* documents is the host's job: every file the document pulls in is validated
   separately, in its own coordinates, grouped by file, and any `error` anywhere makes the
   verdict red. `knownVariables` follows the **child scope** — a fragment gets the runtime
   context plus its own `#set`/`#def`, never the parent's, because the parent's macros are
   genuinely invisible to it. Circular includes stay out of the verdict, as they are in the
   reference; they are a render-time guard and, for Studio, a lint.

## Why

- **Parity is the product.** The right pane claims to show what the JS, PHP and Python engines
  produce. Host-side expansion breaks that in four measured ways at once, and each stays
  invisible until a user's fragment happens to hit it.
- **One implementation, not four.** The seam now exists for every host of this engine, not
  just for Studio, and the semantics live in the one place that can gate them against the
  reference.
- **A folder is the smallest set that works, and it already exists.** Spec §8 wanted "several
  templates whose slugs feed `knownIncludes`"; files in a directory are exactly that, with no
  format to invent and "save a file" as the way to add a fragment.
- **Exactness is not a preference.** The engine compares targets byte for byte; a resolver
  that is more forgiving would resolve templates that validation had just called unknown.

## Consequences

- M0 is small here: `TSpxTemplateSet`, `TSpxSetResolver`, one field on `TSpxContext`, and the
  resolver handed to the engine per render. `SpxRenderSample` and `SpxRenderBatch` resolve
  through it, so preview and export agree by construction.
- `SpExtractDirectives` keeps its editor jobs — the fragment prelude, macro values and
  jump-to-directive in the panel, and the closure walk — and is not an expansion mechanism.
- An unsaved, untitled document has no folder and therefore no set: `Templates` is nil, every
  `#include` renders verbatim, and the panel says why. That is also the engine's and the
  reference's behaviour without a resolver, so it is a truthful state rather than a fallback.
- A neutralized value embedded in an included template is **removed**, not restored — the
  child is author markup and the reserved-sentinel strip runs on it. Data-derived text belongs
  in the runtime context (engine spec §5.2, §6).
- Revisit if nested sets or per-project manifests become a real need — the loader and the
  resolver are where they plug in, and no stored format has to be migrated.

## Revision history

**Second revision, 2026-07-25 (engine `v0.3.0`).** The seam shipped, so this record moved from
"the engine should grow one" to the API it grew, and the slug rule flipped from
case-insensitive to **exact**: the case-insensitivity it had relied on was a defect in the
engine's `knownIncludes` check, fixed in `v0.2.2`. The "case-collision inside one set is a
workspace error" rule went with it — with exact matching, two files whose names differ only in
case are simply two templates, and on NTFS they cannot coexist anyway.

**First revision, 2026-07-25.** The original had **Studio** expanding includes by substituting
the occurrence spans `SpExtractDirectives` reports. Reading `@spintax/core`
(`internal/render.ts:91,106`) and the Python port (`_render.py:603`) showed the family resolves
inside render behind a host callback, under semantics a text-level pre-pass cannot reproduce.
The span substitution, the depth and cycle rules, the verbatim-on-failure fallback and a shape
gate against the engine's then-looser anchor were all dropped. The same reading corrected the
`knownVariables` rule for closure validation: the child scope means a fragment never sees the
parent's macros, so the union that had been specified would have silenced a true warning.
