# Third-party notices

Spintax Studio is licensed under the GNU General Public License, version 3 or later (see
[LICENSE](LICENSE)), with the additional permission stated below. It ships as one executable with
everything it needs inside it, so this file lists what that executable carries besides our own
code, and what each licence asks of us in return.

**The additional permission**, which is part of the licence of Spintax Studio's own code and
travels with it:

> **Additional permission under GNU GPL version 3 section 7.** As a special exception, the
> copyright holder of Spintax Studio gives you permission to combine Spintax Studio with the
> components covered by the Mozilla Public License 1.1 that this program links — SynEdit and
> TurboPower Internet Professional (IPro) — and to convey the resulting work. You may keep those
> components under the terms of the MPL 1.1; the terms of the GNU GPL version 3 continue to apply
> to the rest of the work. If you modify this program, you may extend this exception to your
> version, but you are not obliged to do so.

The exception is needed because MPL 1.1 and the GPL are not compatible on their own. SynEdit
offers "GPL Version 2 or later" as an alternative to the MPL in every file header and so needs no
exception; **IPro does not** — the phrase "General Public License" appears nowhere in that
component — and it is linked into the shipped executable for the HTML preview. Rather than carry a
grant that covers one and not the other, this one names both.

The project is developed by [301.st](https://301.st/); the SPINTAX language reference is at
<https://spintax.net/>. Distributed derivatives must retain this notice.

The entries are grouped by what they oblige. Anything here that requires attribution must also
appear in the application's About box — the About box is the copy a user can actually read, and
this file is the copy an audit can.

## Requires attribution in the shipped application

**Spintax Studio** — GNU General Public License v3.0 or later
Copyright (c) 2026 301.st. <https://301.st/>
Additional permission under GPL v3 section 7 for the MPL-1.1 components it links (SynEdit and
IPro); the grant is at the top of NOTICE.md.
SPINTAX language reference: <https://spintax.net/>

**Material Design Icons** — the font glyphs used by the application controls: diagnostics,
variables, variants, the group editor, reroll, copy, preview modes, search/navigation and
editor controls. The help and insert-example cells are drawn by the project and are not MDI
glyphs.
Apache License 2.0, © Pictogrammers and contributors. <https://pictogrammers.com/library/mdi/>
The MDI cells listed in `scripts/make-icons.py` are rendered from the project's webfont into
`assets/icons/` and embedded as `gui/SpxIcons.pas`. The font itself is not redistributed.

**Twemoji** — the fourteen flags beside the interface languages.
CC-BY 4.0, © 2020 Twitter, Inc and other contributors. <https://github.com/twitter/twemoji>
The 72 px originals are vendored in `assets/flags/` and scaled into the sprite embedded as
`gui/SpxFlags.pas`. A flag stands for a country and a menu item names a language; where the two
disagree the choice is recorded, one line per language, in `scripts/make-flags.py`.

## Linked libraries

**Free Pascal RTL and FCL** — modified LGPL (LGPL with the static-linking exception).
The exception exists precisely so a statically linked executable may be distributed under its
own terms; Studio is GPL-3.0-or-later, which the LGPL permits combining with in any case, and no
further obligation follows.

**Lazarus LCL** — modified LGPL, same exception, same conclusion.
<https://www.lazarus-ide.org/>

**SynEdit** — MPL 1.1 (the editor component; unmodified).
**TurboPower Internet Professional (IPro)** — MPL 1.1 (the HTML preview; unmodified).
MPL 1.1 covers the files themselves: a change to either component's source would have to be
published. We use both as they ship, so nothing here is ours to publish — if that ever stops
being true, this line stops being true with it. MPL 1.1 does not combine with the GPL on its own,
which is what the additional permission at the top of this file is for: SynEdit's own headers
offer "GPL Version 2 or later" as an alternative and would not need it, IPro's offer nothing of
the kind and do.

## The engine

**spintax-win** is our own, MIT-licensed, and is a git submodule rather than a copy
(`engine/`, pinned by tag). Its notice is its own file, in its own repository.
