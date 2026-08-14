---
type: note
status: active
tags: [store, ai, policy]
project: spintax-studio
---

# Store policy 11.16 — the four duties, and where each one lives

Policy 11.16 "Live Generative AI Content" (Store Policies version 7.19, effective
14 October 2025) makes four demands of a product that generates content with live AI. This
file maps each demand to the thing that satisfies it, and records the procedure for the one
demand that is a procedure. It is a publish-folder document because two of the four are
performed **at the submission form**, and the next session should find the decisions here
rather than re-derive them.

## 1. "Disclose the use of live generative AI in the metadata"

In [`../store-listing.md`](../store-listing.md), since 2026-08-13: the description names
"optional live generative AI" in plain words — what Generate and Fix do, whose key, whose
account, and that it is off until turned on. The suite pins the phrase and the report address
to the file, so the disclosure cannot quietly fall out of a later rewrite. The thirteen
localized drafts in `marketing/store/` take the same two paragraphs before the submission —
`scripts/check-listing-drafts.py` keeps their structure in step; the prose is the
pre-submission review's.

## 2. "Note the use of live generative AI in Partner Center during the submission process"

A form action, not a file: at the `v0.1.1.0` submission, answer the AI-content question in
Partner Center's Properties/declarations step affirmatively. It cannot be prepared further
than this note, because the form's exact wording changes and a misquoted question is worse
than none (the same rule the data-declaration note in
[`network-slice-edits.md`](network-slice-edits.md) §3 already follows). Do not carry last
submission's answers forward: R0 truthfully declared no AI service, and this build is the
reason that answer changes.

## 3. "Ensure that dynamic content created by generative AI models complies with all applicable Store Policies"

What the product itself does, stated exactly — neither more nor less:

- Every draft is verified by the engine before the window applies it, which is a claim about
  SYNTAX and renderability, not about content. The application does not and cannot moderate
  meaning.
- The model and the endpoint are the reader's own choice, and any key or account involved is
  theirs (BYOK, spec §4.5). Where the endpoint's operator states a content policy, that
  policy governs generation; an endpoint can also be self-hosted or otherwise state none, and
  then the reader is the operator and there is no third party's policy to point at. The
  profile always names the recipient the reader chose, which is what makes either case
  answerable.
- The prompt the loop sends (held byte-exact by fixtures) asks for template text from the
  reader's own brief; nothing in it solicits content a Store policy names.
- Nothing generated is published by this application anywhere: the draft lands in the
  reader's editor, on their machine, and goes no further unless they take it somewhere.

Compliance beyond that is handled through duty 4: content the reader believes crosses a
policy has a named address to the developer, always available in the About window.

## 4. "Provide a means for users to report inappropriate content to the developer. You must take appropriate actions based on those reported concerns"

**The means:** the About window (Help → About) shows **support@301.st** as a line of plain
text beside the licence — "Report inappropriate AI output: support@301.st", in the reader's
own interface language, all fourteen. The same address is named in the privacy policy (all
three copies, suite-gated) and in the listing description. It is present whether or not the
network is on — output pasted through the manual path is AI output too. *(Until 2026-08-14
this was a Help-menu item that opened a mailto; the owner moved it into the About box, which
also removed the application's one mailto hand-off to the shell — the privacy policy's link
count moved from three to two in the same change.)*

**The procedure, which is the "appropriate actions" half:**

1. Reports to support@301.st are read by the developer (the same inbox the privacy policy
   names; confirmed live by the owner 2026-08-08).
2. Each report is assessed against the Store Policies it may implicate, with the reported
   text and, when given, the brief that produced it.
3. What acting looks like, by cause: a defect in OUR prompt (it solicited or failed to steer
   away from the reported class) is a fixture-gated prompt change in its upstream source and
   ships with the next version; content originating in the reader's chosen model is reported
   onward through that provider's reporting channel WHERE ONE EXISTS — a self-hosted
   endpoint has no such channel, and there the answer is what it honestly can be: the
   finding, and the advice to change the model or the profile; anything suggesting the
   APPLICATION misrepresents what it sends is a defect here and is fixed as one.
4. The reporter gets an answer at the address they wrote from: what was found and what was
   done. No report data is collected by the application itself — the exchange is ordinary
   mail the reader writes in their own mail application; the application only shows the
   address, and never opens a mail program or sends anything (privacy policy).

No volume so far; this procedure is written before the first report rather than after it.
