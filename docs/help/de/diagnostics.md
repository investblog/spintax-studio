# Was die Tafel „Diagnose" Ihnen sagt

Jede Zeile in dieser Tafel ist ein Urteil der **Maschine**, und dasselbe Urteil bekämen Sie von
der JavaScript-, PHP- oder Python-Umsetzung — vier eigenständige Maschinen, gemessen an einem
gemeinsamen Korpus. Es ist nicht Studios Meinung über Ihre Vorlage. Nennt die Maschine hier etwas
einen Fehler, nennt jede andere Maschine der Familie es auch einen Fehler, und Ihre Vorlage
verhält sich auf Ihrem Server so wie in diesem Fenster.

| was dasteht | wer es sagt | was es bedeutet |
|---|---|---|
| **Fehler** | die Maschine | die Vorlage tut nicht das, wonach sie aussieht |
| **Warnung** | die Maschine | sie rendert, aber wahrscheinlich nicht wie gemeint |
| **Studio-Notiz** | Studio | die Maschine sagte nichts, und es ist trotzdem der Rede wert: eine Einfügung im Kreis, ein Ziel mit anderer Schreibung, ein Steuerzeichen |

Die Spalte **Ort** ist Zeile und Spalte. Ein Klick auf die Zeile setzt den Cursor dorthin.

> Jedes Beispiel unten wird bei jedem Bau des Programms durch die Maschine geschickt, die diese
> Kopie von Studio mitbringt, und rechts steht genau das, was sie zurückgab. Nichts hier ist
> erinnert oder geraten; eine Antwort, die aufhörte zu stimmen, würde den Bau anhalten. Die
> Version der Maschine steht unter **Hilfe**, **Über das Programm**.

## Wie die Beispiele zu lesen sind

Der Pfeil `→` trennt die Vorlage von dem, was die Maschine zurückgab. `⏎` ist ein Zeilenumbruch
in einer Ausgabe, `(leer)` heißt, dass sie überhaupt nichts ausgab, und `…` steht für eine
Ausgabe, die zu lang ist, um sie ganz zu zeigen. Text hinter der Ausgabe, durch drei Leerzeichen
abgesetzt, ist eine Anmerkung und nicht Teil der Antwort.

Die Bedingungen, unter denen die Beispiele liefen, stehen hier und nicht versteckt in den Tests —
ohne sie ließen sich manche Antworten nicht nachvollziehen. Der Satz von Vorlagen zählt am
meisten: sonst ruhte
`#include "frag"` → `Fragment` auf etwas, das dieses Dokument nie sagt.

```spx-fixture
locale: de
seed: 7
empty: (leer)
include frag: Fragment
include loop: #include "loop"
include Intro: Einleitung
```

`seed` legt die zufällige Wahl fest: ohne ihn antwortete eine Auswahl oder eine Mischung jedes Mal
anders, und es gäbe nichts zu prüfen.

**Die Locale ist hier `de`, und sie entscheidet zweierlei:** wie viele Zahlformen die Maschine
erwartet und welche Form zu welcher Zahl gehört. Deutsch und Englisch verlangen zwei. Russisch,
Ukrainisch, Belarussisch, Serbisch, Kroatisch und Bosnisch verlangen drei. Die Locale kommt vom
Wähler über der rechten Hälfte, nicht von der Sprache der Oberfläche.

---

## Klammern

**Setzen Sie den Cursor auf eine Klammer, und das Konstrukt zeigt sich ganz:** wo es anfängt, wo
es aufhört und **jedes seiner Trennzeichen**. Verschachtelte Gruppen leuchten nicht mit auf — sie
haben eigene Trennzeichen, und die kommen, wenn der Cursor auf ihrer Klammer steht. Es ist der
schnellste Weg zu sehen, wo das endet, was Sie gerade bearbeiten, besonders in einer langen Zeile,
in der die `}` zwei Bildschirme nach rechts gewandert ist.

Ein Trennzeichen ist nicht nur `|`. In einer Mischung hat `[a<br>|b]` zwei: die Maschine liest
`<br>` als Trennzeichen **vor dem nächsten** Stück, und die Hervorhebung zeigt es mit den anderen,
weil es zum Bau des Konstrukts gehört.

### `bracket.unclosed` — eine Klammer wird geöffnet und nie geschlossen

```
ein Preis {billig|teuer  →  Ein Preis {billig|teuer
```

Die Maschine rät nicht, wo Sie schließen wollten. Der Text bleibt, wie er ist, Klammer und alles,
und die Auswahl findet nie statt.

### `bracket.mismatched` — von einer Klammer anderer Art geschlossen

```
ein Preis {billig|teuer]  →  Ein Preis {billig|teuer]
```

`{` wartet auf `}` und `[` auf `]`. Eine Mischung, die von einer geschweiften Klammer geschlossen
wird, ist keine Mischung.

### `bracket.unexpected-closing` — eine schließende Klammer ohne offene

```
ein Preis billig} und alles  →  Ein Preis billig} und alles
```

Sie bleibt als Text stehen. Meistens ist es eine Klammer, die von einer Änderung übrig blieb.

---

## Festlegungen

### `set.malformed` — diese `#set`-Zeile folgt nicht der Regel

```
#set stadt = Berlin
in %stadt%  →  #set stadt = Berlin ⏎ In %stadt%
```

**Der Name gehört zwischen Prozentzeichen:** `#set %stadt% = Berlin`. Das ist der häufigste erste
Fehler, und er setzt gleich zwei Zeilen in die Tafel — die missratene Zeile selbst und „diese
Variable ist nirgends festgelegt", weil keine Festlegung geschah und `%stadt%` niemandem gehört.

Sehen Sie sich die Ausgabe an: die gescheiterte Anweisung blieb **wie geschrieben** im Text
stehen. Die Maschine las sie nicht als Anweisung, also ist sie eine gewöhnliche Zeile und landet
im Ergebnis.

### `def.malformed` — diese `#def`-Zeile folgt nicht der Regel

```
#def seiten = {1|3}
%seiten%  →  #def seiten = 1 ⏎ %seiten%
```

Dieselbe Regel und derselbe Preis. `#def` unterscheidet sich von `#set` nicht in der Schreibung,
sondern darin, **wann** der Wert entfaltet wird: `#set` entfaltet ihn bei jeder Nennung erneut,
`#def` einmal je Durchgang. Ein Schreibfehler kostet Sie beides.

Und sehen Sie genau hin: das `{1|3}` in der gescheiterten Anweisung **hat eine Möglichkeit
gezogen**. Die Zeile wurde gewöhnlicher Text — und gewöhnlicher Text wird gerendert wie
gewöhnlicher Text, Klammern und alles. Eine missratene Zeile ist nicht abgeschaltet; sie hört bloß
auf, eine Anweisung zu sein.

### `definition.duplicate-name` — dieser Name ist oben schon festgelegt

```
#set %x% = erste
#set %x% = zweite
%x%  →  Zweite
```

Es funktioniert — die **letzte** Festlegung gewinnt —, aber die Maschine nennt es einen Fehler:
ein Dokument, in dem ein Name zweimal gesetzt wird, liest sich mehrdeutig, und in einem Monat
wissen Sie nicht mehr, welche der beiden Zeilen die lebende ist. Der Fehler zeigt auf die
**zweite** Festlegung; die erste steht weiter oben.

### `def.include-in-value` — `#include` im Wert einer Festlegung

```
#def %x% = #include "frag"
%x%  →  Fragment
```

Eine Einfügung in einem Wert entfaltet sich zu einem anderen Zeitpunkt, als Sie erwarten würden,
und die Familie verbietet es. Setzen Sie das `#include` in eine eigene Zeile.

---

## Variablen

### `variable.undefined` — diese Variable ist nirgends festgelegt

```
hallo, %name%  →  Hallo, %name%
```

Eine Warnung und kein Fehler: die Maschine druckt den Namen, wie er dasteht. Das ist so gewollt —
der Wert kann von außen kommen, vom Wirtsprogramm. In Studio liefern Sie solche Werte in der Tafel
Variablen unter **Sitzungswerte**.

**Der Wert einer Festlegung lässt sich in der Tafel ändern.** Stellen Sie sich im oberen Teil auf
die Spalte Wert und drücken Sie **F2** (oder tippen Sie einfach los); **Eingabe** übernimmt,
**Esc** verwirft. Die Änderung geht **ins Dokument**, in einem einzigen Rückgängig-Schritt:
`Strg+Z` stellt sie zurück.

Der Name und die Art (`#set` oder `#def`) lassen sich nicht ändern — eine Entscheidung und keine
unfertige Ecke. Aus einer Zelle heraus umzubenennen zerreißt jede Nennung der Variablen im
Dokument, und die Zeile zu löschen nähme den Kommentar und die Einrückung mit. Beides gehört in
den Text, wo Sie sehen, was Sie tun.

Genau der Wert ändert sich. Die Einrückung, die zusätzlichen Leerzeichen, die Schreibung des
Namens und ein Kommentar am Zeilenende bleiben, wie sie waren —
`   #set  %Marke%   =   Acme   /# Rest #/` kommt aus einer Änderung zurück und unterscheidet sich
nur in `Acme`. Die Datei liegt in git, und eine Zeile neu zu formatieren erschiene dort als Ihre
Änderung.

**Eine Verweigerung heißt, dass die Maschine die Zeile anders läse.** Die Änderung wird nicht
stillschweigend übernommen: die Maschine liest das Ergebnis zurück, und sagt es nicht das
Verlangte, bleibt das Dokument in Ruhe und die Statusleiste sagt es. Drei wirkliche Ursachen: ein
`/#` im Wert öffnet einen Kommentar, der den Rest der Datei frisst, ein Zeilenumbruch beendet die
Anweisung zu früh, und ein Kommentar **in** der Anweisung macht die Zeile stückweise unänderbar —
diese ändern Sie im Text.

**Zwei Gesten auf dem Namen einer Variablen.** Der Name in der Tafel ist ein Verweis und keine
Aufschrift:

- **ein Klick auf den Namen** bringt den Cursor an die erste Stelle, an der das Dokument diese
  Variable benutzt, und die Zeile leuchtet kurz auf. Dasselbe Wort in einem Kommentar oder als
  Ziel eines `#include` zählt **nicht** — die Tafel bringt Sie dorthin, wo die Variable wirklich
  wirkt.
- **Strg+Klick** schreibt eine Festlegung ins Dokument und öffnet den Gruppeneditor darauf. Der
  Wert, den Sie schon getippt haben, zieht als erste Möglichkeit ein:

```
#set %marke% = {Vulkan}
Kasino %marke%  →  Kasino Vulkan
```

Der Unterschied zwischen beiden ist, was das Schließen des Fensters übersteht. Ein Sitzungswert
nicht: er steht nicht in der Datei, nicht in git, und keine andere Maschine der Familie sieht ihn.
Eine Festlegung schon, und nur eine Festlegung bringt diese Warnung endgültig zum Schweigen. Ein
`Strg+Z` stellt das Dokument zurück.

**Ein Sitzungswert ist zunächst eine Vorlage und kein Text.** Das ist es, was die Maschine mit
jedem Wert des Wirtsprogramms tut, und die Vorschau muss zum Server passen — `{billig|teuer}` ins
Wertfeld getippt gibt also eine Auswahl und nicht diese Zeichen. Wenn Sie den Text selbst
meinten, setzen Sie in der dritten Spalte den Haken bei **als Text**: dann bleiben geschweifte
Klammern und Prozentzeichen Zeichen.

### `variable.self-reference` — die Festlegung nennt sich selbst

```
#set %x% = a %x% b
%x%  →  A a a … %x% … b b b
```

Fünfzig Ebenen, dann Schluss. Die Maschine entfaltet bis zur Tiefengrenze und hält an und lässt
`%x%` in der Mitte stehen. Keine Schleife, und auch nicht das, was Sie wollten.

Das `…` oben ist die Abkürzung dieses Dokuments und nicht die der Maschine. Die wirkliche Ausgabe
ist 207 Zeichen lang und trägt auf jeder Seite **einundfünfzig** Buchstaben statt fünfzig: die
fünfzigste Ebene hält an und lässt den Wert stehen, wie er ist, und der Wert enthält von jedem
einen mehr.

### `variable.circular-reference` — die Festlegungen nennen sich im Kreis

```
#set %x% = %y%
#set %y% = %x%
%x%  →  %y%
```

Jede Seite entfaltet sich genau **einmal** und hält dann an: `%x%` wurde `%y%` und nicht `%x%`.
Die Maschine rollt den Kreis auf, statt ihn zu laufen, und übrig bleibt der andere Name aus dem
Kreis — setzen Sie `%x% %y%` in ein Dokument, und es gibt `%y% %x%` aus, das Paar vertauscht.

Die Tafel zeichnet eine Zeile für **jede Nennung, die den Kreis schließt**, nicht eine Zeile für
den Kreis und nicht eine je Festlegung. Eine Festlegung, die den Kreis zweimal nennt, bekommt zwei
Zeilen auf ihrer eigenen Zeile: `#set %x% = %y% %y%` gegen `#set %y% = %x%` sind drei Fehler, zwei
davon in der ersten Zeile. Die Zeilen werden nicht zusammengefasst. Und die Stelle liegt auf der
Festlegung, die wirklich gilt: ist der Name zweimal festgelegt, ist das die **letzte**.

---

## Einfügungen

### `#include` wirkt nur am Zeilenanfang

```
vorher #include "frag" danach  →  Vorher #include "frag" danach
```

```
#include "frag"  →  Fragment
```

Keine Diagnose, und genau darum geht es: ein `#include` mitten in einer Zeile ist **keine**
Einfügung. Die Maschine liest es als gewöhnlichen Text und sagt nichts, weil es nichts zu
beanstanden gibt — Sie schrieben Text und bekamen Text.

**Das Ziel darf aber eine Zeile tiefer stehen**, und das überrascht von der anderen Seite. Der
Abstand, den die Maschine zwischen dem Wort und seinem Ziel erlaubt, schließt Zeilenumbrüche ein,
das hier ist also eine Einfügung und sie wirkt:

```spx-good
#include
"frag"  →  Fragment
```

Leere Zeilen dazwischen gehen auch. Alles andere geht nicht: ein Wort vor dem Ziel oder irgendetwas
außer Leerzeichen dahinter — und das Ganze ist wieder Text. Der Editor färbt das Ziel in seiner
eigenen Zeile, lässt aber das Wort gewöhnlich, bis das Ziel gekommen ist: er verspricht keine
Anweisung, deren Ende er noch nicht sieht.

### `include.unknown-target` — kein solches Ziel im Satz

```
#include "nichtda"  →  (leer)
```

Ziele sind die `.spintax`-Dateien im Ordner des offenen Dokuments. Ein unbekanntes Ziel entfaltet
sich zu nichts — der Absatz verschwindet, statt kaputtzugehen, weshalb es so leicht zu übersehen
ist.

**Darum hat die Tafel Variablen einen dritten Abschnitt, «Includes».** Er listet jedes `#include`
des Dokuments auf und dazu, ob der Satz sein Ziel hat — eine Zeile je Vorkommen, ein zweimal
genanntes Ziel sind also zwei Zeilen. Der Abschnitt erscheint nur, wenn das Dokument Einfügungen
hat. Ein Klick auf eine Zeile bringt den Cursor zu dem `#include`, das dieses Ziel nennt.

Die Marke hat **drei** Werte, und der dritte zählt: „kein Satz" heißt nicht „der Ausschnitt
fehlt", sondern „es gibt noch nirgends nachzusehen". Der Satz ist der Ordner neben dem Dokument,
und ein ungespeichertes Dokument hat keinen Ordner — bis zum ersten Speichern ist also jedes Ziel
so gekennzeichnet. „FEHLT" erscheint nur, wenn es einen Ordner gibt und die Datei wirklich nicht
darin ist.

### `note.case-mismatch` — das Ziel gibt es, in anderer Schreibung

```
#include "intro"  →  (leer)
```

Der Satz enthält `Intro.spintax` — und die Maschine sagt trotzdem, es gebe kein solches Ziel,
während Studio seine Notiz über die Schreibung hinzufügt. Die Schreibung zählt: `intro` und
`Intro` sind verschiedene Ziele. Windows öffnete die Datei so wie so, weshalb Studio im Satz
nachsieht und nicht im Dateisystem: sonst widerspräche die Vorschau dem Server über dasselbe
Dokument.

### `note.cycle` — eine Einfügung im Kreis

Enthält `loop.spintax` selbst `#include "loop"`, dann:

```
#include "loop"  →  (leer)
```

Die Maschine setzt nichts ein statt der Unendlichkeit. Die Notiz ist da, damit Sie wissen, warum
der Absatz verschwand.

Die Zeile ist gegen **`loop`** ausgestellt und nicht gegen das Dokument, das Sie ansehen — der
Kreis gehört dem Ausschnitt, und dorthin geht auch der Cursor beim Klicken. Im offenen Dokument
ist nichts unterstrichen, denn mit der Zeile, die Sie geschrieben haben, ist alles in Ordnung.

---

## Zahlformen

### `plural.arity` — nicht so viele Formen, wie die Locale verlangt

```
#set %n% = 5
%n% {plural %n%: Ding|Dinge|Dingse}  →  5 ｛plural 5: Ding|Dinge|Dingse｝
```

**Keine Leere — die Maschine druckt das ganze Konstrukt**, mit breiten Klammern `｛｝` statt der
schmalen. So sagt sie „ich habe das gesehen und konnte es nicht anwenden". Unübersehbar nennt das
niemand, und das ist gut so: ein still verschwundener Absatz brauchte länger, bis man ihn fände.

Deutsch verlangt zwei Formen, Russisch drei. Unter der Locale dieses Dokuments ist
`{plural %n%: Ding|Dinge}` die richtige.

**Leere entsteht aus einem anderen Grund, und die beiden sind leicht zu verwechseln.** Vergleichen
Sie diese zwei, die sich nur in der Zahl der Formen unterscheiden:

```
{plural %n%: Ding|Dinge}  →  (leer)   zwei Formen: richtig für Deutsch
{plural %n%: Ding|Dinge|Dingse}  →  (leer)   drei Formen: falsch für Deutsch
```

Beide drucken nichts, und die Tafel behandelt sie verschieden: die erste zieht nur
`variable.undefined`, die zweite zieht auch `plural.arity`. **Leere ist also kein Zeichen für
einen Formfehler** — sie kommt hier daher, dass `%n%` nicht festgelegt ist, und die Maschine prüft
die Zahl, bevor sie die Formen zählt, hält also an, ehe die Frage nach der Anzahl überhaupt
aufkommt.

Darum legt das Beispiel oben in diesem Artikel `%n%` zuerst fest. Ohne das wäre die Ausgabe bei
jeder Zahl von Formen leer und zeigte über die Anzahl gar nichts.

Die Tafel und die Ausgabe beantworten hier verschiedene Fragen, und das ist kein Widerspruch: die
Zeile setzt die **Prüfung** dorthin, die die Formen im Text zählt und sich für die Zahl nicht
interessiert; die Leere kommt vom **Rendern**, das seine eigene Reihenfolge hat. Geben Sie der
Zahl eine Ziffer, wie es das erste Beispiel tut, und Sie sehen, was die Anzahl wirklich tut.

### `plural.count-macro` — die Zahl kommt aus einem `#set`, und das würfelt bei jeder Nennung neu

```
#set %n% = {1|2}
%n% {plural %n%: Ding|Dinge}  →  1
```

Sehen Sie, was übrig blieb: **die Zahl wurde gedruckt und das Hauptwort nicht.** Die Zahl muss
eine Zahl sein, wenn die Form gewählt wird, und ein `#set`, dessen Wert selbst eine Auswahl ist,
wird nie eine — die Maschine setzt den Wert ein, **ohne ihn zu rendern**, im Zahl-Platz landet
also der wörtliche Text `{1|2}`. Die Zahl und die Form können sich nicht widersprechen; die
Maschine lässt stattdessen das Wort fallen.

`#def` verhält sich anders und entfaltet seinen Wert einmal je Durchgang, der Zahl-Platz bekommt
also eine Zahl:

```
#def %n% = {1|2}
%n% {plural %n%: Ding|Dinge}  →  1 Ding
```

Dafür gibt es überhaupt keine Zeile in der Tafel. Daher die Regel: machen Sie die Zahl zu einer
schlichten Ziffer oder einem `#def`, niemals zu einem `#set`.

### `plural.nested-brackets` — Klammern in den Formen

```
{plural %n%: {Ding|Sache}|Dinge}  →  ｛plural %n%: ｛Ding|Sache｝|Dinge｝
```

Formen sind schlichter Text. Eine Auswahl darin wird nicht entfaltet, und das ganze Konstrukt wird
stattdessen in breiten Klammern gedruckt.

---

## Mischungen

### `permutation.unknown-key` — unbekannter Schlüssel in der Einstellung

```
[<foo=1>a|b|c]  →  Bfoo=1cfoo=1a
```

Die bekannten Schlüssel sind `minsize`, `maxsize`, `sep` und `lastsep`. Ein unbekannter ist keine
Einstellung — und wenn er das Einzige im Block ist, ist der ganze Block überhaupt keine
Einstellung: er wird zum Trennzeichen zwischen den Stücken, was die Ausgabe zeigt.

**Steht ein wirklicher Schlüssel daneben, ist der Ausgang völlig anders**, und das ist der
wahrscheinlichere Fehler — ein Schlüssel von mehreren falsch getippt:

```
[<sep=", ";foo=1>a|b|c]  →  B, c, a
```

Der Block ist eine Einstellung, `sep` wird befolgt, der unbekannte Schlüssel schlicht fallen
gelassen, und die Tafel sagt in beiden Fällen dasselbe darüber. Die Diagnose sagt Ihnen also, dass
ein Schlüssel nicht verstanden wurde; sie sagt Ihnen nicht, was danach geschah. Dafür lesen Sie
die Ausgabe.

### `permutation.minsize-not-integer` — minsize ist keine ganze Zahl

```
[<minsize=zwei>a|b|c]  →  B c a
```

Ein nicht numerischer Wert fällt samt seiner Grenze weg, und es gilt die Vorgabe — nämlich alle
Stücke.

### `permutation.maxsize-not-integer` — maxsize ist keine ganze Zahl

```
[<maxsize=viele>a|b|c]  →  B c a
```

Genau dasselbe vom anderen Ende: die obere Grenze verschwindet, und die Ausgabe enthält wieder
jedes Stück.

---

## Studio-Notizen ohne etwas zu zeigen

Die drei Notizen unten lassen sich in diesem Dokument nicht durch ein Beispiel zeigen, und der
Grund ist jedes Mal ein anderer und wird genannt. Artikel haben sie trotzdem: die Hilfe schuldet
**jeder** Zeile, die die Tafel zeigen kann, eine Antwort, sonst führt eine Zeile ins Leere.

### `note.raw-sentinel` — ein Steuerzeichen im Text

Die Zeichen U+E000–U+E005 sind das, was die Maschine für ihre eigene Auszeichnung benutzt, und sie
**entfernt** sie vor dem Zerlegen. Sind sie in Ihre Vorlage geraten — meist aus einem anderen
Editor eingefügt —, sagt Studio es: weder die Vorschau noch der Server werden sie zeigen.

Hier steht mit Absicht kein Beispiel: diese Zeichen sind unsichtbar, und eine Zeile mit ihnen sähe
leer aus. Es gäbe nichts zu sehen.

### `note.unknown-target` — der Satz ist leer, es ist nichts zu beurteilen

Sie erscheint, wenn der Satz neben dem Dokument **leer** ist: keine einzige Vorlage außer dieser.
Es gibt nichts, woran das Ziel zu prüfen wäre, Studio sagt also nicht „kein solches Ziel" — es
sagt, dass es nicht antworten kann. Legen Sie eine einzige Vorlage in diesen Ordner, und die Notiz
weicht dem gewöhnlichen `include.unknown-target`, das in der Sache antwortet.

Ein nie gespeichertes Dokument hat **überhaupt** keinen Satz, und das ist ein dritter Fall und
nicht dieser: Einfügungen bleiben dann wörtlich in der Ausgabe stehen, und die Tafel sagt nichts
über sie. Speichern Sie das Dokument, und sie fangen an zu wirken.

Hier steht kein Beispiel, weil es keines geben kann: der Satz dieses Dokuments ist oben genannt
und nicht leer.

### `note.too-deep` — Einfügungen zu tief verschachtelt

Die Maschine hält bei der zwanzigsten Ebene verschachtelter `#include` an und setzt darunter
nichts mehr ein. Die Grenze gehört der Familie: die JavaScript-, PHP- und Python-Maschinen tun
dasselbe, ein Dokument, das an sie stößt, verhält sich also überall gleich.

Hier steht kein Beispiel wegen seiner Größe: eines zu zeigen brauchte einundzwanzig Dateien.

---

## Eine Stille für jede Sprache: Abkürzungen

### Eine Abkürzung lässt das nächste Wort klein

```
Dr. unsere Preise sind niedrig  →  Dr. unsere Preise sind niedrig
Xyz. unsere Preise sind niedrig  →  Xyz. Unsere Preise sind niedrig
```

Zwei Zeilen, die sich in einem Wort unterscheiden, und das zweite Wort jeder sagt Ihnen die Regel:
nach `Dr.` bleibt der Satz klein, nach `Xyz.` wird er großgeschrieben. Die Maschine schreibt nach
einem Punkt groß — außer nach einer Abkürzung, die sie kennt, und nach allem in der Form von
`z.B.` oder `d.h.`. Sie ist still: keine Diagnose, keine Warnung, und der einzige Weg, es zu
merken, ist die Ausgabe zu lesen.

**Die Liste ist nicht deutsch, und auch nicht englisch.** Sie hat 46 Einträge, und 29 davon sind
russisch:

| | |
|---|---|
| lateinisch | `etc vs mr mrs ms dr prof sr jr inc ltd co corp no st ave blvd` |
| kyrillisch | `соц эл см ср ст ул пр пер г р руб коп тыс млн млрд трлн доп напр прим изд обл респ стр табл рис мин макс тел факс` |

Beide Hälften gelten in **jeder** Locale — die Regel fragt nie, welche Sprache Sie eingestellt
haben. `руб.` schützt das nächste Wort also in einem deutschen Dokument, und `Dr.` schützt es in
einem russischen.

Für deutsche Texte ist die Folge einfach und unangenehm: von den Abkürzungen, die Sie täglich
schreiben, stehen nur `Dr.` und `Prof.` in der Liste, weil sie sich zufällig mit der lateinischen
Hälfte decken. `Nr.`, `bzw.`, `usw.`, `Str.` und `ca.` stehen nicht darin und beenden einen Satz.
Die Formen mit mehreren Punkten — `z.B.`, `d.h.`, `u.a.` — sind davon nicht betroffen; für die
einzelnen Wörter hilft nur, umzuformulieren.

---

## Wie die richtige Form aussieht

```spx-good
ein Preis {billig|teuer}  →  Ein Preis billig
```

```spx-good
[<minsize=2;sep=", ">a|b|c]  →  C, b
```

```spx-good
#set %vip% = 1
{?vip?für Sie|für alle}  →  Für Sie
```

```spx-good
#set %n% = 5
%n% {plural %n%: Stück|Stücke}  →  5 Stücke
```

```spx-good
vorher /# eine Notiz #/ danach  →  Vorher danach
```

Fünf Konstrukte, fünf saubere Zeilen: eine Auswahl, eine Mischung mit Einstellungen, eine
Bedingung, eine Zahlform mit einer Zahl davor und ein Kommentar. Keines davon setzt etwas in die
Tafel.

---

## Häufig gefragt

**Warum ist der Absatz einfach verschwunden?**
Zwei häufige Ursachen, beide oben: ein unbekanntes `#include`-Ziel und eine Einfügung im Kreis.
Beide drucken nichts. Die dritte, die man zuerst verdächtigt — die falsche Zahl von Zahlformen —
druckt **nicht** nichts: die Maschine druckt das ganze Konstrukt in breiten Klammern `｛｝`. Leere
kommt dort von einer nicht numerischen Zahl und nicht von der Zahl der Formen.

**Warum wirkt meine Variable mit Umlaut im Namen nicht?**
Namen bestehen aus lateinischen Buchstaben, Ziffern und dem Unterstrich. `%größe%` ist überhaupt
keine Nennung einer Variablen — die Maschine liest es als Text und sagt nichts, weil es aus ihrer
Sicht nichts zu melden gibt:

```
hallo %größe% und %name%  →  Hallo %größe% und %name%
```

Beide kamen unverändert durch, und das ist die Falle: nur das zweite zog eine Zeile in der Tafel.
Das erste ist still, nichts sagt Ihnen also, dass es nie eingesetzt werden wird. Benennen Sie es
um. Im **Wert** sind Umlaute dagegen völlig in Ordnung.

**Warum wird derselbe Fehler zweimal gezeigt?**
Ein Kreis von Festlegungen zieht eine Zeile für jede Nennung, die ihn schließt — zwei Stellen zum
Ansehen, manchmal drei. Das sind keine Dubletten, und sie werden nicht zusammengefasst.

**Die Tafel sagt Fehler und die Ausgabe sieht richtig aus. Was denn nun?**
Beides. Das kommt bei einem doppelt festgelegten Namen vor: das Rendern ist richtig — der letzte
Wert gewinnt — und das Dokument ist mehrdeutig. Das Urteil gilt dem Dokument und nicht dieser
einen Ausgabe.

**Ich habe die Locale gewechselt und das Dokument wurde rot.**
Das ist die Locale bei der Arbeit. Das Demo-Dokument ist englisch, und seine Zahlformen tragen
zwei Formen; stellen Sie die Locale auf Russisch, und aus diesen zwei Formen wird ein Fehler der
Anzahl, weil Russisch drei verlangt. Deutsch verlangt wie Englisch zwei, das Demo-Dokument bleibt
unter `de` also ruhig. Die Locale gehört zum **Dokument**, weshalb Studio sie nicht ändert, wenn
Sie die Sprache der Oberfläche wechseln.

**Stimmt die Vorschau mit dem überein, was mein Server ausgibt?**
Mit derselben Maschine, derselben Version, derselben Locale und denselben Werten — ja, genau, und
genau darum lässt die Vorschau das wirkliche `spintax-win` laufen und keine Annäherung daran. Mit
einer **anderen** Maschine der Familie — der für JavaScript, PHP oder Python — überträgt sich das
Urteil und die Menge der Texte, die die Vorlage hergeben kann, aber nicht, welchen davon ein
bestimmter Startwert zieht. Genau diese Ziehung zu wiederholen verspricht die Familie nicht.
