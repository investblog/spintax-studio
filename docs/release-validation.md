# Release validation

Three records, newest first: a pre-tag check of the AI candidate on 2026-08-14, `v0.1.1.0`
validated on 2026-08-08 (tagged, never submitted — the tree moved on), `v0.1.0.0` (R0) on
2026-08-03 and published on 2026-08-04.

---

# Pre-tag check — 2026-08-14 (the first candidate that makes outgoing connections)

**Not the formal record for the next version** — that one follows the convention below and
runs against the exact artefact the next tag produces. This run answers R1-10's question
early, before the tag exists: does the AI candidate, with the manifest as it now stands,
pass WACK at all? It does.

## Candidate

Built locally by `scripts/make-msix.py` from the working tree at `VERSION` 0.1.1.0 —
deliberately NOT submission material (the tag's CI artefact is), but carrying the same
capability and resource declarations the next tag will (the version number itself will
differ: the next tag must be a new one):

- `internetClient` declared for the first time (N6, owner's decision 2026-08-09: technically
  unnecessary at medium IL, declared so the storefront says "uses your internet connection"
  before install). The suite pins the capability pair exactly.
- Fourteen `<Resource Language>` entries (the 2026-08-09 fix), first time through MakeAppx.
- One package build was LOST to the double-hyphen-in-XML-comment trap: the 2026-08-09
  languages comment carried a prose ` -- ` and MakeAppx reported it as an "expected '>'"
  at a column, exactly as the manifest's own header warns. The suite now takes the comments
  out and holds every body hyphen-pair-free (and not hyphen-terminated), and the remainder
  free of pairs and unclosed openers — so the next one fails as a named check instead of a
  package build.

## WACK

```powershell
appcert.exe reset
appcert.exe test -appxpackagepath build\spintax-studio.msix `
  -reportoutputpath build\wack\spintax-studio-wack-20260814-191344.xml
```

Result: `OVERALL_RESULT=PASS`, `PARTIAL_RUN=FALSE`. Declaring `internetClient` moved no
required test.

The optional test **Blocked Executable Files** reports three findings — one API reference
and two blocked-executable substrings — one more than R0's two:

- `shell32.dll!ShellExecuteW` — the deliberate browser action (the two marks), unchanged;
- `reg` — the HTML entity name in `TSynHTMLSyn`'s table (`&reg;`), unchanged;
- `dnx` — NEW, and measured before being explained: the executable contains the byte
  sequence exactly once, inside a table of 4-byte-aligned offsets whose neighbours read
  `8nx`, `Xnx`, `lnx` — a coincidence of binary data, not a reference to any tool. Same
  class as `reg`: an analyzer finding in an optional test, not Store-blocking, and nothing
  to silence.

**For the next submission's certification notes:** no demo account is needed (policy
10.3.1) — the AI feature is opt-in behind the reader's own endpoint and key, and the entire
product is verifiable without one; the report channel is the About window's plain-text
address, named in the listing description and the privacy policy.

---

# v0.1.1.0 — validated 2026-08-08

## Candidate

The **exact** artefact the tag produced, downloaded from the draft release rather than rebuilt
locally — a local rebuild would be a different package and the report would describe something
nobody submits.

- Tag `v0.1.1.0` → `8c65ae2`, built by `.github/workflows/release.yml`
- `spintax-studio.msix`, 2 943 284 bytes
- SHA-256 `0c854fb7002a9e497944d61c407915dc9321b847268ceb3a6e4f9a4c2b4b9088`, **checked against
  the published `SHA256SUMS` before the run**
- Identity, publisher and architecture unchanged from R0, so this is an update rather than a
  new identity: `301.SpintaxStudio`, `CN=BEE1F94B-ABDE-4CF8-9F30-1DF4DAFDAE83`, x64

CI was green on that commit across all five jobs before the tag was cut, which is new: the
release path had never had the two regenerate-and-diff gates until this version, and `ci.yml`
does not run on a tag at all (a `branches:` filter excludes tag pushes).

## WACK

```powershell
appcert.exe reset
appcert.exe test -appxpackagepath build\spintax-studio.msix `
  -reportoutputpath build\wack\spintax-studio-wack-20260808-192523.xml
```

Kit version `10.0.19041.5609`. Result: **`OVERALL_RESULT=PASS`, `PARTIAL_RUN=FALSE`.**
24 tests — **all 13 required tests pass**, including application manifest, resource packages,
branding, private code signing, platform-appropriate files and DPI awareness.

One OPTIONAL test fails, **Blocked Executable Files**, with three analyser findings. R0 had two;
the third is new, and it was investigated rather than assumed to be another false positive of
the same kind:

| finding | what it actually is |
|---|---|
| `shell32.dll!ShellExecuteW` | LCL's `OpenURL`, behind the two marks that hand an address to the browser. Deliberate, and the privacy policy describes it. |
| `"reg"` | the HTML entity name in SynEdit's `TSynHTMLSyn` table. `&reg;` appears once in the binary; `reg.exe` appears zero times. |
| `"cMD"` — **new in this version** | a byte coincidence inside compiled code at offset 234753, surrounded by x86-64 REX.W instruction prefixes. Not a string. |

Measured in the shipped executable, extracted from the package under test:

```
CreateProcessW  0    WinExec     0    cmd.exe     0
CreateProcessA  0    system      0    reg.exe     0
ShellExecuteW   1    powershell  0
```

So the binary imports exactly one process-launching API — the browser action — and references
no blocked executable at all. The analyser matches ASCII substrings and these two hit machine
code and a collation table. Removing them is not possible without removing HTML entity support
and the browser action, which would change the product to silence a report that is not about
the product.

The report is kept locally under `build/wack/`; generated build evidence is not tracked.

---

# R0 Release Validation

Date: 2026-08-03 (validation) · 2026-08-04 (published)

**Outcome: live in the Microsoft Store** — <https://apps.microsoft.com/detail/9mw3ch7b530p>.

## Candidate

- Package: `build/spintax-studio.msix`
- Store upload wrapper: `build/spintax-studio.msixupload`
- Identity: `301.SpintaxStudio`
- Publisher: `CN=BEE1F94B-ABDE-4CF8-9F30-1DF4DAFDAE83`
- Version: `0.1.0.0`
- Architecture: x64
- Store ID: `9MW3CH7B530P`

The package was generated by `python scripts/make-msix.py`. The Store tile source is
`assets/brand/spintax-mark-310.png`; the generated role assets are `310x310` and `310x150`,
so they meet the dimensions declared by the manifest.

**The tile in the SHIPPED package is off-centre**, found 2026-08-06 by the reader looking at the
file: the mark sat at the top left of its canvas with margins L19 R79 T3 B63 — 212×244 of ink in
310×310. Only this file was affected; `spintax-mark-180.png`, which the `.ico` is built from, was
centred all along, which is why the application's own icon looked right. Corrected in the tree by
re-rendering from the vendored vector and centring (L49 R49 T33 B33); it reaches the Store with
the next package, since tiles are built from this file at submission time.

## WACK

Windows App Certification Kit was run against the exact MSIX candidate:

```powershell
appcert.exe reset
appcert.exe test -appxpackagepath build\spintax-studio.msix `
  -reportoutputpath build\wack\spintax-studio-wack-20260803-000024.xml
```

Result: `OVERALL_RESULT=PASS`, `PARTIAL_RUN=FALSE`. All required tests pass, including
application resources, manifest, branding, platform compatibility and DPI awareness.

The optional test **Blocked Executable Files** reports two static references:

- `shell32.dll!ShellExecuteW`, used by the deliberate About/site action that opens the
  user's browser;
- `reg`, which is the HTML entity name in Lazarus/SynEdit's `TSynHTMLSyn` table (`&reg;`),
  not a call to `reg.exe`.

These are analyzer findings in an optional test, not Store-blocking failures. Removing the
browser action or HTML entity support would change product behavior solely to silence a false
positive. The WACK report is kept locally under `build/wack/`; generated build evidence is not
tracked.

## Certification and publication

Certification passed on the first submission; the listing went live on **2026-08-04**
(`ReleaseDateUtc` `2026-08-04T10:32:03Z`, last updated `10:31:53Z`). As the storefront reports
it:

- Listing: <https://apps.microsoft.com/detail/9mw3ch7b530p>
- Title `Spintax Studio`, publisher `301` (publisher id `93915800`), category *Developer tools*
- Price `Free`; platform `x64`; package family name `301.SpintaxStudio_jnd8jmenjzsm0`
- Download size ≈ 2.54 MB; listing language `English (United States)`
- Age rating: ESRB *Everyone* (IARC questionnaire)
- `Accessible: false` — the declaration is off, as decided in
  [ADR 0009](decisions/0009-accessibility-on-a-toolkit-with-no-bridge.md). UI Automation
  support for the editor and diagnostics remains a post-release slice.

The two account-side blockers named before submission are closed: the reserved identity matched
the generated manifest, and the privacy policy is hosted at
<https://spintax.studio/privacy.html> (the storefront also serves its own snapshot of the text,
which does not follow later edits to the site).

The published package is the `v0.1.0.0` tag, so `git log v0.1.0.0..HEAD` is what users do not
have yet.
