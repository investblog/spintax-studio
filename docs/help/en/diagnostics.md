# What the Diagnostics tab is telling you

Every line in that tab is a verdict from the **engine**, and the same verdict you would get from
the JavaScript, PHP or Python implementation — four independent engines held to one shared
corpus. It is not Studio's opinion about your template. If the engine calls
something an error here, every other engine in the family calls it an error too, and your
template will behave the same way on your server as it does in this window.

| what it says | who says it | what it means |
|---|---|---|
| **error** | the engine | the template will not do what it looks like it does |
| **warning** | the engine | it renders, but probably not the way you meant |
| **Studio note** | Studio | the engine said nothing, and it is still worth saying: a circular include, a target whose case differs, a control character |

The **Where** column is a line and a column. Clicking the row puts the caret there.

> Every example below was run through `spintax-win v0.4.0`, and the right-hand side is exactly
> what it returned. Nothing here is remembered or guessed.

## How to read the examples

The arrow `→` separates the template from what the engine returned. `⏎` is a line break inside an
output, `(empty)` means it printed nothing at all, and `…` marks an output too long to show in
full. Text after the output, set off by three spaces, is a note rather than part of the answer.

The conditions the examples were run under are here rather than hidden in the tests — without
them some answers cannot be reproduced. The template set matters most: otherwise
`#include "frag"` → `Fragment` would rest on something this document never states.

```spx-fixture
locale: en
seed: 7
empty: (empty)
include frag: Fragment
include loop: #include "loop"
include Intro: Introduction
```

`seed` pins the random choice: without it an enumeration or a permutation would answer
differently every time and there would be nothing to check.

**The locale is `en` here, and it decides two things:** how many plural forms the engine expects,
and which form goes with which number.
English asks for two. Russian, Ukrainian, Belarusian, Serbian, Croatian and Bosnian ask for
three. The locale comes from the selector above the right-hand pane, not from the language of the
interface.

---

## Brackets

### `bracket.unclosed` — a bracket is opened and never closed

```
a price {cheap|dear          →  A price {cheap|dear
```

The engine does not guess where you meant to close it. The text stays as it is, brace and all,
and the choice never happens.

### `bracket.mismatched` — closed by a bracket of another kind

```
a price {cheap|dear]         →  A price {cheap|dear]
```

`{` waits for `}` and `[` waits for `]`. A permutation closed by a brace is not a permutation.

### `bracket.unexpected-closing` — a closing bracket with nothing open

```
a price cheap} and all       →  A price cheap} and all
```

Most often a leftover from an edit: the opening brace was deleted and the closing one stayed.

---

## Definitions

### `set.malformed` — this `#set` line does not follow the rule

```
#set city = Boston
in %city%                    →  #set city = Boston ⏎ In %city%
```

**The name goes in per cent signs:** `#set %city% = Boston`. This is the commonest first mistake
and it puts two lines in the panel at once — the malformed line itself, and "this variable is
defined nowhere", because no definition happened and `%city%` belongs to nobody.

Look at the output: the failed directive stayed in the text **as written**. The engine did not
read it as a directive, so it is an ordinary line and it goes into the result.

### `def.malformed` — this `#def` line does not follow the rule

```
#def pages = {1|3}
%pages%                      →  #def pages = 1 ⏎ %pages%
```

The same rule and the same price. `#def` differs from `#set` not in spelling but in **when** the
value is expanded: `#set` expands it again at every reference, `#def` once per render. A mistake
in the writing costs you both.

And look closely at the output: the `{1|3}` inside the failed directive **picked a variant**. The
line became ordinary text — and ordinary text is rendered like ordinary text, braces and all. A
malformed line is not switched off; it merely stops being a directive.

### `definition.duplicate-name` — this name is already defined above

```
#set %x% = first
#set %x% = second
%x%                          →  Second
```

It works — the **last** definition wins — but the engine calls it an error: a document where one
name is set twice reads ambiguously, and in a month you will not remember which of the two lines
is the live one. The error points at the **second** definition; the first is further up.

### `def.include-in-value` — `#include` inside a definition value

```
#def %x% = #include "frag"
%x%                          →  Fragment
```

An include inside a value expands at a different moment than you would expect, and the family
forbids it. Put the `#include` on a line of its own.

---

## Variables

### `variable.undefined` — this variable is defined nowhere

```
hello, %name%                →  Hello, %name%
```

A warning rather than an error: the engine prints the name as it stands. That is by design — the
value may arrive from outside, from the host. In Studio you supply such values on the Variables
tab, under **Session values**.

**A definition's value can be edited in the panel.** Stand on the Value column in the upper
section and press **F2** (or just start typing); **Enter** applies, **Escape** abandons. The edit
goes **into the document**, in one undo step: `Ctrl+Z` puts it back.

Exactly the value changes. The indentation, the extra spaces, the case of the name and a trailing
comment all stay as they were — the file is in git, and reformatting a line would show up there
as your change.

**A refusal means the engine would read the line differently.** The edit is not applied silently:
the engine reads the result back, and if it does not say what was asked, the document is left
alone and the status bar says so. Three real causes: `/#` in the value opens a comment that eats
the rest of the file, a line break ends the directive early, and a comment **inside** the
directive makes the line un-editable in pieces — edit that one in the text.

**Two gestures on a variable's name.** The name in the panel is a link, not a label:

- **click the name** and the caret moves to the first place the document uses that variable, and
  the line lights up for a moment. The same word inside a comment or as an `#include` target does
  **not** count — the panel takes you where the variable actually works.
- **Ctrl+click** writes a definition into the document and opens the group editor on it. The
  value you have already typed moves in as its first option:

```
#set %brand% = {Vulkan}
casino %brand%               →  Casino Vulkan
```

The difference between the two is what survives closing the window. A session value does not: it
is not in the file, not in git, and no other engine in the family can see it. A definition does,
and only a definition silences this warning for good. One `Ctrl+Z` puts the document back.

**A session value is a template by default, not text.** That is what the engine does with any
host value, and the preview has to match the production server — so `{cheap|dear}` typed into the
value field gives a choice, not those eleven characters. If you meant the text itself, tick **as
text** in the third column: then braces and per cent signs stay characters.

### `variable.self-reference` — the definition refers to itself

```
#set %x% = a %x% b
%x%                          →  A a a … %x% … b b b
```

Fifty levels, then a stop. The engine expands to the depth limit and halts, leaving `%x%` in the
middle. Not a loop, and not what you wanted either.

The `…` above is this document's abbreviation, not the engine's. The real output is 207 characters
and carries **fifty-one** letters on each side rather than fifty: the fiftieth level stops and
leaves the value as it stands, and the value holds one more of each.

### `variable.circular-reference` — the definitions refer in a circle

```
#set %x% = %y%
#set %y% = %x%
%x%                          →  %y%
```

Each side expands exactly **once** and then stops: `%x%` became `%y%`, not `%x%`. The engine
unwinds rather than looping, and what survives is the other name in the circle — put `%x% %y%`
in a document and it renders `%y% %x%`, the pair swapped.

The panel draws a row for **each** definition in the circle, not one for the circle.

---

## Includes

### `#include` only works from the start of a line

```
before #include "frag" after →  Before #include "frag" after
```

```
#include "frag"              →  Fragment
```

Not a diagnostic, and that is the point: an `#include` in the middle of a line is **not** an
include. The engine reads it as ordinary text and says nothing, because there is nothing to
complain about — you wrote text and got text.

### `include.unknown-target` — no such target in the set

```
#include "nosuch"            →  (empty)
```

Targets are the `.spintax` files in the folder of the open document. An unknown target expands to
nothing — the paragraph disappears rather than breaking, which is exactly why it is easy to miss.

**That is why the Variables tab has a third section, Includes.** It lists every `#include` the
document contains and, for each, whether the set has its target — one row per occurrence, so a
target named twice is two rows. The section appears only when the document
has includes. Clicking a row moves the caret to the `#include` that names that target.

The mark has **three** values, and the third matters: `no set` is not "the fragment is missing",
it is "there is nowhere to look yet". The set is the folder beside the document, and an unsaved
document has no folder — so until the first save every target is marked that way. `MISSING`
appears only when there is a folder and the file really is not in it.

### `note.case-mismatch` — the target exists, in another case

```
#include "intro"             →  (empty)
```

The set holds `Intro.spintax` — and the engine still says there is no such target, while Studio
adds its note about the case. Case matters: `intro` and `Intro` are different targets. Windows
would open the file in either case, which is why Studio looks in the set rather than on the file
system: otherwise the preview would disagree with the production server about the same document.

### `note.cycle` — an include in a circle

If `loop.spintax` contains `#include "loop"`, then:

```
#include "loop"              →  (empty)
```

The engine substitutes nothing rather than infinity. The note is there so you know why the
paragraph vanished.

---

## Plurals

### `plural.arity` — not as many forms as the locale asks for

```
#set %n% = 5
%n% {plural %n%: item|items|itemses}   →  5 ｛plural 5: item|items|itemses｝
```

**Not emptiness — the engine prints the whole construct**, with the braces replaced by wide ones
`｛｝`. That is how it says "I saw this and could not apply it". Nobody would call that
unnoticeable, and that is good: a paragraph that vanished silently would take longer to find.

English asks for two forms, Russian for three. Under this document's locale
`{plural %n%: item|items}` is the correct one.

**Emptiness happens for another reason, and the two are easy to confuse.** Compare these two,
which differ only in how many forms they carry:

```
{plural %n%: item|items}             →  (empty)   two forms: right for English
{plural %n%: item|items|itemses}     →  (empty)   three forms: wrong for English
```

Both print nothing, and the panel treats them differently: the first draws only
`variable.undefined`, the second draws `plural.arity` as well. So **emptiness is not the mark of
an arity error** — here it comes from `%n%` being undefined, and the engine checks the count
before it counts the forms, stopping before the question of arity arises.

That is why the example at the top of this article defines `%n%` first. Without it the output
would be empty whatever the number of forms, and would demonstrate nothing about arity at all.

### `plural.count-macro` — the count comes from `#set`, and that rerolls on every reference

```
#set %n% = {1|2}
%n% {plural %n%: item|items}   →  1
```

Look at what survived: **the number printed and the noun did not.** The count has to be a number
by the time the plural is chosen, and a `#set` whose value is itself a choice never becomes one —
the engine substitutes the value **without rendering it**, so what lands in the count slot is the
literal text `{1|2}`. The count and the form cannot disagree; the engine drops the word instead.

`#def` behaves differently, expanding its value once per render, so the count slot gets a number:

```
#def %n% = {1|2}
%n% {plural %n%: item|items}   →  1 item
```

There is no panel row at all for that one. Hence the rule: make the count a plain number or a
`#def`, never a `#set`.

### `plural.nested-brackets` — brackets inside the plural forms

```
{plural %n%: {item|thing}|items}   →  ｛plural %n%: ｛item|thing｝|items｝
```

Forms are plain text. A choice inside them is not expanded, and the whole construct is printed in
wide braces instead.

---

## Permutations

### `permutation.unknown-key` — unknown key in the permutation config

```
[<foo=1>a|b|c]               →  Bfoo=1cfoo=1a
```

The known keys are `minsize`, `maxsize`, `sep` and `lastsep`. An unknown one is not a setting —
it becomes the separator between the elements, which is what the output shows.

### `permutation.minsize-not-integer` — minsize is not a whole number

```
[<minsize=two>a|b|c]         →  B c a
```

A non-numeric value is dropped along with its limit, and the default is used — which is all the
elements.

### `permutation.maxsize-not-integer` — maxsize is not a whole number

```
[<maxsize=many>a|b|c]        →  B c a
```

Exactly the same from the other end: the upper limit disappears, and the output again holds every
element.

---

## Studio notes with nothing to show

The three notes below cannot be demonstrated by an example in this document, and the reason is
different in each case and stated. They still have articles: the help owes an answer to **every**
code the panel can show, or a row in the panel leads nowhere.

### `note.raw-sentinel` — a control character in the text

The characters U+E000–U+E005 are what the engine uses for its own markup, and it **removes** them
before parsing. If they reached your template — usually pasted in from another editor — Studio
says so: neither the preview nor the production server will show them.

There is no example here on purpose: those characters are invisible, and a line carrying them
would look empty. There would be nothing to see.

### `note.unknown-target` — the set is empty, so there is nothing to judge by

It appears when the set beside the document is **empty**: not one template besides this one.
There is nothing to check the target against, so Studio does not say "no such target" — it says
it cannot answer. Put a single template in that folder and the note gives way to the ordinary
`include.unknown-target`, which answers on the merits.

A document that has never been saved has no set **at all**, and that is a third case, not this
one: includes then stay in the output verbatim and the panel says nothing about them. Save the
document and they start working.

There is no example here by construction: this document's set is declared above and is not
empty.

### `note.too-deep` — includes nested too deeply

The engine stops at the twentieth level of nested `#include` and substitutes nothing below it.
The limit belongs to the family: the JavaScript, PHP and Python engines do the same, so a document
that hits it behaves identically everywhere.

There is no example because of its size: showing one would take twenty-one files.

---

## A silence in every language: abbreviations

### An abbreviation keeps the next word lowercase

```
Ltd. our prices are low      →  Ltd. our prices are low
Xyz. our prices are low      →  Xyz. Our prices are low
```

Two lines that differ by one word, and the second word of each tells you the rule: after `Ltd.`
the sentence stays lowercase, after `Xyz.` it is capitalised. The engine capitalises after a full
stop — except after an abbreviation it knows, and anything shaped like `e.g.` or `U.S.`. It is
silent: no diagnostic, no warning, and the only way to notice is to read the output.

**The list is not English.** It holds 46 entries, and 29 of them are Russian:

| | |
|---|---|
| English | `etc vs mr mrs ms dr prof sr jr inc ltd co corp no st ave blvd` |
| Russian | `соц эл см ср ст ул пр пер г р руб коп тыс млн млрд трлн доп напр прим изд обл респ стр табл рис мин макс тел факс` |

Both halves are live in **both** locales — the rule never asks what language you set. So `руб.`
shields the next word in an English document, `Ltd.` shields it in a Russian one, and an English
author who writes `no.` or `st.` mid-sentence is using a Russian-length list without knowing it.

It bites in one place: a sentence that legitimately begins after `No.`, `St.` or `Co.` comes out
lowercase. Rewrite the sentence rather than fighting the rule — the same shielding is what keeps
`e.g. this` from being capitalised mid-sentence, which is far commoner.

---

## What the correct form looks like

```spx-good
a price {cheap|dear}         →  A price cheap
```

```spx-good
[<minsize=2;sep=", ">a|b|c]  →  C, b
```

```spx-good
#set %vip% = 1
{?vip?for you|for everyone}  →  For you
```

```spx-good
#set %n% = 5
%n% {plural %n%: item|items} →  5 items
```

```spx-good
before /# a note #/ after    →  Before after
```

Five constructions, five clean lines in the panel — which is to say none at all.

---

## Frequently asked

**Why did the paragraph simply disappear?**
Two common causes, both above: an unknown `#include` target and an include in a circle. Both
print nothing. The third one people suspect first — the wrong number of plural forms — does
**not** print nothing: the engine prints the whole construct in wide braces `｛｝`. Emptiness
there comes from a non-numeric count, not from the number of forms.

**Why does my variable with a non-ASCII name not work?**
Names are ASCII letters, digits and the underscore. `%café%` is not a variable reference at all —
the engine reads it as text and says nothing, because on its reading there is nothing to report:

```
hello %café% and %name%      →  Hello %café% and %name%
```

Both came through unchanged, and that is the trap: only the second drew a row in the panel. The
first is silent, so nothing tells you it will never be substituted. Rename it.

**I switched the locale and the document turned red.**
That is the locale doing its job. The demo document is English and its plural blocks carry two
forms; switch the locale to Russian and those two forms become an arity error, because Russian
asks for three. The locale belongs to the **document**, which is why Studio does not change it
when you change the language of the interface.

**Is the preview the same as what my server will produce?**
Yes, with one condition: the same engine version and the same locale. That is the whole reason the
preview runs the real `spintax-win` rather than an approximation of it.
