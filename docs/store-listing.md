---
type: release-artifact
status: draft
product: spintax-studio
---

# Microsoft Store listing draft

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

Partner Center displays these as bullets. Enter each line as a separate feature; do not include
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
20. Open-source Apache-2.0 Studio built around the SPINTAX engine family

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
- Website: `https://spintax.studio/`.
- Support contact: `https://301.st/contact`.
- Additional license terms: leave blank to use Microsoft's Standard Application License Terms. The repository's MIT license remains the source license for the code.
- Privacy policy: publish [`https://spintax.studio/privacy.html`](https://spintax.studio/privacy.html)
  at a public HTTPS URL and enter that URL in Partner Center.
- Pricing: `Free`; audience: public; discoverability: available and discoverable in the Store.
- Complete the IARC age-rating questionnaire and choose the appropriate app category in Partner Center.
- Accessibility declaration: leave unchecked for R0; the current build has not passed the
  required UI Automation and assistive-technology scenarios.
