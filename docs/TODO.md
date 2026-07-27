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
      ([ADR 0003](decisions/0003-include-resolution-and-template-set.md), 2026-07-25, revised
      twice the same day). The family resolves includes **inside render**, behind a host
      callback, with a child scope, lenient empty on unknown target / cycle / depth, and a
      depth cap of 20. `spintax-win` grew that seam in `v0.3.0`, so Studio supplies a
      `TSpIncludeResolver` and expands nothing itself. A set is the flat folder of `*.spintax`
      files beside the document, slug = filename, matched **exactly** — the case-insensitive
      rule this ADR first carried was built on an engine defect, fixed in `v0.2.2`.
- [x] **Target architecture — x86_64** (2026-07-26). Settled by installing Lazarus: its
      bundled FPC 3.2.2 targets `x86_64-win64`, so `lazbuild` produces the Store-shaped
      binary with no cross-compiler juggling. The console suite still builds with whatever
      `fpc` is on PATH (i386 locally, whatever CI has), which is the point of keeping
      editor-core GUI-free.
- [ ] **Thesaurus for the synonym feature** — a local base (which one?) or LLM-only. (M4)
- [ ] **Persistence** — keep the LLM-loop history and generated variant sets between
      sessions, or treat them as session-only. (M4 / M3)

## Milestones (spec §9)

M0 is reused whole; the GUI (M1–M2) and the LLM loop (M4) are independent; M3/M4 order is
interchangeable. **R0 (the first Store release) = M0–M3, offline, no AI** (spec §9); M4 and
the managed tier are later releases.

- [x] **M0 — editor-core (`SpxStudio.pas`).** `RenderSample` / `RenderFragment` /
      `RenderBatch` / `ExtractModel` / `HealthReport` over the engine, plus the template set
      and the resolver built on it. Pure Pascal, GUI- and network-free,
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

      Three more contracts, from measuring the engine and reading the reference on
      2026-07-25:
      - **The set is data, and editor-core does no I/O.** It arrives as an in-memory
        `slug → text` map built by the host from the folder listing, so M0's tests need no
        filesystem, and the same map becomes the resolver handed to the engine.
      - **Validation covers the include closure.** Every file the document pulls in is
        validated separately, in its own coordinates, grouped by file, with `knownIncludes` =
        the set's slugs and `knownVariables` **per the child scope**: a document gets its
        runtime variables, an included file gets those plus its own `#set`/`#def` and *not*
        the parent's, because the parent's macros are genuinely out of scope for it (ADR
        0003). Without the closure a document is green while the export degrades on a broken
        fragment; with the parent's names mixed in, a true `variable.undefined` would be
        silenced. Any `error` anywhere in the closure makes the verdict red. Cache per file
        text: `SpValidate` is still quadratic in `#set`/`#def` count (measured on the
        `v0.3.2` engine: 17.6 / 253 / 3982 ms at 400 / 1600 / 6400 definitions, and paid once
        per file in the closure), so only the edited file may revalidate on a keystroke.
        *Done 2026-07-26* (PR 2): `TSpxValidationCache`, created and owned by the worker and
        handed to `SpxHealthReport`, which without one still validates everything afresh —
        and the report must be identical either way, which the suite checks. Measured where
        only the document changes: a 20-fragment set with 300 definitions each goes from
        **411 ms per keystroke to 14.8 ms**, a 200 KB document from **501 ms to 62 ms**.
        The review of that PR found the cache's container was not byte-exact —
        `TStringList` compares through the OS collation, which calls distinct code points
        equal — so it is a `TDictionary` now, and the closure walk's own lists got
        `UseLocale := False`; that half was a pre-existing defect that made the walk skip a
        real fragment. Both gated, the walk one by a check that fails without the fix.
      - **No include expansion in editor-core.** The set is loaded, its slugs feed
        `knownIncludes`, and a `slug → text` resolver is handed to the engine once the engine
        has the seam — nothing more. No substitution by span, no depth or cycle bookkeeping,
        no shape gate: all of that belongs to the render, and reproducing it host-side
        diverges from the family (ADR 0003).

      **Landed so far** (2026-07-25):

      - *the render path* — `TSpxContext` (locale, runtime variables, template set, RNG mode
        and seed), `SpxContext` / `SpxSeededContext`, `SpxRenderSample`, and `SpxRenderBatch`
        returning `TSpxVariant` records that carry their seed. Control runs: dropping
        `PostProcess := True` fails four checks, and unseeding the batch fails three of the
        four reproduce-from-its-seed checks (the fourth matched by chance on a four-option
        template, which is why there are four).
      - *include resolution through the engine's seam* — `TSpxTemplateSet` (`slug → text`,
        built by the host) and `TSpxSetResolver` over it, handed to
        `TSpContext.IncludeResolver` per render. Pins the semantics Studio's preview claim
        rests on: resolution, exact-case targets, unknown → empty, no set → verbatim, the
        child not seeing the parent's macros but inheriting the runtime context, nesting, a
        cycle unwinding to empty, and a batch resolving and still reproducing from its seed.
        Control run: never passing the resolver fails 8 checks.

      - *the analysis path* — `SpxRenderFragment` (the document's `#set`/`#def` prelude plus
        the selection), `SpxExtractModel` (the variables and includes panel) and
        `SpxHealthReport` (the include closure validated file by file, plus health probes on
        fixed seeds and Studio's own notes with positions). Two review passes before the
        commit found nine defects between them, including `TStringList.IndexOf`'s
        case-insensitive default reintroducing inside Studio the very bug the engine fixed in
        `v0.2.2`; every fix has a control run behind it.

      - **One engine thread, warmed at startup.** The engine's post-process builds a lazy
        global (`GAbbrevs`) with no synchronisation, so two first renders on two threads
        race; and post-process is 0.7 s on a 237 KB template, too slow for the UI thread on
        every debounce. editor-core therefore keeps no state of its own — a single worker can
        own every engine call, "latest wins" (spec §5). The worker itself arrived with M1.

      The suite stood at 101 checks, green in both builds, when M0 closed.
- [ ] **M1 — GUI shell.** Two panes, SynEdit + a spintax highlighter, live preview, bracket
      matching, validity indicator. The DeepL skeleton.

      **Landed so far** (2026-07-26): Lazarus 4.8 installed; `gui/` holds the application —
      `SpintaxStudio.lpr`, `SpxMainForm` (top strip with locale / seed / reroll / copy, a
      SynEdit pane, a preview pane, a status bar) and `SpxEngineThread`. Forms are built in
      code rather than from `.lfm`, so the project builds headless and reviews as text
      (spec §6). `build.sh` builds the app when lazbuild is present and says so when it is
      not; CI grew a Windows leg that installs Lazarus and runs lazbuild.

      The **engine thread** is the part that is logic rather than layout, and it is gated by
      the console suite like everything else: one worker owns every engine call, warms the
      engine's lazy global before the first request, and replaces queued work instead of
      accumulating it. Seven checks, including fifty edits posted faster than fifty renders
      can run — the superseded ones must be dropped, not walked through one stale preview at
      a time.

      **The highlighter landed** (2026-07-26), split the way editor-core is: `src/SpxTokens.pas`
      is a pure line tokenizer with no SynEdit in it, gated by the console suite;
      `gui/SpxSynHighlighter.pas` is the adapter that hands SynEdit one token and a colour.
      Nesting is coloured by depth through four cycling shades, and the between-line state is
      a comment flag, a "logical line still empty" flag and a depth — an integer, not a
      stack, which is what makes unbounded nesting a non-issue and answers ADR 0002's open
      risk. The editor opens on the spintax.net walkthrough (`src/SpxDemo.pas`), which is
      also a test fixture: it must scan balanced, validate clean, render non-empty and vary.

      A review before the commit found six real defects, all now fixed with regression
      checks: a `#set` after a comment that closed mid-line was coloured as a directive
      (confirming a macro the engine never defines), `#set`/`#def` were coloured without
      `%name%` and `=`, `{?1x?…}` and `{??…}` were coloured as conditionals where the engine
      falls through to an enumeration, a config after a space was left uncoloured although
      the engine trims and applies it, the depth cap doubled as the pack mask (raising it
      would have flipped the comment flag), and the adapter never called
      `SetAttributesOnChange`, so a future settings pane would not have repainted.

      A second external review (2026-07-26) found two more, both confirmed by measuring the
      engine rather than by reading: a directive after a comment that opened AND closed on
      its own line was drawn as plain text (the anchor was tried once, before the scan, so a
      line starting with a comment never got a second look), and `#include`'s gap was
      narrower than the family's. Both fixed, with the differential that found them now in
      the suite; the third finding — the build printing one gui/ warning — was the intended
      behaviour and is recorded as a known risk below.

      **Bracket matching landed** (2026-07-26). The rule is `SpxMatchBracket` in
      `src/SpxTokens.pas` — pure, one forward pass, gated by 18 checks including a round
      trip over every bracket in the demo template. It exists because SynEdit's own matcher
      is wrong for this language twice over: it counts parentheses and quotes as brackets
      (ordinary text in spintax — the demo's "(spin syntax)" would sprout a phantom pair),
      and it ignores block comments, so it pairs an opener inside one with a closer outside.
      A mismatched kind is not a pair either: that is `bracket.mismatched`, the validator's
      finding, and the editor does not draw a pair the engine rejects.
      `gui/SpxBracketMarkup.pas` is the adapter — it descends from SynEdit's markup and
      replaces only the pair-finding, so all the painting stays inherited; the built-in
      instance is disabled. **Unverified by me: the highlight itself.** The logic is tested
      and the wiring compiles, but nothing here can see a window — the colours on screen
      need a human eye once.

      **Squiggles landed** (2026-07-26). `SpxDocumentMarks` (editor-core) turns the report
      into spans and `gui/SpxDiagMarkup.pas` draws them: a red wave under an error, amber
      under a warning, on the engine's own positions and under the text, so the highlighter's
      colours survive. Three rules it carries: only the open document is underlined (a
      fragment's positions are coordinates in another buffer), `Line = 0` is not drawn at all
      — the engine admitted it could not locate the finding, and the panel is the honest place
      for it — and `End* = 0` marks one character rather than a guessed extent.

      **The preview became two views** (2026-07-26): «Страница» renders the output as a page
      through `TIpHtmlPanel`, «Исходник» keeps the text-with-tags view. Verbatim in both, and
      the page waits for a click above 16 KB of output because IPro's layout is quadratic —
      [ADR 0004](decisions/0004-html-preview-page-and-source.md), where the numbers are.
      `gui/SpxPreviewPane.pas` owns the switch and the guard; the form just hands it a string.

      Two real bugs fell out of using it. The window closed without the process ending
      (`Application.CreateForm`, not a hand-built form: LCL terminates only for
      `Application.MainForm`), and the app opened on locale `ru` against an English demo,
      which is a genuine `plural.arity` error — it now opens on the demo's language.

      **The document became a file** (2026-07-26), which the milestones did not list and
      half of M2 depends on: `gui/SpxFiles.pas` carries the host's rules — bytes in and out
      with a UTF-8 BOM stripped on read and never written, the file's own line ending and
      trailing terminator preserved, `.spintax` membership, and the slug taken from the name
      exactly as the filesystem spells it. 29 checks against a real temp folder, ending with
      the one that closes the loop: a document that `#include`s a fragment on disk renders it,
      and the same slug in another case does not.

      The menu (Создать / Открыть / Сохранить / Сохранить как / Перечитать набор), the
      unsaved-changes guard, the caption with the file name and a dirty marker, and opening a
      path from the command line came with it. Only the FOLDER crosses the thread boundary —
      the worker owns the set it builds, so no mutable object travels with a job that
      latest-wins may replace, and the directory scan stays off the UI thread.

      Verified in the running app, not only in the suite: a prepared folder opened by path
      renders its fragment inline, the wrong-case include is flagged with a red squiggle and
      a note, and three files (LF, CRLF, and one with no trailing terminator) came back byte
      identical after open + save.

      Still to come: the panels of M2.

- [ ] **M2 — the variables panel is an EDITOR, with a plain ↔ structured toggle**
      (decided 2026-07-26, after studying the spintax.net playground; the reference
      implementation is `W:\projects\spintax.net\src\client\play.ts`, functions
      `parseRawVars` / `serializeVars` / `rowsToPairs` / `setMode` / `combinedTemplate`).

      **What the playground does.** Variables live in a box SEPARATE from the template, in
      two interchangeable views: structured rows `[set|def] [name] [value] [×]`, or a plain
      textarea holding the same `#set`/`#def` lines. Switching flushes one into the other.
      The `#set`/`#def` choice is carried through untouched — rewriting one into the other
      would silently change the semantics (a macro re-rolled at every reference vs a
      definition rolled once per render). At render time the box is prepended to the
      template; its names also go in as `knownVariables` so `%refs%` are not flagged.

      **What we take:** the ergonomics, whole. Editing a macro's value in a row beats
      hunting it inside a long directive line, especially when the value itself is nested
      spintax, and the kind selector puts the `#set`/`#def` difference in front of the user
      instead of leaving it invisible.

      **What we do NOT take: the second buffer.** The playground owns both texts and never
      writes a file. Studio's document is a file on disk that the other engines of the family
      read, so the directives must live IN it. Our structured view is therefore an editor
      OVER the document, not a box beside it — which is affordable exactly because
      `SpExtractDirectives` reports every directive's span, value and consumed line: a row is
      a view of a span, and editing it rewrites that span alone.

      **Two things that must not merge into one list** (the playground has only the first,
      because it has no notion of host-supplied render context):
      - *Definitions* — `#set`/`#def`, text in the document, committed to git, read by other
        engines;
      - *Runtime values* — not in the document at all; they feed `TSpxContext.Vars` and
        `knownVariables` for the preview, and they are per-session.
      A single flat list would teach the user that typing a value edits their file, which is
      true for one group and false for the other.

      **The slice, in order:**
      1. ~~editor-core gains one pure function —~~ *done 2026-07-26 (PR 3), but as FOUR narrow
         ones rather than the single `SpxSetDirective(Kind, Name, Value)` sketched here.*
         Measured reason: the engine reports a macro's name lower-cased and its value
         trimmed, while the span it gives covers the indentation, the keyword's own spelling
         and the spacing around `=`. Re-spelling a line from those three fields would rewrite
         `<TAB>#set  %Brand%=x   ` as `#set %brand% = x` — a formatting change nobody asked
         for, in a file the user keeps in git. So: `SpxSetDirectiveValue` /
         `SpxSetDirectiveName` / `SpxSetDirectiveKind` / `SpxDeleteDirective`, each splicing
         the smallest region that can carry the change, plus `SpxDocOffset` for the position
         mapping. Each refuses (leaving the document untouched) on a bad index, on a change
         that does not fit the kind, on a span whose text the renderer did not consume — which
         is ANY comment inside the directive, because Text is cut from comment-stripped source
         while the span maps back to the source — and, after the review of this PR, on a
         result the engine does not read back as asked: a value carrying `/#` used to open a
         comment that ate the rest of the file, and an empty or spaced name used to turn a
         definition into body text, both reporting success.
         44 checks. Mutation runs confirm they bite — the span guard, code-point columns, the
         value's trailing blanks, the name splice, the deletion widening and the tab handling
         each fail exactly the checks that name them.
      2. ~~the panel: two groups, rows in the playground's shape~~ *done 2026-07-27 (PR 4).*
         The bottom strip became tabbed — Диагностика | Переменные — rather than taking more
         room from the template. Definitions show kind, name and value and jump to their line
         on click; the session group is editable end to end (panel → job → `TSpxContext.Vars`
         → render and `knownVariables`), so a `%name%` with a value stops being reported
         undefined. Every row carries `DirIndex`, the occurrence index the edit functions
         take, and the suite checks that the two orders agree rather than trusting them to.
         The session store is pruned by `SpxKeepRuntime` in editor-core (gated): a value for
         a name the document has since DEFINED would otherwise go on suppressing a warning
         that macro no longer earns.
         **Not done here:** the plain ↔ structured toggle. The playground needs a plain
         textarea because it has no document; ours is the editor on the left, and a second
         editable copy of the same lines is a second source of truth. Revisit only if using
         it proves otherwise.
         **Unverified by me: the panel on screen.** The layout is built in code and compiles,
         the rules behind it are gated, but nothing here can see a window — and raising the
         user's windows at 2am to photograph one is not verification worth having.
      3. write-back goes through SynEdit's own edit API so undo and the caret behave, and the
         panel re-derives from the text after every change (`SpExtractDirectives` is linear).
         Still open, and it is why the definitions group is read-only: assigning a whole new
         document into SynEdit would throw away the undo history and move the caret, which is
         worse than waiting one PR.

      **Measured before it can surprise the panel** (2026-07-26): a directive's `Column` is
      where its CONSUMED text begins, and indentation is part of that — `  #set %a% = 1`
      reports column 1, not 3, while `/# c #/#set %a% = 1` reports 8, because the comment is
      not part of what the directive consumed. Self-consistent, but it means "jump to the
      directive" lands at the line start rather than on the keyword unless the panel adjusts,
      and a span rewrite must not assume the span begins at the `#`.

      **Refuse to guess:** anything not round-trippable — a directive inside a comment,
      spacing the row cannot reproduce — is a read-only row that says "edit in the text".
      Changing `#set` ↔ `#def` is an explicit action with a word about what it changes, never
      a silent normalisation.

      **Risks already named:** two writers over one buffer (the text is the single source of
      truth, the panel is always derived); spans go stale after every edit (re-derive, do not
      cache); the value field holds spintax and will eventually want the same colouring
      (`SpxTokens` can scan a fragment, but that is not M2).

- [x] **Highlighter gap — the per-element trailing separator.** *Done 2026-07-27 (PR 5).*
      `[a<br>|b]`: the engine takes that `<br>` as the separator placed before the next
      element, and it now wears the config colour. The rule was measured through the engine
      rather than read off the grammar, because it is not obvious: `<br>` and `<, >` ARE
      separators while `<br/>`, `<br />`, `</b>` and `<span class="x">` are not — the HTML
      guard trips on a leading or trailing slash, or a tag name followed by whitespace. So is
      position: before the closing bracket it belongs to the last element and stays text, only
      the last one in an element counts, and inside a brace group the pipe is not a
      permutation boundary at all.
      **Known gap, pinned by a check:** a permutation opened on an EARLIER line does not get
      the colour. Telling "directly inside a permutation" from "inside a group" needs the
      kinds of the open brackets, and what crosses a line is a depth — an integer, not a
      stack, which is what makes deep nesting free. Kinds are tracked for one line only.
- [ ] **Highlighter gap — an include target on the following line.** The family's anchor
      allows `[ \t\n\r\f\x0B]+` between `#include` and its target, so the target may begin on
      the next line; measured, the engine reports `include(frag)` for `#include`+LF+`"frag"`.
      The scanner colours only the same-line members (space, tab, VT, FF) and leaves the rest
      plain, because painting the keyword would mean claiming a directive before knowing
      whether a quoted target ever arrives — a wrong colour, which is the worse error here.
      Closing it needs a continuation flag in `TSpxScanState` (bit 18 is free) and a rule for
      un-painting when the target never comes. Pinned by
      `scan/include-target-on-the-next-line-is-a-known-gap`.
- [ ] **Known dependency risk — `SynEditWrappedView` is marked experimental** by Lazarus, and
      `TLazSynEditLineWrapPlugin` comes from it. The build prints that warning on every run on
      purpose: it is the one gui/ warning there is, it is true, and hiding it would hide the
      day the API changes. Revisit if wrapping ever misbehaves after a Lazarus upgrade.
- [ ] **M2 — panels.** *The diagnostics half landed 2026-07-26* (PR 1 of the M2 plan):
      `SpxPanelRows` turns a report into lines — the document first, then each included file
      in walk order, by position inside a file with the unlocated findings last — and every
      row says whose finding it is, the engine's verdict or Studio's note. Wording for the
      engine's seventeen codes was read off the sites that emit them, and an unknown code
      shows as itself so a newer engine cannot vanish from the panel. The window lists them
      under the editor; a click jumps, and a finding in an included file OPENS that file
      through the same unsaved-changes guard as the menu.

      Two things the live run taught, both now settled: the engine's columns are code points
      while SynEdit's logical ones are bytes (spec §7 — the jump landed thirteen characters
      early on a Cyrillic line, and the squiggles had the same defect), and a `%имя%` in
      Cyrillic is not a variable to anyone — the engine does not warn about it and the
      tokenizer does not colour it, so a fixture that used one was measuring nothing.

      Still open here: keyboard navigation of the list (the jump is on click, so Up/Down does
      not move the caret — belongs with the hotkeys slice), and colouring rows by severity.

      And one staleness worth knowing before it confuses somebody: a row's position comes
      from the worker's cached set, re-read only on open, save and «Перечитать набор», while
      the jump opens the file from DISK. If a fragment changed under Studio, the row can point
      past the new file's end; SynEdit clamps to the last line, so the landing is silently
      wrong rather than loud. The honest fix is to re-read the set when the window regains
      focus, which is its own slice.

      *The rest of M2 landed 2026-07-27 (PR 6):* a selection previews on its own, in the
      document's scope, with the rule that **only the preview narrows** — diagnostics, marks,
      panels and the status bar keep describing the whole file, gated by a check where the
      error outside the selection still counts. Select-and-wrap goes through SynEdit's own
      edit path (one undo step, verified), refuses column and line selections — where
      `SelText` round-trips column-wise and would swallow text nobody selected — and restores
      the block afterwards, without which a second wrap was a silent no-op. Hotkeys live in a
      «Правка» menu; two shortcut decisions are recorded in the code: the brace wrap avoids
      Ctrl+Shift+B because that is `ecMatchBracket`, and Ctrl+Shift+C is deliberately taken
      from `ecColumnSelect`.

      Left as notes, not code: Copy now copies the FRAGMENT while a selection is active
      (it matches what is on screen, but it is new behaviour for an old button); and
      `Partial` does double duty in the worker as both the report flag and the branch
      selector, so the suite cannot tell those two apart.

      Variables (`SpExtract` + `SpExtractDirectives` for the values),
      diagnostics (`SpValidate`) with squiggles and jump-to-error driven by `TSpDiag`
      positions (engine ≥ `v0.2.0` — bumped in Pre-M0, not here), partial preview of a
      selection, select-and-wrap, hotkeys on every key action. Studio's own lints surface
      here too, labelled as ours rather than the engine's: a raw U+E000–U+E005 sentinel in
      the document, an include cycle, a depth-limit hit, a slug collision in the set, and an
      `#include` the engine accepts but the family reference renders as text.
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

## Reported to the engine, and closed

- [x] **`[<li>one</li>|…]` was taken as a permutation config** — reported 2026-07-26 from
      Studio's highlighter, fixed the same day in engine `v0.3.3`, and the tokenizer followed.
      The engine now carries the family's `looksLikeHtmlStartTag` guard and gates the key
      form on `(?:minsize|maxsize|sep|lastsep)\s*=` rather than a substring, which also
      closed two traps Studio had never seen: `[<separator>a|b]` lost its separator word to a
      `sep` substring match, and `[<xminsize=2>a|b]` executed a `minsize` the template never
      wrote. `SpxTokens` ports both rules plus the quote-aware `>` scan, with nine cases
      measured against the engine before being pinned.

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
- Reserved sentinels U+E000–U+E005 are the engine's. `SpRender` deletes them before parsing
  while `SpExtract` / `SpValidate` / `SpExtractDirectives` read the source as written, so a
  raw one in a document makes the panel and the preview tell different stories — the family
  reference included. Data-derived values go in through `SpNeutralize`; the template itself is
  author content and is never auto-shielded.

## Done

- [x] Repository bootstrapped; the spec homed as the source of truth (2026-07-23).
- [x] Engine wired in as a submodule at `engine/`, pinned to `v0.1.0` (2026-07-23).
- [x] The two gating decisions settled — Lazarus/LCL and submodule — recorded as ADRs
      0002 and 0001 (2026-07-23).
- [x] **Engine bumped to `v0.3.3`** (2026-07-26). The permutation-config gate: a leading
      HTML start tag stays content, and the key form is chosen by
      `(?:minsize|maxsize|sep|lastsep)\s*=` rather than a substring — which also closed
      `[<separator>a|b]` losing its separator word and `[<xminsize=2>a|b]` executing a config
      the template never wrote. No public API moved. `SpxTokens` ports all three rules
      (guard, key test, quote-aware `>`); a 187-case differential against the engine agrees
      everywhere, and the one documented gap — a permutation whose closing tag is on a later
      line — was measured rather than assumed. Corpus grew to 204 cases, engine 200/0/4.
- [x] **Engine bumped to `v0.3.2`** (2026-07-26). Three fixes land, two of them visible
      through calls Studio makes and now pinned as baseline tripwires: an include match that
      spans line terminators no longer leaves a **phantom second include** for the closure
      walk to chase, and a CRLF-terminated include no longer reports a span that crosses into
      the next line with a stray `CR` in `Text` — the panel points at those positions and the
      fragment prelude re-emits that text. The third closed the directive-value rtrim
      divergence, so the spec's "shown as reported, we do not normalise" note keeps its rule
      and loses its caveat. **Most paths went linear** — but not the one that mattered: a
      later measurement found `SpValidate` still quadratic on a `#set`/`#def`-heavy document
      (17.6 / 253 / 3982 ms at 400 / 1600 / 6400 definitions), which is the engine's own open
      item. So debounce stays load-bearing and the caller-side cache stays worth doing.
- [x] **Engine bumped to `v0.3.0`, and `#include` resolution is wired** (2026-07-25). The
      engine grew the family's resolver seam ([engine ADR 0004](../engine/docs/decisions/0004-include-resolver-seam.md)):
      `TSpContext.IncludeResolver`, an abstract class the host subclasses, plus
      `MaxIncludeDepth` where 0 selects the family's 20. Studio's side is `TSpxTemplateSet`
      and `TSpxSetResolver` — the lookup and nothing else. The same tag range also made
      target comparison **exact** (`v0.2.2`), which reversed this project's slug rule: it had
      been written case-insensitive on the strength of a `TStringList.IndexOf` default that
      was itself the defect. Studio now matches slugs against its own map and never through a
      file open, because on NTFS the filesystem would resolve the wrong case and the preview
      would disagree with every other engine about the same document.
- [x] **Engine bumped to `v0.2.1`** (2026-07-25). `#include` is recognised the way the rest
      of the family recognises it: five shapes the engine used to accept as includes are
      plain text again, and since `include.unknown-target` is an `error` that was a
      verdict-level parity defect. **Studio's minimum engine is now `v0.2.1`** — on `v0.2.0`
      the diagnostics panel would redden templates the family calls valid. All 14
      `studio_tests` checks passed unchanged across the bump, which is exactly what the
      baseline tripwires are for. The tag also surfaced an engine divergence Studio must not
      compensate for: directive values are right-trimmed with PHP's charset (VT and NUL
      included) where the reference strips only spaces, tabs and one `\r`, so the variables
      panel and the prelude take `TSpDirective.Value` verbatim (spec §7).
- [x] **Pre-M0 (b) — the scaffolding is in, and it gates** (2026-07-25). `build.sh` (clean
      unit cache, an optimised build and a `-Co -Cr` checked one, a clear error when
      `engine/` is empty), CI on ubuntu + windows with `submodules: recursive` plus a
      shellcheck job, `.gitignore` for the extensionless fpc targets, and the
      `quality-pascal` chain with both git hooks installed — the whole deployment recorded
      in `.agents/REGISTRY.md`, including why the gate now resolves `fpc` itself (it had
      been silently skipping the compile step on this machine) and why Studio runs no
      corpus step.

      The first Pascal came with it, kept to what makes the gate real rather than to M0's
      surface: `src/SpxStudio.pas` carries `SpxInitHost` (the codepage duty, spec §7), and
      `tests/studio_tests.dpr` holds 14 checks — the host contract (codepage, Cyrillic
      round-trip, `PostProcess` default and effect) plus tripwires on the engine baseline
      the submodule pin is supposed to provide (diagnostic positions, `SpExtractDirectives`,
      the four-argument `SpValidate`, and `#include` still rendering verbatim, which is what
      the preview relies on until the resolver seam lands). Green in both builds.
- [x] **Pre-M0 — engine `v0.2.0` released and the submodule bumped** (2026-07-25). `engine/`
      moved off `v0.1.0` to the tag carrying `TSpDiag` positions and `SpExtractDirectives`;
      the pinned tree compiles clean under `-Sew -vm4046` for `i386-win32`. M0 can be written
      against both additions.
- [x] **ADR 0003 revised the same day it was written** (2026-07-25): the resolver moved from
      Studio into the engine. Reading `@spintax/core` (`internal/render.ts:91,106`) and the
      Python port (`_render.py:603`) after the first version showed the family resolves
      includes inside render behind a host callback, with a child scope that excludes the
      parent's `#set`, lenient empty on unknown/cycle/depth, cycles by ref string and
      `maxDepth` 20 — none of which a text-level pre-pass can reproduce, and one of which
      (child scope) had already produced a wrong `knownVariables` rule here. Studio's span
      substitution, shape gate, depth and cycle rules were dropped with it.
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
