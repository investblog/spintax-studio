# Spintax Studio

This program is an editor for templates. A template is ordinary text with a few marked places
in it, and one template can produce a great many different texts — that is the whole point of
writing one instead of writing the texts.

The window is two panes. On the left is your template, the thing you edit. On the right is one
of the texts it produces, redrawn as you type. Nothing between them needs pressing: what you see
on the right is what the engine returns for what is on the left at that moment.

```spx-fixture
locale: en
seed: 7
empty: (empty)
```

The engine is built into this program, and it is the Pascal member of a family: the same
language is also published for JavaScript, PHP and Python. The four are independent programs
held to one shared set of test fixtures, so what a template MEANS is the same in all of them —
the constructs, the verdict on whether it is valid, the finishing touches. A template this
window calls valid is valid there.

What is not promised, and the difference matters when you compare: the random draw. A seed makes
the preview repeatable HERE — the same seed and the same template give the same text tomorrow —
but the same seed in the JavaScript engine may pick a different alternative. Seeds are for
reproducing your own work, not for matching another engine's.

Everything here works with no network connection. There is no account, no sign-in and nothing
to switch on: open the program and it is running.

## The two panes

Type on the left. The right pane redraws after a short pause, so the preview keeps up with a
sentence rather than with each letter.

A template with a choice in it has no single answer, and the preview shows one of them:

```spx-good
{Hi|Hello} there.  →  Hi there.
```

Press **Reroll** above the right pane for another. If you want the same one every time — while
you are comparing two edits, say — tick **Seed** and the preview stops moving until you untick
it or change the number.

The switch above the right pane offers **Page** and **Source**. Templates are usually HTML, and the
two questions "how does this look" and "what markup came out" do not answer each other: a broken
tag makes slightly crooked layout the eye skips over, while prose with tags in it does not read
as prose. The switch above the pane changes which one you are looking at.

Select part of the template and only that part is rendered — in the document's own scope, so a
fragment that uses a variable defined at the top still renders the way it will in place.

## The panels along the bottom

The strip of tools down the side opens three panels, one at a time.

**Diagnostics** lists what the engine found wrong, each with the line and column it starts at.
Clicking a row puts the caret there. This is the same verdict the engine gives everywhere else,
not a second opinion from the editor — which is why a template this panel calls valid is one
the other engines will accept.

**Variables** shows the names your document defines and the names it merely uses. A name it uses
and nothing defines is one you can fill in here for the session: type a value beside it and the
preview picks it up. Tick **as text** when the value is text that means itself rather than a
little template of its own.

**Variants** generates many texts at once. Say how many, generate, and read them in the list
before exporting. Near-duplicates can be dropped as they are produced, and a seed makes the
whole set reproducible: the same seed and the same template give the same variants tomorrow.

Beside those controls the panel says how many variants the template can make at all:
`{a|b} and {c|d}` makes four. That number is what tells you a template is thin before you
generate fifty and find out by reading them.

It is an exact count only while every choice is left to chance. A conditional, a plural, or an
`#include` whose target the set has not got is decided by something else — a value you supply,
a number, a fragment that may yet arrive — so the panel says **at least** instead. That is the
honest word: supplying a value can only add texts, never remove any. A number far too large to
read stops at a trillion and says **at least** for the same reason.

A variant is one filled-in template — one choice made at every construct — and that is not
the same as a text that reads differently. `{a|a}` is two variants and one text, deliberately:
the two options can stop matching after a single edit, and collapsing them would mean
generating every combination first, which is the work the number exists to save you. A `#def`
counts the same way: the engine draws it once per render whether the branch you took uses it
or not.

Export writes them out three ways: as an XLSX workbook, as plain text with one variant per line,
or as one file per variant in a folder you choose.

## The group editor

Put the caret inside a `{a|b|c}` and open the group editor from the tool strip. It lists the
alternatives as rows: edit them, add one, remove one, and the document is rewritten to match.

It refuses edits that would change what the group MEANS rather than what it says — a `|` typed
into an alternative would turn one option into two, and a `}` would end the group early. When it
refuses, it says so and leaves the document alone.

## Settings

The View menu holds them, and every one is remembered between sessions: the interface language
and whether it follows the template, which side the tool strip is on, the theme, the editor's
font and size, whether the preview shows the page or the source, the GSA import switch, which
panel is open, and the widths of the panels that slide out.

The interface speaks fourteen languages, chosen in the same menu. That is separate from the
language of your template, which is what decides plural forms and is set above the right pane.

## Importing a GSA template

This one is off until you turn it on, in **View**, **GSA import**, because most people writing
templates have never used GSA Search Engine Ranker. With it on, **File**, **Import GSA template…**
reads a SER template and converts it into this language.

The conversion is careful in a specific way. Anything it cannot express faithfully it refuses
and tells you about, rather than quietly turning it into something that renders. Constructs
that would be misread if they stayed in the text — BBCode brackets, a `#` inside a link, a
`#file[...]` macro — are lifted out into variables, and the summary says how many.

Two things to know about the result:

- **The lifted values are session values.** They appear in the Variables panel and are not saved
  with the document. Save the converted template, open it tomorrow, and you will see `%…%` where
  the lifted text was. Nothing is lost from the file you imported — that one is untouched — but
  the converted document is not self-contained.
- **It is rendered without the tidying pass.** Every other document here gets the finishing
  touches described in the language guide; a converted template does not, because it is not our
  text to tidy. It is somebody else's template, usually on its way back to GSA, and it has to
  survive character for character.

The imported document is untitled and unsaved, like a new one. The file you picked is left
exactly as it was.
