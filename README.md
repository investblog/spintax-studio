# Spintax Studio

A native Windows editor for spintax templates, in the shape of a translator: two panes,
your template on the left, a live render on the right. The engine that decides what comes
out — and whether the template is even valid — is [`spintax-win`](https://github.com/investblog/spintax-win),
the same one published for JavaScript, PHP and Python, embedded in-process. On top of it:
live preview, real validation with diagnostics, and an authoring loop where an LLM writes
a template, the engine checks it, and the model repairs what the engine rejects.

> **Status: design.** This repository is the spec being brought to a buildable state. No
> application code yet — the source of truth is [`docs/spec.md`](docs/spec.md), and the
> open decisions are tracked in [`docs/TODO.md`](docs/TODO.md).

## Principles

- **DeepL metaphor.** Minimal chrome, two large panes, instant feedback. Type, paste or
  generate a template on the left; see exactly what it produces on the right.
- **Local-first, zero telemetry.** A local client. Model keys and settings stay on the
  user's machine. The engine runs fully offline; the network is only for cloud models, and
  can be left off entirely (a local model, or manual authoring).
- **One `.exe`, no runtime.** A native build — no bundled Node, PHP or Python.
- **Engine as the source of truth.** Preview and the valid / invalid verdict come from the
  real engine, not from a model's self-assessment. What the model writes is run through the
  engine before a human is asked to look.

## Relationship to the engine

The engine stays pure and zero-dependency — no network, no GUI is ever added to it. Studio
is a separate product that *consumes* it; everything new (GUI, LLM providers, export) lives
here, in the layers above. That boundary is deliberate and is not crossed.

## Family

- [`investblog/spintax-win`](https://github.com/investblog/spintax-win) — the engine (Object Pascal, MIT)
- [`investblog/spintax-js`](https://github.com/investblog/spintax-js) — `@spintax/core`, the reference engine and the home of the golden corpus
- [`investblog/spintax-php`](https://github.com/investblog/spintax-php) · [`investblog/spintax-py`](https://github.com/investblog/spintax-py) — the PHP and Python engines

Syntax reference: https://spintax.net

## License

MIT.
