---
type: release-artifact
status: published
product: spintax-studio
---

# Microsoft Store listing

**Live since 2026-08-04:** <https://apps.microsoft.com/detail/9mw3ch7b530p>. This file is the
copy that was submitted; what the live page actually carries is recorded at the end.

This is the R0 listing copy. Keep it separate from the developer README: the Store page
describes the shipped product, not the repository or future AI work.

## Short description

Write, validate, preview, generate and export spintax templates in a focused offline Windows editor.

## Description

Spintax Studio is a native Windows workspace for writing controlled, reusable text templates.

Write once. See what it means.

The editor and live preview sit side by side, so every change is visible immediately. Write
your template on the left and inspect the rendered result on the right. Alternatives, groups,
variables, directives and markup remain readable in the source while the preview shows the
actual text produced by the engine.

From a brief to a working template.

You do not have to hand-write every variation. Visit spintax.net for the SPINTAX syntax
reference, examples and AI authoring skills. Give ChatGPT, Claude or another model your brief
and ask it to prepare a richly varied template instead of composing every alternative by hand.
Bring that draft into Studio and take control: preview what it actually produces, find and fix
syntax problems, refine the choices, and generate reproducible variants locally.

R0 does not call an AI service, send your documents to the cloud or require a model key. AI is
an optional way to create the first draft; Studio is the offline workspace where you inspect,
correct and finish the template.

Learn the language while you work.

Built-in help is part of the application, not a web page you have to find. Each topic explains
the construct in plain language, shows a working example, and connects diagnostics to the
relevant article. Select a valid example and see its result in the preview; select a repair
and make the corrected form yours.

See the structure behind the text.

Inspect variable definitions and references, session values, includes and their resolution
status. Open the group editor beside the caret when a nested choice needs attention. The panels
are designed for understanding a template, not just producing another random output.

Generate variants you can reproduce.

Create a set of variants locally, review the generated text, and use a seed when you need the
same result again. Export one variant per line as plain text or send a complete set to an XLSX
workbook. The result is yours to inspect, edit and use in your own workflow.

Built for local work.

Spintax Studio works offline. R0 requires no account, cloud service, model key, telemetry,
browser, Node.js, PHP or Python runtime. Your templates and exports stay on your computer;
the application does not send them anywhere. It is a focused Windows editor for authors,
localization workflows, SEO content teams and anyone who needs controlled variation instead
of opaque paraphrasing.

Spintax Studio is open source and built around the SPINTAX language and engine family. Learn
the language and explore the engines at spintax.net.

## Product features

Partner Center displays these as bullets. Bullet 21 arrived with the GSA import on 2026-08-06
and is **not on the live page yet** — it goes up with the same Partner Center visit as the
licence corrections below. Enter each line as a separate feature; do not include
the line numbers or bullet characters in the Store form. Each feature stays below Microsoft's
200-character limit.

1. Native Windows spintax editor for writing and maintaining reusable text templates
2. Two-pane live preview: edit the template on the left and inspect the rendered result on the right
3. Spintax syntax highlighting with bracket matching for alternatives, groups, variables and directives
4. Precise validation diagnostics with line and column positions for faster error fixing
5. Built-in offline help with tested examples, correct forms and repair guidance
6. Variable inspector for definitions, references, session values and undefined names
7. Include inspector showing targets, positions and resolution status
8. Visual group editor for alternatives and nested spintax groups
9. Permutation tools for ordering alternatives and choosing controlled subsets
10. Plural forms and language-aware content patterns for reusable templates
11. Deterministic variant generation with seed support for repeatable results
12. Variant list for reviewing generated outputs before export
13. Plain text export with one generated variant per line
14. XLSX spreadsheet export with XML-safe text and UTF-8 content
15. Light and dark themes for a comfortable editing workspace
16. Multilingual interface with 14 available UI languages
17. Offline by design: no account, cloud service, API key, telemetry or runtime required
18. Windows x64 desktop app with no browser, Node.js, PHP or Python runtime required
19. Local-first workflow for SEO content, localization workflows and reusable product copy
20. Open-source GPL-3.0-or-later Studio built around the SPINTAX engine family
21. Optional import of GSA Search Engine Ranker templates, converted and verified by the real engine

## Captured screenshots

Captured from the English release executable at 1500x890, with no personal documents or
account information visible. The files are intentionally local: keep them in
`build/store-submission/` and upload them to Partner Center from there. Five frames are light and five are dark so the listing shows
the editor in both supported themes:

1. `build/store-submission/spintax-01-diagnostics.png` - a real syntax error with source position and engine diagnostic.
2. `build/store-submission/spintax-02-variables.png` - document definitions, session values and the Includes teaching link.
3. `build/store-submission/spintax-03-variants.png` - 20 generated variants with seed and export actions.
4. `build/store-submission/spintax-04-group.png` - the group editor opened from the tool rail beside the caret.
5. `build/store-submission/spintax-05-help.png` - a valid help example selected in the Choices article and rendered on the right.
6. `build/store-submission/spintax-06-dark-workspace.png` - the live editor and preview in the dark theme.
7. `build/store-submission/spintax-07-dark-variables.png` - variables panel in the dark theme.
8. `build/store-submission/spintax-08-dark-variants.png` - generated variants and export actions in the dark theme.
9. `build/store-submission/spintax-09-dark-group.png` - editable group alternatives in the dark theme.
10. `build/store-submission/spintax-10-dark-help.png` - the help topic tree and a rendered example while the editor is dark.

Use the final Store logo assets supplied by the brand rather than a screenshot of the editor
icon. Do not present AI, cloud models, telemetry or an online service as part of Studio R0; the
optional external authoring workflow above must remain clearly external to the application.

## Submission notes

- Package: `build/spintax-studio.msixupload`.
- Architecture: `x64`; device family: `Windows.Desktop`.
- Listing language: `English (United States)`; leave `What's new in this version` blank for the first submission.
- Website: `https://spintax.net` — **deliberate, decided 2026-08-04.** The draft asked for
  `https://spintax.studio/`; that site is not ready to be the address a Store listing sends
  people to, and `spintax.net` is fully working. Revisit when the studio site is.
- Support contact: `https://spintax.net` — same decision. The draft asked for
  `https://301.st/contact`; the listing therefore offers no direct contact route, which becomes
  an obligation only when R1 ships live generative AI (spec §11).
- Additional license terms: **must not be left blank.** The source license is
  GPL-3.0-or-later (with the section 7 exception in `NOTICE.md`), and Microsoft's Standard
  Application License Terms restrict copying and redistribution in ways the GPL does not allow to
  be added. Enter the project's own terms, or a URL to `LICENSE`, so the package is conveyed under
  the licence it is actually under. *(R0 shipped with this field blank — see the note at the end.)*
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

The application has no sign-in, license activation, telemetry, analytics, or backend. It makes no network requests at all. It carries two brand links -- spintax.net on the tool rail and 301.st in the status bar -- which, when clicked, ask Windows to open that address in the tester's own browser; the application itself opens no connection and neither link is required to test the product. Optional AI authoring resources at spintax.net are external to the application and require no credentials in Studio.
```

## What the live listing actually carries

Read back from the storefront on 2026-08-04, not from the submission form — the page is the
only place these values can be confirmed. Everything below matches the draft unless it is
marked otherwise:

- Title `Spintax Studio`, short title `Spintax`, publisher `301`, category *Developer tools*,
  price `Free`, platform `x64`, listing language `English (United States)`.
- Description and all twenty feature bullets are the text above, unchanged.
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
text is not worth taking. They ride with `v0.1.1.0` together with the rebuilt executable — see
*What `v0.1.1.0` carries* in [`TODO.md`](TODO.md). Until then the live page stays as it is on
purpose.
