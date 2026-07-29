# Third-party notices

Spintax Studio is MIT-licensed (see [LICENSE](LICENSE)). It ships as one executable with
everything it needs inside it, so this file lists what that executable carries besides our own
code, and what each licence asks of us in return.

The entries are grouped by what they oblige. Anything here that requires attribution must also
appear in the application's About box — the About box is the copy a user can actually read, and
this file is the copy an audit can.

## Requires attribution in the shipped application

**Material Design Icons** — the four glyphs on the tool rail (diagnostics, variables, variants,
the group editor).
Apache License 2.0, © Pictogrammers and contributors. <https://pictogrammers.com/library/mdi/>
Only the four glyphs listed in `scripts/make-icons.py` are used; they are rendered from the
project's webfont into `assets/icons/` and embedded as `gui/SpxIcons.pas`. The font itself is
not redistributed.

**Twemoji** — the fourteen flags beside the interface languages.
CC-BY 4.0, © 2020 Twitter, Inc and other contributors. <https://github.com/twitter/twemoji>
The 72 px originals are vendored in `assets/flags/` and scaled into the sprite embedded as
`gui/SpxFlags.pas`. A flag stands for a country and a menu item names a language; where the two
disagree the choice is recorded, one line per language, in `scripts/make-flags.py`.

## Linked libraries

**Free Pascal RTL and FCL** — modified LGPL (LGPL with the static-linking exception).
The exception exists precisely so a statically linked executable may be distributed under its
own terms; ours is MIT and no further obligation follows.

**Lazarus LCL** — modified LGPL, same exception, same conclusion.
<https://www.lazarus-ide.org/>

**SynEdit** — MPL 1.1 (the editor component; unmodified).
**TurboPower Internet Professional (IPro)** — MPL 1.1 (the HTML preview; unmodified).
MPL 1.1 covers the files themselves: a change to either component's source would have to be
published. We use both as they ship, so nothing here is ours to publish — if that ever stops
being true, this line stops being true with it.

## The engine

**spintax-win** is our own, MIT-licensed, and is a git submodule rather than a copy
(`engine/`, pinned by tag). Its notice is its own file, in its own repository.
