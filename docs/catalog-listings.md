# Catalog listings — copy for the forms that are not PAD

Drafts for catalogs that take a hand-written submission rather than `pad.xml`. The PRODUCT
facts below are taken from [`pad-listing.md`](pad-listing.md) or
[`store-listing.md`](store-listing.md), which are gated. **Nothing here is gated**, so when a
fact changes there, re-read this file. Facts about the catalogs themselves come from their own
pages, read on 2026-10-05. Where each submission stands is recorded in `docs/TODO.md`, under
*Catalog submissions*.

## FileHorse — <https://www.filehorse.com/contact/>

`/submit/` lists what to include and points to the contact form. That form has four required
fields: **Name, Email, Subject, Message**, and a reCAPTCHA checkbox, which the accessibility
tree does not show and a screenshot does (read in a browser, 2026-10-05). They
ask the sender to say who they are, review by hand, and scan with VirusTotal and Google Safe
Browsing. They ask for an icon "preferably 256px x 256px". There is no exact 256 asset: the
site has 96, 180 and 512, and the message offers the 512.

- **Name:** the owner's, or a role at 301.st. It is a required field, and the page asks for
  it.
- **Email:** `webmaster@301.st`
- **Subject:** `Software submission: Spintax Studio 0.2.3.0 (free, Windows)`
- **Message:**

```

Hello,

I am writing on behalf of 301.st, the developer of Spintax Studio, to submit it for listing.

Program: Spintax Studio 0.2.3.0
Website: https://spintax.studio/
Download (portable ZIP, 2.94 MB): https://github.com/investblog/spintax-studio/releases/download/v0.2.3.0/spintax-studio-0.2.3.0-win64-portable.zip
Microsoft Store listing (currently 0.2.2.0; 0.2.3.0 follows): https://apps.microsoft.com/detail/9mw3ch7b530p
License: Open Source, free (GPL-3.0-or-later)
Requirements: Windows 10 version 1809 or later, x64; no installer, no runtime
Icon (512x512): https://spintax.studio/assets/icon-512.png
Screenshot: https://spintax.studio/assets/shots/editor.png
PAD file: https://spintax.studio/pad.xml

Spintax Studio is a native Windows editor for spintax templates: two panes, the template on
the left, its live render on the right. The preview and the valid/invalid verdict come from
the real spintax engine inside the application, not from a second parser. Diagnostics carry
line and column positions and link to the built-in help. Variants are generated locally, can
be reproduced with a seed, and can be exported to plain text, XLSX, or one file per variant. It works
offline: no account, no telemetry. Interface and help in 14 languages.

Source code: https://github.com/investblog/spintax-studio

Best regards,
<name>
301.st
webmaster@301.st
```

`<name>` is the same as the Name field.

## AlternativeTo — <https://alternativeto.net/manage/new/>

The account must be at least seven days old. Review takes from a couple of days to a week
(free). The form's fields are taken from submission guides, not from the form itself, which
answers 403 to anything but a browser. Read the form when it is open, and correct this
section.

| Field | Value |
|---|---|
| Name | `Spintax Studio` |
| Tagline | `Windows editor for spintax templates, with live preview and export` |
| Website | `https://spintax.studio/` |
| Platforms | Windows |
| License | Free, Open Source (GPL-3.0-or-later) |
| Source | `https://github.com/investblog/spintax-studio` |
| Tags | `spintax`, `text-editor`, `content-writing`, `seo`, `template-editor` |
| Icon / screenshot | `icon-512.png`, `assets/shots/editor.png` on spintax.studio |

Description: the English `Char_Desc_2000` from `pad-listing.md`, as is.

**"Alternative to" is the owner's call, and it is a claim.** Studio is a template editor,
and it ALSO has optional AI drafting: it turns text you already have, or a brief, into a
template, through an endpoint the user configures (`store-listing.md`, "From the text you
already have"). So it overlaps with AI rewriters only through that one opt-in feature, and
only for users who bring an endpoint. Its main job is writing and checking spintax by hand,
which is what the editing views of spinner tools are for. Which of those tools a reader
would actually swap for Studio has NOT been researched here. Product names that came up in
a search (The Best Spinner, SpinnerChief, Chimp Rewriter, WordAi, Spin Rewriter) are
pointers, not findings. AlternativeTo refuses plain requests, so check each one in the form,
where the autocomplete shows what exists and what it does.
