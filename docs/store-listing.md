---
type: release-artifact
status: published
product: spintax-studio
---

# Microsoft Store listing

**Live since 2026-08-04:** <https://apps.microsoft.com/detail/9mw3ch7b530p>. This file is the
copy for the NEXT submission; what the live page actually carries is recorded at the end, and
the differences travel with the next Partner Center visit (`v0.2.0.0`)
([`publish/store-listing-edits.md`](publish/store-listing-edits.md)).

Updated 2026-08-13 for the AI slice: the description now discloses the live generative AI
feature and names the report channel (Store policy 11.16), because the next submitted build
carries Generate and Fix. Keep it separate from the developer README: the Store page
describes the submitted product, not the repository.

Refreshed 2026-08-14 for the owner's pre-submission review — the product moved in the last
week and the copy had not: the AI draft's main path is now *turn the text you already have
into a template* (the brief is the second mode, not the first); the draft is verified by the
real engine before it ever replaces the document; the editor gained find-and-replace and an
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
The draft is not taken on trust: it is verified by the same engine that renders your preview
before it ever replaces your document, and Fix sends the engine's own findings back for
repair. All of it goes to the endpoint you configure, with your own key and account when the
endpoint uses them, and it is off until you turn it on. Prefer to keep the network out of it?
Copy the prepared prompt to ChatGPT, Claude or another model and paste the draft back — that
path needs no key and no connection. Either way Studio is where you take control: preview
what the draft actually produces, find and fix syntax problems, refine the choices, and
generate reproducible variants locally.

The AI connection sends only what you choose to send, to the endpoint you configured, and
nothing until you turn it on. Found an AI draft inappropriate? Write to support@301.st — the
address is in the About window.

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

Spintax Studio works offline. It requires no account, cloud service, telemetry, browser,
Node.js, PHP or Python runtime, and no model key — the optional AI connection is off until
you turn it on, and even then a key only if the endpoint you point it at asks for one. Your
templates and exports stay on your computer; nothing is sent anywhere
except what you yourself send to the AI endpoint you configured. It is a focused Windows
editor for authors, localization workflows, SEO content teams and anyone who needs controlled
variation instead of opaque paraphrasing.

Spintax Studio is open source and built around the SPINTAX language and engine family. Learn
the language and explore the engines at spintax.net.

## Product features

Partner Center displays these as bullets. The GSA import bullet arrived on 2026-08-06 and is
**not on the live page yet** — it goes up with the same Partner Center visit as the licence
corrections below. Enter each line as a separate feature; do not include the line numbers or
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
9. Permutation tools for ordering alternatives and choosing controlled subsets
10. Plural forms and language-aware content patterns for reusable templates
11. Insert menu that wraps a selection into a choice, shuffle or comment and drops in ready-made constructs
12. Deterministic variant generation with seed support for repeatable results
13. Variant list for reviewing generated outputs before export
14. Export as plain text with one variant per line, or as an XLSX workbook with XML-safe UTF-8 content
15. Light and dark themes for a comfortable editing workspace
16. Multilingual interface with 14 available UI languages
17. Offline by default: no account, no telemetry, and no browser, Node.js, PHP or Python runtime — the optional AI link uses your own provider, and your own key when one is needed
18. Local-first workflow for SEO content, localization workflows and reusable product copy
19. Open-source GPL-3.0-or-later Studio built around the SPINTAX engine family
20. Optional import of GSA Search Engine Ranker templates, converted and verified by the real engine

## Captured screenshots

**STALE AS OF 2026-08-14 — recapture before submission.** The ten frames below predate the
last week of the product: none shows the AI draft panel (the submission's headline feature
and its disclosure), the find bar's replace row, or the Insert menu, and the menu bar in
every frame is one menu short. The capture probes in `scripts/` still apply; the frame
COMPOSITION is the owner's call at review time — at minimum one light and one dark frame of
the AI panel belong in the set.

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

## What the live listing actually carries

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
*What `v0.1.1.0` carries* in [`TODO.md`](TODO.md). Until then the live page stays as it is on
purpose.
