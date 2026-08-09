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
      at `engine/`, pinned to tag `v0.5.1`. Clone with `--recurse-submodules`.
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
- [x] **Thesaurus for the synonym feature — LLM-only, decided 2026-08-05.** There will be no
      local base. A thesaurus answers without seeing the sentence the word lands in: not its
      sense there, not agreement, not register — and in Russian not even the morphology needed
      to put the synonym in the right form. Everything that makes a substitution usable is
      contextual, and a weak model already does it. The price, stated rather than discovered:
      **no provider, no synonyms** — the one feature in the product that does not work offline,
      and in M4 it has to read as disabled rather than broken. (spec §4.1, §4.5, §10)
- [ ] **Persistence** — keep the LLM-loop history and generated variant sets between
      sessions, or treat them as session-only. (M4 / M3)
- [ ] **Import GSA SER templates?** — an opportunity the engine opened on 2026-08-06, not a
      commitment. `spintax-win v0.4.0` ships `src/Spintax.Gsa.pas`: `SpGsaToSpintax` converts an
      existing GSA Search Engine Ranker template into this family's syntax, reports what it
      refuses in an `Unsupported` list rather than guessing, and lifts what it cannot fix in
      place — BBCode, fragment URLs, `#file[...]` — out into host variables. It sits outside
      `unit Spintax`, has its own suite, and adds nothing to the engine's public surface, so
      linking it is Studio's decision alone and costs the engine nothing either way.

      What it would BUY: an author with a library of SER templates gets them in without
      retyping, and the conversion is verified the way everything else here is — by rendering
      the result through the real engine. What it would COST: a second dialect on screen (the
      refusal list has to be SHOWN, not swallowed), converter-invented variables appearing in
      the variables panel, and a support surface for a product we do not control. Decide before
      M4 rather than during it.

## Where R0 is (published), and what `v0.1.1.0` carries (re-checked 2026-08-06)

**Published in the Microsoft Store** — <https://apps.microsoft.com/detail/9mw3ch7b530p>.
Certification passed and the listing went live on 2026-08-04 (`ReleaseDateUtc`
`2026-08-04T10:32:03Z`), free, publisher `301`, category *Developer tools*, x64, package
family `301.SpintaxStudio_jnd8jmenjzsm0`, ~2.5 MB. Tag `v0.1.0.0`; the MSIX was built from
the tagged commit by `.github/workflows/release.yml`, WACK passed against the exact
candidate, and the record is in [`release-validation.md`](release-validation.md).

**The licence changed after the release: GPL-3.0-or-later, 2026-08-04** (was Apache-2.0),
copyright holder unchanged — `301.st`. `LICENSE` is the verbatim GPLv3 text and `NOTICE.md`
carries an **additional permission under GPL v3 section 7** for the MPL-1.1 components the
executable links. That permission is not decoration: SynEdit's headers offer "GPL Version 2 or
later" as an alternative to the MPL and would combine with the GPL on their own, but **IPro's
do not** — the phrase "General Public License" appears in no file of that component, and it is
linked in for the HTML preview. The engine submodule stays MIT under its own repository;
nothing here relicenses it.

### What `v0.1.1.0` carries (nothing is submitted before it)

**Owner's decision, 2026-08-04: no separate Store update.** Two of these are listing-only edits
that need no new package, but a listing edit is still a review cycle — and spending one on two
lines of text is not worth it. Everything below goes in one submission, whenever the next
version is cut. Until then the published `0.1.0.0` and its live listing stay as they are, which
is a deliberate state and not a backlog of things anyone forgot.

1. **`0e512d3` — the horizontal splitter**, visible and grabbable; it was five pixels and sank
   into the page frame. Landed ten hours after the tag, so the build on users' machines does
   not have it. A tag is what ships: `git log v0.1.0.0..HEAD` is the running list.
2. **`LegalCopyright` in the executable's version resource** said `MIT` — a licence name in a
   copyright field, and the wrong licence. Fixed in the tree and gated by the suite; it needs a
   rebuild to reach anyone, which is exactly what the next version is.
3. **Listing, feature bullet 20** still reads "Open-source Apache-2.0 Studio". The exact
   replacement text is in [`publish/store-listing-edits.md`](publish/store-listing-edits.md) §2.
4. **Listing, "Additional license terms" — DECIDED, stays blank** (owner, 2026-08-08). An empty
   field conveys the package under Microsoft's Standard Application License Terms, which restrict
   redistribution in ways GPLv3 §10 says a distributor may not add; the owner has weighed that
   and chosen it. Recorded in [`publish/store-listing-edits.md`](publish/store-listing-edits.md)
   §3 rather than left as an open item, so it is not raised again each release.
5. **The 301ST mark in the status bar**, done 2026-08-04 — a link to <https://301.st> at the
   right end, opposite the spintax.net ribbon on the rail: the company in one corner, the
   language and engine family in the other. The glyph is generated into the executable by
   `scripts/make-companymark.py` from `assets/brand/301.svg`, sliced to the system ink because
   the status bar is the one strip the theme never touches.

   **It is the window's second link, so the privacy policy's list changed with it** — and the
   policy now draws the line the old wording smudged: a link is not a network request. The
   application opens no socket at all; clicking a mark hands an address to Windows, and the
   browser is what visits the site, exactly as if the address had been typed. `docs/privacy.md`
   names both marks and says that in as many words; the suite's count moved from one to two in
   the same commit, which is what the count is for.

   **The policy is published in TWO places and BOTH are wrong today** — read on 2026-08-08,
   not assumed. This entry used to say "republish the hosted copy", which is not enough and
   reads as if one action closed it:

   - <https://spintax.studio/privacy.html> — *"There is **one** external action: clicking the
     spintax.net mark in the tool rail…"* Owner republishes.
   - **the listing's `PrivacyUrl` is NOT that page.** It is a frozen Microsoft snapshot,
     `https://cdn.storeedgefd.dsx.mp.microsoft.com/eus2/privacy-policy-storage/…/privacy_policy_5736d213-….txt`,
     fetched and read: it carries the same one-link text. That is the copy a Store customer
     opens, and it changes **only** through the Partner Center field at submission. Republishing
     the site does not touch it.

   The contact line differs across all three copies as well — `docs/privacy.md` says
   `support@301.st`, both published copies say `https://301.st/contact`, and the live listing's
   `SupportUris` is `https://spintax.net`. **`support@301.st` is the owner's choice** (2026-08-08)
   and becomes the published contact at submission; confirm the mailbox is live before it does.
   The `SupportUris` difference stays an owner decision at submission, not a defect to fix here.

6. **The engine moved to `v0.5.1`**, 2026-08-07 (was `v0.3.3`, which is what R0 shipped
   against; `v0.4.0` and `v0.4.1` were each pinned for part of the day — see below). Nothing Studio can see changed, and that was checked rather than read off a
   changelog: the engine's whole `interface` section is byte-identical between the two tags.
   What is inside is a render speed-up — 64 KB of plain text carrying no spintax went from
   15 ms to 2.5 ms by the engine's own measurement, which is the live preview's exact path —
   and `src/Spintax.Gsa.pas`, an optional converter that is **not** part of `unit Spintax`.
   The suite is green on the new engine in both binaries, and the help documents' claim that
   their examples were rendered by a named version was re-pointed at `v0.4.0`, which the
   example gate had just re-proved by running every one of them again.

   **And then `v0.4.1`, because an outside review found `v0.4.0`'s converter defective** —
   which this suite could not have caught, since it only ever imported a single
   `#file[l.txt,…]`. Two defects, both reproduced here before they were believed:
   `#file[A.txt,1,S]` and `#file[a.txt,1,S]` shared one variable and rendered as `A.txt`
   twice — a SER template pulling from two lists came back pulling twice from one; and
   partially overlapping tag sets (`{#A a|#B b}` then `{#A c|#C d}`) were translated as
   independent groups instead of refused. Both are Studio checks now, and both were proved to
   FAIL on `v0.4.0` by putting the submodule back on it. The engine proper is unchanged
   between those two tags; only `Spintax.Gsa` moved.

   **Then `v0.5.0`, and this one changes behaviour Studio documents.** The interface only GREW
   — nothing removed, and `SpCompile` / `SpRenderCompiled` / `TSpTemplate` / `ESpintax` added —
   but an unterminated `/#` is ordinary text now where it used to swallow the document. Four
   checks failed on the bump and every one of them was right to: two gated help examples that
   documented the old rule, and two group-editor checks. The editor itself needed no change,
   because it decides by reading an edit back through the engine: it now accepts
   `#set %x% = A /# oops` in a document with no `#/` (the value means itself) and still refuses
   it in a document that has one further down (the pair would eat the group). Help rewritten to
   the measurement, including the counter-example that shows what the pairing costs.

   **`SpCompile` is not adopted yet and is worth its own slice:** parse once, render many. By
   the engine's own timing, building and destroying the node tree is 84% of an article's
   render, and this window rebuilds it on every keystroke of the preview and once per variant
   in a batch. Both are exactly the shape that API is for.

7. **GSA SER import**, done 2026-08-06 — off by default, `View` → `GSA import` reveals
   `File` → `Import GSA template…`. Editor-core in `src/SpxGsaImport.pas`, gated without a
   window; the window half is a setting, a menu item and a summary that names every refusal.
   **A converted template renders with the cosmetic stage off** (spec §4.7), carried as data
   from `TSpxGsaResult.PostProcess` through `TSpxContext` to the job. The lifted values are
   session variables and are not saved with the document — the dialog says so, and so does the
   help.

8. **`.spintax` is claimed as a file type**, added 2026-08-06 — declared in the manifest, not
   written into the registry, which is what the MSIX path is for: the association appears on
   install, goes on uninstall, needs no elevation, and passes certification. Nothing in the code
   had to change, because the window already opens a path handed to it on the command line
   (`SpxMainForm.pas:559`). MakeAppx accepts the manifest and the package builds.

   **The file's icon is the app's own logo, and that is fine.** The "app and document should
   look different" convention is weak for a Store app: the executable lives in `WindowsApps`
   and never sits in a folder beside the reader's templates, so there is nothing to confuse it
   with. No new artwork is owed.

   **What IS thin is the asset SET, and it is polish rather than a defect.** The manifest points
   at one `Square44x44Logo.png`, the package carries no `resources.pri` (11 entries: manifest,
   exe, seven PNGs), so a `targetsize-256` variant would simply be ignored — Windows takes the
   literal path. Explorer draws a file icon up to 256 px in the extra-large view, where a 44 px
   source is scaled almost six times. Compared side by side against a fresh vector render: the
   upscale is soft at the edges and the mark sits slightly small, but the flat geometry and
   heavy outlines hide it well, and 16/32/48 — every list and details view — are unaffected.
   **Not worth changing the packaging pipeline for now:** that pipeline produced a certified
   package, and adding MakePri means re-running WACK for a gain confined to one view. When it
   is done, do it whole — targetsize 16/24/32/48/256 rendered from the vector, plus the PRI.

   **A second double-click opens a second window, and that is the right answer, not a gap.**
   Studio is single-document: one window, one template. Handing the file to a running instance
   would mean either replacing the open document — losing the reader's place and prompting about
   unsaved work — or growing tabs, which is a different product. Closed rather than open.

   **Not verified end to end yet:** proving the double-click opens Studio needs the package
   installed locally, and this package's identity is the one the Store copy already has. Worth
   doing deliberately, on the owner's say-so, rather than as a side effect of a test.

9. **The Store tile was off-centre**, corrected 2026-08-06. `spintax-mark-310.png` — the file
   `make-msix.py` builds the `310x310` and `310x150` tiles from — had the mark at the top left of
   its canvas: 212×244 of ink in 310×310, margins L19 R79 T3 B63. The published package carries
   it; the corrected tile ships with this version. The `.ico` was never affected (it is built
   from `spintax-mark-180.png`, which is centred), and the app icon's own complaint was a
   different thing entirely — Windows drawing a smaller frame in the corner of a bigger cell,
   fixed by emitting the sizes the shell asks for.

10. **The help got a document about the PRODUCT**, done 2026-08-06, and it is now the first
   thing in the contents. Until then the help described the LANGUAGE and the DIAGNOSTICS and
   never the program: a reader who opened it was told how to read an example before being told
   what the two panes are. The reader's complaint, in as many words. `docs/help/{en,ru}/studio.md`
   covers the panes, the panels, the group editor, the settings and the GSA import, and its one
   example is gated like every other — which caught both of them being wrong the first time
   (`{Hi|Hello} there.` renders `Hi there.` under the fixture, not `Hello there.`).

   Also learned, and now obeyed: **`→` in this help means "and the engine returned", so it
   cannot appear in prose.** Menu paths written `View → GSA import` were read by the suite as
   ungated examples and failed the build, which is the check working.

11. **The About box says what the product is**, done 2026-08-06. It was the attribution notice
   and nothing else — the reader's words were "it tells you nothing about the product and looks
   broken, just technical" — and all three causes were in this repository rather than in
   NOTICE.md: the loudest thing on screen was the audit rubric `REQUIRES ATTRIBUTION IN THE
   SHIPPED APPLICATION` in capitals; the text was wrapped once in the file and again by the
   memo, which is what stranded `SynEdit and`, `IPro)` and `glyphs.` on lines of their own; and
   nothing said what Studio does. The box now opens with a sentence **in the reader's own
   language** (`sAboutWhat`, all fourteen), then the licence and the two addresses, then the
   notice in full on the same screen — a second click would weaken an obligation NOTICE.md
   states in as many words.

12. **The variants panel says how many variants the template can make**, done 2026-08-07 — the
   GTW number, *«Max возможных вариантов»*, beside the count you are asking for. `src/SpxCount.pas`
   computes it from the editor's OWN token scan (`SpxTokens`), so a construct is whatever the
   highlighter and the group editor already think it is, and no second parser exists to drift.
   It runs on the engine thread with the render, because counting reads the directive prelude
   through the engine.

   **Cost, measured against the render of the same document rather than in isolation** — which
   is the only comparison that decides anything, since both run in one job:

   | document | render | count | on top |
   |---|---|---|---|
   | 8 KB, 200 choices | 4.5 ms | 0.6 ms | 14% |
   | 78 KB, 2000 choices | 45 ms | 8.9 ms | 20% |
   | 86 KB, no constructs | 42 ms | 3.8 ms | 9% |

   (Re-measured after the second review's fixes, which cost about a millisecond on the middle
   row: one `Pos` per line for the loose-`#include` detector.)

   **No cache, and that is a measurement rather than a preference.** The count started at
   18.2 ms on 100 KB and is 8.2 — the saving came from deleting a redundant engine pass, not
   from remembering answers. What is left is 6–16% on top of a render, and a memo could only
   skip it on a job whose document has not changed — a reroll, a seed change, a fragment
   preview — every one of which pays the full render anyway. A cache there would buy a tenth of
   a job it cannot skip, in exchange for three invalidation conditions (the text, the session
   values, the template set) that are exactly where a stale-cache bug lives. Worth revisiting
   only if the engine's render gets much cheaper than the scan, which is the opposite of the
   direction it has been moving.

   **Every rule in it was settled by ENUMERATION, not by reasoning**, and that is what the
   suite does too. Counted from `TestVariantCount`, not estimated:

   - **31 `CheckCounted`** — rendered with 20 000 seeds through the real engine, distinct
     outputs counted, arithmetic must equal them;
   - **9 `CheckFloor`** — also enumerated, but asserting the promise rather than the number:
     when the panel says *at least N*, `N ≤ what the engine really makes`, and the answer must
     not claim to be exact;
   - **13 `CheckSays`** — a written-down number, for the cases that cannot be enumerated by
     construction: where a variant and a distinct text differ on purpose (a `#def`, `{a|a}`),
     and the saturation ceiling.

   *(This paragraph has now been wrong TWICE about its own arithmetic — "twenty" when there
   were 16, then "25 and 15" when there were 29 and 14, in the sentence scolding the first
   miscount. Both times a reviewer counted and I had not. A claim about the evidence is a claim
   like any other, and the reason it kept slipping is that it was written from memory of what I
   had just added instead of from the file.)*

   Four of the first nine answers were wrong and the enumeration said so — `[a|b|c]` is 6 and
   the counter said 24, `#set` used twice is 4 and it said 16. The permutation is not `n!` once
   its options carry variants: it is `Σ k!·e_k`, the elementary symmetric polynomial over the
   option counts, which also gives the 12 of `[<minsize=2>a|b|c]` for free.

   **What it will not promise, and says so.** A conditional, a plural, an `#include` the set
   has not got, and now any include the scanner and the engine disagree about, are each decided
   by something other than chance: each counts as one and the panel says *at least*, because
   supplying a value can only add. The ceiling is a trillion and reads *at least* for the same
   reason. And what is counted is a VARIANT — one filled-in template — which is not the same as
   a text that reads differently: `{a|a}` is two variants and one text, recorded as a check so
   it is a decision rather than a bug someone finds later. The API comment claimed "distinct
   texts" until the review read it against that check.

   Three defects found before review, all by measurement and each worth its line: a "counts are
   never zero" guard in the multiply made `e_k = 0` behave as 1 and inflated every permutation;
   the directive prelude was counted as body text; and offsets rebuilt by adding line lengths
   were one byte short per line under CRLF, so every `%x%` after line one was read past its
   start and the macro was never found. The last passed a probe written with `#10` and failed
   the suite written with `LineEnding` — a document with the line ending the APP will hand it,
   or the measurement is of a file nobody has. The counter now carries each token's text and
   has no offsets at all.

   **And five more the FIRST outside review found, every one reproduced before it was
   believed** — worth recording as a class, because the suite was green through all of them and
   each is a template the author of the counter did not think to ask about:

   1. **Session values were skipped entirely.** A reader who types `{aa|bb}` into the Variables
      panel doubles the template, and the counter ignored runtime variables by name. Worse, a
      session value **outranks** a same-named `#set`: the engine lays the host's table over the
      definitions (`Spintax.pas:3145-3151`) and never rolls a `#def` the host has named. So the
      counter was reading a value the render would not use.
   2. **The permutation's size range is four asymmetric branches, not one rule.**
      `Spintax.pas:1830-1837`: only-maxsize starts at **one**, `minsize=0` is a value rather
      than an absence, and a contradictory pair **widens** to the whole set. The first version
      folded all four into "absent means n" and clamped the wrong end — 6 for
      `[<maxsize=2>a|b|c]` where the engine makes 9, 6 for `[<minsize=0>a|b|c]` where it makes
      15. Now copied from the engine's source, with -1 for absent for the same reason it is
      -1 there.
   3. **`#def` was multiplied into the option it was written in.** The engine rolls every
      definition once, before the body, dependencies first, used or not
      (`Spintax.pas:3162-3184`) — so it multiplies the DOCUMENT. Written the old way,
      `{%d%|%d%}` came out 3: neither the four draws there are nor the two texts that emerge.
   4. **Masking the directive prelude by editor LINE broke the five-terminator model** — the
      charter's own "two line models" trap, walked straight into. `#set %x% = qq` U+2028
      `{aa|bb}` is a directive and a choice on one editor line, and blanking the line threw the
      choice away. The engine reports each directive's span, so the span is what is masked now,
      code points converted to bytes.
   5. **An `#include` whose target sits on the next line is invisible to the token scan** and
      resolves perfectly well in the engine — 2 counted where 6 exist, and called exact. Fixed
      not by teaching this file a second rule about where a target may sit, but by counting the
      occurrences the ENGINE reports and comparing: they disagree, the answer becomes a floor.
      That holds for every future divergence, not only this one.

   The sixth finding was that `src/SpxCount.pas` was never `git add`ed — the one defect no
   amount of testing would have caught, since every gate ran on the working tree.

   ▁▁▁

   **A SECOND review, on the fixed code, found six more — and they share ONE root cause worth
   more than the list.** `SpxTokens` is a PRESENTATION scan, and its own header promises only
   that it will never claim a construct the engine does not see. It promises nothing in the
   other direction. This file took "no second parser" as a guarantee of agreement when it is
   only a guarantee of one-sidedness, reconciled exactly one divergence (`#include`
   occurrences) and read every other scanner opinion as engine truth. All six, reproduced
   before they were believed:

   1. **An unterminated `/#` deleted the rest of the document from the count and still said
      *exact*.** The engine changed here in `v0.5.0` — the charter records it — and an
      unterminated opener is now ordinary text; the scanner still swallows to end of document.
      This is not an edge case: it is the state of the document for every keystroke between
      typing `/#` and typing `#/`. The scan's own final state (`InComment`) says when it
      happened, so the answer is a floor now.
   2. **A `#def` inside an INCLUDED fragment was rolled once for the whole document.**
      `ResolveIncludes` renders the whole template again per occurrence, so the fragment's
      definition rolls once per include — and two fragments that both define `%d%` are two
      different macros. One flat name-keyed list across the recursion answered 2 where the
      engine makes 4, and 2 where it makes 6. The scope now belongs to the document, and an
      included fragment is one. *The suite's own `include-twice` used a fragment with no `#def`
      in it, which is exactly why it was green.*
   3. **A closer of the wrong kind was accepted.** `[a|b|c|d|e}` reported **120 exact** for a
      template the engine prints verbatim as one text. `SpxTokens.SpxMatchBracket` is careful
      about mismatched kinds; the walk was not.
   4. **The documented floor was not a floor.** `#include "f" junk` is not an include (the
      engine's anchor allows only trailing whitespace) and renders as one literal line — the
      counter resolved the fragment anyway and said *at least 2* about a document that makes 1.
      A floor above the truth is worse than no floor. The reconciliation now runs BEFORE the
      walk and, when the scanner and engine disagree about how many includes exist, no include
      is resolved at all.
   5. **An `#include` can resolve without being a directive in the source.** `ResolveIncludes`
      runs over the RENDERED text, so `{pp|#include "f"}` resolves when that option is drawn —
      the engine reports no directive, the scanner sees plain text, the two agree, and both are
      looking at the wrong thing. Nothing short of rendering settles it, so what is detected is
      the possibility: body text carrying the word. A commented-out `#include` is a COMMENT
      token and does not trip it, which is the case that rules out a plain textual search.
   6. **A conditional threw away its branches' CONTENTS, not just the branch selection** — a
      document wrapped in one `{?lang?…|…}` reported "at least 1" however large it was. The
      biggest branch is the honest floor: some value selects it. **And the first version of
      that fix treated a plural the same way and was wrong** — measured: a plural form holding
      a construct makes the engine refuse the whole thing and print the source verbatim, one
      text, where the same shape written as a conditional makes two. The suite caught it in one
      run *because the floor is enumerated rather than written down*, which is the argument for
      `CheckFloor` existing at all.

   Two wiring defects came with them. **With the help open, the Variants panel showed the help
   example's count** — or "Possible variants: 1" before anything was clicked — beside a Generate
   button still generating from the reader's document; `Res.HelpSet` is the guard `ShowOffer`
   and `ShowVariant` already carry, for the same "two routes into one pane" reason. And the word
   **"texts"** had crept back into four places after the first review took it out of the unit
   header, including this item's own heading.

   Also fixed while in there: a macro chain past the engine's `MAX_VARIABLE_DEPTH` of 50 was
   over-counted (the guard costs nothing — the expansion stack IS the depth), and
   `PermutationCount` ran its inner loop over the full range where `e_k` is still zero, which
   was 101 ms at 3 000 options.

   **A seventh turned up while fixing the third**, and it belongs with them: a REDEFINED macro
   was counted from its FIRST definition and the engine takes the LAST — 2 against 3 for a
   two-line document. It was there because the counter asked `SpxExtractModel` for its macros,
   and that structure exists for the PANEL: flattened, deduplicated, ordered for a grid. The
   engine keeps `#set` and `#def` in separate maps, each last-wins, and lays the definitions
   over the sets — so a `#def` beats a `#set` of the same name whichever order they are written
   in. Building the table from the directive list directly fixes it, satisfies the charter's
   "values come from `SpExtractDirectives`" more exactly than the wrapper did, and removes the
   second whole-document pass that made it slow. *«Разве нельзя переопределять переменную?» was
   the first question a reader of this project ever asked* (2026-07-29), which is a fair measure
   of how exotic the shape is.

   Shown in the top strip's second half, which the progress line owns during a run: the two are
   never wanted at once. Measured on screen in both languages and in all three states — exact,
   *at least*, and mid-run — not read off the properties.

13. **The engine moved again, to `v0.5.1`** (2026-08-07, `621383d`). **API: nothing** — the
   `interface` section is byte-identical to `v0.5.0`, checked the way this project always checks
   it rather than read off a changelog. The engine reports corpus PASS=230 FAIL=0 SKIP=4 and
   a local suite of 474 in both builds; the eight cases the previous pin failed are the changes
   below. Drop-in to build, and NOT drop-in to what the window says:

   **The permutation config, which Studio mirrors in `SpxCount.ReadPermConfig`.** Three rules
   moved and the counter was a release behind on all three the instant the submodule advanced:
   the `=` after a key is now REQUIRED (`[<sep="-" maxsize 2>a|b|c]` used to cut the set to two
   and now prints all three), the whitespace around it is JS `\s` within ASCII rather than
   space-and-tab, and a failed candidate RETRIES at the next position the way a regex does
   (`[<minsize foo minsize=1>…]` finds the second one). **And two more were wrong before the
   bump, which neither review caught:** the counter mirrored the engine's `FindInt` and not its
   `HasConfigKey`, so a `<...>` with no real key — `[<maxsize 2>…]`, `[<xmaxsize=1>…]` — was
   read as a config where the engine reads it as a separator and prints every option. Mirroring
   a rule means taking on the gate that decides whether it applies, and the warts too: a key
   word inside a quoted separator really is a key to the engine, and `[<sep="maxsize=1">a|b|c]`
   is 3 on both sides. Ten checks now gate this, all enumerated.

   Found in passing, and it is the same class one level down: a permutation config split across
   lines (`[<minsize` LF `=2>a|b|c]`) is 12 to the engine and 6 here, because the scanner wants
   the closing `>` on the line it started — its own documented approximation. The tell is exact
   (the token after `[` opens an angle bracket it does not close, where real HTML content closes
   its own), so that one is a floor now rather than a wrong promise.

   **The diagnostics moved, and there nothing needed fixing except a sentence.** False
   `set.malformed` / `def.malformed` after a VT, NUL or lone CR are gone; a name defined twice
   now resolves to the LAST definition, which moves `variable.self-reference`,
   `variable.circular-reference` and `plural.count-macro` in both directions; and a circular
   reference is reported once per REFERENCE that closes the circle rather than once per
   definition — `#set %x% = %y% %y%` against `#set %y% = %x%` is three errors, two of them on
   the first line, anchored on the surviving definition. **Studio's panel was already right**:
   `SpxPanelRows` sorts stably and deduplicates nothing, so two findings on one character stay
   two rows. What was wrong was the help, which said in both languages that the panel draws a
   row *for each definition in the circle*. Measured, then rewritten — not adjusted to match the
   code, because the engine is what the sentence is about.

   `tests/SpxJson.pas` is the engine's own harness and Studio does not build a corpus runner, so
   that part of the release is not ours.

14. **The include target on a later line is read** (2026-08-07) — the last known gap in the
   scanner, and it closed the counter's own debt with it. `#include` on one line and `"frag"` on
   the next is one directive to the engine; the editor now colours that target, and the variant
   count for such a document is exact instead of *at least*. The keyword itself stays plain and
   always will: a forward-only scan cannot confirm a directive whose end it has not reached, and
   SynEdit does not re-paint a line backwards. The help says so in both languages, in the
   section that already explained why a mid-line `#include` is not one.

15. **The help was reviewed by MEASUREMENT before being translated** (2026-08-07), because a
   wrong sentence translated twelve times is thirteen wrong sentences. Only arrow examples are
   gated; roughly 150 declarative sentences were checked by nothing at all. Every claim that
   could be rendered was rendered, at each document's own fixture, and the verdicts follow.

   **Wrong, and corrected from the measurement:**

   - **The provenance line named `spintax-win v0.4.0`** — in all four of
     `{en,ru}/{syntax,diagnostics}.md`, in the sentence whose whole job is to tell the reader
     the examples are real. Two engine bumps went past it. It no longer names a version at all:
     the examples are re-rendered by the suite on every build, so what is true forever is *"run
     through the engine this copy ships with, every time the program is built"* — and the
     version itself is one click away in About. **A fact that must be edited on every bump is a
     claim that will go stale again**, which is the general form worth keeping.
   - **"A `<…>` block holding no `=` is the separator itself"** — false in both directions, and
     in both languages. `[<xmaxsize=1>…]` holds an `=` and is still the separator;
     `[<maxsize 2>…]` holds a key and no `=` and is also the separator. The rule is a KEY, at a
     word boundary, followed by `=`. Rewritten with both traps as examples — and the second one
     turned up something the document had never said: the panel calls `xmaxsize` an unknown key
     while the render treats the whole block as a separator. The diagnostic and the output are
     answering different questions.
   - **EN said "URLs, e-mail addresses, bare domains and decimal numbers are shielded"** with no
     qualification, where RU has said *латинские* for weeks. Measured: `сайт.рф` comes out
     `Сайт. Рф`, and `т.е.` comes out `Т. Е.`. The word-boundary check is ASCII
     (`Spintax.pas:1836-1840`). EN now carries the limit, in both places it belongs.
   - **EN's "46 entries, most of them Russian"** is true and vague where RU is exact. Counted
     from `Spintax.Unicode.inc`: **46 entries, 29 Cyrillic, 17 Latin.** EN now says 29.
   - **"A `minsize` above the `maxsize` is accepted without a word"** stopped there, which
     invites the wrong inference. The floor wins: the ceiling is raised to meet it. Shown.
   - **`permutation.unknown-key` described only the rarer case.** An unknown key ALONE makes the
     whole block a separator; an unknown key BESIDE a real one is simply dropped and the config
     is obeyed — `[<sep=", ";foo=1>a|b|c]` gives `B, c, a`, with the same diagnostic. That is
     the likelier mistake and the document had the reader expecting the other outcome.
   - **`note.cycle` never said which file its row is against.** It is the fragment's, so nothing
     is underlined in the open document.
   - **Two closed enumerations in the product guide were short.** Settings named six of the
     eleven things the app actually remembers (`SpxSettings` writes lang, lang.follow,
     rail.right, preview.source, gsa.import, panel, font.size, font.family, slide.width,
     help.width, theme); export named two of its three buttons.

   **Ungated claims turned into checked bytes.** The generator has always supported multi-line
   templates, which nobody had used for this: the split-line `#include` block added days earlier
   was a behavioural claim shown as a fence with no arrow, and is now
   `#include` / `"frag"` → `Fragment`, compared byte for byte. Same for `[<and>red|green]`, which
   was asserted inside a sentence. Proved the new gate bites: changing that expected output to
   `(empty)` fails exactly one named check and nothing else.

   **Right, and left alone — which is most of it.** Plural arity per locale (en 2; ru, uk, be,
   sr, hr, bs 3); `maxsize` above the count quietly reduced; the fragment's `variable.undefined`
   reported against the fragment at line 1 with no squiggle in the document — all three parts;
   a `#set` count giving `plural.count-macro` and an empty render; a wrong arity printing the
   construct back in wide braces; `set.malformed` and `def.malformed` each drawing two rows;
   `definition.duplicate-name` pointing at the second definition; `note.case-mismatch` drawing
   both a note and an error; `#def` as a count drawing nothing at all; an untaken branch costing
   no random draw (measured with a counting RNG: `{Lite|{Plus|Max}}` takes exactly one);
   one include row per occurrence; exact target matching; comments removed before anything else,
   not nesting, and keeping the logical line open.

   **One finding was mine and wrong.** The document says a tagged separator "under another seed
   answers `One br two`" — an output that is honest, flagged as another seed, and therefore not
   a defect. It gained a companion that shows the behaviour at this document's own seed instead
   of describing an unreachable one.

16. **The help machinery stopped assuming two languages** (2026-08-07), which is the thing that
   had to happen before the first translation rather than during it. Five places in the suite
   were written when two was the only number there could be, and they failed in two opposite
   ways — which is the part worth keeping:

   - `if code = 'en' then 47 else 54` **does not fail for a third language.** It hands it
     Russian's number and passes. A wrong pass is worse than a red build, and this shape had it.
   - `WANT: array[0..1]` **skips** a third language instead, so its silences chapter would have
     had no ratchet at all and nobody would have known.

   Both are now one table keyed by the language's own code — `HELP_LANG_FACTS`, with the clean
   example count and the silences count — and a language with no row fails **by name**. Proved
   by deleting the Russian row: three named checks go red, none of them silently borrowing
   English's numbers. The count of registered languages is derived from the table's length; the
   fallback loop asks the shipped unit which languages have their own document instead of naming
   `en` and `ru`; and the search check looks its page up by slug, where it used to assert index
   `3` and would have followed whichever chapter slid into that position.

   **`ENGINE_CODES` is now held against the engine.** It is spelled out by hand on purpose — a
   list derived at runtime would move whenever the engine did, silently, which is the opposite of
   a ratchet — but a hand-written list has its own hole: a code the engine gains and nobody
   transcribes is enforced NOWHERE, and the first sign would be a reader double-clicking a
   diagnostic row and landing on the contents page. The suite reads `engine/src/Spintax.pas` as
   text and compares in both directions. Proved by removing one entry: it is named exactly.

   *The first version of that scanner walked the file pairing quotes, and the engine's source is
   mostly PROSE — its apostrophes ("does not", "the engine's") desynchronised the pairing at the
   first one. It found 6 codes of 17 and reported the other 11 as dropped, which reads exactly
   like a real regression. What it looks for now is a run of the code alphabet with a quote hard
   against each end, which needs no pairing and cannot drift.*

   **And the generator now refuses mismatched prose headings.** Its cross-language check compared
   the CODE anchors per section and let the positional ones (`slug-0`, `slug-1`) differ — so a
   section with three prose headings in one language and two in another gives the same id to
   different paragraphs, and a reader switching language lands on the wrong one, silently, since
   the id resolves. Never seen with two languages written together; a matter of time with twelve
   translated later. One comparison, with a message naming both files.

   What is deliberately KEPT is the all-or-nothing rule: a language is registered with all three
   documents running parallel, or it is not registered and falls back to English. That is what
   makes a half-translated document impossible, and it is the intended pressure.

17. **The help now answers in all fourteen interface languages** (2026-08-07). Twelve folders
   added after the machinery was fixed, one at a time, each costing exactly what item 16 promised:
   a folder of three documents, one entry in `LANGS`, three `HELP_DOCS` rows and one
   `HELP_LANG_FACTS` row. No test needed editing for any of them.

   **Every document was MEASURED, not translated.** Each language's arrow examples were rendered
   through the pinned engine before a word was written, which is the only reason the silences
   chapters disagree with each other — and they disagree a lot, because the engine's abbreviation
   list is 46 entries of which 29 are Russian and the word-boundary check is ASCII
   (`Spintax.pas:1836-1840`):

   - **Latin script is shielded and Cyrillic is not.** Croatian and Bosnian get `dr.`, `prof.`,
     `mr.` from the Latin half, `d.o.o.` from the multi-dot form, and `stranica.hr` and even
     `jedan.dva` untouched as bare domains. Ukrainian, Belarusian and Serbian get none of that:
     `т.д.` comes apart into `Т. Д.`, `сайт.бел` into `Сайт. Бел`.
   - **Serbian sits on the boundary and shows it best.** `г.`, `ул.`, `стр.`, `тел.` shield
     because they coincide with the Russian half; `бр.`, `нпр.`, `итд.`, `тзв.` do not. And
     `dr.` shields while ћирилично `др.` does not — one word, two scripts, two behaviours.
   - **Turkish's silence is the most visible of the fourteen:** `i` uppercases to `I`, not `İ`.

   **The measurement also caught a false claim in three documents I had just written.** The
   `set.malformed` article says the mistake puts TWO rows in the panel; that is true wherever the
   example uses a Latin name and false where it uses a Cyrillic one, because a Cyrillic name is
   not a variable and the second row never appears. Measured `[set.malformed]` alone against the
   claimed pair, in uk, be and sr. The examples now use a Latin name, as ru already did.

   It was PROSE, not a gated example, which is why it survived being written three times — the
   same class the charter records twice already. The gate compares the bytes on either side of an
   arrow and nothing else; a sentence beside one is still on trust.

**Not on the list, and not an oversight:** the listing's website and support URI both point at
`spintax.net` rather than the `spintax.studio` and `301.st/contact` the draft asked for. Owner's
decision, 2026-08-04 — the site at `spintax.studio` is not ready to be the address a Store
listing sends people to, and `spintax.net` is fully working. Leave it until that changes.

The block below is the state as it stood going in, kept because item 4 is still live:

The product scope is closed: M0, M1, M2 and M3 are complete. The built-in help and About box
are part of the application, and the current release is deliberately **Windows-only,
offline-only and without generative AI**. The remaining work is submission preparation, not
another product milestone:

1. ~~Run the release gate on the exact candidate.~~ **Done 2026-08-03.** Suite green in both
   binaries, x64 GUI built, MSIX packed and validated, WACK passed. Store artwork is rendered
   into `assets/store/`, which is gitignored: Partner Center reads it, the build does not, and
   `assets/brand/` is the tracked mark it derives from.
2. ~~Finish the Partner Center draft.~~ **Done — the listing is live.** Identity matched,
   category *Developer tools*, IARC rating ESRB *Everyone*, the copy and features from
   [`store-listing.md`](store-listing.md), screenshots uploaded, and the privacy policy hosted
   at <https://spintax.studio/privacy.html>. Two listing fields ended up different from the
   draft — see the *What the live listing actually carries* note there.
3. **Run Windows App Certification Kit (WACK)** against the release package. **Done
   2026-08-03:** the exact MSIX candidate passes WACK with no partial run. The optional
   blocked-executable test reports the deliberate browser launch and SynEdit's `&reg;`
   entity string; see [`release-validation.md`](release-validation.md).
4. **Keep the accessibility declaration off for R0.** Keyboard access, high contrast and
   hints are useful improvements, but `docs/accessibility-baseline.txt` shows that the main
   editor text and diagnostic controls are absent from the UI Automation tree. The declaration
   would therefore overstate the tested experience. UIA text support for SynEdit is a post-R0
   slice, not a release blocker.

Not R0: M4 and the managed AI tier, persistence for the LLM loop, the other help
languages, RTL, the mini-context strip, the help silence whitelist, and the rename refactor.
(A thesaurus stood in this list until 2026-08-05; it is not deferred, it is dropped — see the
open decisions above.)
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

- [x] **Highlighter gap — an include target on the following line.** **Closed 2026-08-07**,
      and the shape of the fix is the interesting part: the continuation flag went into
      `TSpxScanState` at bit 18 as planned, but the *un-painting* half of the plan turned out
      to be impossible and unnecessary in the same breath. SynEdit scans forward and never
      re-paints a line backwards, so a keyword painted optimistically on line one cannot be
      taken back when line two turns out to be prose — there is no un-painting to write.

      So the keyword stays plain **permanently**, by decision rather than by omission, and the
      TARGET is what is now claimed once it arrives. That is the half that carries the meaning
      (which file), the half the diagnostics already underline, and the half `SpxCount` needed:
      a document with `#include` LF `"frag"` used to be a lower bound because the counter could
      not see the include, and it is exact now. The file's contract survives intact — it still
      never claims a construct the engine does not see, and it is still allowed to miss one.

      Measured and deliberately NOT followed: the engine strips comments before it looks for
      directives, so `#include` LF `/# c #/ "frag"` and `#include` LF `"frag" /# c #/` are real
      includes to it. Claiming those would mean running the comment scanner inside the
      decision, and an unterminated comment carries the question onto further lines. They stay
      a floor. Twelve scanner checks and six counter checks gate the boundary; the old pin
      `scan/include-target-on-the-next-line-is-a-known-gap` is gone, replaced by
      `scan/include-target-on-the-next-line`, which asserts the opposite.
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
      the same layer — **and only through it**, since the thesaurus was dropped on 2026-08-05.
      Keys local, zero telemetry. The provider is therefore the difference between a feature
      that is off and one that is missing: with none configured, synonyms and the loop are
      disabled controls with a reason attached, and everything else in the window still works
      with no network at all.

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

- [x] ~~**СПРАВОЧНИКА ЯЗЫКА НЕТ**~~ (закрыто выше) — и это, а не следующая UX-мелочь, была самая большая дыра R0.
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

- [x] ~~**ОКНО «О ПРОГРАММЕ» — план, 2026-07-30.**~~ (сделано выше) Меньше по объёму и обязательно до первой
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

- [ ] **Остальные одиннадцать языков.** *(Немецкий — первый из двенадцати — готов 2026-08-07.)* Решено: язык может отставать **целыми документами, но не
      внутри одного** — проверка «на каждый код по статье» делает полудокумент невозможным по
      построению. Просмотрщик обязан честно сказать, на каком языке показывает.

## The Store says this application speaks one language. It speaks fourteen.

- [ ] **`<Resources>` in the manifest declares `en-us` and nothing else, so the listing
      advertises English only.** Measured on 2026-08-09, inside the package that was being
      submitted as `v0.1.1.0` — not from the draft, from the artefact:

      ```
      AppxManifest.xml   ->   <Resources><Resource Language="en-us" /></Resources>
      resources.pri      ->   absent (the package has 11 entries: manifest, exe, seven PNGs,
                              the block map and the content types)
      storefront JSON    ->   SupportedLanguages = ["English (United States)"]
      ```

      The window has spoken fourteen languages since long before R0, and the help has answered
      in all fourteen since 2026-08-07. **This is not a missing feature, it is a false claim
      about the product on its own storefront** — the same class as `LegalCopyright="MIT"` and
      the Apache-2.0 feature bullet, and it costs the same thing: a reader searching the Store
      in their own language never finds an application that would have answered them in it.

      Nothing caught it because nothing compares the manifest to `gui/lang/`. The suite already
      counts the fourteen language tables and the fourteen help folders and holds them to each
      other; the manifest is the third place that fact lives and the only one outside the gate.

      The work, in order:

      1. ~~`packaging/AppxManifest.xml.in` — one `<Resource Language="…" />` per shipped
         language.~~ **Done 2026-08-09:** fourteen entries, `en-us` keeping its region and the
         other thirteen as bare subtags, with the reason in a comment above them.
      2. ~~**A gate between them**, or item 1 rots the day a fifteenth language lands.~~
         **Done 2026-08-09:** `CheckManifestLanguages` in the suite reads
         `packaging/AppxManifest.xml.in`, folds each tag to its primary subtag and compares the
         set with `SpxLangCode` over `TSpxLang`. Proved in both directions — removing `tr` from
         the manifest names it as missing, adding `ja` names it as extra.
      3. Decide whether a `resources.pri` is needed at all. The strings are compiled into the
         executable, not into MRT resources, so the declaration may be enough on its own —
         **measure it, do not assume**: build the package, install it, and read
         `SupportedLanguages` back from the storefront JSON after the submission goes live.
         Adding MakePri means re-running WACK, which the icon-asset note below already weighs.

- [ ] **Localised Store listings.** Declaring the languages is half of it; the listing itself is
      English-only. A customer whose Store is set to German sees an English description for an
      application whose window and help are both German.

      Fourteen listings is not the obvious answer — each is a title, description, feature
      bullets and screenshots, all hand-maintained in Partner Center forever, and every one is
      a place for a claim to rot (the live English bullet 20 still says Apache-2.0, five days
      after the relicence). Worth deciding deliberately:

      * which languages get a listing at all — the interface list is fourteen, the *market* list
        is a different question and the answer may be three or four;
      * the source of truth. `docs/store-listing.md` holds the English draft today; a localised
        set wants the same treatment or it drifts the way the live bullet did;
      * screenshots. A localised listing with English screenshots is worse than an English
        listing, and the window can be photographed in any of the fourteen —
        `scripts/` already has the probe shape for that (`PrintWindow` from outside the
        process, which is how the About box was measured in three languages in a minute).

      **Not for `v0.1.1.0`** — that submission is in flight. The manifest fix above is a package
      change and needs its own version; the listings are Partner Center edits and can follow.

      **Drafts exist as of 2026-08-09, in `marketing/store/` (gitignored).** Thirteen files, one
      per non-English language, translated from `docs/store-listing.md` with no claim altered,
      each carrying a *Reviewer's notes* section naming what the translator was unsure about.
      They are drafts for a human who speaks the language, not copy to paste — that is the whole
      point of keeping them out of the repository. `scripts/check-listing-drafts.py` (tracked)
      holds them to the source: it reads the language list from the manifest, so it inherits the
      gate above rather than adding a fifteenth list.

      Three things the drafts turned up that no amount of reading would have:

      * **Partner Center accepts twenty features, and the source had twenty-one.** Documented
        limit, quoted in `docs/store-listing.md`. The GSA bullet took the list over on
        2026-08-06 and nothing counted, because the count had never been near twenty. The two
        offline bullets — one about accounts and telemetry, one about runtimes, both ending
        "runtime required" — are now one line, which drops no claim. The checker refuses a
        twenty-first, and refuses any feature over 200 characters **in the target language**.
      * **Terminology has to be taken from `docs/help/<lang>/`, not chosen.** Two of the first
        drafts used a different word for *engine* than the shipped help does (Croatian *pogon*
        against 64 uses of *motor*; German *Engine* against 60 uses of *Maschine*), which would
        have read as a different product to the reader who clicks through.
      * **A reviewer's note is a claim like any other.** One said Turkish lines are the longest
        after German; measured, Turkish is among the shortest. Another described the seed
        caption as Latin when it is Cyrillic `сид`.

      Still open, and unchanged by the above: which markets get a listing at all, and the
      screenshots — a localised listing with English screenshots is worse than an English one.

## AI-авторинг (открыто 2026-08-09, решение — [ADR 0011](decisions/0011-ai-authoring-offline-and-the-canonical-prompt.md))

Направление задано владельцем: следующий функционал — AI-интеграции. Форма первого среза
решена в ADR 0011: **ни одного сетевого вызова.** Studio собирает промпт, пользователь несёт его
в свою модель, возвращает черновик, Studio чистит его, валидирует настоящим движком, при ошибках
собирает repair-промпт и рендерит образцы. Витрина ровно это уже обещает с 2026-08-04, поэтому
срез не трогает ни листинг, ни политику, ни декларацию о данных.

Источник — не наш: `W:\Projects\spintax-js\packages\authoring-prompt`, `PROMPT_VERSION = '2'`.
Читать `docs/spec-llm-authoring-prompt.md` там же — это рационал, а не план.

- [x] **A0 — эталоны промпта.** *(2026-08-09, `84220f6`.)* Скрипт снимает `systemPrompt` / `userPrompt` с JS-сборщика по
      восьми брифам из `packages/authoring-prompt/conformance/briefs.json` и кладёт их в
      `tests/fixtures/prompt-v2/`. Node нужен только здесь и только сопровождающему (на этой
      машине v22.23.1); в сборке Studio его нет и не появится.

      **Уже проверено:** два прогона сборщика дали побайтово одинаковый результат, значит гейт
      будет точным, а не пороговым. Размеры: `en` 5590–5615 байт системного промпта, `ru`
      6939–6959, пять различных системных промптов на восемь брифов.

      Вместе с эталонами коммитится `PROMPT_VERSION`, с которого они сняты. Без этого через два
      релиза никто не скажет, чему соответствует порт.

- [x] **A1 — порт сборщика на Pascal.** *(2026-08-09, `7fa1d49`.)* `SpxPrompt.pas`: `SpxBuildAuthoringPrompt`,
      `SpxBuildRepairPrompt`, `SpxCleanModelTemplate`. Параметры те же, что в семье —
      `locale`, `channel`, `variationLevel`, `allowedVariables` (где элемент это либо имя, либо
      `{ name, case, note }`).

      **Грамматический падеж объявляется, а не выводится из имени** — спека промпта записала
      это как измеренный факт: в реальном наборе `%CasinoGamesAcc%` держал творительные формы,
      то есть соглашение об именовании врало, а декларация не могла. Порт обязан сохранить
      именно это, иначе он воспроизведёт ошибку, которую пакет уже исправил.

      Гейт: побайтовое сравнение с эталонами A0 по всем восьми брифам. Доказать его в обе
      стороны — сломать один блок правил и увидеть именованное падение.

- [x] **A2 — петля в окне.** *(2026-08-09, `4f3a4db`; находки ревью — `759e020`.)* Бриф → промпт (скопировать) → вставить ответ модели →
      `SpxCleanModelTemplate` → `SpValidate` под ТОЙ ЖЕ локалью → при ошибках repair-промпт с
      точным спаном → рендер образцов.

      Три вещи, за которые семья уже заплатила и которые порт обязан унаследовать:

      1. **Валидировать той же локалью, которой рендерим.** `validate()` без локали пропускает
         проверку арности множественного числа, а `render()` по умолчанию берёт 2 формы — и
         трёхформенный plural проходит валидацию, а потом рендерится fallback'ом `｛…｝`.
      2. **Позиции диагностик относятся к ОЧИЩЕННОМУ тексту.** Repair получает тот же
         `cleanedTemplate`, иначе «точный спан» указывает в строку, у которой другая нумерация
         из-за снятых code fences.
      3. **Никогда не верить output-контракту.** «No code fences» сказать правильно, и модели
         всё равно их вернут. Контракт в промпте, терпимый разбор в хосте.

      Всё, что трогает движок, идёт через `TSpxEngineThread` — как и любой другой вызов в этом
      приложении.

- [x] **A3 — справка на срез.** *(2026-08-09.)* Правило проекта: когда срез меняет то, что
      пользователь видит и делает, его статья в `docs/help/` едет тем же коммитом. Четырнадцать
      языков, примеры-фикстуры прогоняются через настоящий движок.

**Что срез стоил, помимо кода.** Три дефекта нашлись запуском приложения и разглядыванием
его (в наборе не падало ничего): панель мерила подписи через `Canvas` в конструкторе, до того
как форма даёт ей `Parent`; `SpxLoadPrefsFrom` зажимал индекс панели двойкой, написанной когда
панелей было три; две `alLeft`-панели при `Left = 0` упорядочивает проход выравнивания, а не
порядок создания. Ревью нашло ещё восемь, из них одно тяжёлое — `Columns[case].ReadOnly`
закрывал список выбора вместе с вводом, то есть падеж нельзя было объявить вообще.

И дважды за одну сессию правило в `.gitattributes` испортило фикстуру, которую защищало.
Теперь на директорию стоит `-text` без исключений.

## Сеть (открыто 2026-08-09, решение — [ADR 0012](decisions/0012-the-network-slice-byo-key-over-winhttp.md))

Офлайновый срез стоит и работает, поэтому сеть открыта. Она **не добавляет функции — убирает
ручной шаг**: всё, что придёт по сети, идёт по уже построенной и проверенной петле
(`SpxCleanModelTemplate` → редактор → рендер на воркере → диагностика → repair-промпт). Сеть
подключается к её началу и к её концу, и больше нигде.

Решения владельца: транспорт WinHTTP; ключ пользователя в DPAPI; Anthropic **плюс** поле для
OpenAI-совместимого endpoint; `internetClient` объявляется, хотя технически не требуется.

- [x] **N0 — правки опубликованного подготовлены** *(2026-08-09).* Готовый текст —
      [`docs/publish/network-slice-edits.md`](publish/network-slice-edits.md): буллет 17, три
      места в `docs/privacy.md`, декларация о данных. **Он не публикуется сейчас и не въезжает в
      `docs/privacy.md` сейчас** — сегодняшняя сборка сети не имеет, и политика, описывающая
      сетевую функцию, была бы ложной в другую сторону. Абзацы переезжают ТЕМ ЖЕ КОММИТОМ,
      который добавит файл в `NET_ALLOWED`.

      **И гейт, ради которого всё это, не знал про выбранный транспорт.** `NET_UNITS` не
      содержал ни `winhttp`, ни `wininet` — оба в `winunits-base`, оба собраны под этот таргет,
      то есть транспорт из ADR 0012 проехал бы мимо единственной проверки, чья работа — заметить,
      на зелёной сборке. Исправлено; проверено добавлением `winhttp` в `uses` живого юнита
      (`FAIL offline/SpxFiles.pas opens no socket`) и откатом. `NET_ALLOWED` пуст, и пустота —
      решение: это состояние того предложения в политике.

      Утверждения, которые перестанут быть верными:

      * `docs/store-listing.md:104`, буллет 17 — *«no account, cloud service, API key or
        telemetry»*;
      * `docs/privacy.md:14` — *«does not collect, transmit or store any personal data»*;
      * `docs/privacy.md:25` — *«makes no network request of any kind… and there is nothing in it
        that could make one»*.

      Политика публикуется в ДВУХ местах, и второе — замороженный снапшот на CDN Microsoft,
      который обновляется только полем в Partner Center при подаче. Плюс декларация о сборе
      данных при сертификации: это отдельная строка в подаче, а не следствие правки текста.

      **Локальная модель — не облако, и политика обязана сказать это отдельно.**
      `http://localhost:11434` не отправляет ни байта за пределы машины; смешать это с облаком в
      одном абзаце значит соврать в обе стороны.

- [x] **N1 — `gui/SpxHttp.pas`, обёртка над WinHTTP** *(2026-08-09).* Один запрос, отменяемый и
      ограниченный: четыре таймаута, потолок на тело, отмена между чтениями. `SpxHttpParseUrl`
      вынесен отдельно — окно покажет читателю хост до вызова, а набор проверяет, что принимается
      и что отвергается, ни разу не выйдя в сеть. Плоский `http` принимается намеренно: локальная
      модель отвечает на нём, и отказ отверг бы единственную конфигурацию, которая не покидает
      машину.

      **Политика ЕЩЁ НЕ переписана, и это проверяется, а не обещается.** Транспорт в коробке, но
      ручки к нему из окна нет, поэтому опубликованное предложение остаётся верным про пакет,
      который ставит читатель. Держит это `http/the transport is not reachable from the window`:
      первый юнит, который подключит транспорт, удалит эту проверку — и тот же коммит должен
      привезти переписанную политику в трёх копиях и буллет 17. Текст готов
      (`docs/publish/network-slice-edits.md`), так что это перенос, а не сочинение.

      Доказано в обе стороны: снятый разбор схемы красит `http/an ftp url…`; `winhttp`, убранный
      из разрешённого файла, красит `offline/SpxHttp.pas is the one file allowed a socket`;
      `SpxHttp` в `uses` любого юнита окна красит триггер политики.

- [x] **R1-2 / N2 — ключ в Credential Manager** *(2026-08-09).* `gui/SpxSecrets.pas`.
      **Не свой файл, как записал ADR 0012, а хранилище Windows** — спека §6 говорит это прямо и
      раньше, а намерение владельца («DPAPI, привязанный к пользователю») исполняется сильнее:
      файла не существует вообще, значит его нельзя ни приложить к багрепорту, ни потерять,
      промахнувшись путём. ADR получил поправку.

      `CredWriteW` / `CredReadW` / `CredDeleteW` / `CredFree` объявлены из `advapi32.dll` — в
      `winunits-base` их нет. Отсутствие секрета — не ошибка: первый запуск и свежий профиль
      Windows дают один и тот же обычный ответ, и сообщение будет «введите ключ заново», а не
      «401».

      Проверка действительно пишет — подделывать тут нечего, смысл юнита в том, что секрет
      уходит в хранилище Windows. Пишет, читает, перезаписывает, удаляет и подтверждает удаление
      под именем провайдера, которого не может выдать никакая настоящая конфигурация; в хранилище
      после прогона не остаётся ничего (проверено `cmdkey /list`). Значение не-ASCII намеренно:
      круговой проход UTF-8, который работает только для ASCII, — дефект, ждущий своего входа.

      **Проверка, из которой нет возврата, — разведение двух пространств имён** (§6). Если
      BYOK-ключ и сервисный токен когда-нибудь сольются в одну цель, один молча перезапишет
      другой. Доказано склейкой слотов: семь именованных падений, включая живое обращение к
      хранилищу.

- [x] **Ревью 2026-08-09: семь находок, и CI был красным пять коммитов** *(a2a3e7a, 15bebfc, e3e41b9).*
      Все семь воспроизведены до правок. Главная — не в списке ревьювера, а под ним: локальный
      гейт собирает **одну** из трёх платформ CI, и «25686 проверок, 0 упавших» стояло в пяти
      подряд коммитах, пока ubuntu и macos падали на каждом. `SpxHttpParseUrl` объявлен в
      интерфейсе и реализован только под `{$IFDEF WINDOWS}`. Читать `gh run list` после пуша.

      - **Транспорт не собирался вне Windows** → заглушка + `TestPlatformSplit`: для каждого
        юнита с верхнеуровневым `{$IFDEF WINDOWS}` каждая процедура из интерфейса должна быть
        реализована в `{$ELSE}` или вне блока. Доказано удалением заглушки.
      - **И заглушка оказалась хуже дефекта**: `heUnsupported` на любой URL уронил
        `SpxLlmIsLocal` — CI ответил на исправление двумя новыми падениями. Разбор URL
        переписан на чистом Pascal: «эндпоинт на этой машине?» — вопрос **приватности**, а не
        транспорта, и он теперь проверяется на всех трёх ногах.
      - **Код сертификата был чужим кодом**: `..._CERT_CN_INVALID` = base+169 (это
        `SECURE_INVALID_CERT`). `winhttp` объявляет их все и уже был в `uses`. Набор
        спрашивает **числами** из опубликованного списка Microsoft.
      - **Разбор ответа мог убить процесс**: `AsString` в fpjson не конверсия, а утверждение —
        `{"error": []}` и `"message": "текст"` бросали исключение на сетевом потоке. Ревертом
        с новыми фикстурами набор не падает, а **умирает**: `EInvalidCast`.
      - **Ответ на промпт правки дублировал документ**: промпт просит вернуть шаблон целиком,
        а единственное действие вставляло его в каретку. Появилась кнопка «Заменить документ»
        (14 языков, через `SelText` — с отменой).
      - **И справка про этот промпт врала на всех четырнадцати**: «указывает на точные места,
        а не на весь документ» — промпт несёт `TEMPLATE (line-numbered):`, весь. Найдено не
        ревью, а при написании абзаца про Replace.
      - **Панель получала текст «сейчас» с диагностикой «тогда»** → `TSpxJobResult.Source`.
      - **Падежи и заметки перетекали между документами** → `ResetDeclarations` на обеих
        границах; бриф намеренно не трогается, он виден.
      - **Гейт на число языков не мог упасть**: `'14' in text` истинно из-за буллета `14.`.
        Доказано в обе стороны.

      Фотографией найден восьмой: три `alRight`-кнопки с `Left = 0` расставляет align-проход, и
      он отвечает по-разному — en дал Repair/Insert/Replace, следующая сборка на de дала
      Replace/Insert/Repair. `Left := 10000`, как для `alLeft` в уставе.

- [ ] **Разделение CI по смыслу, а не по платформе — предложено 2026-08-09, частично сделано.**
      Сделано: разбор URL и все вопросы «что такое URL» идут на всех трёх ногах; то, что умеет
      транспорт, спрашивается там, где он есть, а на другой стороне — **именованные** проверки
      (`http/a good url reports no transport on this platform`), а не тишина.
      Не сделано и пока не нужно: **отдельный Windows-бинарник для интеграционных проверок.**
      Сегодня по-настоящему Windows-связан ровно один `TestSecrets` (он реально пишет в
      хранилище); второй `.dpr`, вторая цель сборки и вторая нога CI ради одной процедуры —
      дороже, чем стоит. Пересмотреть, когда Windows-интеграция вырастет: сетевой воркер (R1-3)
      и GUI-зонды — первые кандидаты.

- [ ] **Настоящая кроссплатформенность — НЕ в R1, но форма записана.** Интерфейсы уже без
      Windows в сигнатурах, так что цена — реализации, а не переделка:
      секреты — Keychain Services (macOS) / Secret Service (Linux); транспорт — libcurl или
      NSURLSession. **Headless Linux: если Secret Service недоступен, правильный запасной путь —
      ключ в памяти до закрытия приложения, и НИКОГДА не запись в конфиг** (спека §6/§7 —
      «никогда не плейнтекст»); окно обязано сказать, что ключ не сохранён.
      Пока продукт только для Store и только Windows, это остаётся записью, а не работой: ADR
      0012 уже оценил зависимости класса libcurl/OpenSSL (вес MSIX, повторный WACK, вопрос
      лицензии при GPL) и отверг их для этого релиза.

- [ ] **N2 (закрыто выше) — ключ.** `CryptProtectData` / `CryptUnprotectData` из `crypt32.dll` (в `winunits-base`
      их нет), без `CRYPTPROTECT_LOCAL_MACHINE`. **Отдельным файлом, не в `settings.txt`** — этот
      файл люди прикладывают к сообщениям об ошибках. Потеря ключа после переустановки Windows
      должна читаться как «ключ не читается, введите заново», а не как «ошибка 401».

- [x] **R1-1 / N3 — `TLlmProvider` и два формата запроса** *(2026-08-09).* `gui/SpxLlm.pas`:
      Anthropic Messages и любой OpenAI-совместимый URL. Тело собирается `fpjson`, ответ
      разбирается `jsonparser` — ни строки ручного экранирования. Сборка тела, заголовки и
      разбор ответа отделены от вызова, поэтому набор спрашивает их, ни разу не выйдя в сеть.

      **Главная проверка не нуждается в фикстуре:** промпт с кавычкой, обратным слэшем, табом,
      переводом строки и кириллицей собирается в тело и разбирается ОБРАТНО — эталон байтов
      утверждал бы только, что код делает то же, что делал, а это утверждает, что он делает
      верно. Тринадцать записанных ответов покрывают 401, 429, переполнение контекста, ошибку
      на 200, не-JSON и пустой ответ; они написаны по документированным формам провайдеров, а
      не сняты с живого вызова, и так и подписаны.

- [x] **R1-6 / часть N0 — политика переехала в источник** *(2026-08-09, раньше плана).* Гейт
      `http/the transport is not reachable from the window` покраснел на R1-1, как только
      `gui/SpxLlm.pas` упомянул `SpxHttp`. Соблазн сузить проверку до «достижимо из формы»
      отвергнут: этого не решает честно ни одно сканирование текста, и это было бы ослаблением
      проверки ради экономии. Переписаны `docs/privacy.md`, обе опубликованные копии, буллет 17
      и тринадцать черновиков.

      **Два гейта покраснели по делу, и оба были правы.** `offline/and it still promises nothing
      is collected` держал буквальную фразу «does not collect, transmit or store any personal
      data»: половина её осталась верной (не собираем), половина перестала (передаём то, что
      попросят). Общее обещание, ставшее наполовину ложным, хуже отсутствия обещания — якорь
      переехал вместе с утверждением, и теперь их три вместо одного.

      **И одного гейта не было.** Проверка трёх копий держала МАРКИ И КОНТАКТ, но не содержание,
      поэтому прошла при неполной `privacy.html`: источник и копия для Partner Center описывали,
      что уходит, а страница — нет, потому что правка задела два её абзаца и пропустила два
      других. Найдено подсчётом фразы по трём файлам руками. Теперь четыре маркера содержания
      по каждой копии; доказано удалением абзаца про локальный endpoint — падает именно та копия.

- [ ] **N3 (закрыто выше) — два формата запроса.** Anthropic Messages API и любой OpenAI-совместимый URL. Второе
      покрывает OpenAI, OpenRouter и локальные модели почти бесплатно.

- [ ] **N4 — ошибки, которых у продукта не было.** Нет сети, таймаут, 401, 429, переполнение
      контекста, ответ не JSON, ответ обрезан. Каждая говорит, что случилось и что делать, на
      языке читателя — четырнадцать строк на сообщение. Молчащая кнопка здесь хуже, чем
      отсутствие кнопки.

- [ ] **N5 — сеть выключена, пока её не включили**, по образцу GSA-импорта (`gsa.import=no`,
      переключатель в меню «Вид»). Это НЕ повод оставить буллет 17 и политику как есть: см. N0.

- [ ] **N6 — `internetClient` в манифест** (решение владельца), и `CheckManifestLanguages` рядом
      с ним придётся дополнить проверкой на capability, иначе строчка уедет при следующей правке
      манифеста незамеченной.

- [ ] **N7 — WACK и `docs/release-validation.md` снимаются заново.** Этот кандидат впервые делает
      исходящие соединения; прошлый прогон про него ничего не говорит.


- [ ] **Эталоны устареют молча.** `spintax-js` не сабмодуль Studio, кросс-репозиторного гейта
      нет. Сверять `PROMPT_VERSION` при каждой регенерации. Этот проект уже платил за зеркало
      чужого правила, отставшее на релиз при зелёном наборе (`SpxCount.ReadPermConfig` после
      `v0.5.1`) — набор был зелёным потому, что спрашивал про то, что и так было верно.

## Raised by review, not yet built

- [ ] **The GSA conversion runs on the UI thread and is quadratic in DISTINCT macros.**
      `gui/SpxMainForm.pas:4341` calls `SpxImportGsa` straight from the menu handler -- every
      other engine-family call in this application goes through `TSpxEngineThread` -- and
      `TLifter.Ref` (`engine/src/Spintax.Gsa.pas:316`) looks its keys up with a linear
      `FKeys.IndexOf`. Measured by the review, on this machine:

      | input | distinct lifted | time |
      |---|---|---|
      | 1 000 x `#file[lN.txt,1,S]` (20 KB) | 1 000 | 298 ms |
      | 2 000 x same (41 KB) | 2 000 | 1 292 ms |
      | 4 000 x same (83 KB) | 4 000 | 4 155 ms |
      | 4 000 x a full line (249 KB) | 4 003 | **38 922 ms** |

      Text volume alone is fine -- 220 KB with 2 distinct macros is 69 ms -- so the driver is
      the count of distinct macros, which is exactly what a large SER project template has.
      During those 39 seconds the window is frozen with no cursor, no progress and no cancel,
      and Windows marks it *Not Responding*.

      **Not a `GAbbrevs` race**: `EnsureAbbrevs` is reached only from the post-process, and the
      converter renders nothing. The defect is the freeze. The work is to move the call onto
      the worker with progress and cancel, which is a slice of its own -- **deliberately not in
      `v0.1.1.0`** (owner's decision, 2026-08-08).

- [ ] **The caret path is quadratic on one very long line, and was before any of today's
      work.** `SpxMatchBracket` and `SpxConstructOf` walk the whole text, and `ConfigSkip`
      copies the enclosing LINE once per `[` to hand it to `PermConfigLength`. Measured on this
      machine, `[<p>` x20 000 on one 80 KB line: **3150 ms** for a single bracket match, on the
      UI thread. (The scan itself is 4 ms since 8a52cb7; a review measured the caret path at
      6216 ms before that commit, 8187 ms after it -- the bounds were being computed per
      bracket, where they save nothing -- and it is 3150 ms now that they are passed wide open
      there and the comment lookup is hoisted.) Fixing it properly means making the two walks
      line-aware so they stop copying, which is a slice of its own.

- [ ] **A permutation whose HTML sits on the line after the `[` counts 1.** `[` LF
      `<b>bold</b>|x]` is two options to the engine and this reports "at least 1": the
      next-line tell cannot tell a config from markup, because deciding that needs the rest of
      the permutation and the scan has only the line. The floor holds; the number is poor. The
      same restructuring as the entry above would answer it.

- [ ] **The help's control-name gate holds a floor, not a ceiling.** `CheckHelpNamesControls`
      asserts each language names a control as its own string table does, somewhere across its
      three documents -- so a document naming one WRONGLY is masked by a sibling naming it
      right, which is what English had (`studio.md` said "Literal" where `diagnostics.md` said
      *as text*). The 27 masked occurrences were found by grepping the wrong words once, by
      hand. Tightening it needs a way to know which documents discuss which control, and every
      version of that is a hand-written list per language.

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

- [x] ~~**A separator on a middle line may appear one caret move late.**~~ *(closed 2026-08-01:
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
- [x] **Show how many variants the template can produce.** (M3.) **Done 2026-08-07** — see
      item 12 of *What `v0.1.1.0` carries*. The open question in this line was answered by
      measurement rather than by choice: an `#include` the set CAN resolve is counted exactly
      (the fragment is counted too), and only an unresolvable one, a conditional or a plural
      turns the answer into a lower bound.
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
      socket, and the brand links (one then, two since 2026-08-04) are named rather than
      omitted. The suite reads every shipped unit's uses clause and fails the build on a
      network unit, so the page cannot quietly stop being true. *(It called those links
      "outbound actions" until 2026-08-05; they are not. Handing an address to the shell is the
      user's act and the request is their browser's — the page draws that line now.)*

      **Hosted 2026-08-04 at <https://spintax.studio/privacy.html>** and entered in Partner
      Center; the storefront serves its own snapshot of the text beside the listing. Expand it
      when BYOK AI (R1) adds network, and again for a managed tier — and republish both copies,
      because the Store snapshot does not follow the site.
- [x] **No purchases in R0** — no paywall, trial, or IAP; a free offline app keeps the first
      submission out of financial policy too.
- [ ] **AI disclosure + report path** — **R1+ only** (once live generative AI ships): disclose
      in listing + Partner Center, and give an in-app/listing contact for reporting problematic
      AI output. R0 ships no AI, so this obligation does not apply to the first submission.
- [x] **Store listing — live 2026-08-04**, <https://apps.microsoft.com/detail/9mw3ch7b530p>.
      Copy, the twenty feature bullets and the ten screenshots came from
      [`store-listing.md`](store-listing.md); the developer README was not pasted into it.
      What the listing actually carries is recorded at the end of that file.
- [x] **Windows App Certification Kit** — exact candidate passed on 2026-08-03; the report and
      interpretation are recorded in [`release-validation.md`](release-validation.md).

Decisions owed **before the relevant submission** (not switchable later):
- ~~Partner Center account type — individual vs company, before R0.~~ Settled by the account
  that published R0: the listing's publisher is `301` (publisher id `93915800`). Commerce
  (R2+) has to be checked against the type that account actually is before any billing.
- **Paid managed-AI tier needs its own ADR** before any billing (R2+): Store IAP vs
  third-party purchase API (Stripe/…), prices/terms, cancellation, Partner Center disclosure.
  See spec §10/§11.

## To report to the engine

- [ ] **`Spintax.Gsa.pas:626` — a tag block with ONE option is neither converted nor refused.**
      `TranslateBlock` does `if parts.Count < 2 then Exit` (returning `bkPlain`) **before** the
      tag-shape test at `:631-640` that exists to catch this. Measured on the pinned `v0.5.1`:

      ```
      {#.de Hallo} today.        ->  renders `#.de Hallo today.`, Refused = 0
      {#TAG1 hello} world        ->  renders `#TAG1 hello world`,  Refused = 0
      {x|{#.de Hallo}}           ->  the tag comes out at random
      {#.de Hallo|#.com Hello}   ->  refused, correctly
      ```

      That is the coin flip the unit's own header (`:12-18`) forbids in as many words. The fix
      looks like moving the count test after the shape test, so a block that is tag-SHAPED and
      unreadable is `bkUnsupported` whatever its option count.

      **Studio guards itself meanwhile** — `GuardTagBlocks` in `src/SpxGsaImport.pas`, which
      reads the converted document back and lifts the shape into a refusal. **Delete that guard
      when this lands**, and the checks named `gsa/a one-option tag block…` with it.

- [ ] **The converter's bracket rule expires the day SER gains `[]` — WAIT for that release,
      do not pre-empt it.** GSA replied on 2026-08-06 that they will implement rather than
      adopt, and that `[]` and `{?xyz?}` are the two they want. From the moment `[]` ships in
      SER, a bracket in a SER template stops meaning one thing. Measured today, against the
      converter as it stands:

      ```
      SER source :  Order [red|green|blue] now.
      converted  :  Order %__gsa_l1%red|green|blue%__gsa_l2% now.
      rendered   :  Order [red|green|blue] now.      { literal -- brackets lifted as BBCode }
      natively   :  Order green blue red now.        { what the author will then mean }
      ```

      Not corrupt, and visible rather than silent — but not what the template says. **There is
      nothing to fix before then:** today SER has no `[]`, so protecting the bracket is right,
      and a rule written now would be written against a guess. His `[]` may or may not carry
      the `<sep=…>` config, and that decides what counts as a permutation.

      The rule when it comes: a bracket group with a top-level `|` is a permutation; one that
      is a single token, or `/token`, optionally `=value`, is a BBCode tag; brackets straight
      after `#name` are a macro and are already handled. **It belongs in the engine's converter,
      not here** — Studio's side is convert, session variables, warn, and none of that changes.
      The payoff grows with the difficulty: whatever SER renders natively needs no conversion
      at all.

- [ ] **Post-process rewrites a value the host neutralised.** **Answered, not fixed:** on
      `v0.5.0` the engine documents the rule instead — `docs(gsa): render a converted template
      with PostProcess=False, and say why`, plus a warning where `PostProcess` is introduced —
      and the behaviour still reproduces exactly as measured below. That is a legitimate answer
      (Studio's own rule does not depend on a fix), so this stays open only as the record of a
      known sharp edge for any other host. Measured 2026-08-06 on
      `v0.4.0` and again on `v0.5.0`, and it is not a converter question — the value goes straight through
      `TSpContext.Vars`, neutralised the way `SpNeutralize` is documented for:

      ```pascal
      vars.AddOrSetValue('v', SpNeutralize('#file[l.txt,1,S]'));
      ctx.Vars := vars;  ctx.PostProcess := True;
      SpRender('%v%', ctx)   →  #file[l.txt,1, S]     { a space inside the macro }
      ```

      | value handed in | rendered | what happened |
      |---|---|---|
      | `#file[l.txt,1,S]` | `#file[l.txt,1, S]` | space after the comma |
      | `a,b` | `A, b` | space **and a capital** |
      | `x,y,z` | `X, y, z` | both, twice |
      | `1,5` | `1,5` | intact — a comma between digits is shielded |
      | `one.two` | `one.two` | intact — the domain rule |
      | `[b]` | `[b]` | intact — neutralising did protect it from the PARSER |

      With `PostProcess := False` every value is returned verbatim. So the sentinels do their
      documented job against parsing and none at all against typography: a host that marks a
      value literal is asking for text that is not to be touched, and gets prose conventions
      applied to it anyway. Whether restored regions should be exempt from post-processing is
      the engine's decision; the measurement is the report.

      **It reaches Studio today, with no GSA involved:** the variables panel's `Literal` flag
      goes through `SpxValueForEngine` → `SpNeutralize`, so any literal session value carrying
      `,` before a letter — or simply starting lower-case — is shown rewritten in the preview.
      Found while measuring the GSA converter, which is where it is visible in its ugliest
      form, but it belongs to neither the converter nor this application.

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
