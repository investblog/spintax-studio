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
account information visible. Five frames are light and five are dark so the listing shows
the editor in both supported themes:

1. [`assets/store/spintax-01-diagnostics.png`](../assets/store/spintax-01-diagnostics.png) - a real syntax error with source position and engine diagnostic.
2. [`assets/store/spintax-02-variables.png`](../assets/store/spintax-02-variables.png) - document definitions, session values and the Includes teaching link.
3. [`assets/store/spintax-03-variants.png`](../assets/store/spintax-03-variants.png) - 20 generated variants with seed and export actions.
4. [`assets/store/spintax-04-group.png`](../assets/store/spintax-04-group.png) - the group editor opened from the tool rail beside the caret.
5. [`assets/store/spintax-05-help.png`](../assets/store/spintax-05-help.png) - a valid help example selected in the Choices article and rendered on the right.
6. [`assets/store/spintax-06-dark-workspace.png`](../assets/store/spintax-06-dark-workspace.png) - the live editor and preview in the dark theme.
7. [`assets/store/spintax-07-dark-variables.png`](../assets/store/spintax-07-dark-variables.png) - variables panel in the dark theme.
8. [`assets/store/spintax-08-dark-variants.png`](../assets/store/spintax-08-dark-variants.png) - generated variants and export actions in the dark theme.
9. [`assets/store/spintax-09-dark-group.png`](../assets/store/spintax-09-dark-group.png) - editable group alternatives in the dark theme.
10. [`assets/store/spintax-10-dark-help.png`](../assets/store/spintax-10-dark-help.png) - the help topic tree and a rendered example while the editor is dark.

Use the final Store logo assets supplied by the brand rather than a screenshot of the editor
icon. Do not advertise AI, cloud models, telemetry, or an online service in the R0 listing.

## Submission notes

- Package: `build/spintax-studio.msixupload`.
- Architecture: `x64`; device family: `Windows.Desktop`.
- Privacy policy: publish [`https://spintax.studio/privacy.html`](https://spintax.studio/privacy.html)
  at a public HTTPS URL and enter that URL in Partner Center.
- Accessibility declaration: leave unchecked for R0; the current build has not passed the
  required UI Automation and assistive-technology scenarios.
