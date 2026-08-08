---
type: note
status: active
tags: [store, release]
project: spintax-studio
---

# Partner Center, at the `v0.1.1.0` submission

Everything here is entered by hand in Partner Center. Nothing in this folder is read by the
build; it exists so the exact strings are settled before the submission form is open, and so
the next session can see what was decided rather than re-deriving it from the storefront.

The live listing was read from the storefront on 2026-08-08, not from the draft:

```
curl "https://storeedgefd.dsx.mp.microsoft.com/v9.0/products/9MW3CH7B530P?market=US&locale=en-us&deviceFamily=Windows.Desktop"
```

That JSON is the only honest source for what the page currently carries — the HTML page is a
JavaScript shell and fetches nothing readable.

---

## 1. Privacy policy — TWO publications, not one

The listing's `PrivacyUrl` is **not** a link to the site. It is a frozen Microsoft snapshot of
the text typed into the Partner Center field:

```
https://cdn.storeedgefd.dsx.mp.microsoft.com/eus2/privacy-policy-storage/93915800/…/privacy_policy_5736d213-….txt
```

So republishing the website changes nothing a Store customer reads. Both copies are stale
today — each still says *"There is one external action"* while the shipping window has two
marks.

- **Upload** [`privacy.html`](privacy.html) to `https://spintax.studio/privacy.html`. It keeps
  the site's existing markup and classes; only the wording, the effective date and the contact
  changed.
- **Paste** [`privacy-partner-center.txt`](privacy-partner-center.txt) into the privacy-policy
  field. That is the copy the customer opens.

Both are held to `docs/privacy.md` and to the code by the suite: `offline/exactly two links…`
counts the `OpenURL` calls, and `privacy/…` asserts all three copies name both marks and the
same contact.

## 2. Feature bullet 20 — the licence

Live text:

> Open-source Apache-2.0 Studio built around the SPINTAX engine family

Replace with:

> Open-source GPL-3.0-or-later Studio built around the SPINTAX engine family

R0 was submitted while the repository still said Apache-2.0. The project has been
GPL-3.0-or-later since 2026-08-04 (ADR 0010), and `LICENSE`, `NOTICE.md`, the About box and the
executable's version resource all agree — only the storefront still carries the old name.

Also note the live `Features` array has 20 bullets and the draft in
[`../store-listing.md`](../store-listing.md) now has 21: the GSA import is new in this version.

## 3. Additional license terms — LEFT BLANK, by the owner's decision

**Owner's decision, 2026-08-08: this field stays empty.** Recorded here so it is not re-opened
every release.

What that means, stated once and not argued again: an empty field conveys the package under
Microsoft's Standard Application License Terms, which restrict copying and redistribution.
GPLv3 §10 says a distributor may not impose further restrictions on the rights the licence
grants. The two are in tension for anyone who receives the package from the Store and then
tries to exercise a GPL right through it. It does not affect the source, which is available
under the GPL from the repository regardless.

The earlier note in [`../store-listing.md`](../store-listing.md) still reads "must not be left
blank" — that was the analysis, and this is the decision that answers it.

## 4. Support contact

`SupportUris` on the live listing is `https://spintax.net`; the policy's contact is now
`support@301.st` (confirmed live by the owner, 2026-08-08). These are different fields and may
legitimately differ — the support URI is where a buyer is sent, the policy contact is who
answers about the policy. No change asked for here; noted so the difference reads as a
decision rather than an oversight.
