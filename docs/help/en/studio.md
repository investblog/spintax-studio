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
you are comparing two edits, say — tick **seed** and the preview stops moving until you untick
it or change the number.

The switch above the right pane offers **Page** and **Source**. Templates are usually HTML, and the
two questions "how does this look" and "what markup came out" do not answer each other: a broken
tag makes slightly crooked layout the eye skips over, while prose with tags in it does not read
as prose. The switch above the pane changes which one you are looking at.

Select part of the template and only that part is rendered — in the document's own scope, so a
fragment that uses a variable defined at the top still renders the way it will in place.

## Find and replace

Press **Ctrl+F** and a search field opens in the header. The counter beside it says how many
places the text occurs and which one you stand on; **Enter** steps forward, **Shift+Enter**
steps back, and F3 works straight from the document. Case does not matter until you tick the
case box beside the field — and the folding is the engine's own, so a Cyrillic or accented
letter matches its other case exactly where the preview would call them one letter.

Press **Ctrl+H** — or the **Replace…** menu item — and the bar grows a second row: the
replacement and two buttons. **Replace** changes the occurrence you stand on and steps to the
next; while nothing is found yet, the first press only finds. **Replace all** sweeps the whole
document at once and the status bar says how many places changed; one Ctrl+Z takes the whole
sweep back.

The replacement is literal. It may be empty — that deletes — and it may contain the text you
searched for without sending the sweep in circles: the places to change are decided first, on
the text as it was. When occurrences overlap, the counter counts every one a step can visit,
but a sweep can only change those that do not share letters — so "replaced" may honestly
report a smaller number than the counter.

A replaced document goes through the same engine pass as typed text: the preview redraws, and
the diagnostics answer about what is now there.

## Inserting the marks

Everything that puts this language's own marks into the document sits in the **Insert** menu.

The three wrap commands take the selection as it stands: **Wrap in {…}** makes it a choice, **Wrap in […]**
a shuffle, and **Wrap in /#…#/** (Ctrl+/) a comment. The comment wrap refuses when a `#/` in or around the selection — or a comment already open at
that spot — would end a comment early: the first closer wins wherever it stands, text would fall
back out, and the status bar says so because the engine does not. With nothing selected,
Ctrl+/ inserts the pair and leaves the caret inside it.

The constructs below land exactly as the menu reads them. **#set %name% = value**, **#def %name% = {a|b}** and **#include "name"** take a line
of their own — a directive counts only when it starts its line, so text before the caret
stays above and text after it moves below — and the name comes out selected, ready to be
typed over. Keep names in Latin letters: a name in another alphabet is silently not a name.
The `#include` target is the one exception — it is compared to your fragment names exactly as
written.

**{?name?then|else}** is inline. With a selection, the selected text becomes the "then" half — a way to make
what is already written conditional; with nothing selected the whole shape goes in. A selection carrying a bare `|`, an unbalanced bracket or an open comment is refused: the wrap
would change what it says instead of framing it.

The last item puts the example open in the help into the document — the help pane's own
button, made reachable from the keyboard.

## The panels along the bottom

The strip of tools down the side opens four panels, one at a time.

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

**AI draft** is where a template starts when you would rather not write every variant by
hand. Say what you want in the brief, list the variables the model may use, and press
**Copy prompt**. The application does not talk to a model and holds no key: it writes the prompt for
you to take to whichever one you already use. Bring the answer back and press **Insert into document** — the
engine in this window then says what it makes of it in the diagnostics panel, exactly as it does
for anything you type yourself. If there are errors, **Copy repair prompt** builds a second prompt: it carries the whole document with its lines numbered and names
the exact places the engine objected to. The answer to it is the corrected document in full,
so bring that back and press **Replace the document** — **Insert into document** would leave
the broken one where it is and put a corrected copy beside it.

The case column is the part worth filling in. A variable is put in verbatim — nothing inflects
it — so in a language with cases the sentence has to be built around the form the value already
has, and a model can only choose correctly if it is told which form each name holds. It cannot
be worked out from the name: one real template set kept its instrumental forms in a variable
whose name said accusative.

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
