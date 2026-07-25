---
type: decision
status: active
tags: [engine, editor-core, workspace]
project: spintax-studio
---

# 0003 — Studio resolves `#include`; a template set is a flat folder

**Date:** 2026-07-25

## Context

The engine does not resolve `#include`. With no resolver the directive survives rendering
verbatim, which the engine pins in its own assertions (`include/line-survives-render`) under
a comment stating the rule: *"`#include` resolution is a HOST concern in both engines."* The
engine only *sees* includes: `SpExtract` lists the targets, `SpValidate` reports
`include.unknown-target`, and only when a slug list is supplied. Measured against
`spintax-win` at `main`:

| probe | result |
|---|---|
| `SpRender('#include "frag"' + LF + 'after')` | `#include "frag"` + LF + `After` — the directive is output as text |
| `SpValidate('#include "intro"', knownIncludes = ['Intro'])` | clean — the slug match is case-insensitive |
| `SpExtract('/# #include "hidden" #/' + LF + '#include "live"')` | `live` only — a commented-out include does not exist |

Studio is the host, so Studio is the resolver. The spec assumed a template set (§8) without
saying who expands the directive or what a set is on disk, and the backlog carried the
on-disk format as an M3/M4-level question. It is neither: until it is settled the right pane
shows the directive as literal text, and the "set of templates" that feeds `knownIncludes`
has no definition to be fed from.

### Why a list of targets is not enough

The first draft of this decision had Studio take the target list from `SpExtract` and find
the lines to substitute with its own scan, arguing that a commented-out include would be
skipped because the engine never reports it. Review caught that this does not hold, and the
measurement confirms it:

| probe | result |
|---|---|
| `SpExtract` on a document with `frag` **both** inside `/# … #/` and live | `[frag]` — one entry for two occurrences; the list cannot tell them apart |
| are block comments nestable? `/# a /# b #/ c #/ d` | renders `C #/ d` — **not** nestable, the first `#/` closes |
| expand *both* occurrences with the fragment `/# intro fragment #/` + LF + `Привет` | `Привет` + LF + `#/` + LF + LF + `Привет` — the commented-out copy leaks its text *and* a stray `#/` |
| the same with a fragment that carries no comment | identical to the correct expansion |

`SpExtract().Includes` is deduplicated (`if Result.Includes.IndexOf(ref) < 0 then Add`), so a
target list says *whether* a slug is included, never *where*. A Studio scan over the original
source would then replace the commented-out occurrence too, and the damage needs nothing
exotic: a fragment that documents itself with `/# … #/` is enough, because comments do not
nest and the inner `#/` closes the outer comment early.

So the resolver needs an **occurrence-level** contract — positions, not a set of names.

## Decision

1. **editor-core expands includes before rendering.** `#include "slug"` is replaced by the
   text of the template carrying that slug, recursively, and the expanded text is what goes
   to `SpRender`. The engine is untouched; this is a host step above it.
2. **A template set is a flat folder** — the `*.spintax` files beside the current document
   (`.spintax` is the family's extension: the VS Code and Sublime packages already claim it).
   The slug is the filename without its extension, matched **case-insensitively**, which is
   what the engine's own `knownIncludes` check does. No manifest, no nesting, no project file.
   Two files whose slugs differ only in case (`Intro.spintax`, `intro.spintax` — impossible on
   NTFS, arriving via an archive, a clone on a case-sensitive filesystem or CI) are a
   **workspace error**: that slug resolves to nothing and the set says why, rather than
   silently taking whichever the directory listing returned first.
3. **The engine reports the occurrences; Studio substitutes them.** `v0.2.0` gains
   `SpExtractDirectives(src)` — every `#set` / `#def` / `#include` the renderer sees, with its
   source span (`Line`/`Column`/`End*`, same contract as `TSpDiag`), its source text, and for
   `#set`/`#def` its value. Comments are already stripped by the engine, so a commented-out
   include is simply not in the list, and an inline `#include` — which the engine does not
   treat as a directive — is not either. Studio replaces spans **last occurrence first**, so
   earlier offsets stay valid, and owns no scanner of its own.
4. **An occurrence is expanded only if its line has the reference shape** —
   `^[ \t]*#include\s+"([^"]+)"\s*$` against the `Text` the engine reported. The engine
   currently recognises `#include` **wider** than the family reference: `#includes "frag"`,
   `#include"frag"`, `#include "frag" junk`, `#include ""` and `#include "a" "b"` come back as
   includes (and `SpValidate` calls the target unknown), where `spintax-js`, PHP and Python
   render all five as ordinary text; conversely `#include` + newline + `"frag"` is an include
   to the reference and invisible to the engine. That is a long-standing engine defect, not
   corpus-covered and scheduled for its own fix. Until it lands, Studio expanding what the
   engine reports would produce output no other engine in the family produces — so the shape
   check stands between them. It is not a scanner: Studio still never looks for directives,
   it only checks the shape of a line it was handed, and when the engine narrows the check
   becomes a no-op with its tests unchanged. The case the engine misses stays unexpanded, and
   is a known, recorded divergence rather than a silent one.
5. **editor-core never touches the disk.** The set reaches it as an in-memory `slug → text`
   map built by the host from the folder listing. M0 stays verifiable without a filesystem,
   and the flat-folder rule (with its collision check) lives in the loader.
6. **Recursion is bounded**: a depth limit, and a cycle is a slug already on the current
   expansion path (a diamond — the same fragment included twice from different places — is
   fine). An unknown target, a cycle or an over-deep chain leaves the directive verbatim and
   raises a Studio-level note — never a crash, never a hang. The verdict stays the engine's:
   `include.unknown-target` comes from `SpValidate` with the set's slugs as `knownIncludes`.

## Why

- **Otherwise the preview answers the wrong question.** The verbatim output is the engine's
  truth, but a user who typed `#include "intro"` means "the intro belongs here"; a two-pane
  editor whose right pane echoes the directive fails its one job. Every host in the family is
  expected to resolve includes — Studio is the family's GUI host.
- **A folder is the smallest set that works, and it already exists.** Spec §8 wanted
  "several templates whose slugs feed `knownIncludes`"; files in a directory are exactly
  that, with no format to invent, nothing to keep in sync with the filesystem, and "save a
  file" as the way to create a fragment.
- **Case-insensitive slugs are not a free choice.** The engine's check is case-insensitive by
  default and NTFS is too; a case-sensitive resolver would refuse to expand a target that
  validation had just accepted. Which is exactly why a case-collision inside one set has to
  be an error and not a coin toss.
- **One scanner, and now it is actually one.** Spans come from the engine, which already
  owns the comment rule and the five line terminators, and already maps stripped text back to
  source coordinates for `TSpDiag`. `SpExtractDirectives` also settles two other things
  Studio would otherwise reconstruct: the directive prelude for the fragment preview (spec
  §4.2) and the `#set`/`#def` **values** for the variables panel (spec §4.4) — `SpExtract`
  returns names only. One addition to `v0.2.0`, three consumers, no duplicated grammar.

## Consequences

- M0's editor-core gains a resolver seam: expansion runs before `RenderSample`,
  `RenderBatch` and `RenderFragment`, and the set's slugs become the `knownIncludes` passed
  to `HealthReport`.
- **Validation covers the include closure, not just the open document.** Expansion is a
  render-path step, so the document is validated unexpanded — a position inside substituted
  text has nowhere to point in the editor. But a broken bracket or plural inside a fragment
  would then make a document green while the export degrades, so `HealthReport` validates
  every file in the closure **separately, in its own coordinates**, and reports them grouped
  by file. Each pass gets `knownVariables` = runtime variables ∪ every `#set`/`#def` name in
  the closure and `knownIncludes` = the whole set's slugs; without that union a fragment using
  a parent's macro reports a false `variable.undefined` (measured). The verdict is red if any
  file in the closure has an `error`.
- The variables panel (spec §4.4) marks include targets known/unknown from the same set, and
  the spans make "jump to the directive" possible without a second scan.
- An unsaved, untitled document has no folder and therefore no set: its includes stay
  verbatim and the panel says why. That is the one state where the preview shows a raw
  directive.
- Loading a fragment strips a leading UTF-8 BOM; substituting a directive keeps the line
  terminator that followed it and drops the fragment's trailing newlines, so an include does
  not manufacture blank lines.
- **A span can carry a comment with it, and on this path that is harmless.** A comment at the
  head or tail of a directive line stays outside the span; one *inside* the directive is part
  of what the renderer consumed, so the span covers it — and if that comment swallowed the
  line's terminator, the span crosses into the next source line, and replacing it deletes the
  comment. Expansion feeds `SpRender`, which strips comments anyway, and never writes back
  into the editor buffer, so nothing is lost. It is a trap for any later feature that *does*
  write a span replacement into the document (an "inline this include" refactor): that one
  must re-check the span against the buffer first.
- **Raw sentinels split the two views.** The editor-side calls read the source as written,
  while `SpRender` deletes the reserved U+E000–U+E005 before parsing. A document carrying raw
  ones can therefore hold a directive the panel sees and the renderer does not, or the
  reverse. The family's reference diverges in exactly the same way, so Studio does not paper
  over it: foreign text enters a template through `SpNeutralize`, and a raw sentinel in a
  document is a Studio lint (spec §4.3, §7).
- Revisit if nested sets or per-project manifests become a real need — the resolver seam and
  the in-memory set are where they would plug in, and no stored format has to be migrated.
