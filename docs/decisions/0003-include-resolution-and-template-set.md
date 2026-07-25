---
type: decision
status: active
tags: [engine, editor-core, workspace]
project: spintax-studio
---

# 0003 — The engine resolves `#include`; Studio supplies the resolver and the set

**Date:** 2026-07-25 (revised the same day — see *Revision history*)

## Context

`spintax-win` renders `#include` verbatim: with no resolver the directive survives rendering
unchanged, which the engine pins in its own assertions (`include/line-survives-render`) under
a comment stating the rule — *"`#include` resolution is a HOST concern in both engines."* The
engine only *sees* includes: `SpExtract` lists the targets, `SpValidate` reports
`include.unknown-target`, and only when a slug list is supplied. Measured against the engine:

| probe | result |
|---|---|
| `SpRender('#include "frag"' + LF + 'after')` | `#include "frag"` + LF + `After` — the directive is output as text |
| `SpValidate('#include "intro"', knownIncludes = ['Intro'])` | clean — the slug match is case-insensitive |
| `SpExtract('/# #include "hidden" #/' + LF + '#include "live"')` | `live` only — a commented-out include does not exist |

Studio needs includes to work: a set of templates sharing fragments is the point of §8, and a
right pane that echoes the directive answers a question nobody asked.

### "A HOST concern" does not mean "expand the text yourself"

The first version of this decision read that comment as an invitation for Studio to expand
includes itself, and specified a text-level substitution. Reading the reference settled it the
other way. `@spintax/core` resolves includes **inside render**, behind a host callback
(`internal/render.ts:91,106`), and so does the Python port (`_render.py:603`); both cite the
WordPress plugin's `for_child_render`. The host supplies `ref → text | null`; the engine does
the rest, with semantics a host cannot reproduce from outside:

| | family (JS, Python; plugin lineage) | text-level expansion |
|---|---|---|
| what is substituted | the child is **parsed and rendered on its own**, its *output* is spliced | raw text, the whole document renders as one |
| child scope | inherits the runtime context, **not** the parent's `#set`/`#def` | the child sees the parent's macros |
| unknown target, cycle, depth overflow | **empty string**, leniently | — |
| child output containing `{`, `|`, `%` | already output, never re-parsed | re-parsed as markup by the parent |

Plus the details a host would have to guess: cycles are detected **by the ref string** (two
aliases of one template are not a cycle and recurse to the limit), `DEFAULT_MAX_DEPTH = 20`,
and the same counter also caps parse nesting.

`spintax-win` is the only port in the family without that seam. So the gap is the engine's,
not Studio's, and filling it in Studio would mean a preview that matches no other engine —
which is the one thing this product cannot do.

### Why the occurrence API still earns its place

`SpExtract().Includes` is deduplicated (`if Result.Includes.IndexOf(ref) < 0 then Add`), so a
target list says *whether* a slug is included, never *where*. Measured:

| probe | result |
|---|---|
| `SpExtract` on a document with `frag` **both** inside `/# … #/` and live | `[frag]` — one entry for two occurrences |
| are block comments nestable? `/# a /# b #/ c #/ d` | renders `C #/ d` — **not** nestable, the first `#/` closes |
| expand *both* occurrences with the fragment `/# intro fragment #/` + LF + `Привет` | `Привет` + LF + `#/` + LF + LF + `Привет` — the commented-out copy leaks its text and a stray `#/` |

That measurement is what put `SpExtractDirectives` into engine `v0.2.0`, and it stands even
though Studio no longer substitutes anything: the fragment preview needs the `#set`/`#def`
prelude in source order, and the variables panel needs macro **values**, neither of which
`SpExtract` returns.

## Decision

1. **Include expansion lives in the engine.** `spintax-win` grows the family's resolver seam
   (`ref → text | null` on the render context) with the reference's semantics: child scope,
   lenient empty on unknown target / cycle / depth overflow, cycles by ref string, default
   max depth 20, and the reference's line anchor. Studio passes a resolver closure and
   `SpRender` does the work — editor-core has no expansion code, no substitution by span, no
   cycle rules and no shape gate of its own.
2. **A template set is a flat folder** — the `*.spintax` files beside the current document
   (`.spintax` is the family's extension: the VS Code and Sublime packages already claim it).
   The slug is the filename without its extension, matched **case-insensitively**, which is
   what the engine's `knownIncludes` check does. No manifest, no nesting, no project file.
   Two files whose slugs differ only in case (`Intro.spintax`, `intro.spintax` — impossible on
   NTFS, arriving via an archive, a clone on a case-sensitive filesystem or CI) are a
   **workspace error**: that slug resolves to nothing and the set says why, rather than
   silently taking whichever the directory listing returned first.
3. **editor-core never touches the disk.** The set reaches it as an in-memory `slug → text`
   map built by the host from the folder listing; the resolver closure reads that map. M0
   stays verifiable without a filesystem, and the flat-folder rule (with its collision check)
   lives in the loader.
4. **Until the engine has the seam, includes render verbatim, and Studio does not fake it.**
   That is the engine's documented no-resolver behaviour and what any host in the family gets
   before it supplies one. The variables panel still marks targets known/unknown, and
   `include.unknown-target` still comes from `SpValidate` with the set's slugs — validation
   does not wait for expansion.
5. **Validation walks the include closure** — the engine validates one document at a time, so
   deciding *which* documents is the host's job. Every file the document pulls in is validated
   separately, in its own coordinates, grouped by file; any `error` anywhere makes the verdict
   red, because the export degrades on a broken fragment. `knownVariables` follows the **child
   scope**: a fragment gets the runtime context plus its own `#set`/`#def`, **not** the
   parent's — the parent's macros are genuinely not in scope for it, and pretending otherwise
   would suppress a warning that is true.

## Why

- **Parity is the product.** The right pane claims to show what the JS, PHP and Python engines
  produce. Host-side expansion breaks that in four measured places at once (scope, failure
  mode, re-parsing, and the family's `maxDepth`/cycle rules), and every one of them is
  invisible until a user's fragment happens to hit it.
- **One implementation, not four.** The seam exists in two ports already and comes from the
  plugin; adding it to `spintax-win` fixes the gap for every future host of this engine, not
  just for Studio. It also removes the need for Studio to gate the engine's looser `#include`
  rule, because the same commit narrows that rule to the reference anchor — a fix the engine
  already owes on verdict-parity grounds.
- **A folder is the smallest set that works, and it already exists.** Spec §8 wanted "several
  templates whose slugs feed `knownIncludes`"; files in a directory are exactly that, with no
  format to invent and "save a file" as the way to add a fragment.
- **Case-insensitive slugs are not a free choice.** The engine's check is case-insensitive and
  NTFS is too; a case-sensitive resolver would refuse a target validation had just accepted.
  Which is why a case-collision inside one set must be an error rather than a coin toss.

## Consequences

- **M0 shrinks.** No `ExpandIncludes`, no span substitution, no depth/cycle bookkeeping — the
  render helpers take the set and hand a resolver to the engine once the seam exists. What
  remains Studio's is the set (loading, slugs, collisions) and the closure walk for validation.
- **R0 depends on an engine release.** Includes are only useful in the preview once the seam
  ships, so either R0 waits for that engine version or R0 ships with includes validated but not
  expanded. Recorded as an open decision in the backlog rather than settled here.
- **Raw sentinels split the two views.** The editor-side calls read the source as written,
  while `SpRender` deletes the reserved U+E000–U+E005 before parsing, so a document carrying
  raw ones can hold a directive the panel sees and the renderer does not, or the reverse. The
  reference diverges identically — it is the family's contract, not a port bug. Foreign text
  enters a template through `SpNeutralize`, and a raw sentinel in a document is a Studio lint
  (spec §4.3, §7).
- The variables panel marks include targets known/unknown from the same set that feeds the
  resolver, and `SpExtractDirectives` spans make "jump to the directive" free.
- An unsaved, untitled document has no folder and therefore no set: its includes resolve to
  nothing and the panel says why.
- Revisit if nested sets or per-project manifests become a real need — the set loader and the
  resolver closure are where they plug in, and no stored format has to be migrated.

## Revision history

**2026-07-25, same day.** The first version had **Studio** expand includes: substitute the
occurrence spans from `SpExtractDirectives`, last one first, recursively, with its own depth
limit and cycle detection, leaving the directive verbatim on failure — plus a shape gate to
keep the engine's looser `#include` rule from expanding lines the family renders as text.
Reading `@spintax/core` and the Python port after that was written showed the family resolves
includes *inside* render with a host callback, under semantics a text-level pre-pass cannot
reproduce (table above). The whole host-side apparatus — spans for substitution, the shape
gate, the depth and cycle rules, the "verbatim on failure" fallback — was dropped with it.
What survived unchanged: the flat-folder set, case-insensitive slugs with the collision rule,
no disk I/O in editor-core, and closure validation — though its `knownVariables` union was
corrected here, because the child scope means a fragment never sees the parent's macros.
