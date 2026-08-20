---
type: release-artifact
status: published
product: spintax-studio
---

# Microsoft Store listing

**Live since 2026-08-04; `0.2.1.0` live since 2026-08-18** (storefront `LastUpdateDateUtc`
`2026-08-18T19:01:12Z`, read back cache-busted on 2026-08-20 — the same read found the
What's-new field still carrying the pre-review `0.2.0.0` draft; see that section): <https://apps.microsoft.com/detail/9mw3ch7b530p>.
This file is the copy for the NEXT submission; the measured read-back of the live page is
recorded at the end. ([`publish/store-listing-edits.md`](publish/store-listing-edits.md) is
dated history of the pre-`0.2.0.0` edit queue.)

Updated 2026-08-13 for the AI slice: the description now discloses the live generative AI
feature and names the report channel (Store policy 11.16), because the next submitted build
carries Generate and Fix. Keep it separate from the developer README: the Store page
describes the submitted product, not the repository.

Refreshed 2026-08-14 for the owner's pre-submission review — the product moved in the last
week and the copy had not: the AI draft's main path is now *turn the text you already have
into a template* (the brief is the second mode, not the first); a finished draft arrives verified by
the real engine and nothing replaces the document until the reader applies it (since
2026-08-15 the window never applies a draft by itself); the editor gained find-and-replace and an
Insert menu; the report address moved into the About window. Features 6+7 and 13+14 were each
merged to stay within Microsoft's twenty, freeing two slots for find-and-replace and the
Insert menu.

## Short description

Write, validate, preview, generate and export spintax templates in a focused offline Windows editor.

## Description

Spintax Studio is a native Windows workspace for writing controlled, reusable text templates.

Write once. See what it means.

The editor and live preview sit side by side, so every change is visible immediately. Write
your template on the left and inspect the rendered result on the right. Alternatives, groups,
variables, directives and markup remain readable in the source while the preview shows the
actual text produced by the engine.

From the text you already have — or a brief — to a working template.

You do not have to hand-write every variation. This application includes optional live
generative AI: paste the text you already have — a product page, a letter, a description —
and Generate turns it into a richly varied template, or describe what you want in a brief.
The draft is not taken on trust: a finished draft arrives verified by the same engine that
renders your preview, nothing replaces your document until you apply it yourself, and Fix
sends the engine's own findings back for repair. Everything travels to the endpoint you
configure, with your own key and account when the endpoint uses them, and it is off until
you turn it on. Prefer to keep the network out of it? Copy the prepared prompt to ChatGPT,
Claude or another model and paste the draft back — that path needs no key and no connection.
Either way Studio is where you take control: preview what the draft actually produces, find
and fix syntax problems, refine the choices, and generate reproducible variants locally.

The AI connection sends only what you choose to send, to the endpoint you configured.
Found an AI draft inappropriate? Write to support@301.st — the address is in the About
window.

Learn the language while you work.

Built-in help is part of the application, not a web page you have to find. Each topic explains
the construct in plain language, shows a working example, and connects diagnostics to the
relevant article. Select a valid example and see its result in the preview; select a repair
and make the corrected form yours. The interface and every help page ship in fourteen
languages.

See the structure behind the text.

Inspect variable definitions and references, session values, includes and their resolution
status. Open the group editor beside the caret when a nested choice needs attention. The panels
are designed for understanding a template, not just producing another random output.

Generate variants you can reproduce.

Create a set of variants locally, review the generated text, and use a seed when you need the
same result again. Export one variant per line as plain text, send a complete set to an XLSX
workbook, or write one file per variant into a folder you choose. The result is yours to
inspect, edit and use in your own workflow.

Built for local work.

Spintax Studio works offline. It requires no account, no cloud service, no telemetry, and no
browser, Node.js, PHP or Python runtime — the optional AI connection is off until you turn
it on, and even then a key is needed only if the endpoint you point it at asks for one. Your
templates and exports stay on your computer; nothing is sent anywhere except what you
yourself send to the AI endpoint you configured. It is a focused Windows editor for authors,
localizers, SEO content teams and anyone who needs controlled variation instead of opaque
paraphrasing.

Spintax Studio is open source and built around the SPINTAX language and engine family. Learn
the language and explore the engines at spintax.net.

## Product features

Partner Center displays these as bullets. The GSA import bullet and the licence correction
went live with the `0.2.0.0` visit on 2026-08-15 (measured: positions 20 and 19 on the
storefront). Enter each line as a separate feature; do not include the line numbers or
bullet characters in the Store form.

**Microsoft allows twenty features, not more, and 200 characters each** — documented on
[Add and edit Store listing info](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/add-and-edit-store-listing-info):
*"no more than 200 characters per feature. You may include up to 20 features."* Adding the GSA
bullet took this list to twenty-one, which the submission form would have refused; nothing here
counted them, because the count had never been near the limit before. The two offline bullets
were merged into one — *no account, cloud, API key or telemetry* and *no browser, Node.js, PHP
or Python runtime* were separate lines that both ended in "runtime required", so the merge drops
no claim. `scripts/check-listing-drafts.py` now counts, and refuses a twenty-first.

1. Native Windows spintax editor for writing and maintaining reusable text templates
2. Two-pane live preview: edit the template on the left and inspect the rendered result on the right
3. Spintax syntax highlighting with bracket matching for alternatives, groups, variables and directives
4. Precise validation diagnostics with line and column positions for faster error fixing
5. Built-in offline help with tested examples, correct forms and repair guidance
6. Variable and include inspectors: definitions, references, session values, targets and resolution status
7. Find and replace that counts and folds case exactly the way the engine does, safe in any language
8. Visual group editor for alternatives and nested spintax groups
9. Shuffles that reorder alternatives or pick controlled subsets, with separators of your choice
10. Plural forms and language-aware content patterns for reusable templates
11. Insert menu that wraps a selection into a choice, shuffle or comment and drops in ready-made constructs
12. Deterministic variant generation with seed support for repeatable results
13. Variant list for reviewing generated outputs before export
14. Export as plain text (one variant per line), as an XLSX workbook with XML-safe UTF-8 content, or as one file per variant
15. Light and dark themes for a comfortable editing workspace
16. Multilingual interface with 14 available UI languages
17. Offline by default: no account, no telemetry, and no browser, Node.js, PHP or Python runtime — the optional AI link uses your own provider, and your own key when one is needed
18. Optional AI draft: turn your own text or a brief into a template — finished drafts arrive checked by the real engine, and applying them is yours
19. Open-source GPL-3.0-or-later Studio built around the SPINTAX engine family
20. Optional import of GSA Search Engine Ranker templates, converted and verified by the real engine

## What's new in this version (0.2.2.0)

> **The text below is the field, verbatim and form-ready** — one line per bullet, no
> backticks, no markdown. Partner Center keeps the breaks it is given, so a draft wrapped to
> this file's width pastes as bullets broken across three lines; the 0.2.0.0 field was
> unwrapped by hand at the form, and this removes that step. Microsoft's limit is **1500
> characters** ("This field has a 1500 character limit. (Previously, this field was called
> Release notes)"), read 2026-08-20 from the page the other limits come from; this is 963. The thirteen
> other languages are in `marketing/store/<lang>.md` under the same heading, and
> `check-listing-drafts.py` now REQUIRES the section, measures it and refuses a wrapped line.

Spintax Studio 0.2.2 is about the moments the window used to stop answering.

• A template whose definitions refer to each other in a circle could leave the diagnostics panel unresponsive for many seconds. It answers at once now, and reports one finding per name rather than one for every path through the circle, so the panel is shorter as well as faster.
• The diagnostics panel is much quicker on documents with many findings.
• Importing a large GSA template no longer freezes the window while it converts.
• Two plural findings used to be wrong: a list of forms supplied by a #def was reported as the wrong number of forms on a template that rendered correctly, and a condition used as the count made the whole block disappear with nothing reported at all. Both are right.
• The variants panel answers promptly on templates whose macros and fragments refer to each other widely, and says when the number it gives is a lower bound.
• Engine updated to v0.8.0.

## How the 0.2.2.0 field was written

**Measured, not carried over.** Each bullet, and what stands behind it:

- The circle: `SpxHealthReport` on the corpus's own 507-byte `cycle-diamond-terminates`
  took 8 859 ms and produced 2 097 152 panel rows on the engine 0.2.1.0 shipped; on `v0.8.0`
  it is 1 ms and 22 rows. "Many seconds" rather than a number, because the cost depends on
  the document. Reachable by writing definitions, not by writing an attack.
- The panel: 16 000 rows in two interleaved runs, 1 726 ms → 118 ms; 32 000 descending,
  24 057 ms → 1 609 ms. "Much quicker" rather than a multiplier, because the multiplier is a
  property of the shape and the ordinary case is smaller than either.
- The import: it was ~18 s on a template with eight thousand distinct lifted macros, on the
  UI thread. It is on the worker now, so the window answers; the conversion still takes its
  time. **The bullet deliberately does not say "faster"** — that is a separate engine fix
  which is merged upstream and untagged, and if it is pinned before this ships the bullet
  gets "and converts far more quickly" and not before.
- The two plural findings and the variants panel are 0.2.1.0's, unpublished; wording taken
  from that block, which was itself measured.

**What is deliberately NOT here.** 0.2.1.0's installation fix. It is the largest thing that
version did, and it has no reader: anyone who met it could not install the app at all, and
anyone who can read this field already has a version that installs. Saying it would
advertise a fault to the only people it never reached.

**The four corrections ride with this visit.** The live field still says "your own AI
provider and key" without the when-needed qualifier, "any construct" (which overstates the
Insert menu), "View > GSA import" (that is the enable switch, not the import path) and
locates the splitter "between the panes". They are fixed in the corrected 0.2.0.0 block
below — but that block is not what goes in the form now. Whatever ships must not
re-introduce them, and the text above avoids all four by not repeating those sentences.

## What's new in this version (0.2.1.0) — WRITTEN, NEVER PUBLISHED

**This text never reached the live page.** Measured on 2026-08-20 by reading the storefront
past its cache: `Notes` still carries the pre-review 0.2.0.0 draft, ending "Engine updated
to v0.5.1", while the live package is 0.2.1.0 and carries engine `v0.7.0`
(`git ls-tree v0.2.1.0 engine`). So the 0.2.1.0 submission went in without touching the
field at all, and **nobody has ever read the block below**. Kept as the record of what that
version carried; the copy that ships next is the 0.2.2.0 block above it, which folds these
in. The listing field is not a changelog — it shows one version's text and replaces it — so
a change that misses its visit is not published late, it is not published.

Written 2026-08-18 against the working tree, not yet against a tag: check it against
`git log v0.2.0.0..HEAD` before it is typed into the form, the way the 0.2.0.0 block was.

> Spintax Studio 0.2.1 is a repair release.
>
> • Fixes an installation failure. Some systems refused to install 0.2.0.0 and the Store
> reported only "Something went wrong"; the package declared one of its fourteen languages
> in a form Windows will not accept. Nothing else about the app changed for it.
> • The variants panel could take a long time on a template whose macros or fragments refer
> to each other widely. It now answers promptly, and says so when the number it gives is a
> lower bound.
> • Engine updated to v0.7.0. Two plural findings were wrong before it: a form list supplied
> by a #def was reported as the wrong number of forms while rendering correctly, and a
> conditional used as the count made the whole block disappear with nothing reported. Both
> are right now. A template whose definitions expand into each other can no longer stall the
> preview.

Two claims here were checked rather than carried over: "some systems" rather than "all",
because what was measured is that this machine's Windows refuses the package and the
storefront still offered it — how far back the deployment stack accepts a bare `sr` was not
measured. And the engine bullet names what a READER sees, not the engine's own release
notes; the render speed-up in v0.4.0 is already live and is not repeated here.

**Still to decide before the visit:** the four corrections listed under the 0.2.0.0 block
below are still not on the live page. They ride with this visit or they wait again.

## What's new in this version (0.2.0.0)

The exact text for Partner Center's "What's new in this version" field, written 2026-08-15
against the v0.2.0.0 tag. Every line was checked against the tag's carry list before it
went in; the match counter and the ClearType fix were both measured to be in `v0.1.0.0`
already (`git tag --contains`) and are deliberately absent.

> Spintax Studio 0.2 introduces the optional AI draft. Turn plain text or a short brief
> into a spintax template using your own AI provider — and your own key, when the endpoint
> needs one; requests go only to the endpoint you configure, and there is no key or server
> of ours. Every draft is checked by the
> real spintax engine before the app calls it ready, and it lands in the answer box, never
> in your document: applying it with Insert or Replace is your own act, and Insert
> respects your selection.
>
> Also new in this version:
>
> • Insert menu — ready-made #set, #def, #include and conditions at the caret; wrap a
> selection in a choice, a shuffle, a comment or a condition.
> • The built-in help now answers in all fourteen interface languages and reads as an
> author's guide.
> • The variants panel tells you how many variants your template can produce.
> • Import GSA Search Engine Ranker templates (File > Import GSA template, once enabled
> in the View menu; off by default), converted and verified by the real engine.
> • .spintax is a file type: double-click a template to open it.
> • The horizontal splitter above the bottom panels is now visible and grabbable, and the
> Store tile is centred.
> • Licence: GPL-3.0-or-later, stated in the app and in the executable's version info.
> • Engine updated to v0.5.1 — plain-text rendering several times faster.

"Several times faster" rather than the engine's own "6×": that number was measured on one
scenario (64 KB of plain text) and does not generalise to every document.

**What the live page carries in this field is the PRE-review draft** — measured off the
storefront `Notes` on 2026-08-16: the submission went in before the four Codex corrections
above landed, so the live text says "and key" without the when-needed qualifier, "any
construct", "View > GSA import" as the path, and locates the splitter "between the panes".
All four are listing inaccuracies, not shipped-code defects — two of them do misdescribe
the product ("any construct" overstates the Insert menu; "View > GSA import" is the enable
switch, not the import path) — and a listing edit is a review cycle (owner's batching rule,
2026-08-04), so they ride with the next visit. The block above
is the corrected copy for that visit.

## Captured screenshots

**Recaptured 2026-08-15 against 0.2.0.0.** Nine frames, five light and four dark, so the
listing shows both supported themes. Regenerate the whole set with:

```
.\scripts\capture-store.ps1
```

The script is reproducible and needs no hands: frames 1-6 take their whole state from
`%LOCALAPPDATA%\spintax-studio\settings.txt` (theme, language, which bottom panel is open,
the preview face) and from the document passed as `ParamStr(1)`; frames 7-9 add a menu
command and mouse messages on top of that state (see below). The capture itself is
`PrintWindow(..., PW_RENDERFULLCONTENT)`, which needs the window to exist rather than to be
in front. The reader's own settings file is copied aside and restored afterwards. Fixtures
live in `scripts/store-fixtures/`. The script assumes this machine's display scale - its
coordinates are unscaled window pixels - and frame 3's generation needs the attached AI key
this machine holds; on a machine without it that frame's answer box comes out empty.

Captured from the English release executable at 1500x890, with no personal documents
visible. The files are intentionally local: keep them in `build/store-submission/` and
upload them to Partner Center from there.

1. `spintax-01-editor.png` - the two-pane shape: template on the left, live render on the right, with choices, a permutation, a conditional, variables and an include all on screen and the status bar reading *valid*.
2. `spintax-02-diagnostics.png` - a real unclosed bracket, its source position (5:8) and the engine's own message, plus the undefined-variable warning beneath it.
3. `spintax-03-ai.png` - **the AI loop complete**: plain text in the brief, the generated template applied to the document by the reader's own Replace - so the editor holds spintax the model wrote, the preview renders it, and the variables table lists the `#set` names the draft introduced. The pane's status reads *Document replaced*; before Replace was pressed it read *Draft verified* - the engine had checked this draft when the loop finished (the buttons themselves accept whatever is in the answer box, edits included). The connection row shows the provider, the endpoint, the model and an attached key. *(An earlier composition loaded the same plain text as the document and the brief, and read as if the editor's text had been sent to the model - which Generate never does: it sends the brief. Fix, the other button, does send the document it is repairing; that is the privacy policy's subject, not this frame's.)*
4. `spintax-04-dark-variants.png` - twenty generated variants with their seeds and lengths, the similarity filter, and the export actions.
5. `spintax-05-dark-german.png` - the same window in German, one of the fourteen interface languages.
6. `spintax-06-dark-source.png` - the preview showing rendered source rather than the page.
7. `spintax-07-help.png` - the built-in help open on the Choices chapter, an example clicked and its render live on the right - the help's examples are fixtures, and clicking one runs it through the real engine.
8. `spintax-08-replace.png` - find and replace: the two-row bar over the document, *matches: 2* counted over the document as the needle is typed.
9. `spintax-09-dark-group.png` - the group editor slid out beside a choice, its three alternatives on their own lines, ready to edit and apply.

**On the key in frame 3.** It is a real, working key and the frame is a real generation.
What the pane displays is `SpxLlmKeyHint` - start, ellipsis, last four - which the source
calls "the dashboard fragment, recognisable and unusable"; the field itself is write-only.
Verified in the capture before shipping it.

**How frames 7-9 are reached.** The help, the group editor and the replace bar are not
persisted in settings, but they are all STATE once asked for, and a menu is a walkable USER
object: the script fires the menu item by caption through `WM_COMMAND`, which needs neither
focus nor the foreground. The help example is then clicked by sending mouse messages to the
child under the point - deepest-first, because LCL stacks four equal-rect containers there
and only the innermost one acts. The one thing still out of reach is the variables panel's
Definitions section, collapsed behind a splitter no setting carries and no message can drag.
The whole set still regenerates unattended, and a setup step that finds no target now fails
the run instead of photographing the wrong window.

Use the final Store logo assets supplied by the brand rather than a screenshot of the editor
icon. Do not present telemetry or an always-on online service as part of Studio; the AI
connection is presented exactly as the description states it — optional, disclosed, the
reader's own key and provider, off until turned on (policy 11.16). *(This note said "do not
present AI as part of Studio R0" until 2026-08-13; the next submitted build carries Generate
and Fix, and the description above is the disclosure.)*

## Submission notes

- Package: `build/spintax-studio.msixupload`.
- Architecture: `x64`; device family: `Windows.Desktop`.
- Listing language: `English (United States)`; leave `What's new in this version` blank for the first submission.
- Website: `https://spintax.net` — **deliberate, decided 2026-08-04.** The draft asked for
  `https://spintax.studio/`; that site is not ready to be the address a Store listing sends
  people to, and `spintax.net` is fully working. Revisit when the studio site is.
- Support contact: `https://spintax.net` — same decision. The draft asked for
  `https://301.st/contact`. The direct contact obligation that arrives with live generative AI
  (spec §11, Store policy 11.16) is met since 2026-08-13 by the report channel itself:
  `support@301.st` in the description, the privacy policy and — since 2026-08-14, as plain text
  beside the licence — the About window (the Help-menu mailto item it replaced is gone; owner's
  call). The SupportUris field can stay as decided.
- Additional license terms: **DECIDED — left blank** (owner, 2026-08-08). The analysis stands
  and is why the question was asked: the source licence is GPL-3.0-or-later (with the section 7
  exception in `NOTICE.md`), and Microsoft's Standard Application License Terms — which an empty
  field conveys the package under — restrict copying and redistribution in ways GPLv3 §10 says a
  distributor may not add. The owner has weighed that and chosen to leave it empty; it does not
  affect the source, which is under the GPL from the repository regardless. See
  [`publish/store-listing-edits.md`](publish/store-listing-edits.md) §3 so this is not re-opened
  every release.
- Privacy policy: hosted at [`https://spintax.studio/privacy.html`](https://spintax.studio/privacy.html)
  **and** entered in Partner Center — **two publications, not one**. The listing's `PrivacyUrl`
  is a frozen Microsoft snapshot of the text typed into that field, not a link to the site, so
  republishing the page does not change a word of what a Store customer reads. Read from the
  storefront on 2026-08-08; both copies are stale today, and `docs/TODO.md` carries the detail.
- Pricing: `Free`; audience: public; discoverability: available and discoverable in the Store.
- Complete the IARC age-rating questionnaire and choose the appropriate app category in Partner Center.
- Accessibility declaration: leave unchecked for R0; the current build has not passed the
  required UI Automation and assistive-technology scenarios.

## Notes for Certification

Paste the following text into the Partner Center certification notes field:

```text
Spintax Studio is an offline Windows x64 desktop editor for SPINTAX templates. No account, credentials, network connection, model key, subscription, or external service is required for testing.

1. Install the MSIX package and launch Spintax Studio from the Start menu.
2. The app opens with a built-in demo template. Edit the document in the left editor pane and confirm that the rendered preview updates in the right pane.
3. Enter an invalid bracket or directive and confirm that the diagnostics panel reports the problem and its source position. Restore the document or restart the app when finished.
4. Open Help from the toolbar or Help menu. Select a valid example and confirm that it renders in the preview. The example can also be inserted into the document with the help action.
5. Open the Variables/Includes panel and the Variants panel from the left tool rail. Generate a small set of variants, optionally enable a seed, and select a generated result for preview.
6. Use the export actions to save TXT and XLSX output to a local folder selected by the tester.
7. Optionally use File > Open to load a local template file. This is not required because the built-in demo covers the main workflow.

The application has no sign-in, license activation, telemetry, analytics, or backend, and no demo account is needed (policy 10.3.1): the optional AI feature is off as installed and sits behind the tester's own endpoint and key, and every other feature above is verifiable without it. As installed the application makes no network requests; the AI panel's Generate and Fix connect only after the tester configures an endpoint at the foot of the AI draft panel and confirms the consent dialog, and internetClient is declared for exactly this feature. The window carries two brand links -- spintax.net on the tool rail and 301.st in the status bar -- which, when clicked, ask Windows to open that address in the tester's own browser; neither link is required to test the product. AI output can be reported to support@301.st, shown as plain text in the About window (Help > About) and named in the privacy policy.
```

## Supported languages, and the second Serbian listing

The storefront's *Supported languages* line is not written here: it is read from
`<Resources>` in `packaging/AppxManifest.xml.in`, which is the list of languages the WINDOW
speaks. On 2026-08-16 it read, in this order:

```
Belarusian, Bosnian (Latin), Croatian, Dutch, English (United States), French, German,
Italian, Portuguese, Russian, Serbian, Spanish, Turkish, Ukrainian
```

**"Serbian" there was wrong, and the storefront was reporting our error faithfully.** A bare
`sr` is listed by Microsoft under Serbian *(Latin)*, beside `sr-latn-rs`, while the window is
Cyrillic — which is why that entry has no script beside it and "Bosnian (Latin)", correctly
resolved from `bs`, does. The tag was also unregisterable and took the whole package down with
it (2026-08-18; the incident is in [`TODO.md`](TODO.md)). It is now `sr-Cyrl`, so **the line
will read `Serbian (Cyrillic)` after the next submission** — expected, not a regression.

**A Serbian LATIN listing is a separate thing and does not touch the package.** Partner Center
carries it under *Additional Store listing languages* → *Manage additional languages*, which
Microsoft documents as the place to add languages "that are not included in your packages". So
the second Serbian description is a listing action; the interface stays Cyrillic only (owner's
call, 2026-08-18), and declaring `sr-Latn` in the manifest would claim a Latin window that does
not exist. The suite now fails by name if anyone tries.

**WHAT ACTUALLY WENT IN WITH `0.2.1.0`: Cyrillic in BOTH Serbian listings.** The additional
language was added during that submission and filled with the same Cyrillic copy, because that
was what existed. Known and deliberate, not an oversight — and it leaves one of the two showing
a reader the wrong script, since Microsoft's own table files a bare `sr` under Serbian (LATIN).

**Prepared for the next visit, and the files are now named by the STORE ROW they go into:**

| file | script | Microsoft row | Partner Center slot |
|---|---|---|---|
| `marketing/store/sr-Latn.md` | Latin | Serbian (Latin) — the bare `sr` | **the main Serbian listing** |
| `marketing/store/sr-Cyrl.md` | Cyrillic | Serbian (Cyrillic) — `sr-cyrl` | the additional one |

The rename matters more than it looks. A file called `sr.md` holding CYRILLIC prose is a trap
with a name on it: the obvious thing to do with it is paste it into the `sr` slot, and `sr` is
Microsoft's LATIN row — which is the exact shape of the defect that cost this product a release
on 2026-08-18. `check-listing-drafts.py` now refuses a file named `sr.md` outright and says why.

`sr-Latn.md` is produced by TRANSLITERATING `sr-Cyrl.md` rather than translated afresh — Serbian
Cyrillic to Latin is 1:1 and deterministic in that direction, so the two cannot say different
things. The checker recomputes it and fails if it has been hand-edited or still holds Cyrillic;
`--regen-sr-latn` rewrites it, and the Latin file is never edited directly. Edit the Cyrillic
one and regenerate.

Measured against the caps IN THE TARGET SCRIPT, because digraphs make Latin longer: short
description 111 → 111, description 3315 → 3353 of 10000, longest feature 154 → 156 of 200, worst
single growth +8 characters. No field is near a limit.

**SUBMITTED ON ITS OWN, 2026-08-18 — a listing-only submission with the package unchanged.**
The owner's batching rule ("a review cycle for two lines of text is not worth taking") was set
aside deliberately for this one, and the shape is worth writing down because it is the first of
its kind here: **no new package, so no new version and no download for anyone already on
`0.2.1.0`.** The storefront's `SupportedLanguages` line is built from the manifest and must
therefore NOT move; only the description text and `LastUpdateDateUtc` change.

**How to verify it, and the baseline it is being verified against.** The storefront serves the
listing per LOCALE, so ask it for each Serbian one directly — cache-busted, because this API
sits behind a CDN and a plain request served an hour-old answer during the `0.2.1.0` release:

```
curl -H "Cache-Control: no-cache" "https://storeedgefd.dsx.mp.microsoft.com/v9.0/products/9MW3CH7B530P?market=RS&locale=sr-Latn-RS&deviceFamily=Windows.Desktop&_=$RANDOM"
```

Read 2026-08-18 before certification, `LastUpdateDateUtc 2026-08-18T14:46:05Z`, both Serbian
locales returning the SAME Cyrillic text — which is the state the submission exists to end:

```
sr-Latn-RS   Пишите, проверавајте, гледајте, генеришите и извозите spintax предлошке …
sr-Cyrl-RS   Пишите, проверавајте, гледајте, генеришите и извозите spintax предлошке …
```

Certified and correct looks like this instead, matching `marketing/store/` byte for byte:

```
sr-Latn-RS   Pišite, proveravajte, gledajte, generišite i izvozite spintax predloške …
sr-Cyrl-RS   Пишите, проверавајте, гледајте, генеришите и извозите spintax предлошке …
SupportedLanguages still carries "Serbian (Cyrillic)" and nothing else changed
```

If BOTH locales come back Latin, the wrong slot was filled and the Cyrillic listing is gone —
that is the failure mode to look for, and it is why the two are read separately rather than
one being assumed from the other.

Terminology for whoever reviews it: take it from `docs/help/sr/`, the way the other thirteen
drafts do — a different word for *engine* reads as a different product to a reader who clicks
through. And the transliteration is machine-made: the draft's own header still says nothing is
published until someone who reads Serbian has looked at it, and that still holds.

## What the live listing actually carries

**Re-read 2026-08-16, after `0.2.0.0` went live** (`LastUpdateDateUtc 2026-08-15T22:51:00Z`).
What was actually measured, stated as measured: four description probes (the languages
sentence, the third export path, `localizers`, `support@301.st`) are all present — markers
of the proofread text, not a byte comparison of the whole; the feature count is twenty with
GPL-3.0-or-later at position 19 and the GSA bullet at 20 — the other eighteen were not read
individually; and the What's-new field WAS byte-compared, which is how the pre-review draft
was identified. The licence bullet correction that waited since R0 is therefore on the page,
and the rebuilt executable ships the corrected `LegalCopyright`. The paragraphs below record the
2026-08-04 read-back and stand as history of what the R0 page carried until then:

Read back from the storefront on 2026-08-04, not from the submission form — the page is the
only place these values can be confirmed. Everything below matches the draft unless it is
marked otherwise:

- Title `Spintax Studio`, short title `Spintax`, publisher `301`, category *Developer tools*,
  price `Free`, platform `x64`, listing language `English (United States)`.
- Description and all twenty feature bullets matched the draft as it stood at the
2026-08-04 submission; the text above has been rewritten since (2026-08-13/14) and goes up
with the next visit.
- Age rating ESRB *Everyone*; the accessibility declaration is off (`Accessible: false`).
- Package family `301.SpintaxStudio_jnd8jmenjzsm0`, ≈ 2.54 MB.

**Two fields differ from what the draft first asked for** — website and support URI are both
`https://spintax.net`, where it named `https://spintax.studio/` and `https://301.st/contact`.
Measured from the storefront rather than assumed, and then **kept**: the owner's decision of
2026-08-04 is that `spintax.studio` is not ready to be the address a Store listing sends people
to, while `spintax.net` works completely. The submission notes above now say so, so the next
submission does not "correct" them back.

**The licence on the live page is out of date.** R0 was submitted while the repository said
Apache-2.0, so feature bullet 20 on the published listing reads *"Open-source Apache-2.0 Studio"*
and the "Additional license terms" field is blank, which puts the package under Microsoft's
Standard Application License Terms. The project is GPL-3.0-or-later as of 2026-08-04. The shipped
`0.1.0.0` executable also carries `LegalCopyright="MIT"` in its version resource; that one is
fixed in the tree and needs a rebuild.

**None of it is submitted on its own.** Owner's decision, 2026-08-04: the two listing fields need
no new package, but changing them is still a review cycle, and a review cycle for two lines of
text is not worth taking. They ride with the next submission (`v0.2.0.0`) together with the rebuilt executable — see
*What `v0.2.0.0` carries* in [`TODO.md`](TODO.md). Until then the live page stays as it is on
purpose.
