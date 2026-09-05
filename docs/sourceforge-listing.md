---
type: release-artifact
status: published
product: spintax-studio
tags: [distribution, marketing]
---

# SourceForge project listing

**Live since 2026-09-05.** Name, summary, description, 16 features, homepage, support
URL and all twenty-seven categories are filled and were read back from the server after
saving; the owner uploaded the three screenshots. What is written below is what the page
carries. The Downloads section began as a finding and is now mostly a record of the fix; the
one thing still open there, and the manual import behind it, are called out where they sit.

The project is <https://sourceforge.net/projects/spintax/> — unixname `spintax`, fixed at
creation and not editable; the display **Name** is a separate field, so the page can read
*Spintax Studio* on a `/projects/spintax/` URL. Created 2026-09-05 by importing the GitHub
repository, with SourceForge's release importer pointed at the GitHub releases.

**Scope: Spintax Studio only** (owner's decision, 2026-09-05). The other engines are
mentioned as the family this one belongs to, and linked; they are not what the project is.

**The product claims are not this file's to invent.** Every statement about what the
application does — in the summary, the description and the features — is the same claim as in
[`store-listing.md`](store-listing.md), compressed to SourceForge's much smaller fields. If one
needs to change, it changes there first: this project has published a false claim on a
storefront twice, and both times it was one document drifting from another. Everything else
here is SourceForge's own — the form's limits, the project settings, the categories, what the
release import produced, the screenshots — and is measured against SourceForge.

## The form's own limits — measured, not assumed

Read off the admin form's DOM on 2026-09-05 (`maxlength` attributes and the live character
counters), because a limit discovered mid-paste is how a field gets filled badly or skipped:

| Field | Form name | Limit |
|---|---|---|
| Name | `name` | **40 characters** |
| Unixname | — | fixed, `spintax`, read-only |
| Homepage | `external_homepage` | none |
| Short Summary | `summary` | **70 characters** |
| Full Description | `short_description` | **1000 characters** (counter, no `maxlength`) |
| Features | `features-N.feature` | no limit; the list grows a row at a time |
| Preferred Support Page | `support_page` + `support_page_url` | None / project admins / URL |

Two traps in that table. The description field is *called* `short_description` and is the
long one; and a textarea submits **CRLF**, so its eight newline characters — four blank-line
separators between five paragraphs, two newlines each — cost eight more than the text measures
locally. The copy below is 973 characters as written and 981 as the browser will count it.

Categorization is a separate page (`/admin/trove`) with nine sections; Screenshots is a
third. Both are listed further down with the exact option strings the form offers.

## Name

```
Spintax Studio
```

14 of 40. The imported default was `spintax-studio`, the repository name.

## Short Summary (70)

```
Offline Windows editor for spintax templates with live preview
```

62 characters. Alternatives measured against the same cap, if the owner prefers a verb or
the word *export*: *Write, preview and export spintax templates in a Windows editor* (63),
*Spintax template editor for Windows: live preview, checks, export* (65).

## Full Description (1000)

**Form-ready, verbatim** — the fence is the field, so nothing has to be inferred about where
it starts and stops. Paragraphs separated by one blank line and **not hard-wrapped**: a
textarea keeps the breaks it is given, and a draft wrapped to this file's width would paste as
ragged half-lines. That is the same trap the Store's What's-new field set.

```
Spintax Studio is a native Windows editor for spintax templates: two panes, your template on the left, its live render on the right.

Preview and the valid/invalid verdict come from the real spintax engine inside the application, not from a second parser. Diagnostics carry line and column positions and link to the built-in help; panels list variable definitions, references, session values and #include targets with their resolution status.

Generate variants locally, reproduce them with a seed, and export as plain text, an XLSX workbook, or one file per variant.

Offline by default: no account, no telemetry, no Node.js, PHP or Python runtime — one self-contained executable. Optional AI drafting is off until you turn it on and talks only to the endpoint you configure, with your own key when it needs one.

Interface and built-in help in 14 languages. Free and open source, GPL-3.0-or-later. The SPINTAX language and its engine family are documented at spintax.net.
```

**What is deliberately not in it**, having been cut for the 1000: the group editor, find and
replace, the Insert menu, themes, and the GSA import. All five are in the Features list,
which has no cap — the description carries what a reader needs to decide, the list carries
what they get.

**Two wordings are load-bearing and must survive any edit.** *"with your own key when it
needs one"* — not *"your own provider and key"*, which overstates it; a local endpoint may
need no key. And *"talks only to the endpoint you configure"* — the application cannot claim
that nothing leaves the computer, because a proxy or a tunnel answers on a loopback port too
(spec §4.5).

## Features

Entered one per row; the form adds a row as you fill the last one. Derived from the twenty
Store bullets, merged where SourceForge's narrower column would wrap them.

1. Two-pane editor: your template on the left, the engine's live render on the right
2. Preview and validation come from the real spintax engine, not from a second parser
3. Syntax highlighting with bracket matching for alternatives, groups, variables and directives
4. Diagnostics with line and column positions, each linked to the built-in help
5. Variable and include inspectors: definitions, references, session values, targets and resolution status
6. Visual group editor for nested alternatives, opened beside the caret
7. Shuffles, plural forms and language-aware patterns, with separators of your choice
8. Find and replace that counts and folds case exactly the way the engine does
9. Insert menu that wraps a selection into a choice, shuffle or comment
10. Deterministic variant generation with seeds, and a variant list to review before export
11. Export as plain text, as an XLSX workbook, or as one file per variant
12. Built-in offline help with tested examples and repair guidance
13. Interface and help in 14 languages, with light and dark themes
14. Optional AI drafting through the endpoint you configure — off until you turn it on
15. Optional import of GSA Search Engine Ranker templates, verified by the real engine
16. One self-contained Windows executable: no account, no telemetry, no runtime to install

## Homepage and support

- **Homepage:** `https://spintax.net` — the same address the Microsoft Store listing carries
  in its website field. The imported default was `https://spintax.sourceforge.io`, an empty
  SourceForge-hosted vhost, and must not stay.
  *Owner's call:* `https://spintax.studio` is the product's own site, and the Store's support
  URI already points at it — measured on the storefront 2026-09-05, where `AppWebsiteUrl` is
  `spintax.net` and `SupportUris` is `spintax.studio`. That move is undated in this repository
  (the records still described the 2026-08-04 decision, when both were `spintax.net`), so if
  the studio site is now the front door, this field moves with it.
- **Preferred Support Page → URL:** `https://github.com/investblog/spintax-studio/issues`.
  The in-application report channel stays `support@301.st` (About window), which is what the
  Store's AI-content policy disclosure names; the two are not in conflict.
- **Socials:** left empty. Filling `twitter_handle` and its neighbours with a guess is a
  published claim like any other.

## Categorization

Exact option strings, read off the nine `/admin/trove` selects on 2026-09-05.

- **Topic:** `Text Editors » Text Processing`, `Internet » SEO`,
  `Software Development » Localization (L10N)`.
  *Considered and left out:* `Artificial Intelligence » AI Text Generators`. The AI drafting
  is real and optional, but a reader arriving from that category expects a generator and
  finds an editor. Owner's call, not a defect either way.
- **License:** `OSI-Approved Open Source » GNU General Public License version 3.0 (GPLv3)`.
  **This is an approximation the form forces:** the licence is GPL-3.0-**or-later** with an
  additional permission under section 7 for the MPL-1.1 components (SynEdit, IPro), and
  SourceForge's list offers neither the "or later" form nor exceptions. `LICENSE` and
  `NOTICE.md` remain authoritative and both travel in the source archives.
- **Operating System:** `Windows`.
- **Development Status:** `5 - Production/Stable` — published, certified and live in a
  curated store since 2026-08-04, three versions in. `4 - Beta` is the conservative reading
  of a `0.2.x` version number; owner's call.
- **Intended Audience:** `by End-User Class » End Users/Desktop`,
  `by End-User Class » Advanced End Users`, `by End-User Class » Developers`.
- **Programming Language:** `Free Pascal`, `Object Pascal`, `Pascal`.
- **User Interface:** `Graphical » Win32 (MS Windows)`.
- **Translations:** all fourteen the application ships — `Belarusian`, `Bosnian`, `Croatian`,
  `Dutch`, `English`, `French`, `German`, `Italian`, `Portuguese`, `Russian`, `Serbian`,
  `Spanish`, `Turkish`, `Ukrainian`. Every one exists in the form's list, checked.
  Note `Portuguese` and not `Brazilian Portuguese`, matching what the Store reports.
- **Database Environment:** none.

## Downloads — what the import actually produced

Measured on 2026-09-05, before the page was filled:

- The big green button on `/projects/spintax/files/` reads **"Download Spintax Studio
  v0.2.1.0 source code.zip (2.4 MB)"**. SourceForge picked the default itself, and it picked
  the one file a Windows reader cannot run.
- Each release folder holds `spintax-studio.msix`, `spintax-studio.msixupload`,
  `SHA256SUMS`, `README.md` (the GitHub release body, which SourceForge renders as the
  folder's release notes) and both source archives.
- **The MSIX is not signed** — `scripts/make-msix.py` has no signing step, because the Store
  signs it. A reader who downloads it cannot install it.
- **`.msixupload` is a Partner Center submission container.** It has no meaning outside the
  submission form and should not be offered to anyone.
- The newest folder is `v0.2.1.0`, because the **`v0.2.2.0` GitHub release is still a
  draft** — so SourceForge advertises a version older than the Store's.

So the page as imported hands a Windows user a source archive, an uninstallable package, and
an upload container. Four things fix it, in order of what they buy — **all but one done on
2026-09-05, and the ZIP did not wait for a new tag**:

1. **A portable ZIP, built from the artefact the TAG produced.** `release.yml` builds
   `spintax-studio-<version>-win64-portable.zip` from now on. For `0.2.2.0`, which was tagged
   before that step existed, the archive was made without rebuilding anything: download this
   release's own `spintax-studio.msix`, check it against the published `SHA256SUMS`
   (`729df8df…`, the value `release-validation.md` records), take `spintax-studio.exe` out of
   it, and zip it with the tag's `LICENSE`, `NOTICE.md` and `README.md`. That exe is
   **byte-identical to the one the Microsoft Store installs** (`9E7193F8…`, compared against
   the installed 0.2.2.0), so the ZIP is the tag's output and not a local rebuild.
   Then it was RUN: unzipped into an empty folder, launched, and it opened both windows the
   charter describes (`Untitled — Spintax Studio` and `Spintax Studio`) with no error dialog.
   The settings file was backed up first and verified unchanged after.
2. **The `v0.2.2.0` GitHub release is published** (owner's command, 2026-09-05), so the
   importer stops advertising 0.2.1.0.
3. **The release notes now say which file to download**, because SourceForge writes the GitHub
   release body into the folder as `README.md` and renders it under the file list — which is
   exactly where a visitor who does not know what a `.msixupload` is will be looking.
4. **The portable ZIP is the default download for Windows**, ticked in the file manager rather
   than left to SourceForge's own heuristic (which had picked the source archive, and picked
   the ZIP by itself once it existed — a guess that happened to be right is not a setting).
   Verified from outside, logged out, with a Windows user agent:
   `/projects/spintax/files/latest/download` resolves to
   `spintax-studio-0.2.2.0-win64-portable.zip`.

**Still open, and the owner's to do:** delete the `.msixupload` files from the SourceForge
folders. Deleting published files is not an agent's action here.

## The integration, and exactly how far it is proven

**Wired 2026-09-05 by the owner, the narrow way.** One webhook on the repository, which is
what SourceForge's own manual instructions describe and what this project chose over the
automatic setup. Read back from both sides rather than taken from either:

```
GitHub      hook 674990351   active   events ['release']   content_type form   secret set
            url  https://sourceforge.net/p/spintax/files-sf/github_webhook
SourceForge admin page reads "Integration configured"
deliveries  ping           200 OK
            release/edited 200 OK   (x2, fired deliberately as a test)
```

**What that proves and what it does not.** The pipe exists and carries real `release` events,
not merely the ping SourceForge tells you to look for: two were delivered and answered 200.
It does NOT prove that a new release gets IMPORTED, because the events fired were `edited`
and the one that matters is `published`, and nothing visible changed on the Files tab
afterwards — which says little either way, since SourceForge shows each file's GitHub
timestamp rather than its own import time, so a re-import of identical bytes and a
do-nothing look the same. **The first real proof is the next release**; until then the
one-time import form is the fallback, and it is the thing to reach for if a release ever
appears on GitHub and not here.

**Why not the automatic setup.** It was started and stopped at GitHub's consent screen,
which is where the scopes stop being a description and become a list: `write:repo_hook`
**and `public_repo`** — read *and write* to public repositories, not merely leave to add a
hook. Nothing was authorised, and afterwards the repository still had no webhook and the
release body was untouched. A webhook only *sends* SourceForge events and grants it access
to nothing, which is the same job for less. The secret is not copied into this file.

**And the automatic form's checkbox is ticked by default:** *Add a SourceForge download
button into GitHub release notes* — which rewrites the release body. Here that body is
hand-written copy telling a reader which of four files to download, so the box wants
clearing before that form is ever submitted. Written down because it was submitted ticked on
the first attempt, and only the consent screen stopping the flow made that harmless.

**The test edit was not the no-op it was called.** Re-writing the release body with its own
text went through a shell redirect that added a trailing newline, and the round trip
normalised the stored line endings as well: the rendered text never changed, but "identical"
was the wrong word for it. It was set back to exactly the authored notes through the API,
byte for byte, and checked. A no-op is a claim like any other.

## The gate

`scripts/check-sourceforge-listing.py`, run by the `listing` job in `ci.yml`. It holds this
file to the form's three limits (counting the description in CRLF, as a textarea submits it),
refuses a hard-wrapped description paragraph, and pins the licence name, the language count
(read from the package manifest, not typed), and the two load-bearing AI wordings. It also
checks **every number this file states about itself** — "14 of 40", "62 characters", "973 …
and 981", "16 features" — because those are right when written and stale after one edit. The
count is written in digits because a number WORD needs a table to read, and a table silently
ignores the numeral it lacks.

Verified the way this project verifies a gate: eleven mutations, each caught by name, the file
restored byte-for-byte afterwards.

**What it does not cover, written here rather than assumed:** it reads a file, not the live
page. If somebody edits the project in the browser and not here, it passes and this file
becomes fiction — which is precisely how the Store's `SupportUris` moved to `spintax.studio`
with two documents still describing the old decision.

## Screenshots

**They exist, and not in this repository** — `W:\Projects\spintax.studio\static\assets\shots`,
in the product site's tree, 1500×890 each. This file first said the repository had none and
that new ones would have to be photographed; the owner corrected it on 2026-09-05. Worth the
line: `assets/store/` here is promotional art and gitignored, so *searching this repo* is what
produced the wrong answer, and the product's own site is where its pictures live.

Three are live, in this order, with these captions (read off the public page):

| File | Caption |
|---|---|
| `editor.png` | Two panes: the template on the left, the engine's own render on the right |
| `ai.png` | Optional AI drafting: your endpoint, your key, and nothing applied until you apply it |
| `group-dark.png` | The group editor opens beside the caret — dark theme |

`editor.png` goes first because it is the product in one frame: syntax highlighting, `#set`,
`#def`, `#include`, a shuffle with its configuration, a conditional, and the rendered text
beside them, with `valid · 4 ms` in the status bar.

The API key visible in `ai.png` is masked by the window itself (`sk-ant-api03…2AAA`), which is
the application's doing and not a crop — worth knowing before anyone edits or re-shoots it.
