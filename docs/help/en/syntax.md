# The language, construct by construct

A template is ordinary text with a few marked places in it. Everything that is not marked is
copied out as it stands; the marks are what make one template able to produce many texts.

There are six of them, and that is the whole language: a **choice** between alternatives, a
**shuffle** of several pieces, a **macro** you define once and use by name, a **condition**, a
**count** that picks the right word form, and an **include** that pulls in another template.
Comments are a seventh mark that produces nothing at all.

> Every example below was run through `spintax-win v0.4.0`, and the right-hand side is exactly
> what it returned. Nothing here is remembered or guessed.

The other document in this help, **What the Diagnostics tab is telling you**, is about what goes
wrong. This one is about what the constructs do when nothing goes wrong — including the several
places where a template does something surprising and nothing reports it.

## How to read the examples

The arrow `→` separates the template from what the engine returned. `(empty)` means it printed
nothing at all. Text after the output, set off by three spaces, is a note rather than part of the
answer.

The conditions are stated rather than assumed, because without them half the answers below could
not be reproduced:

```spx-fixture
locale: en
seed: 7
empty: (empty)
include intro: Welcome to {Acme|Globex}.
include shout: The %brand% is here.
```

`seed` pins the random choice. A template with a choice in it has no single answer, so an example
without a seed would print something different on every run and there would be nothing to check.
In the window it is the tick-box marked **Seed** above the right-hand pane; tick it and a number
field appears beside it, and the preview stops moving while you edit.

`locale` decides plural forms, and it is the selector above the right-hand pane rather than the
language of the interface. English needs two forms; Russian, Ukrainian, Belarusian, Serbian,
Croatian and Bosnian need three.

## Choices

Braces with `|` between them: the engine picks **one**.

```spx-good
A {small|large} room.  →  A small room.
```

The pick is random, so the same template gives `A large room.` on another run. The choice itself
leaves the text around it alone — though the tidy-up described near the end of this document
still reaches it, which is why the answer above opens with a capital the template does not have.

### Nesting

A choice can contain another, to any depth.

```spx-good
Acme {Pro {Plus|Max}|Lite}  →  Acme Pro Plus
```

The inner choice is only made when the outer one picks the branch it is in: with `Lite` chosen,
`Plus|Max` is never consulted — and, measurably, not even asked for a random number.

### An empty option

An option may be empty. It is the ordinary way to make something appear only sometimes.

```spx-good
A {|very }large room.  →  A large room.
```

Writing the space inside the option, `{|very }` rather than `{|very} `, is a habit rather than a
requirement: the tidy-up collapses the double space either way.

## Shuffles

Square brackets take several pieces, choose how many, put them in a random order and join them.

```spx-good
[red|green|blue]  →  Green blue red
```

Left alone it takes all of them and joins with a single space. Everything else about a shuffle is
set in a `<…>` block immediately after the opening bracket.

### The separator

```spx-good
[<, >red|green|blue]  →  Green, blue, red
```

A `<…>` block holding no `=` is the separator itself. Write it out in full when you want two
different ones:

```spx-good
[<sep=", ";lastsep=" and ">red|green|blue]  →  Green, blue and red
```

`sep` goes between the items and `lastsep` before the final one, which is how an English list is
punctuated.

### How many

```spx-good
[<minsize=2;maxsize=2>red|green|blue]  →  Green blue
```

`minsize` is the floor and `maxsize` the ceiling; the count between them is random, like the
order. Equal values take exactly that many. **With neither, all of them — but with only
`maxsize`, the floor is one**, which surprises people:

```spx-good
[<maxsize=3>a|b|c]  →  C
```

Three items, a ceiling of three, and one piece came out. Write `minsize` too when you mean "all
of them, at most three". A `maxsize` above the number of items is quietly reduced to it, and a
`minsize` above the `maxsize` is accepted without a word.

### A separator between two items

A `<…>` written **between** two items is the separator for that pair.

```spx-good
[red|green<and>|blue]  →  Green and blue red
```

It belongs to the item **after** it and travels with that item through the shuffle, so it turns up
wherever that item lands rather than at a fixed place in the output. A `<…>` after the **last**
item is not a separator at all and prints as text:

```spx-good
[red|green|blue<and>]  →  Green blue<and> red
```

## Macros

`#set` gives a name to a piece of text. The name is used as `%name%`, and the directive must be
the first thing on its line — leading spaces and tabs are allowed, anything else is not.

```spx-good
#set %city% = Boston
Fly to %city%.  →  Fly to Boston.
```

Names are ASCII letters, digits and `_`. A name in any other alphabet is not a name, which the
other document covers under `set.malformed`.

### `#set` rolls again, `#def` rolls once

This is the whole difference between the two, and it only shows when the value contains a choice.

```spx-good
#set %pick% = {A|B}
%pick% %pick% %pick%  →  A A B
```

```spx-good
#def %pick% = {A|B}
%pick% %pick% %pick%  →  A A A
```

Both examples ran under the same seed. `#set` stores the template and rolls it at every use;
`#def` rolls once and keeps the answer. Use `#def` for something that must agree with itself — a
brand, a city, a name, a count — and `#set` for variety.

One seed cannot tell them apart: there are seeds where `#set` happens to pick the same option
three times and the two look identical. That is worth knowing before you conclude from a single
preview that a definition is not working.

## Conditions

`{?name?then|else}` asks whether a macro has a value.

```spx-good
#set %n% = 5
{?n?we have %n%|nothing yet}  →  We have 5
```

The `else` half may be left out — `{?name?then}` prints nothing when the answer is no. A `!`
inverts the question:

```spx-good
#set %vip% = 1
{?!vip?stranger|friend}  →  Friend
```

Having a value means having **at least one character that is not a space**. A macro set to
nothing, or to spaces only, counts as having no value.

A condition's name must **start** with a letter or `_`, which is stricter than a macro's — and the
silences chapter says what a name starting with a digit turns into.

## Counting

`{plural %n%: …}` picks the word form that goes with a number.

```spx-good
#def %n% = 1
%n% {plural %n%: file|files}  →  1 file
```

```spx-good
#def %n% = 5
%n% {plural %n%: file|files}  →  5 files
```

The count is a `#def` here rather than a `#set` on purpose, and the rule is worth keeping: **make
the count a plain number or a `#def`, never a `#set`.** What reaches the count slot from a `#set`
is the stored TEXT, `{5|5}` rather than `5` — not a number, so the whole construct produces
nothing and the panel says `plural.count-macro`. The count and the form cannot disagree: the word
disappears instead.

```
#set %n% = {5|5}
%n% {plural %n%: file|files}  →  5
```

The number of forms is decided by the locale, not by you: under `en` there are two, under `ru`
three. The wrong number is an error the panel reports (`plural.arity`), and the engine then prints
the whole construct back with the braces swapped for wide ones `｛｝`, so it cannot be mistaken for
output.

## Fragments

`#include "name"` puts another template in at that point, and the directive must be the first
thing on its line — again, leading spaces and tabs are allowed.

```spx-good
#include "intro"  →  Welcome to Acme.
```

The fragment is rendered as its own template, so a choice inside it is made afresh: `intro` holds
`{Acme|Globex}` and answers with either.

The name is matched **exactly**. `Intro` and `intro` are two different fragments, and on Windows
that is easy to get wrong because the file system does not care. A missing target renders as
nothing and the panel says `include.unknown-target`; a target that differs only in case gets a
Studio note naming the one you probably meant.

### A fragment does not see your macros

It is rendered as its own template: it has the session's values, but not the `#set` and `#def` of
the document that included it.

```
#set %brand% = Acme
#include "shout"  →  The %brand% is here.
```

`shout` is `The %brand% is here.`, and the name has to be defined in the fragment itself. This one
is not a silence — the panel does say `variable.undefined` — but it says it against **`shout`**, at
line 1 of that file, and no squiggle appears in the document you are looking at, because the
position belongs to another buffer. Read the **File** column when a warning seems to be about a
line you did not write.

## Remarks

`/# … #/` is a comment: everything between the marks is removed before anything else happens.

```spx-good
draft /# not sure about this #/ ready  →  Draft ready
```

Comments do not nest. The first `#/` closes the comment, whatever came before it, so a comment
wrapped around text that itself contains `#/` ends earlier than it looks.

## What the engine tidies afterwards

The output is not quite the text the constructs produced. Several things happen to it at the end;
two you meet daily.

The first letter of every sentence is capitalised:

```spx-good
one. two. three.  →  One. Two. Three.
```

That is why the examples in this help so often answer with a capital where the template has a
small letter. A dot after an abbreviation the engine knows does not end a sentence, and neither
does anything shaped like `e.g.` or `U.S.`:

```spx-good
e.g. this stays lower  →  e.g. this stays lower
```

```spx-good
Ltd. our prices are low  →  Ltd. our prices are low
```

Any other word ends a sentence, however short — length has nothing to do with it:

```spx-good
Xyz. our prices are low  →  Xyz. Our prices are low
```

The list the engine knows has 46 entries, most of them Russian, and the other document goes
through it under **A silence in every language**.

The second everyday one is that runs of spaces collapse to one. That is what lets you leave an
empty option without counting the spaces around it.

The rest, in one breath: a space before `,;:!?.` is dropped and one is inserted after it; the
whole output is trimmed; the capital arrives after a line break and after a block tag as well as
after a full stop; and URLs, e-mail addresses, bare domains and decimal numbers are shielded and
come out exactly as typed.

```spx-good
hello , world  →  Hello, world
```

```spx-good
one.two  →  one.two
```

## Silences

Every case below renders, produces something other than what it looks like, and draws **no
diagnostic at all**. They are collected here because nothing else in the window will ever mention
them.

**A `#include` that is not alone on its line is plain text.**

```spx-good
Before. #include "intro"  →  Before. #include "intro"
```

The same is true of a directive with anything after it, and of `#include"intro"` with no space.
The rule is the family's rather than this engine's, and it is what makes a directive recognisable
without parsing the whole line.

**A condition whose name starts with a digit is not a condition.** It becomes an ordinary choice
between `?1x?yes` and `no`:

```spx-good
{?1x?yes|no}  →  ?1x? Yes
```

**A `<…>` at the head of a later item is not a separator** and prints as it stands:

```spx-good
[red|<and>green]  →  <and>Green red
```

The block at the head of the **first** item is the separator — that is the syntax the shuffles
chapter opens with, and `[<and>red|green]` answers `Green and red`. Anywhere after a `|` it is
plain text, and a separator between two items goes at the **end** of the first.

**A bare tag at the end of an item is taken as that pair's separator** and printed as its own
text:

```spx-good
[one<br>|two]  →  Two one
```

Under this seed the two landed in the other order, so the separator did not come out at all;
under another the same template answers `One br two`. A closing tag (`</b>`), a self-closing one
(`<br/>`), one carrying attributes (`<br class="x">`) and a tag in the middle of an item are all
left alone.

**An unclosed comment is ordinary text** — it opens nothing, and the `/#` is printed:

```spx-good
before /# rest of it  →  Before /# rest of it
```

But it is still half of a pair. If a `#/` appears further down the document, the two find each
other and everything between them goes — including whatever the author wrote in between:

```
{a /# oops|b} middle #/ tail  →  {a tail
```

The choice above lost its second alternative and its closing brace, and no diagnostic says so:
this is what the text MEANS, not a mistake the engine can see. When a `/#` is meant literally,
the safe place for it is a variable's value rather than the template body.

## Where to look next

The other document, **What the Diagnostics tab is telling you**, has one article per line the
panel can show — what it means, what causes it, and what the engine does with the template while
it is there. Press F1 with the caret inside a construct and the help opens at that construct's
chapter **in that document**: a brace on **Brackets**, a `[…]` on **Permutations**, a `#set` line
on **Definitions**.
