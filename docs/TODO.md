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
      at `engine/`, pinned to tag `v0.3.3`. Clone with `--recurse-submodules`.
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

## What R0 still needs (re-checked 2026-08-02)

The product scope is closed: M0, M1, M2 and M3 are complete. The built-in help and About box
are part of the application, and the current release is deliberately **Windows-only,
offline-only and without generative AI**. The remaining work is submission preparation, not
another product milestone:

1. **Run the release gate on the exact candidate.** Build the checked and optimised suites,
   build the x64 GUI, regenerate the About unit, run the full suite, pack MSIX, validate it,
   install it in a clean test profile and exercise the primary path: open, edit, diagnose,
   preview, generate, export, help and About.
2. **Finish the Partner Center draft.** Verify the reserved package identity against the
   generated manifest, choose the category and age rating, provide the Store listing from
   [`store-listing.md`](store-listing.md), add screenshots and publish the hosted privacy
   policy URL. These are account and content tasks, not code tasks.
3. **Run Windows App Certification Kit (WACK)** against the release package. **Done
   2026-08-03:** the exact MSIX candidate passes WACK with no partial run. The optional
   blocked-executable test reports the deliberate browser launch and SynEdit's `&reg;`
   entity string; see [`release-validation.md`](release-validation.md).
4. **Keep the accessibility declaration off for R0.** Keyboard access, high contrast and
   hints are useful improvements, but `docs/accessibility-baseline.txt` shows that the main
   editor text and diagnostic controls are absent from the UI Automation tree. The declaration
   would therefore overstate the tested experience. UIA text support for SynEdit is a post-R0
   slice, not a release blocker.

Not R0: M4 and the managed AI tier, a thesaurus, persistence for the LLM loop, the other help
languages, RTL, the mini-context strip, the help silence whitelist, and the rename refactor.
The empty-panel links and the `spx-good` examples remain worthwhile post-R0 help work, but they
must not reopen the release scope.

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
- [x] **M1 — GUI shell** *(closed 2026-07-30 on re-reading it: every part of the milestone is
      in, and its own last line named the only thing outstanding — "the panels of M2" — which
      landed. The box was simply never ticked.)* Two panes, SynEdit + a spintax highlighter,
      live preview, bracket matching, validity indicator. The DeepL skeleton.

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

      **The source view got its markup coloured** (2026-07-28), which turned into two more
      findings. SynEdit's HTML highlighter opens a tag at every `<`, so one `Цена < 100` in
      the output colours the paragraph after it as attributes and swallows the real `</p>`;
      the rule the family follows lives in `src/SpxHtmlScan.pas` and `gui/SpxSourceMarkup.pas`
      paints those runs back — the tokenizer is private and forking 2600 lines of LCL for a
      colour is not worth it ([ADR 0006](decisions/0006-paint-over-the-html-highlighter.md)).
      **The rule is gated; the painting is not.** The 16 scanner checks run in the suite, but
      the overlay itself was verified by pixel probe, the same standing gap as the bracket
      highlighting above — nothing in the suite can see a window.
      And the wrap plugin costs the square of a line's length — 14.5 s for one line of 1 MB,
      while the same text unwrapped is 16 ms — so past 32 KB on a line the view is rebuilt
      without it and scrolls sideways. It has to be REBUILT: the plugin cannot be taken off a
      live editor, freeing it access-violates and detaching it leaves a dead line-mapping view.

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

      The panels of M2 landed below; this historical shell entry is closed.

- [x] **M2 — the variables panel is an EDITOR** *(closed 2026-07-30 in the shape we chose,
      which is NOT the title's: the plain ↔ structured toggle was declined — see step 2 — and
      editing the name, the kind and delete were closed by decision, one of them because it
      would break the document. What shipped: the value edited in its row, the session half,
      the include group, click-to-jump and Ctrl+click to define.)* With a plain ↔ structured
      toggle
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

      **The session half became usable, 2026-07-30.** Three things, all reported or asked for
      by the user:

      - **A session value could not be typed.** Each character replaced the last — `[V]`,
        `[u]`, `[l]` — because the value was part of `SetModel`'s signature, so the render it
        triggered rebuilt the grid and tore down the cell editor, and the next key started a
        fresh edit. The user read it as "an illusory chance to edit them". A session row's value
        is out of the signature now; names still count.
      - **Clicking a name jumps to its first use**, via the HIGHLIGHTER'S scanner rather than a
        string search: `%name%` inside a comment or as an `#include` target is not a reference.
        Session rows carry no position of their own — `SpExtract` answers names without them —
        so the panel asks by name and the window finds the place.
      - **Ctrl+click writes `#set %name% = {value}` into the document** and opens the group
        editor on it, carrying the session value in as the first option. **This is the first
        time the panel writes through to the file**, which is the direction this whole M2 item
        is going: one undo step, through SynEdit's own edit API. The shape was measured —
        `{value|}` renders nothing half the time, a bare value gives the group editor nothing to
        edit.

      Names are shown as the DOCUMENT spells them in both groups now (the engine folds them),
      from the same single scan.

      **The include group landed 2026-07-30**, and spec §4.4 asked for it from the start: the
      targets the document names, each marked with whether the set has it. It was not "half
      drawn" before — the worker did not carry `Includes` to the GUI at all, so the branch of
      data did not exist.

      **Three states, not two, and the third is why.** `Known` is False both for a fragment the
      set does not have and for a document with no set to look in — a new file has no folder
      beside it — so a two-state mark would tell that user MISSING about a question nobody has
      asked yet. The worker answers "was there a set" from `FSet`, because it is the only thing
      that knows. Measured on all four states: no includes → the group is not there; includes
      with no set → both rows say "no set"; a set where `frag.spintax` exists and
      `gone.spintax` does not → "yes" and "MISSING"; a click → the caret at the `#include` that
      names it.

      **The group comes and goes** rather than standing empty: most documents include nothing,
      and a third permanently blank table would take room from the two that always have
      something to say. Its splitter hides with it — a drag handle for an invisible panel is a
      line drawn across the window.

      Read-only, and it stays that way: an include's target is a slug the SET owns, and renaming
      it would have to rename a file, which is not an edit this panel may make.

      **A jump says where it landed** (2026-07-30, the user's call over a gesture for opening
      the group editor — the gesture would have cost the double-click that select-and-wrap
      needs). SynEdit's own current-line highlight, given a colour for 900 ms and then cleared:
      that buys the full row width, which a markup cannot, because a markup colours text.

      It lives in `JumpToPos`, the single funnel every jump goes through, so DIAGNOSTICS rows
      got it too — the user noticed that before I did. The three layers coexist, measured on the
      pixels: the engine's wave is a FRAME so it never fights a background, the selection holds
      its own span (`clHighlight` inside, the wash outside), and the rest of the document is
      untouched. **The one carve-out is stepping through search matches**, which repeats — the
      timer would re-arm and the wash would stop meaning "just arrived".

      Its first version armed the colour after moving the caret, which left a wash on every
      line visited: the markup only adopts a new line from a caret change that happens while
      the highlight is LIVE (`syneditmarkupspecialline.pp:228` early-exits otherwise). Arm
      first, and repaint the whole editor when clearing rather than trusting a line number.

      **Still open, and it is the bulk of this item:** editing a DEFINITION's value in its row.
      That needs the span rewriting (`SpExtractDirectives` reports every span) plus the plain ↔
      structured toggle above.

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
      3. ~~write-back goes through SynEdit's own edit API so undo and the caret behave~~
         *the VALUE landed 2026-07-30. The name, the kind and delete are **closed, not
         deferred** — the user's call, and one of them by measurement.*

         **Why the panel stops at the value.** Three paths already write a definition, and one
         of them is better than a grid cell at the common case:
         - the TEXT itself, with highlighting, bracket matching and full undo;
         - **click the row → jump → edit in place**, which is the pain this item named as its
           reason ("hunting the macro inside a long line") and which the jump already solved;
         - **the group editor** — and a definition's value usually IS a group
           (`{hundreds|thousands|millions}`), which it edits one variant per line, with the kind
           switch and a permutation's config. A one-line cell cannot do that.

         The value edit stays because it is the quickest path for a value that is NOT a group,
         and it is built and gated. The other three would each add a second way to write the
         file for something the editor does trivially — and one of them is worse than that:

         **Renaming from a cell would break the document, measured.**
         `#set %brand% = {Акме|Вулкан}` with two `%brand%` references: after
         `SpxSetDirectiveName(0, 'company')` the verdict goes from clean to
         `variable.undefined` and the render prints `%brand%` literally, because the references
         keep the old name. `SpxSetDirectiveName` renames the DEFINITION and nothing else, and
         the hazard is now written at its declaration.

- [ ] **(idea, not planned) Rename a macro WITH its references.** What the cell edit above must
      not pretend to be. It needs every `%name%` occurrence, and the engine reports reference
      names without positions — so it needs the highlighter's scanner, which the jump and the
      name-spelling already use for exactly this. Worth doing only if renaming turns out to be
      something people actually do here; a find-and-replace in the editor covers it until then.

         What unblocked it: `SpxSetDirectiveValue` gained an overload reporting the REGION it
         replaced (half-open, the pair `Splice` takes and the one the group editor's write-back
         already spoke), so the window applies a span through `TextBetweenPoints` instead of
         assigning a whole new `Text` — which is what would have thrown the undo history away
         and moved the caret. Measured: one Ctrl+Z restores exactly, and a value edit leaves the
         indentation, the doubled spaces, the name's own case and a trailing comment untouched.
         In EDITOR coordinates, not `DocText`'s: `DocText` normalises to the file's EOL, while
         the offsets have to be the ones `OffsetToPoint` walks.

         **Four LCL facts this cost, each measured before it was believed:**
         - per-column read-only needs the `Columns` collection, so the gate is `OnSelectEditor`
           nil'ing the editor for the other two columns — adding `Columns` here would walk back
           into the documented FixedCols shift;
         - `OnEditingDone` fires BEFORE the grid copies the editor's text into the cell, so a
           handler reading `Cells` there sees the old value and does nothing. `OnValidateEntry`
           is the hook built for it, and a value written back into `NewValue` becomes the cell —
           which is the revert-on-refusal for free;
         - `goAlwaysShowEditor` is wrong for a FILE edit: validation happens when the editor
           hides, so with it always open Enter committed nothing. It is also a text box standing
           open on every row of a grid that rewrites the document;
         - **LCL's cell editor has no `VK_RETURN` case at all** (grids.pas:10663) and
           `EditorHide` never validates — only a selection MOVE does. So Enter is hooked on the
           editor and commits through the panel's own single commit path. Escape still abandons,
           because that case LCL does have.

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
- [x] **The construct shows itself when the caret steps onto a bracket** (2026-07-30, the
      user's request, GTW's trick). Not only the pair -- every separator the construct has, and
      none belonging to a nested one.

      DEPTH is what tells them apart, and the scanner already reports it: an opener carries the
      level it CREATES and everything inside carries that level, so a separator of this construct
      has the opener's depth and one inside a nested group has more. Measured on `{a|{x|y}|c}`:
      the outer pipes are depth 1, the inner one depth 2. That makes the filter exact and blind
      to KIND -- a conditional's flag, a plural's count and a permutation's config are skipped for
      free, because none of them is a separator token. Fourteen checks in the console suite
      (`SpxSeparatorsOf`, src/SpxTokens.pas, where every structural question in this project goes).

      A permutation's trailing `<br>` IS marked: the engine reads it as the separator placed
      before the next element, which is why the highlighter already paints it as config.

      **The mark is BRAND MAGENTA in both themes** (2026-07-30, the user's call after seeing the
      dark one). The first version used a neutral grey on dark, `#404040` against a `#1E1E1E`
      page: a uniform lift of 34 on every channel, which the user read as "practically
      invisible" — and rightly, because a neutral differs from a neutral only in LIGHTNESS, which
      the eye is worst at. A hue does what a shade could not.

      **The brand's tokens live in the OTHER repo**, `W:/Projects/spintax.net/static/css/theme.css`,
      and the magenta family is the four values `--magenta-900 #6e0c38`, `--magenta-700 #a91455`,
      `--magenta-500 #cc2070`, `--magenta-300 #e04090`. Written down here so a later colour
      decision does not need that checkout open. The site's own pairing is instructive: it puts
      `magenta-300` on dark and `magenta-700` on light, but as a FOREGROUND — its docs colour
      variables and conditionals with it. A fill behind text wants the other end, so dark takes
      `magenta-900` and light a soft tint of `magenta-500` built the way the site builds
      `--accent-soft`: a percentage of the hue rather than a colour chosen beside it.
      Measured: dark `#6E0C38` on `#1E1E1E` lifts 80/18/26, light `#F4CEE0` on white lifts
      11/49/31.

      **The light theme gained a real bracket background** as part of this. SynEdit's bracket
      markup defaults to bolding the character and nothing else, and the palette left
      `BracketBack` at `clNone` -- a bold `|` on white is not a highlight, so the feature would
      have been invisible in the default theme. Pale yellow, distinct from the selection's blue
      and from the jump flash's pale blue.

      **Measured by asking the markup, not by reading pixels.** Two pixel attempts read the wrong
      thing -- a background the light theme did not paint, then something uniform above the text
      -- while `GetMarkupAttributeAtRowCol` is public, is the exact contract SynEdit paints from,
      and cannot be misread. Caret away from a bracket: nothing marked. On the outer brace:
      1, 3, 5, 11. On the inner: 6, 8, 10.

- [x] **The definition jump lands on the keyword** (2026-07-30). A directive's reported `Column`
      is where its CONSUMED text begins and the indentation is part of that, so a jump to it put
      the caret in the margin and left the eye to find the `#set` the row was clicked for. Blanks
      are skipped forward, and only blanks can be there: a comment is not consumed, so
      `/# c #/#set` already reports the `#` itself. Six checks, code points not bytes.

- [ ] **Highlighter gap — an include target on the following line.** The family's anchor
      allows `[ \t\n\r\f\x0B]+` between `#include` and its target, so the target may begin on
      the next line; measured, the engine reports `include(frag)` for `#include`+LF+`"frag"`.
      The scanner colours only the same-line members (space, tab, VT, FF) and leaves the rest
      plain, because painting the keyword would mean claiming a directive before knowing
      whether a quoted target ever arrives — a wrong colour, which is the worse error here.
      Closing it needs a continuation flag in `TSpxScanState` (bit 18 is free) and a rule for
      un-painting when the target never comes. Pinned by
      `scan/include-target-on-the-next-line-is-a-known-gap`.
- [x] **Layout that survives a resize** (2026-07-27). Rules this project follows, each of them
      paid for by something that actually looked broken:
      - **a control that paints its own content must be repainted when it grows.**
        `TIpHtmlCustomPanel.EraseBackground` is deliberately empty and it has no resize
        handler, so the band exposed by dragging the splitter kept its old pixels — a grey
        stripe standing between the panes. The pane invalidates the page and its internal
        child on `Resize`; a parent's invalidation does not reach a clipped child;
      - **the last column takes what the fixed ones leave.** A width in pixels is right at
        exactly one window size: narrower it hides the text behind a scrollbar, wider it ends
        in a dead strip. Both the diagnostics list and the two variable grids recompute it;
      - **proportions, not pixel counts, for the initial split.** The editor starts at 48% of
        the client width rather than at the 540 px that suited the window this was written on;
      - **AutoSize for a label whose caption changes**, or it is sized for one wording and
        clips the other;
      - **constraints on the form**, so the panes cannot be squeezed into nonsense.
      **Unverified by me: the stripe itself.** The diagnosis is from IPro's sources, and the
      fix targets exactly that — but this machine's window would not take a programmatic
      resize or splitter drag, so the confirmation is a human dragging the splitter left.
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

      Both of the things that stood open here are closed. Keyboard navigation landed as
      `DiagKeyUp`: the arrows step and jump without taking the focus, Enter and Space mean the
      same as a click and hand it over. Severity landed as an ICON rather than a row colour
      (`EnsureSevIcons`) — three shapes as well as three colours, with the word still in the
      Level column, because colouring the rows would have meant owner-drawing the list and the
      locale box next door had already measured what that costs a screen reader.

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

      *Followed by PR 7*, which moved the two rules that were living in the form under the
      suite: `SpxPreviewFragment` (which selections narrow the preview, and what a jump's
      selection becomes) and `SpxWrapRange` (whether a selection may be wrapped and where the
      wrapped text ends up). Both take editor-core's own `TSpxPos`/`TSpxRange`/`TSpxSelKind`
      rather than `TPoint` and `TSynSelectionMode` — the form adapts SynEdit into them and
      back, and keeps only the edit itself, because `SelText :=` IS SynEdit's edit API and is
      what holds undo to one step. What remains untested in `gui/` is layout and wiring; the
      arithmetic and the policy are gated, including the "select the same span by hand after
      a jump" case an external review found.

      Variables (`SpExtract` + `SpExtractDirectives` for the values),
      diagnostics (`SpValidate`) with squiggles and jump-to-error driven by `TSpDiag`
      positions (engine ≥ `v0.2.0` — bumped in Pre-M0, not here), partial preview of a
      selection, select-and-wrap, hotkeys on every key action. Studio's own lints surface
      here too, labelled as ours rather than the engine's: a raw U+E000–U+E005 sentinel in
      the document, an include cycle, a depth-limit hit, a slug collision in the set, and an
      `#include` the engine accepts but the family reference renders as text.
- [x] **M3 — export** (2026-07-28, PRs #10–#12). Generate N with distinct seeds, shingle
      dedup, `.xlsx` / `.txt` / per-file.

      `src/SpxDedupe.pas` — shingles, the overlap measure, the retry budget and the
      requested/generated/dropped/tried report; the threshold default is measured rather
      than borrowed (0.75, in the band between a varied template's 0.56 and a one-word
      spin's 0.79). `src/SpxExport.pas` — the three writers, with `.xlsx` written directly
      as minimal OpenXML over the RTL's `zipper` ([ADR 0005](decisions/0005-xlsx-minimal-openxml.md)).
      `gui/SpxVariantsPane.pas` + the batch mode on the engine worker — **a batch is a long
      job, not a call**: up to N + 2N renders (measured 61 s at N = 200), so it runs on the
      one engine thread ONE VARIANT PER TURN, with the interactive queue checked between
      renders, progress per variant and a cancel that is answered by the next step.

      Still open, from the GTW notes above: the count of possible variants and a length
      filter on generation.
- [ ] **M4 — LLM loop.** `TLlmProvider` + adapters + `TAuthoringLoop` (Generate / Verify /
      Fix), the authoring-prompt as system, a local model via localhost, synonyms through
      the same layer. Keys local, zero telemetry.

      Its icon is already in the sprite: `SPX_ICON_AI` (`robot-outline`), put there on
      2026-07-29 at the user's request so the choice is made calmly rather than in the hour
      the feature lands. Nothing draws it yet.

## UX plan, agreed 2026-07-28

The reference is DeepL (spec §3), and what is worth taking from it is its discipline rather
than its palette: ONE row above the panes describing the transformation, per-pane actions at
that pane's own bottom edge as icons, no frames, equal panes.

Order, and it is an order rather than a list — each step would otherwise be redone by the
next:

- [x] **1. DPI and the system font** (2026-07-28). The app was not DPI-aware at all: no
      manifest, so `Application.Scaled` had nothing to work with and Windows would have
      stretched the window as a bitmap above 100%. `Cascadia Mono` now, at the size the
      system reports, and every length goes through `Px()` (`gui/SpxUi.pas`).
- [ ] **2. The chrome, rearranged.** `Copy` belongs at the bottom-right of the pane whose
      text it copies, not in the top strip beside `Reroll` -- that row is about HOW to
      render, and mixing "what to do with the result" into it is what makes it read as a
      developer's toolbar. One language for every caption while we are there.

      **Partly done 2026-07-29** (the user's call: "a modern toggle for the right pane's
      modes, and consider icons instead of buttons"). The two radio buttons became one
      segmented switch (`gui/SpxSegmented.pas`): a view mode is ONE setting with two
      positions, not two settings that happen to be linked, and the control measures its own
      captions so no language can clip them -- the radios each had a fixed 90 px slot.
      `Reroll` and `Copy` became icon buttons with their captions as tooltips, which returned
      about 100 px to a strip that already spills the search field onto a second row at
      820 px wide. Measured across all fourteen languages at 1100 px: one row, nothing
      overlapping, the switch asking for 158–192 px.

      **The bottom tab strip is gone too** (2026-07-29, decided on numbers rather than taste).
      It cost 28 px — 3.6% of the window — and was the only source of three things: which
      panel is current, the keyboard route to the other two, and their names. Removing it for
      the 28 px alone would have been a bad trade; what made it worth doing is that the rail
      had to grow STATE to replace it, and a rail with state can collapse the block entirely:
      the editor goes from 475 to 720 px, +52%, where dragging the splitter stops at its 80 px
      floor. A second click on the lit tool is the collapse (the user's call over a menu-only
      version); the View menu carries the three names and the keyboard route, and with the
      block collapsed none of them is ticked.

      **The strip's last two controls, 2026-07-30.** The locale selector kept a native combo
      (chrome stays system-drawn) but its LIST is drawn by hand: `en — English` in the dropdown,
      the bare tag in the closed box, all ten locales visible instead of eight with a scrollbar.
      Flags were considered and refused — they already mean the INTERFACE's language in this
      window's menu, this is the DOCUMENT's, and a flag is a country while `en` is not.
      Search gained the icon it never had (it was reachable only by Ctrl+F, i.e. only by people
      who already knew), its close/prev/next became sprite icons at one width, and the bar now
      ends where the EDITOR does rather than where the output's controls begin — its close
      button used to sit over the preview. Below the bar's own minimum the editor cannot hold
      it, and it overflows rather than hiding the match counter: measured at a 30% editor, the
      second row and 114 px past the edge.

      **What is still open here is the move itself:** `Copy` is smaller now but still in the
      top strip. Putting it at the preview pane's own bottom edge needs that pane to grow an
      action row, which is the part of this step nobody has built yet.
- [x] **3. The tool rail — slide-out, and on the side of what it edits** *(closed 2026-07-30:
      built, with the side as a remembered setting and a second click collapsing the block.)* DeepL's column
      holds tools that change the OUTPUT and sits beside the output. Ours would hold
      variables and the group editor, which change the TEMPLATE — so it belongs on the LEFT,
      beside the editor. The side is a setting (the user's call, 2026-07-28), which is cheap
      as long as the layout is built from an alignment constant rather than a hardcoded
      `alRight`.

      Its content is NOT DeepL's geometry: their column is a menu of switches 280 px wide,
      ours would hold tables (diagnostics, variables, the variant list). A table in a 280 px
      column is unreadable, so the rail is the ACCESS -- icons, always in reach -- and the
      workspace stays where the data fits. A panel that is genuinely narrow by nature (the
      group editor is a list of variants, one per line) can live in the rail itself.
- [x] **4. Icons — from Material Design Icons** (pictogrammers.com/library/mdi, the user's
      call 2026-07-29). Done 2026-07-29: the MDI control glyphs plus the two project-drawn
      help/action cells in a sprite (`scripts/make-icons.py` → `gui/SpxIcons.pas`), fourteen Twemoji flags in the language
      menu (`scripts/make-flags.py` → `gui/SpxFlags.pas`), and the brand mark as the app icon
      (`scripts/make-appicon.py` → `gui/SpxAppIcon.res`, its own resource because lazbuild
      rewrites the project's). The rail's geometry did not move; the faces lost their letters,
      so a language now changes only a tooltip.

      What it settled on the way: the size is CHOSEN from the strips, never scaled, and
      re-chosen from the FORM's AutoAdjustLayout — a window is built at 96 dpi and told its
      monitor's afterwards, and LCL assigns the new PixelsPerInch after walking the children,
      so a child's own hook is one step behind. NOTICE.md now carries the attributions (MDI
      Apache-2.0, Twemoji CC-BY 4.0) and records why the LGPL of LCL/RTL does not reach an MIT
      binary.

      Left over, both small: the **About box** does not exist yet, and it is where those two
      credits have to be readable by a user rather than by an auditor; and the app icon tops
      out at **128 px** because 180 is the largest raster spintax.net publishes — a 256 for
      Explorer's largest view and the Store tiles wants a vector export from the brand
      (`assets/brand/spintax-mark.svg` is kept for it), not an upscale of ours.

- [x] **5. The editor's font is the editor's, not the desktop's** (2026-07-29, the user's
      specification). The chrome keeps the system font — that rule does not move. The editors
      are the exception twice: the FAMILY, because a template is markup and markup wants a
      fixed pitch, and the SIZE, because a desktop configured at 9 pt was configured for
      captions. Default 12 pt, family `Auto` or named, both remembered; Ctrl+0 returns to the
      EDITOR's default, not the desktop's. All three SynEdits share one policy (the template,
      the source view, the group editor's list).

      **`Auto` asks whether a family can draw THIS document, not whether it is installed** —
      the difference is a page of boxes. Every candidate carries Latin, most carry Cyrillic,
      almost none carries CJK, and `Screen.Fonts` answers yes to all of them. So the cascade
      ends in CJK families and each is asked to draw a sample of the document's own
      characters. Explicitly NOT per-glyph fallback inside one line: one font for the whole
      document, because that is what SynEdit offers and doing it by hand means owning the
      measurement of every line.

      Split by [ADR 0007](decisions/0007-windows-first-cross-platform-seams.md): the POLICY is
      pure (`gui/SpxEditorFont.pas` — cascade, sample, clamp; no LCL, no Windows, driven by
      the console suite with a fake probe), the PROBE is the platform adapter
      (`SpxFontCanDraw` / `SpxFontInstalled` in `gui/SpxUi.pas`; Windows uses
      `GetGlyphIndicesW`, other platforms answer "installed" until a task of their own).

      Three defects a review found here, all confirmed by measurement before fixing, all
      worth remembering:
      - **one emoji collapsed the whole cascade.** `GetGlyphIndicesW` maps UTF-16 code
        *units*; an astral character is two surrogates; no font maps a lone surrogate — so
        every family answered "cannot draw this", the chooser returned nothing, and a
        Japanese document went on being drawn in a Latin font. Surrogates are dropped from
        the probe now: the API cannot speak for them, so they do not vote.
      - **the sample cost 64 ms per render** on a 1.1 MB Cyrillic template — a `Copy` for
        every non-ASCII character plus a `Pos` over a growing string. A bitset makes it 3 ms
        with the same answers, and fixes a membership bug on malformed UTF-8 for free.
      - **the menu caption could lie about the font in use.** One field was both "the last
        computation" and "what is on screen"; building the menu advanced it without applying
        anything. The caption reads `FEditor.Font.Name` now — the control cannot diverge from
        itself.

      Left over, and NOT blocking R0: the four CJK families are offered only when installed,
      so on a bare Windows the tail of the cascade is empty — that is correct, but it means a
      CJK template on a machine without the language pack still gets boxes and nothing says
      why. A diagnostic ("no installed font can draw this document") is the honest fix.

- [x] **6. The locale list reads as a bare tag to a screen reader** (closed 2026-08-02). The
      name went into the ITEM and the drawing did not change — the closed 70 px box still shows
      two letters, because the handler takes the tag from the table rather than from the item.
      The table moved to `SpxStrings` so the suite can hold it to its contract.

      The dangerous part was not the string: `FLocale.Text` was the locale handed straight to
      the engine, and a label in its place would have sent `PluralArity` to a language nobody
      named, with no diagnostic anywhere. `CurrentLocale` is the only reader now.

      What it did NOT buy, measured: the box is still not exposed AS a combo box — UIA reports
      a nameless `Pane`. LCL registers it under its own subclass name (`LCLComboBox`) and
      Windows' proxies for the standard controls are keyed on the class name. The reported
      VALUE changed, which is the whole of the win. ADR 0009.

- [ ] **7. Platform seam debt — `SizeLocaleList`** (opened 2026-07-29 by ADR 0007). The
      locale combo's dropped width is set with a raw `SendMessage(…, CB_SETDROPPEDWIDTH, …)`
      inside `gui/SpxMainForm.pas`, which is exactly the shape ADR 0007 forbids: Win32 in a
      form. Move it behind `SpxSetDropdownWidth(ACombo, APixels)` in `gui/SpxUi.pas`, empty
      outside Windows (a combo whose list is as wide as the box is poorer, not broken).
      Recorded as debt rather than fixed silently — a rule with an unrecorded exception from
      day one is not a rule.

**The interface will be multilingual**, switched together with the text language. Two things
follow, and both are constraints on step 2 rather than later work: no layout may be computed
from a caption's length in Russian (a German caption is a third longer), and the captions
themselves have to leave the code for a table before there are two of them.

## Help & FAQ (начато 2026-07-29)

Авторской документации языка не было нигде: у движка README про API и порт, у спеки Studio
про справку не сказано вовсе. При этом §11 требует от листинга Store «продукт, а не
dev-tool-заглушку», а R0 офлайновый — значит справка должна ехать внутри `.exe`, а не ссылкой.

**Дисциплина, а не объём:** каждый пример в справке прогоняется через настоящий движок в
наборе тестов (`TestHelpExamples` читает сам markdown). Фраза «`{a|b}` даёт a или b» — это
утверждение, а утверждения здесь проверяются. Черновик первого документа поймал этим три
собственных неверных примера; обновление движка теперь роняет сборку, а не делает справку
тихо неправильной.

- [x] **1. FAQ по диагностикам** — `docs/help/ru/diagnostics.md`, 22 статьи: по одной на каждый
      из 17 кодов движка и 5 заметок Studio, 30 проверяемых примеров. Плюс раздел про молчаливые
      поведения, которых нет ни в одной диагностике: `#include` работает только с начала строки,
      кириллическое имя переменной не считается переменной вовсе, неизвестный ключ перестановки
      становится разделителем.

      **Пустота от неверной арности была нашей собственной ошибкой** — она пережила и черновик,
      и первое ревью, потому что байты сходились. Замер: `{plural 5: товар|товара}` печатает
      `5 ｛plural 5: товар|товара｝`, очень заметно; пустоту давал нецелый счётчик, которого в том
      примере просто не определили. Отсюда третья проверка фикстуры — **причинность**: хотя бы
      один пример статьи обязан порождать её собственный код, иначе статья иллюстрирует что-то
      другое и остаётся зелёной.
- [x] **СПРАВКА ЧИТАЕТСЯ В ОКНЕ — сделано 2026-07-30**, [ADR 0008](decisions/0008-help-as-a-generated-unit-and-a-rail-panel.md).
      Не отдельным окном, как планировалось ниже, а **панелью рельса** — решение пользователя и
      верное: `TSpxMainForm` — единственная `TForm` в проекте, и окно было бы первым вторичным.
      Справка делит слот и защёлку с групповым редактором, поэтому кламп ширин не получил
      третьего претендента. Три входа: F1 и пункт меню, пятый инструмент рельса, двойной щелчок
      по строке диагностики — та самая дверь, ради которой инвариант «статья на код» и жил.

      **Что замерено, а не предположено:** якорь по `id` прокручивает без `DataProvider`
      (0 → 6184 при контрольном 0 → 0); предсказанная ловушка с пустым `<a name>` **не
      воспроизвелась**; ширину первой страницы задавала не таблица, а умолчание панели —
      `GetContentSize` назвал это после того, как `width="100%"` ничего не изменил.

      Ниже — исходный план, оставлен как след того, что именно пришлось переиграть:

      1. **Рендерер уже в приложении** — `TIpHtmlPanel`, тот же, что рисует «Страницу»
         предпросмотра ([ADR 0004](decisions/0004-html-preview-page-and-source.md)). Новой
         зависимости не нужно, и это разница между «продуктом» и «текстовым файлом в окне»,
         которую §11 требует от листинга. Дешёвая альтернатива — показать markdown как ТЕКСТ в
         read-only SynEdit — названа здесь честно и отклонена: выглядит как открытый файл.
      2. **Markdown → HTML на СБОРКЕ**, скриптом в `scripts/`, в генерируемый Pascal-модуль —
         тем же приёмом, каким сделаны спрайты (`make-icons.py` -> `gui/SpxIcons.pas`). Markdown
         остаётся единственным источником, поэтому `TestHelpExamples` продолжает читать его же, и
         то, что уезжает в `.exe`, не может разойтись с тем, что проверяет набор. Это и есть
         причина генерировать, а не конвертировать руками.
      3. **СТРАНИЦА НА ТЕМУ, никогда один документ** — и это замер, который у нас уже есть:
         раскладка `TIpHtmlPanel` квадратична, 35 мс на 1.5 КБ против 12.9 с на 172 КБ (спека
         §4.2). Нынешний FAQ — 20.6 КБ, около 0.2 с одной страницей; после справочника языка и
         описания приложения он вырастет кратно, и «одна страница» станет секундами. Генератор
         режет по разделам сразу, пока это стоит ноль.
      4. **Якорь на каждый код диагностики.** Уже принятое решение — двойной щелчок по строке
         открывает статью её кода — держится именно на этом: документ построен как
         `### код — …`, генератор обязан выпустить якорь на каждый, а набор обязан проверить, что
         для каждого кода движка якорь есть. Без этого вход из панели не работает.
      5. **Отдельное НЕмодальное окно.** Модальное заморозило бы живой предпросмотр — причина,
         по которой мастер групп сделан панелью, а не диалогом. Заголовок обязан **кончаться
         именем приложения**: LCL держит второе окно верхнего уровня с заголовком ровно
         `Application.Title`, и иначе его не отличить (ловушка в `AGENTS.md`).
      6. **Второй вход, кроме панели:** F1 и пункт меню на содержание — справка нужна и когда
         ошибки нет.
      7. **Язык.** Справка есть на русском и английском, интерфейс — на четырнадцати языках.
         Просмотрщик обязан сказать это прямо, а не показывать русский молча.

- [x] **РАЗМЕР БИНАРЯ — 49.8 МБ вместо 6.4, закрыто 2026-07-31.** Найдено по дороге к вопросу
      про сплеш и в списке R0 не значилось. Проект собирался с отладочной информацией:
      `spintax-studio.exe` весил 49.8 МБ, `strip --strip-all` того же файла давал 6.6 МБ, а
      сборка с `GenerateDebugInfo = False` — 6.4 МБ. То есть **вся разница** была символами,
      которых никто не читал: `-gl` нет, пробы печатают сообщение, а не стек.

      Флаги релиза: `-O2 -Xs -CX -XX`, отладочная информация выключена, ассерты и проверки
      диапазона **оставлены** — культура проекта падать громко, а суита и так гоняет второй
      бинарь с `-Co -Cr`. Поведение сверено пробой после смены флагов: 24 страницы, 65
      примеров, полоса переключается, поиск даёт те же 9 находок.

      `build.sh` теперь роняет сборку, если exe больше 16 МБ, — потолок щедрый, он не про рост,
      а про то, чтобы вернувшаяся отладочная информация упала на гейте, а не на подаче в Store.
      Проверено мутацией: с потолком 1 МБ гейт краснеет.

- [x] **Плавающий тест в потоковой партии — ЗАКРЫТ 2026-08-01, и виноват был не поток.**
      Заменённая партия по замыслу досылает уже начатый рендер; проба складывала обе в одну
      кучу и считала их одной. Теперь фильтрует по запрошенному номеру и проверяет, что
      «отставшая» строка несёт номер ЗАМЕНЁННОЙ партии. Восемнадцать прогонов подряд —
      одинаковое число проверок; раньше плавало. *Исходная запись:* замечен 2026-07-31, один прогон из шестнадцати.**
      `batchthread/and-the-seeds-start-at-the-new-base` упал в одном прогоне
      `tests/studio_tests_checked`; двенадцать подряд после этого чистые. Настораживает не
      падение, а то, что **менялось само число проверок** (6011 против 6010) — значит гонка не
      в утверждении, а в том, сколько шагов партии успело отработать до опроса.

      Гейт, падающий раз в шестнадцать прогонов, рано или поздно уронит ветку CI без причины, и
      тогда его начнут перезапускать не глядя — что дороже самого дефекта. Чинить надо
      детерминизмом ожидания (ждать признак завершения, а не число), а не увеличением таймаута.

- [x] **СПРАВОЧНИК ЯЗЫКА НАПИСАН — 2026-07-31.** `docs/help/{en,ru}/syntax.md`, по двенадцать
      разделов, 32 и 35 примеров, каждый прогнан движком и сверен побайтово. Шесть форм, которых
      не было ни в одном документе, теперь описаны; молчаний в главе про молчания стало восемь.

      **Ревьювер после каждого языка, и оба раза нашёл прозу, а не примеры.** По-английски —
      тринадцать находок, включая правило сокращений, придуманное вместо измеренного, и пример,
      печатавший ответ другого зерна. По-русски — девять, из них две тяжёлые: механика `#set` в
      счётчике описана наоборот (слово не расходится с числом, а **исчезает**, панель ставит
      `plural.count-macro`), и «блок перед первым элементом не разделитель» — ровно наоборот,
      перед первым он как раз разделитель.

      Третье попало в **уже выпущенный** `ru/diagnostics.md`: он утверждал, что `и.о.` и `т.д.`
      заэкранированы. Измерено — нет: проверка границы слова латинская, поэтому и `сайт.рф`
      выходит как `Сайт. Рф`. Исправлено там же, с примерами в ограждениях.

- [ ] ~~**СПРАВОЧНИКА ЯЗЫКА НЕТ**~~ (закрыто выше) — и это, а не следующая UX-мелочь, была самая большая дыра R0.
      Измерено 2026-07-31** по вопросу пользователя и странице
      [spintax.net/docs/syntax](https://spintax.net/docs/syntax).

      То, что есть, — **руководство по диагностике**: статья на каждый код панели, ни одной на
      конструкцию, которая ничего не ломает. Референс семейства перечисляет 29 форм; шесть из них
      в наших двух документах не упомянуты ни разу, и **все шесть движок поддерживает** — то есть
      это дыра в документации, а не в движке. Прогнано через `v0.3.3`, `TFirstRng`/`TLastRng`,
      `PostProcess := True`:

      | форма | замер |
      |---|---|
      | `price {\|is low}.` — пустой вариант | `Price.` / `Price is low.`, чисто |
      | `[<, >one\|two\|three]` — единый разделитель | `One, two, three`, чисто |
      | `[one\|two<and>\|three]` — разделитель у элемента | `One two and three`, чисто |
      | `[<sep=", ">one\|two<and>\|three]` | `One, two and three` — та самая идиома «a, b и c» |
      | `{?vip?welcome}` — без «иначе» | `Welcome`; с неопределённой — пусто и `variable.undefined` |
      | `{?!vip?no\|yes}` — отрицание | `Yes` |
      | `#set %x% =` (пробелы) + `{?x?T\|F}` | `F` — значение из одних пробелов ложно |

      **Разделитель — ЗАВЕРШАЮЩИЙ** (`Spintax.pas:1311`, `extractTrailingSep`). Ведущий, который
      кажется естественным, — `[one|<and>two]` — печатается буквально: `One <and>two`, **без
      единого замечания**. Пятое молчание, и найдено оно тем же способом, что первые четыре, —
      измерением при письме.

      **Шестое, и хуже:** тег в конце варианта съедается как разделитель и печатается своим
      содержимым. `[one<br>|two]` → **`One br two`**, `[one<b>|two]` → `One b two`, всё чисто.
      Закрывающий уцелел (`[one</b>|two]` → `One</b> two`), и тег в середине тоже
      (`[a<br>b|c]` → `A<br>b c`). У движка на этот `looksHtml` открыт свой пункт
      (`engine/docs/TODO.md:57`) — так что здесь вопрос, документируем мы это или линтуем.

      Следующий документ — `docs/help/{en,ru}/syntax.md`, по той же дисциплине: каждый пример со
      стрелкой прогоняется движком и сверяется побайтово, `spx-good` там, где утверждается
      чистота. Довод писать его раньше рецептов записан ниже, в пункте 5, и теперь измерен.

- [ ] **СЛЕДУЮЩИЙ СЛОЙ СПРАВКИ — план, 2026-07-31.** Просмотрщик сделан (ADR 0008); это про то,
      что он умеет делать, а не про то, где он живёт. Порядок обсуждён и он именно порядок.

      **Общее правило, которое дороже списка.** Всё, что держит эту справку честной, жёсткое:
      каждый пример прогнан через движок, каждый код имеет статью, показать нельзя то, что не
      отрендерено. Каждый новый глагол — вставить, починить, попробовать — обязан отвечать на
      вопрос **«что доказывает, что это остаётся правдой»**. Иначе через десять шагов внутри
      программы окажется вторая, уже без фикстур.

      1. **Пары «не так → так» — СДЕЛАНО 2026-07-31.** ` ```spx-good ` в словаре генератора,
         десять примеров (пять на язык) помечены, суита держит их к обещанию. Ратчет `Good: 5`
         рядом с `Examples` — по замечанию ревьювера: без него достаточно стереть слово, и десять
         проверок исчезали молча; с ним исчезает **счёт**. Генератор отдельно отказывает в
         информационной строке на **закрывающем** ограждении: оба разборщика читают только
         открывающее, так что `spx-good` на закрывающей строке выглядел разметкой и проверялся
         как обычный блок.

         Проверено мутацией того класса, который видит **только** новый контракт: сырой сентинел
         в шаблоне — `SpRender` его удаляет, вывод побайтово тот же, а замечание есть. Одна
         ошибка, и это новая проверка. Дыра, которую это закрыло: глава «Как выглядит
         правильное» содержит **ноль статей и пять примеров** — проверка причинности работает по
         статьям, значит эти пять сравниваются побайтово, а собственная фраза главы «разобранное
         без единого замечания» не проверяется ничем. Измерено 2026-07-31.

         Контракт теперь двусторонний: статья к коду обязана иметь пример, порождающий этот код
         (было), а пример в `spx-good` обязан не порождать **ни одной** строки (стало).

         **Автопочинки не будет, и это не осторожность.** Замерено: `bracket.unclosed` сообщает
         `1:6…1:7` — сам брейс; конца у незакрытой группы нет по определению, а `SpxGroupAt`
         непарную скобку отвергает. Заменять нечего. «Вставить» — не этап на пути к «заменить»,
         а всё, что технически возможно.

      2. **«Вставить к себе» — СДЕЛАНО 2026-07-31.** Полоска над правой панелью: кнопка плюс
         короткая подпись «пример из справки». Появляется вместе с примером и уходит вместе с
         ним — одно правило в одном месте (ветка справки в `RequestRender`). Текст берётся из
         `SpxHelpInsertText`, то есть из таблицы, которую гоняла фикстура, а не со страницы:
         на странице `[<foo=1>a|b|c]` нарисован как `&lt;foo=1&gt;`, и читателю досталось бы
         то, чего движок никогда не рендерил. Суита сверяет обе стороны для всех 67 примеров.

         **Пробой измерено то, до чего суита не достаёт** (LCL она не компилирует): полоски нет
         без справки, нет на странице без примера, есть после клика, нет после вставки; справка
         закрывается, редактор виден, шаблон ложится в позицию каретки, **одна** отмена
         возвращает документ. Проба сначала соврала дважды — считала шаблон по английскому
         документу, когда окно вставляло из русского, и мерила **скрытую** полоску, которую LCL
         не выравнивает.

         И нашла настоящее: подпись вылезала за панель **в восьми языках из четырнадцати** при
         обычном размере окна (панель 283 px, потому что справка занимает 64%). Подпись
         укорочена, обе надписи зажаты по ширине полоски; на 161 px кнопка ужимается, а не
         висит снаружи. Круговой переход темы проверен внутри одного запуска.

         Осталось замеченным, но не сделанным: **переключение языка интерфейса теряет открытый
         пример** — `GoToHelp` сбрасывает его намеренно («новая страница — новая тема»), и на
         смене языка это спорно: статья переезжает через `SpxHelpRelocate`, а пример нет.

         Решения, принятые до кода и подтверждённые им:
         - Кнопка идёт **в правую панель**, а не на пример: в HTML кнопок нет, IPro рисует только
           ссылки, а вторая ссылка на строку зашумила бы пример двумя магентовыми вещами.
         - Действие **закрывает справку** и вставляет шаблон в позицию каретки одним шагом отмены.
           Закрывает не для красоты: справка занимает панель редактора, поэтому вставка идёт в
           документ, которого не видно, и закрытие — единственное, что делает результат видимым.
         - Доказательство даровое: шаблон измерен фикстурой, а после вставки приложение не верит
           справке, а снова гонит настоящий движок.

      3. **Пустые панели учат.** Пустая панель переменных выглядит как «не работает», хотя чаще
         всего она права. Одна строка-ссылка на главу: «Используйте `%имя%` и объявите его через
         `#set`», «`#include "фрагмент"` — только с начала строки». Тон: **как получить данные**, а
         не «данных нет». Каждая ссылка обязана разрешаться через `SpxHelpPageIndex`/якорь, и это
         проверяется так же, как проверяются коды. Цель — слаг, он не зависит от языка; подпись —
         четырнадцать переводов.

      4. **Мини-контекст «в вашем шаблоне это здесь».** Плашка над статьёй: строка, колонка и один
         экранированный фрагмент с отмеченным интервалом. **Блокировано** до появления
         `SpxHtmlEscape` в ядре (не в GUI — иначе набор его не компилирует), с проверками на
         опасных строках: `[<foo=1>a|b|c]`, `%café%`, литеральный `&`, сырой `<tag>`, кириллица.

         И одно надо записать заранее, а не обнаружить потом: **утверждение о справке ослабнет**.
         Сегодня «то, что показано, — это то, что проверено». После плашки — «**статья** — это то,
         что проверено, а полоска над ней — ваш собственный текст, экранированный».

      5. **Молчания — порядок, а не сеть.** Белый список молчаний, сверяемый с главой, ловит
         «задокументировано, но не в списке» и наоборот. Он **не может** поймать «есть, но ни там,
         ни там»: у молчания нет имени, чтобы его перечислить. Новые **коды** движка ловятся уже
         сейчас (`ENGINE_CODES` плюс требование статьи на каждый), новые молчания — нет, по
         построению.

         Способ находить новые — не инвариант, а **следующая написанная глава**: все четыре, что мы
         знаем, нашлись измерением при письме, а не анализом. Это довод писать справочник языка
         раньше рецептов.

      **Не делаем, и вот почему:**
      - ~~**Поиска.**~~ **Сделан 2026-07-31, по требованию пользователя, и довод выше был
        неверен.** «Двенадцать заголовков глав видны целиком» перестало быть правдой в тот
        момент, когда документов стало два: глав двадцать четыре, а статей под ними — тридцать
        одна. Поиск живёт в шапке справки, без отдельного вызова, тем же матчером, что и поиск
        по документу (`SpxFindAll`), и одна статья — одно попадание. Синонимы по-прежнему не
        делаем, и по прежней причине: непроверяемый контент на двух языках протухнет молча.
      - **Песочницы с подстановкой примера в левую панель.** Справка **и есть** левая панель;
        подставив туда пример, её вытесняешь, и статью с примером одновременно уже не видно. К
        этой раскладке пришли через две переделки (ADR 0008).

- [x] **Мелочи, оставшиеся от ревью справки 2026-07-31 — обе закрыты 2026-08-01.** Обе названы и обе не сделаны:
      ~~Escape справку не закрывает~~ — **измерено 2026-08-01: закрывает**, из дерева тем, со
      страницы и из нижней панели (`FormKeyDown` при `KeepPreview`). Перечисленные там выходы
      с тех пор изменились: рельс в режиме справки скрыт, крестик тем убран, а закрытие живёт
      в шапке рядом с тумблером справки. ~~И расхождение обрезки в блоке условий~~ — **закрыто**:
      набор теперь подрезает строку перед разбором, как это делает генератор.

- [x] **ОКНО «О ПРОГРАММЕ» — сделано 2026-07-31.** Модальное, создаётся и освобождается на
      каждый вызов: знак (кадр 64 из иконки приложения, выбираемый по размеру и **заново при
      смене DPI** — иначе на 150% кадр 64 растягивался в 96), обе версии и атрибуции.

      **Атрибуции генерируются** `scripts/make-about.py` из `NOTICE.md`, версия — из файла
      `VERSION` (четыре части, как хочет Partner Center), версия движка — из тега подмодуля.
      Суита держит все три источника друг к другу: каждая лицензия и каждая обязательная запись
      файла есть в тексте, который уезжает; и обратно — записи файла читаются построчно и их
      **число** сверяется, чтобы проверка не могла тихо перестать работать.

      **Версия теперь и в ресурсе exe** (`<VersionInfo>` в `.lpi`): `FileVersion`, `ProductName`,
      `CompanyName` — то, что читают Partner Center, вкладка «Подробно» и отчёт о падении.
      Проверка сверяет её с `VERSION`; расхождение красное.

      Ревью нашло шесть вещей, все закрыты и каждая проверена мутацией. Тяжёлые: генератор брал
      лицензию из **всего** текста записи, и предложение, упоминающее MPL внутри записи про LCL,
      делало LCL «MPL-лицензированным» — теперь читается только там, где она объявлена. И
      обратная проверка в суите обрывалась на любом `## ` внутри прозы: подложенная ошибка
      **исчезала**, унося с собой проверку соседней записи.

      Окно **системного цвета**, а не темы: `SpxTheme` прямо говорит, что обвязка не красится, и
      тёмный диалог со светлой рамкой был единственной поверхностью, которая это нарушала.

- [x] **ЗНАК: на сайте их два — решено 2026-08-01, и решение в том, что они разные по роли.**
      Шестиугольник (`apple-touch-icon.png`) — знак **программы**: он в иконке exe, в заголовке
      окна, на панели задач и в окне «О программе». Лента (`logo.svg`) — знак **бренда**: она
      стоит у подошвы рельса ссылкой на spintax.net и больше нигде. Решение пользователя, и
      оно снимает вопрос не приведением к одному, а разделением: одно говорит «эта программа»,
      другое — «этот проект». Обе теперь вендорены (`assets/brand/`), лента вместе с растром,
      потому что растеризовать SVG на сборочной машине нечем.

- [ ] ~~**ОКНО «О ПРОГРАММЕ» — план, 2026-07-30.**~~ (сделано выше) Меньше по объёму и обязательно до первой
      подачи: единственное место, где пользователь читает атрибуции из `NOTICE.md` (MDI
      Apache-2.0, Twemoji CC-BY 4.0, и почему LGPL у LCL/RTL не достаёт до MIT-бинарника).
      Лицензионная обязанность, не любезность.

      - **Атрибуции генерируются из `NOTICE.md`**, а не переписываются рядом: две копии
        лицензионного текста расходятся, и расходятся молча. Набор проверяет, что каждая
        лицензия, названная в файле, есть в том, что уезжает в `.exe`.
      - **Версия — одна константа**, и пункт связан с «Stable app identity» ниже: там нужна
        4-частная версия для Partner Center, здесь она же на экране. Делать вместе.
      - Плюс версия движка (тег submodule): тот, кто сообщает о расхождении с другим движком
        семейства, должен видеть, против какого собран этот.
      - Модальное окно здесь допустимо: короткое, открывается сознательно.

- [ ] **ПУТЬ ДЛЯ АГЕНТОВ — то, что уже готово на spintax.net** (напоминание пользователя,
      2026-07-30). В R0 у Studio нет AI и она не делает ни одного вызова модели. Но у того, кто
      работает с агентом, путь уже есть — на сайте:
      - **MCP-сервер** `/mcp` (`functions/mcp.ts`), три инструмента поверх того же движка:
        `validate_spintax` (диагностика со строкой и колонкой), `render_spintax` (N вариантов с
        сидами), `analyze_spintax` (ссылки, определения, инклюды и счёт конструкций). `#include`
        там отключён намеренно — шаблон не достаёт ни до файлов, ни до сети.
      - **Три навыка агента**: `spintax-authoring`, `spintax-engines`, `spintax-syntax`
        (`static/.well-known/agent-skills/*/SKILL.md`).

      **Это указатель, а не функция.** Страница справки «если шаблоны вам пишет агент» плюс одна
      строка в «О программе» — и ничего больше в R0.

      **Навыки НЕ идут в справку дословно**, и это решение сайта, которое стоит уважать: SKILL.md
      — сжатый императивный артефакт, адресованный машине, а не страница документации (сказано
      прямо в `src/skills.ts`). Источник человеческого текста — markdown-зеркала документации
      сайта; навыки в справке только называются.

      **Открытый вопрос пользователю, не коду:** упоминать ли это в ЛИСТИНГЕ Store. Само
      приложение генеративного AI не содержит, поэтому под Live Generative AI policy R0 не
      попадает (§11) — но листинг читает рецензент, и формулировка не должна создавать
      впечатление, будто AI внутри.

- [x] **2. Справочник языка — сделано 2026-07-31.** `docs/help/{en,ru}/syntax.md`, по двенадцать
      глав в каждом, 32 и 35 измеренных примеров, своя фикстура на документ и глава о молчаниях.
      Английский не переведён с русского, а **измерен заново**, и измерения разошлись с русскими
      на их же предмете: под `en` правильных форм две, а ошибочных три — ровно наоборот.
      Изначальный план ниже (писать после рецептов) был перевёрнут по решению пользователя, и
      верно: справочник — то, из чего рецепты потом цитируют, а не наоборот.

      *Исходный план:* конструкции по одной, с проверяемыми примерами. Писать после
      редактора групп: часть этого он покажет руками. Источник — зеркала документации сайта, не
      SKILL.md (см. выше).

      **ЧЕК-ЛИСТ ОХВАТА ВЗЯТ У GTW** (`C:\Program Files (x86)\Generating The Web\gtw-help.chm`,
      2011 — пользователь нашёл его 2026-07-30). Двенадцать разделов его оглавления, с тем, что
      каждый значит для нас:

      | у GTW | у нас |
      |---|---|
      | Введение | своё |
      | Переборы | `{a\|b}` |
      | **Перестановки: простые / с одинаковым разделителем / с разными / с переменным числом** | четыре раздела, а не один — см. ниже |
      | Использование переменных | `%var%` и рантайм-значения |
      | Использование констант | **`#set` против `#def`** — та самая разница, которой не видно в интерфейсе |
      | Включаемые файлы | `#include` и набор |
      | Комментарии | `/# #/`, включая то, что они не вкладываются |
      | Синонимизация | наш M4, не R0 |
      | Расстановка ссылок | у нас нет и не планируется |
      | Шинглы | наш дедуп — в описание приложения (волна 3), уже сделан |
      | Дополнительные возможности, Контакты | своё |

      Чего у них нет вовсе, а у нас есть и требует раздела: **условия** `{?flag?…}` и
      **множественное число** `{plural %n%: …}`.

      **Перестановкам нужны четыре раздела, а не один** — и это не копирование структуры, а
      совпадение с нашим собственным опытом: правило висячего разделителя стоило отдельного PR и
      пяти замеров (`<br>` разделитель, а `<br/>`, `<br />`, `</b>` и `<span class="x">` — нет),
      а конфиг перестановки получил HTML-guard только в движке `v0.3.3`. Это самая настраиваемая
      конструкция языка, и одним разделом она не объясняется.

      **СТИЛЬ ПРИМЕРОВ — ровно наоборот, и это главное, что мы у них НЕ берём** (замечание
      пользователя, проверено чтением): их примеры это `{ 1 | 2 | 3 | 4 }`, а «результат» —
      таблица из `1/4/2/3`. Синтаксис показан, смысл не показан ничем: читатель узнаёт форму
      записи и не узнаёт, зачем она. Наша дисциплина обратная и уже держится набором
      (`TestHelpExamples` гоняет каждый пример через настоящий движок), а примеры пишутся
      измерением, а не по памяти.

      **Как открыть файл, чтобы не искать заново:** `hh.exe -decompile` молча не делает ничего;
      распаковывается 7-Zip'ом (`7z x gtw-help.chm`). Текст внутри **двойной кодировки** —
      HTML-сущности поверх cp1251-байтов, то есть `unescape` -> `encode('latin-1')` ->
      `decode('cp1251')`. Ничего из его прозы в наш репозиторий не переносится: взят перечень
      тем, не текст.
- [ ] **3. Само приложение** — две панели, сид и реролл, варианты и дедуп, экспорт. Этот же
      текст уходит в описание для Store.
- [x] **Английская версия FAQ по диагностикам** — `docs/help/en/diagnostics.md`, те же 22 статьи,
      33 проверяемых примера, та же фикстура. Порядок оказался обратным записанному: сделали
      английский раньше, чем «русская устоится», — интерфейс идёт на 14 языках, справка была на
      одном, и листинг Store мировой.

      **Перевода нет ни строки — всё перемерено под `en`,** и локаль меняет не оформление, а сами
      факты: три формы множественного числа здесь ОШИБКА, а две — норма (под `ru` ровно наоборот),
      так что раздел про арность пришлось вывернуть целиком.

      **Раздел про экранирование сокращений был написан как «английская особенность» — и это была
      ошибка, пойманная ревью замером.** Список движка на 46 записей, и **29 из них русские**
      (`г ул стр см руб тыс млн тел…`), а `ScanSingleAbbr` локаль не спрашивает вообще: `руб.`
      экранирует в английском документе, `Ltd.` — в русском. То есть дыра была не там, где
      казалось: она была в РУССКОМ документе, где раздела не было вовсе, хотя `г.` и `стр.` — это
      обычная русская проза. Теперь раздел есть в обоих, с замеренной парой
      (`руб. наша` против `ххх. Наша`) и с примером, который кусается: `дом 5 г. москва` оставляет
      город строчным.

      Держим **паритет по инвентарю статей** (22 кода), а не по прозе: остальное следует аудитории.

- [ ] **Остальные двенадцать языков.** Решено: язык может отставать **целыми документами, но не
      внутри одного** — проверка «на каждый код по статье» делает полудокумент невозможным по
      построению. Просмотрщик обязан честно сказать, на каком языке показывает.

## Raised by review, not yet built

- [x] **An unbalanced bracket inside a permutation's config made the two bracket rules
      contradict each other — FIXED 2026-08-01.** Both walks ask the tokenizer's own
      `PermConfigLength` and skip the config whole; the first attempt left the defect alive
      behind one space, because the engine and the tokenizer left-trim and the walk did not.
      Five checks, three of which fail without the trim. *The original finding:* Found by review 2026-08-01, fuzzing 80 000 documents: on
      `[x|[<sep="{">a|b]|y]` the tokenizer says the inner `[` is closed by the `]` at 17 and the
      pipe at 15 is its separator, while `SpxMatchBracket` pairs that `[` with the OUTER `]` at
      20 — because both stack walks count the `{` inside the config as an opener, and the
      phantom pair swallows the real closer. The editor therefore lights `4..20` and paints a
      separator the new `SpxConstructOf` declines to answer for. Four shapes in 80 000, none in
      the demo, all needing an unbalanced bracket character inside a config. **The pre-existing
      rule is the wrong side**: it draws a pair its own tokenizer contradicts. The fix is for the
      bracket walks to skip a permutation's config the way the tokenizer does — which would also
      close the fact that the walk now lives in two places (`SpxMatchBracket` and
      `SpxConstructOf`), near-verbatim.

- [ ] **A consumer that replaces a RUNNING batch must tell the two apart by `Progress.Id`.**
      Written down 2026-08-01 because a guard for it was built and taken out again. The thread
      installs a replacement between renders, so the render in flight still delivers and the
      replaced batch still gets its own `Done`; a consumer that keeps both mixes two batches in
      one grid, and the old batch's `Done` stops the new one's progress line. **The window does
      not reach that case** — `TSpxVariantsPane.GoClicked` refuses to start while one runs, and
      nothing else raises `OnGenerate` — so it filters nothing. The guard that was tried
      compared against `FNextId`, which `RequestRender` also bumps: one keystroke during an
      export dropped every remaining record including the `Done`, and the panel wedged for the
      session. Measured on the real worker, 121 records dropped. If a second caller ever
      appears, it needs a batch id of its own, never the shared one.

- [ ] ~~**A separator on a middle line may appear one caret move late.**~~ *(closed 2026-08-01:
      `KeepSeps` now invalidates the lines that GAIN a separator, mirroring what `ClearSeps`
      already did for the ones that lose one. The parent invalidates only the two bracket
      lines — `syneditmarkupbracket.pp:200-225` — so nothing else would have.)*

- [ ] **The help's language can move while the help is CLOSED, and nothing relocates it then.**
      Found by review 2026-07-31, latent and not a regression. `RetranslateUi` only relocates
      when the pane is up (`SpxMainForm.pas:2810`, `if HelpShowing and (FTopics.HelpLang <>
      FHelp.HelpLang)`); with the help closed, the topics panel's language moves and `FHelp`
      keeps the previous language's `CurrentPage`/`CurrentAnchor`, which the next
      `OpenHelpPane` hands straight to `ShowPage` without passing through `SpxHelpRelocate`.
      It lands on the right article today **only because the two languages' page tables are
      parallel** — `HELP_PAGE_FIRST = (0, 24)`, `HELP_PAGE_LAST = (23, 47)` and an identical
      slug sequence. A third document, or a language whose chapters differ, breaks it silently.
      The fix is to relocate on the language change rather than on the open, or to store the
      reader's place as a SLUG rather than a page index.

- [ ] **A right-to-left interface means MIRRORING THE WINDOW, not translating it.** Noted
      2026-07-29, the user's, while weighing `swap-horizontal` as an icon for "even the
      panes" — the icon was rejected because a reader would expect it to SWAP the two panes,
      and that is exactly the operation an RTL locale needs. Arabic or Hebrew wants the
      template on the right and the preview on the left, the tool rail on the trailing edge,
      and the gutter on the other side of the text; a mirrored window with a left-to-right
      layout reads as broken even when every caption is correct. So when the language wave
      reaches `ar` or `he`, the work is not another `gui/lang/SpxTextsXx.pas` — it is
      `BiDiMode` through the form, both splitters swapping which pane they resize, and the
      rail's side setting becoming *leading/trailing* rather than *left/right*. The pane swap
      is therefore worth building as its own action first: useful to anyone (some people
      simply prefer the output on the left) and the honest foundation for RTL. LCL's
      `TControl.BiDiMode` / `IsRightToLeft` is the seam; the segmented switch already handles
      `IsRightToLeft` for its image, which is the one place this has been thought about.

- [x] **A high-contrast palette** (closed 2026-08-02). The third table landed, keyed off
      `SpxHighContrast` and COMPUTED rather than stored — `TSpxTheme` stays the two values that
      go in the settings file, so turning the desktop's contrast off cannot strand the app in a
      look nobody chose.

      The note above understated it: `$993300` measures **1.50:1** on the #202020 page a
      contrast theme actually supplies, not merely "nearly as bad" on black. Nine syntax roles
      collapse into four classes, because a theme guarantees only `clWindowText`, `clGrayText`
      and `clHotLight` legible there.

      Three things the note did not know about, all found on the way and all measured: the
      preview was **1.29:1** — black text on the dark page, because the pane took its background
      from the system and left the ink to the renderer's default; the tool rail's own glyphs
      were **1.48:1**, since the sprite is baked at rgb(60,60,60) and those buttons have no
      caption at all, so the glyph IS the control; and the Page/Source switch drew `clWindowText`
      on a hardcoded `#FFFFFF`. All three at 11:1 or better now. ADR 0009.

- [x] **A session value is a template, and sometimes that is not what the author meant**
      (2026-07-29). The Variables panel's session half gained a third column, «как текст»:
      ticked, the value goes to the engine through `SpNeutralize` and its braces and percent
      signs stay characters. Unticked -- the default -- it is a template, because that is what
      a production host passes and the preview has to agree with it. The neutralising is
      `SpxValueForEngine` in editor-core, gated both directly and through a render.

      One bug found on the way, and it is the shape worth remembering: `SpxKeepRuntime`, the
      filter every session value passes on its way to the job, copied the name and the value
      and silently dropped the new flag -- so the checkbox did nothing and nothing said so.
      There is a check for that now.

- [x] **The interface's language is its own setting** (2026-07-29, the user's call). It used
      to follow the document's locale, which meant the whole window changed language whenever
      the locale box was touched. Now: View → Язык интерфейса → English / Русский / Как в
      шаблоне, defaulting to the machine's language. The diagnostics rows follow the
      INTERFACE (the job carries `UiLang`), because Russian headers over English findings was
      the first thing decoupling produced.

- [ ] **(superseded, kept for the reasoning) A session value is a template.**
      (M2, the Variables panel.) Measured: the engine renders a host-supplied value exactly as
      it renders a `#set` one — `{Rome|Paris}` picks a variant, `%other%` expands, a
      self-reference unwinds to the depth limit and stops. That is the family's contract, and
      Studio must NOT neutralise it host-side: the preview would then disagree with every
      other engine on the same document and host values, and the panel's two halves would stop
      meaning the same thing. The engine's own `variable.self-reference` /
      `variable.circular-reference` / `plural.count-macro` codes exist because values are
      templates.

      What is genuinely missing is the author's INTENT. Someone pasting text that happens to
      contain `{` or `%` gets a preview that mangles it and diagnostics about brackets they
      never wrote. The answer is a per-value choice in the panel — literal (`SpNeutralize` on
      the way in, which is what that engine API is for) or spintax — never a silent rule.
      Raised by an external review 2026-07-28; for now the panel at least says what the values
      are.

## Taken from GTW, the editor this syntax came from

Not new milestones — ideas from *Generating The Web 2.7*, the tool whose spintax the family
grew out of, noted where they attach. Recorded 2026-07-28 from two screenshots of it.

- [ ] **A group editor, as a PANEL — not a modal.** (M2, after the core slice below.) GTW's
      «Мастер формул» is the good part: the group's kind switchable at the top, the variants
      one per line under it, and for a permutation its config as fields (`minsize`, `maxsize`,
      `sep`, `lastsep`). Editing `{a|b|c}` inside a long line of prose is the pain it solves.
      **Ours slides out of the tool rail**, not a dialog and not the bottom strip. The
      user's own instruction (2026-07-28) put the variables and formula work in the rail, and
      it is the better place for a second reason: the rail sits beside the editor, so the
      panel is next to the caret it is editing, while the bottom strip is as far from the
      text as the window allows. A modal is out for GTW's own reason inverted — its wizard
      carried its own «Предпросмотр» precisely because its main window had none, and a dialog
      here would cover the document and freeze the live preview, the one thing we have that
      it did not.
- [x] **Core slice it needs first** (2026-07-29, `src/SpxGroups.pas`): `SpxGroupAt` finds the
      group under the caret and `SpxSetGroupVariants` writes it back — with the read-back the
      `SpxSetDirective*` family does, so an edit whose RESULT says something other than what
      was asked is refused and the document is left alone. Measured refusals: a `|` in a
      variant (it would become two), a `}` (it would end the group early), a `{` (it would
      open a nested one), `/#` (it would open a comment that eats the file). Every structural
      question goes to `SpxTokens`, the scanner the highlighter runs, so the group the panel
      offers to edit is the group the colours describe.
- [ ] **Prompt buttons AND a free-form field, in that same panel.** (M4, spec §4.5.) Buttons
      for the frequent verbs — rewrite, +N variants, shorten, diversify — each a **named
      prompt template in config**, editable rather than compiled in; plus one free field for
      everything else. Buttons alone break on the first unusual request; a field alone means
      typing the same sentence ten times a day. Reserve the space at the bottom of the panel
      when the panel is built, so M4 does not re-cut the layout.
- [ ] **Show how many variants the template can produce.** (M3.) GTW puts *«Max возможных
      вариантов: 241 864 704»* next to *«Сгенерировано: 50»*, which is the number that tells
      an author whether their template is thin. Honest only while the document has no
      `#include` and no conditional — decide then whether to show an exact count, a lower
      bound, or nothing at all in those cases.
- [ ] **A length filter on generation.** (M3.) GTW generates with *«Длина текста от 50 до
      Unlimited»*. Cheap next to the render loop and it is a real editorial constraint.
- Confirms M3's shape rather than adding to it: its *«Удалить похожие»* is our shingle dedup
  and *«Перемешать»* is the order variants come out in — both belong next to the result list,
  as buttons over it, not inside a settings dialog.

## Publish prep — Microsoft Store (spec §11)

Distribution target is the Store via MSIX. Some of these are **constraints on M0/M1** (bake
them in, don't retrofit); the submission tasks come once M1/M2 give a demoable product.

Constraints (design into the app from the start):
- [x] **No admin, known-folder storage** *(done: `SpxSettings` takes the base from
      `GetWindowsSpecialDir(CSIDL_LOCAL_APPDATA)` and pins a fixed folder under it — never
      beside the .exe, never with administrator rights.)* Settings / templates / keys go to the user profile
      via known-folder APIs (`%APPDATA%` / `LocalAppData` / Credential Manager), never next to
      the `.exe` — required for the MSIX container and to avoid elevation (spec §7, §11).
- [x] **Stable app identity and Store assets.** The package identity is fixed in
      `scripts/make-msix.py` (`301.SpintaxStudio`, publisher `CN=BEE1F94B-ABDE-4CF8-9F30-1DF4DAFDAE83`,
      display name `301`) and `VERSION` is four-part. Before upload, compare every identity
      field in the generated manifest exactly with Partner Center's identity page. The executable icon and
      package tiles are present, including the 310px source required by the Store roles. The
      English screenshot set is in the local submission folder; Partner Center upload remains.

      **A raster CAN be made from the vector, and the way was found by needing it for the brand
      link's mark (2026-07-31) — but the invocation is not dependable, and that half is the
      part worth writing down.** `assets/brand/spintax-logo-512.png` is genuinely headless
      Chrome's render of `spintax-logo.svg`, alpha intact: `chrome.exe --headless=new
      --disable-gpu --hide-scrollbars --default-background-color=00000000 --window-size=W,W
      --screenshot=out.png page.html`, run from the page's own directory, where `page.html` is
      one `<img src="…svg">` sized in CSS.

      It worked once and has not worked since. Measured, after a review could not reproduce it:
      both headless modes, with and without an isolated `--user-data-dir`, at 256 and at 1024 —
      Chrome exits **0**, prints nothing, and writes no file anywhere. So the recipe is a lead,
      not a procedure: **check that the output file exists**, never the exit code, and expect to
      need another rasteriser. This machine has none — no cairo (cairosvg and svglib both
      refuse), no ImageMagick, and the `convert` on PATH is **Windows' NTFS converter**, which
      must never be run by accident.

      The larger Store asset is now produced and inspected as `assets/brand/spintax-mark-310.png`;
      `scripts/make-msix.py` refuses a source below 310px so the package cannot silently fall
      back to undersized role assets.
- [x] **About box — done 2026-07-31.** Modal, generated from NOTICE.md, VERSION and the
      engine submodule's tag, with the suite holding all three sources to each other.
- [x] **Offline baseline is the review keystone — and it is now GATED, 2026-08-01.** Editor,
      validation, render and export work with no key and no network, and the suite proves it
      rather than the README asserting it: a network unit in any shipped unit's uses clause
      fails the build by name (mutation-tested).

Submission tasks (after a demoable build):
- [x] **MSIX packaging — answered 2026-08-01, and it works end to end.** This was the one
      unknown that could have invalidated the distribution plan, so it was done first rather than
      last. Measured on this machine, with a Windows SDK that turned out to be installed already
      (`makeappx` / `signtool` / `makepri`, 10.0.19041): the Lazarus `.exe` packs into a 2.5 MB
      MSIX, MakeAppx validates the manifest, signtool signs it, the package REGISTERS, and the
      application launches from inside the container and renders its demo document. **The §11
      fallback (EXE/MSI, with signing, hosting and update mechanics on us) is therefore not
      needed and should not be planned for.**

      `scripts/make-msix.py` builds it from `packaging/AppxManifest.xml.in` and also emits the
      Store upload wrapper `build/spintax-studio.msixupload` around the package. The tiles are
      resized from the brand raster into the staging folder and are build output, not committed
      artefacts: unlike the icons and the help they do not travel inside the executable.

      Two things learned on the way, both silent when wrong: **XML forbids a double hyphen
      inside a comment**, which MakeAppx reports only as `expected '>'` at a column; and
      **installing an unsigned or self-signed package needs Developer Mode** — a self-signed
      certificate in the USER's TrustedPeople store is refused with `0x800B0109`, the root not
      being trusted, so the choice is Developer Mode or an elevated shell.

      **What is still owed is an account-side verification, not packaging machinery.** The
      script contains the identity currently associated with the reservation; compare it with
      Partner Center immediately before upload because manifest values are case-sensitive.
- [x] **Code signing — not a task on the MSIX Store path.** Microsoft re-signs MSIX packages
      after certification. The EXE/MSI signing research below is retained only as a fallback
      record and must not become R0 work.

      **On the target path it is not needed at all.** Store hosts and **re-signs** the MSIX
      (§11), so we upload an unsigned package and a Store install never meets SmartScreen. And
      testing our own package before submission needs no certificate either — developer mode
      registers loose files, or a self-signed cert does it locally, both free.

      **Its trigger is the §11 FALLBACK, not another channel.** There is no other channel
      planned. But the fallback — EXE/MSI, still submitted to the Store — puts "подпись, хостинг
      и механика обновлений" on us by that section's own words. Only then does any of the below
      matter.

      1. **SignPath Foundation** — free for qualified OSS. Wants the public repo URL, a
         releases/download page and a project description; review from a few days to a couple of
         weeks. Note both inputs we would not have on the target path: `spintax-studio` is
         private, and there is no download page.
      2. **OSSign (ossign.org)** in parallel, a direct analogue, so one review cannot hold a
         release.

      **The decision it would force: whose name is the publisher.** SignPath shows **«SignPath
      Foundation»** in SmartScreen, not us. If that is acceptable the free route closes it; if
      the publisher must read **301ST LTD** as a verified publisher, that is **Azure Artifact
      Signing** (~$10/mo), which accepts us as a UK company, needs no hardware token and drives
      from CI through `signtool`.

      **Dead ends, with the reason each is dead** — the useful half of this research:
      **EV certificates** no longer bypass SmartScreen, which was their only purpose;
      **Sigstore/cosign** is not Authenticode, so Windows does not read it and it does nothing
      for an `.exe`; **file-based certificates** stopped being issued in 2023; a **purchased OV
      cert with a hardware token** matters only if signing for something other than Windows ever
      does. And no option removes the warning immediately — SmartScreen reputation accrues with
      the VOLUME of clean downloads, so "unknown app" shows up at first on every route.

- [x] **Privacy policy text — written 2026-08-01, `docs/privacy.md`.** Every sentence is a fact
      about the code rather than a promise: no unit in the product links an HTTP client or a
      socket, and there is exactly ONE outbound action (OpenURL on the brand link), which the
      page names rather than omits. The suite reads every shipped unit's uses clause and fails
      the build on a network unit, so the page cannot quietly stop being true.

      **Still to do: host it at a public HTTPS URL and enter that URL in Partner Center.**
      Expand it when BYOK AI (R1) adds network, and again for a managed tier.
- [x] **No purchases in R0** — no paywall, trial, or IAP; a free offline app keeps the first
      submission out of financial policy too.
- [ ] **AI disclosure + report path** — **R1+ only** (once live generative AI ships): disclose
      in listing + Partner Center, and give an in-app/listing contact for reporting problematic
      AI output. R0 ships no AI, so this obligation does not apply to the first submission.
- [ ] **Store listing** — use [`store-listing.md`](store-listing.md): honest product copy,
      screenshots of template → preview → export, and the final logo assets. Do not paste the
      developer README into the listing.
- [x] **Windows App Certification Kit** — exact candidate passed on 2026-08-03; the report and
      interpretation are recorded in [`release-validation.md`](release-validation.md).

Decisions owed **before the relevant submission** (not switchable later):
- Partner Center account type — individual vs company (company for commercial), before R0.
- **Paid managed-AI tier needs its own ADR** before any billing (R2+): Store IAP vs
  third-party purchase API (Stripe/…), prices/terms, cancellation, Partner Center disclosure.
  See spec §10/§11.

## To report to the engine

- [ ] **A directive after content leaves its LF behind when the line ends CRLF.** Measured
      2026-07-28, reduced by delta debugging from a real 116 KB template to four lines:

      ```
      Раз
                          <- blank
      #set %a% = 1
      Два
      ```

      With LF the directive is consumed whole (`Раз\n\nДва`); normalised to CRLF the output
      is `Раз\r\n\r\n\nДва` — an extra blank line, one per directive. A directive in the
      PRELUDE, before any content, is consumed whole either way, which is why every small
      example agrees and only a real document shows it.

      On the user's template — a hundred and fifty `#set` lines interleaved with `&nbsp;` —
      that is thirty-five blank lines at the top of the render, and the source view opens on
      a screenful of nothing. It was reported here twice as "the source view is broken".

      Studio's own part is fixed (the window sends the document with the FILE's endings, not
      SynEdit's platform ones — `DocText`, gated in the suite). What is left is a question
      for the engine: the family's directive splitter takes CRLF as ONE terminator, so
      consuming only the CR looks like the same class of defect as the value rtrim fixed in
      `v0.3.1`/`v0.3.2`. Needs checking against the JS reference before it is filed as a bug
      rather than a difference.

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
