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

The editor, validation, preview, variant generation and export work with no network
connection — the whole of the daily work. There is no account and no sign-in: open the program
and it is running. The one feature that can go online, the AI draft, is off until you turn it
on and has a chapter of its own below.

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

**AI draft** writes the first draft of a template for you — from text you already
have, or from a brief. It does enough to deserve a section of its own: the next one.

## The AI draft

A template usually starts from text that already exists — a product description, a letter, a
page. The **AI draft** panel turns that text into a first template: open it from the tool rail,
leave the header of the left column on **Text to convert**, paste the text, and press **Generate**. When
the draft arrives it replaces the document, the preview renders it, and the diagnostics panel
judges it — the same engine and the same verdict as for anything you type. One Ctrl+Z brings
your old document back; from there, edit it as your own text, because it is.

If there is nothing to paste, switch the header to **Brief** and describe what you want. The
fields above steer the draft either way: **Channel** — a letter, an SMS and a push notification
are written in different registers; **Variation** — how far apart the variants should stand; the
answer's language; and **Variables the model may use**, declared by name. The case column is the part worth filling in. A variable is put in verbatim — nothing inflects it — so in a language with cases the sentence has to be built around the form the value already has, and a model can only choose correctly if it is told which form each name holds. It cannot be worked out from the name: one real template set kept its instrumental forms in a variable whose name said accusative.

The answer is not trusted, it is verified: the draft goes through this window's own engine
before it goes anywhere near your document, and when the verdict finds errors, the loop asks
the model to repair them — the status bar counts the rounds — before handing anything over.
Only a clean draft replaces the document; anything less lands in **The model's answer** instead, with
the status line saying why, and nothing of yours is overwritten. Your edits are protected
the same way: if you typed while an answer was in flight, the draft waits in the panel. While
it works, **Generate** reads **Stop** — press it to abandon the round.

**Fix** is the same loop pointed at your current document: it wakes when the diagnostics
find errors, sends the document together with the exact objections, and applies the corrected
version with the same care.

### The connection, and whose key

As installed, the application sends nothing anywhere. **Generate** and **Fix** go on the
network only after you set up the connection at the foot of the panel and allow it. Pick the
**Format** your endpoint speaks — **Anthropic Messages** or **OpenAI-compatible** — the
**Endpoint** address, and the **Model** name — for Anthropic the list under the arrow offers
current names; elsewhere, type the name your endpoint expects. **Authorization** says whether a key travels: **API key** for the hosted
providers, **none** for servers that want none.

The key is yours, made on your own account — the application never has one of its own:

- **Anthropic** — create a key at `console.anthropic.com`, under API keys.
- **OpenAI** — `platform.openai.com`, under API keys; sending also needs billing enabled on
  the account.
- **OpenAI-compatible** is a family, not one company: OpenRouter answers in the same shape
  with many models under one key, and servers on your own computer — Ollama, LM Studio —
  usually want no key at all: set **Authorization** to **none**.

**Attach key** stores the key in the Windows Credential Manager, encrypted for your Windows
account — not in a file, and never in the document. The field then shows the key's first
characters and its last four — the beginnings are all alike, the tail is what tells keys
apart, and **Forget key** removes it. A key is
attached to the place it was entered for — the scheme, the host and the port: change any of
those and the panel asks for it again.

The first press asks in plain words — **Send to this endpoint?** — naming the recipient. What travels is
the prompt built from your brief or text — together with the channel, variation and language
you chose — the declared variables, the current template and its diagnostics when repairing,
the model name from your profile with a cap on the answer's length, and, under **API key**
authorization, the key in the request headers; nothing else, and
nothing at any other moment. The recipient does not change without you: a
redirect is refused rather than followed, and an unencrypted `http` address is accepted only
on this machine. The permission binds where the key does — the scheme, the host and the port — and shows as
the **Sending allowed** tick in the settings — untick it at any time: nothing new is
sent, and an answer already on its way is never applied. What the software at the address you chose does with the text is its operator's to
state: the request goes to the address in your profile and nowhere else.

### The same loop, without a network

The prompts need no key and no connection at all — this is the path when your model lives in
a chat window, and here you run the loop yourself: the engine gives its verdict after the
paste, not before. **Copy prompt** puts the full prompt on the clipboard; take it to whichever
model you use, paste the answer into **The model's answer**, and press **Insert into document**. If the diagnostics find
errors, **Copy repair prompt** builds the second prompt: it carries the whole document with its lines
numbered and names the exact places the engine objected to. Its answer is the corrected
document in full, so bring it back and press **Replace the document** — **Insert into document** would leave the broken
one in place and put the corrected copy beside it.

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
