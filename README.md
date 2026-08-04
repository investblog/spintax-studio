# Spintax Studio

[![CI](https://github.com/investblog/spintax-studio/actions/workflows/ci.yml/badge.svg)](https://github.com/investblog/spintax-studio/actions/workflows/ci.yml)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-green.svg)](LICENSE)
[![Microsoft Store](https://img.shields.io/badge/Microsoft%20Store-Spintax%20Studio-0078D4)](https://apps.microsoft.com/detail/9mw3ch7b530p)

A native Windows editor for spintax templates, in the shape of a translator: two panes,
your template on the left, a live render on the right. The engine that decides what comes
out — and whether the template is even valid — is [`spintax-win`](https://github.com/investblog/spintax-win),
the same one published for JavaScript, PHP and Python, embedded in-process. The first
release is an offline editor: write a template, see its render, inspect diagnostics and
variables, generate variants, and export them.

Studio is developed by [301.st](https://301.st/); the SPINTAX language reference and engine
family live at [spintax.net](https://spintax.net/).

> **R0 is the offline Windows release, published in the Microsoft Store on 2026-08-04.**
> The source of truth is [`docs/spec.md`](docs/spec.md) and release work is tracked in
> [`docs/TODO.md`](docs/TODO.md). The application includes bracket-aware editing, live
> page/source preview, validation diagnostics, variables and include inspection, variant
> generation and export, a group editor, and built-in help. Generative AI is not part of R0.

## Install

**[Get Spintax Studio from the Microsoft Store](https://apps.microsoft.com/detail/9mw3ch7b530p)** —
free, Windows 10 1809 or later on x64, about 2.5 MB. The Store hosts, signs and updates the
package; nothing else has to be installed to run it.

The rest of this file is for building from source.

## Building

```sh
git clone --recurse-submodules https://github.com/investblog/spintax-studio.git
cd spintax-studio
sh ./build.sh          # Free Pascal 3.2.2+; builds the Windows GUI when Lazarus is present
./tests/studio_tests
```

`build.sh` builds the console suite with `fpc` and the application with `lazbuild`. If Lazarus
is not installed, the console suite still verifies the editor-core. The engine and editor-core
compile on Ubuntu; the R0 GUI is currently supported, tested and distributed only on Windows
x64. The engine is a git submodule pinned to a released tag
([ADR 0001](docs/decisions/0001-engine-as-submodule.md)); a plain clone needs
`git submodule update --init` before the build finds `unit Spintax`.

Platform scope:

- **Windows x64:** complete Studio GUI and the published
  [Microsoft Store package](https://apps.microsoft.com/detail/9mw3ch7b530p).
- **Ubuntu:** engine, editor-core and console tests; no supported GUI build in R0.

## Principles

- **DeepL metaphor.** Minimal chrome, two large panes, instant feedback. Type or paste a
  template on the left; see exactly what it produces on the right.
- **Offline and local-first.** R0 makes no network request, collects no telemetry, and needs
  no account or model key. The About link may open the user's browser when explicitly clicked.
- **One `.exe`, no runtime.** A native build — no bundled Node, PHP or Python.
- **Engine as the source of truth.** Preview and the valid / invalid verdict come from the
  real engine, not from a second parser or an optimistic editor-side guess.

## Relationship to the engine

The engine stays pure and zero-dependency — no network and no GUI are added to it. Studio is
a separate product that *consumes* it; the window, panels and export live in the layers above.
That boundary is deliberate and is not crossed.

## Family

- [`investblog/spintax-win`](https://github.com/investblog/spintax-win) — the engine (Object Pascal, MIT)
- [`investblog/spintax-js`](https://github.com/investblog/spintax-js) — `@spintax/core`, the reference engine and the home of the golden corpus
- [`investblog/spintax-php`](https://github.com/investblog/spintax-php) · [`investblog/spintax-py`](https://github.com/investblog/spintax-py) — the PHP and Python engines

Syntax reference: https://spintax.net

## License

Spintax Studio is licensed under the [GNU General Public License, version 3 or later](LICENSE),
Copyright (c) 2026 301.st, **with an additional permission under GPL v3 section 7** for the
MPL-1.1 components it links — SynEdit and TurboPower IPro. The grant, and why IPro needs it while
SynEdit does not, are at the top of [NOTICE.md](NOTICE.md), which is also the file the
application's About box is generated from.

The engine in `engine/` and the other family engines remain MIT-licensed under their own
repositories and notices; the engine is a submodule, not a copy, and nothing here relicenses it.
