---
type: note
status: active
tags: [store, legal]
project: spintax-studio
---

# Privacy policy — Spintax Studio

**Effective 14 August 2026. Applies to Spintax Studio for Windows.**

*(The date moves when the list below changes, not when the text was written. It moved from
1 August because the window gained a second mark, on the 9th because the application gained
the ability to send text to a model — the largest change this document has had — on the
13th because the window gained a third place that handed an address to the shell, and on the
14th because that third place went away again: the report address is now plain text in the
About window, and the application opens no mail program at all. The version is deliberately
not named: this policy describes the application from its effective date on, and a version
number pinned here would go stale with the first update that changes nothing above.)*

Spintax Studio is an offline desktop application. It collects nothing about you: no account, no
sign-in, no telemetry, no analytics. One feature is an exception, and only once you switch it
on — the AI draft can send the text you hand it to a model endpoint **you** choose, on your
own account and **your** key when that endpoint requires one. It is off until you turn it on,
and this policy describes exactly what it sends and to whom.

## What we collect

Nothing. There is no account to create, no sign-in, no licence check, no telemetry, no
analytics, no crash reporting, and no advertising. We do not know that you have installed the
application, and we have no way to find out from it.

Turning on the AI connection does not change this. A key, when your profile uses one, is
stored on your own computer, in the Windows Credential Manager, encrypted for your Windows
account, and it goes nowhere except to the endpoint you pointed it at. We have no key of our own, no account for you, and no server
in the middle: the request is made by this application, from your machine, on your provider's
account. We never see it.

## What leaves your computer

**With the AI connection off — which is how the application is installed — nothing.** No part of
it makes a network request: not at startup, not while you work, not on exit. The editor,
validation, rendering, the variant generator, export and the built-in help have never needed one
and still do not.

**With it on, and only when you press the button that sends:** the prompt goes out. That is the
brief you wrote — which, in the text-to-template mode, is the source text you pasted — the
variable names you listed, and, when you ask for a repair, your current document with the
diagnostics the engine found in it: the whole document as it stands, whether or not it began as
an AI draft. It goes to the endpoint you configured — with your key and on your account when
the endpoint uses them. Nothing else is added to it: no identifier, no document beyond the one
you pressed the button on, and no record is kept here of what you sent.

**An address on your own machine is an address, not a promise.** You can point this at a model
running locally — something answering on `http://localhost:11434`, say — and many people will.
What we can tell you is what *we* do: the request goes to the address in your profile and
nowhere else, we are not in it, and nothing about it is reported back to us. What we cannot tell
you is what the software at that address does with it next, because we did not write it and
cannot see inside it. It may be exactly the local model it looks like; it may also be a proxy
that forwards. If it matters to you that nothing leaves the computer, that is a question to
settle with whatever you are running there — this application cannot answer it on their behalf,
and a policy that said otherwise would be guessing.

**The recipient does not change without you.** If the address you configured answers with a
redirect, the request is refused and you are told where it wanted to send you, rather than
followed automatically. Otherwise the far end could move where your prompt and your key go, and
you would never see it happen.

What the software at that endpoint does with what you send is its operator's to state, not
ours. Any policy the operator states applies to that exchange, and we are not a party to it.

**The two links in the window are not an exception, because a link is not a request.** The
**spintax.net** mark at the bottom of the tool rail and the **301.st** mark at the right end of
the status bar do one thing when you click them: they ask Windows to open that address. Windows
hands it to whatever browser you use, and the browser is what then visits the site — under your
browser's terms and that site's, exactly as if you had typed the address yourself. The
application is not part of either exchange and sends nothing into them. Nothing is opened
unless you click. The address for reporting AI output you find unacceptable,
**support@301.st**, is shown as plain text in the About window (Help → About): the application
never opens a mail program and never sends mail — writing there is your own act, in your own
mail application.

## What is stored, and where

**Your settings** — the interface language, the theme, the editor font, panel widths and
similar preferences — are written to a single text file in your own user profile
(`%LOCALAPPDATA%`). Installed from the Microsoft Store, that file lives inside the
application's own package container. It contains preferences only: no documents, no personal
details, and nothing that identifies you or your machine.

**Your documents** stay where you put them. Templates, template sets and exported variants are
ordinary files in folders you choose. The application reads and writes them only when you ask
it to, and never copies them anywhere else.

Removing the application removes its settings with it. **An attached AI key is the one
exception:** it lives in the Windows Credential Manager, not in the package, and stays
there until you press **Forget key** in the AI settings or remove it in the Credential
Manager yourself — uninstalling does not clear it.

## Children

The application collects no data from anyone, of any age.

## Changes to this policy

This is the version of the policy that describes the optional AI connection — the earlier one
promised it would be updated and republished before any version that sends text is released,
and this is that update, published with the version that carries the feature. The same rule
holds going forward: if the application ever gains a way to send or store anything not
described here, this policy changes first and ships with it, and the effective date above
moves.

## Contact

Questions about this policy, or about the application: **support@301.st**

To report AI output you find inappropriate, write to **support@301.st** — the address is shown
in the About window (Help → About). Include the application version from the same window.
Reports are read by the developer and acted on.
