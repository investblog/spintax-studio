---
type: release-artifact
status: draft
product: spintax-studio
---

# Microsoft Store listing draft

This is the R0 listing copy. Keep it separate from the developer README: the Store page
describes the shipped product, not the repository or future AI work.

## Short description

Write, validate, preview and export spintax templates on Windows.

## Description

Spintax Studio is a native Windows editor for spintax templates.

Write a template on the left and see the rendered result on the right. The editor highlights
the language's brackets and syntax, while the diagnostics panel points to errors and warnings
reported by the same engine used by the Spintax family of libraries.

Inspect variables and includes, edit groups, generate reproducible variants, and export the
result. Built-in help explains the syntax and links a diagnostic to the relevant article.

R0 is offline and does not require an account, a network connection, a model key or a runtime.
The application does not include generative AI in this release.

## Captured screenshots

Captured from the English release executable at 1500x890, with no personal documents or
account information visible:

1. [`assets/store/spintax-01-valid.png`](../assets/store/spintax-01-valid.png) — valid template and live page preview.
2. [`assets/store/spintax-03-error.png`](../assets/store/spintax-03-error.png) — invalid template with the marked source location and diagnostic message.
3. [`assets/store/spintax-04-variables.png`](../assets/store/spintax-04-variables.png) — definitions and rendered result.
4. [`assets/store/spintax-05-variants.png`](../assets/store/spintax-05-variants.png) — generated variants with export controls.
5. [`assets/store/spintax-06-help.png`](../assets/store/spintax-06-help.png) — built-in help open on a diagnostic article.

Use the final Store logo assets supplied by the brand rather than a screenshot of the editor
icon. Do not advertise AI, cloud models, telemetry, or an online service in the R0 listing.

## Submission notes

- Package: `build/spintax-studio.msixupload`.
- Architecture: `x64`; device family: `Windows.Desktop`.
- Privacy policy: publish [`https://spintax.studio/privacy.html`](https://spintax.studio/privacy.html)
  at a public HTTPS URL and enter that URL in Partner Center.
- Accessibility declaration: leave unchecked for R0; the current build has not passed the
  required UI Automation and assistive-technology scenarios.
