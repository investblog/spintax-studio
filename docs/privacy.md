---
type: note
status: active
tags: [store, legal]
project: spintax-studio
---

# Privacy policy — Spintax Studio

**Effective 9 August 2026. Applies to Spintax Studio for Windows.**

*(The date moves when the list below changes, not when the text was written. It moved from
1 August because the window gained a second mark, and again on the 9th because the application
gained the ability to send text to a model — the largest change this document has had. The
version is not named: the build that carries that feature has no number yet, and a number
written here before it exists would be the one false line in a document about honesty.)*

Spintax Studio is an offline desktop application. It collects nothing about you: no account, no
sign-in, no telemetry, no analytics. One feature is an exception, and only once you switch it
on — the AI draft can send the text you hand it to a model provider **you** choose and pay for,
with **your** key. It is off until you turn it on, and this policy describes exactly what it
sends and to whom.

## What we collect

Nothing. There is no account to create, no sign-in, no licence check, no telemetry, no
analytics, no crash reporting, and no advertising. We do not know that you have installed the
application, and we have no way to find out from it.

Turning on the AI connection does not change this. Your key is stored on your own computer, in
the Windows Credential Manager, encrypted for your Windows account, and it goes nowhere except
to the endpoint you pointed it at. We have no key of our own, no account for you, and no server
in the middle: the request is made by this application, from your machine, on your provider's
account. We never see it.

## What leaves your computer

**With the AI connection off — which is how the application is installed — nothing.** No part of
it makes a network request: not at startup, not while you work, not on exit. The editor,
validation, rendering, the variant generator, export and the built-in help have never needed one
and still do not.

**With it on, and only when you press the button that sends:** the prompt goes out. That is the
brief you wrote, the variable names you listed, and — when you ask for a repair — the draft and
the diagnostics the engine found in it. It goes to the endpoint you configured, with your key,
on your account. Nothing else is added to it: no identifier, no document you did not send, and
no record is kept here of what you sent.

**And if the endpoint you configure is a local one** — a model running on your own machine, at
an address like `http://localhost:11434` — then nothing leaves the computer at all. That is a
different thing from a cloud provider, and this policy is not going to blur them: with a local
model the whole loop, prompt included, stays where your documents are.

What the provider does with what you send is theirs to state, not ours. Their policy applies to
that exchange, and we are not a party to it.

**The two links in the window are not an exception, because a link is not a request.** The
**spintax.net** mark at the bottom of the tool rail and the **301.st** mark at the right end of
the status bar do one thing when you click them: they ask Windows to open that address. Windows
hands it to whatever browser you use, and the browser is what then visits the site — under your
browser's terms and that site's, exactly as if you had typed the address yourself. The
application is not part of that exchange and sends nothing into it. Nothing is opened unless you
click.

## What is stored, and where

**Your settings** — the interface language, the theme, the editor font, panel widths and
similar preferences — are written to a single text file in your own user profile
(`%LOCALAPPDATA%`). Installed from the Microsoft Store, that file lives inside the
application's own package container. It contains preferences only: no documents, no personal
details, and nothing that identifies you or your machine.

**Your documents** stay where you put them. Templates, template sets and exported variants are
ordinary files in folders you choose. The application reads and writes them only when you ask
it to, and never copies them anywhere else.

Removing the application removes its settings with it.

## Children

The application collects no data from anyone, of any age.

## Changes to this policy

A later version will add optional AI assistance, which will send the text you choose to a
provider you configure with your own key. That is not in this version, and this policy will be
updated and republished before any version that does so is released. Nothing in the current
application sends anything anywhere.

## Contact

Questions about this policy, or about the application: **support@301.st**
