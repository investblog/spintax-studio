# Die Sprache, Konstrukt für Konstrukt

Eine Vorlage ist gewöhnlicher Text mit ein paar markierten Stellen darin. Alles, was nicht
markiert ist, wird unverändert ausgegeben; die Markierungen sind es, die eine Vorlage viele Texte
hergeben lassen.

Es sind sechs, und das ist die ganze Sprache: eine **Auswahl** zwischen Alternativen, ein
**Mischen** mehrerer Stücke, ein **Makro**, das Sie einmal festlegen und beim Namen benutzen, eine
**Bedingung**, eine **Zählung**, die die richtige Wortform wählt, und ein **Einfügen**, das eine
andere Vorlage hereinholt. Kommentare sind eine siebte Markierung, die überhaupt nichts ergibt.

> Jedes Beispiel unten wird bei jedem Bau des Programms durch die Maschine geschickt, die diese
> Kopie von Studio mitbringt, und rechts steht genau das, was sie zurückgab. Nichts hier ist
> erinnert oder geraten; eine Antwort, die aufhörte zu stimmen, würde den Bau anhalten. Die
> Version der Maschine steht unter **Hilfe**, **Über das Programm**.

Das andere Dokument dieser Hilfe, **Was die Tafel „Diagnose" Ihnen sagt**, handelt davon, was
schiefgeht. Dieses handelt davon, was die Konstrukte tun, wenn nichts schiefgeht — samt der
mehreren Stellen, an denen eine Vorlage etwas Überraschendes tut und nichts es meldet.

## Wie die Beispiele zu lesen sind

Der Pfeil `→` trennt die Vorlage von dem, was die Maschine zurückgab. `(leer)` heißt, dass sie
überhaupt nichts ausgab. Text hinter der Ausgabe, durch drei Leerzeichen abgesetzt, ist eine
Anmerkung und nicht Teil der Antwort.

Die Bedingungen sind genannt und nicht stillschweigend angenommen, denn ohne sie ließe sich die
Hälfte der Antworten unten nicht nachvollziehen:

```spx-fixture
locale: de
seed: 7
empty: (leer)
include intro: Willkommen bei {Acme|Globex}.
include shout: Die %marke% ist da.
```

`seed` legt die zufällige Wahl fest. Eine Vorlage mit einer Auswahl darin hat keine einzelne
Antwort, ein Beispiel ohne Startwert würde also bei jedem Lauf etwas anderes ausgeben, und es
gäbe nichts zu prüfen. Im Fenster ist es das Kästchen **Seed** über der rechten Hälfte;
setzen Sie den Haken, und daneben erscheint ein Zahlenfeld, und die Vorschau steht still, während
Sie arbeiten.

`locale` entscheidet über die Zahlformen, und es ist der Wähler über der rechten Hälfte, nicht die
Sprache der Oberfläche. Deutsch und Englisch brauchen zwei Formen; Russisch, Ukrainisch,
Belarussisch, Serbisch, Kroatisch und Bosnisch brauchen drei.

## Auswahl

Geschweifte Klammern mit `|` dazwischen: die Maschine nimmt **eine**.

```spx-good
Ein {kleiner|großer} Raum.  →  Ein kleiner Raum.
```

Die Wahl ist zufällig, dieselbe Vorlage gibt bei einem anderen Lauf also `Ein großer Raum.` Die
Auswahl selbst lässt den Text um sich herum in Ruhe — auch wenn der Feinschliff, der gegen Ende
dieses Dokuments beschrieben wird, bis zu ihm reicht.

### Verschachtelung

Eine Auswahl kann eine weitere enthalten, beliebig tief.

```spx-good
Acme {Pro {Plus|Max}|Lite}  →  Acme Pro Plus
```

Die innere Wahl wird nur getroffen, wenn die äußere den Zweig nimmt, in dem sie steht: fällt
`Lite`, wird `Plus|Max` nie befragt — und, messbar, nicht einmal nach einer Zufallszahl gefragt.

### Eine leere Möglichkeit

Eine Möglichkeit darf leer sein. Das ist der gewöhnliche Weg, etwas nur manchmal erscheinen zu
lassen.

```spx-good
Ein {|sehr }großer Raum.  →  Ein großer Raum.
```

Das Leerzeichen in die Möglichkeit zu schreiben, `{|sehr }` statt `{|sehr} `, ist Gewohnheit und
keine Vorschrift: der Feinschliff zieht den doppelten Zwischenraum so oder so zusammen.

## Mischen

Eckige Klammern nehmen mehrere Stücke, wählen wie viele, bringen sie in zufällige Reihenfolge und
fügen sie zusammen.

```spx-good
[rot|grün|blau]  →  Grün blau rot
```

Sich selbst überlassen nimmt es alle und verbindet sie mit einem Leerzeichen. Alles Weitere über
ein Mischen steht in einem `<…>` Block unmittelbar hinter der öffnenden Klammer.

### Das Trennzeichen

```spx-good
[<, >rot|grün|blau]  →  Grün, blau, rot
```

Ein `<…>` Block ist selbst das Trennzeichen, sofern er nicht **eine Einstellung nennt**: eine von
`sep`, `lastsep`, `minsize` oder `maxsize`, als eigenes Wort und mit einem `=` dahinter. Alles
andere an dieser Stelle ist ein Trennzeichen, so sehr es auch nach einer Einstellung aussieht —
ein Schlüssel ohne sein `=`:

```spx-good
[<maxsize 2>rot|grün|blau]  →  Grünmaxsize 2blaumaxsize 2rot
```

oder ein Schlüssel, an den vorn etwas geklebt ist:

```
[<xmaxsize=1>rot|grün|blau]  →  Grünxmaxsize=1blauxmaxsize=1rot
```

Der zweite lohnt einen zweiten Blick: die Tafel nennt `xmaxsize` **sehr wohl** einen unbekannten
Schlüssel, und die Maschine druckt den ganzen Block trotzdem zwischen die Stücke. Die Diagnose
und die Ausgabe beantworten verschiedene Fragen.

Schreiben Sie die Einstellungen aus, wenn Sie zwei verschiedene Trennzeichen wollen:

```spx-good
[<sep=", ";lastsep=" und ">rot|grün|blau]  →  Grün, blau und rot
```

`sep` steht zwischen den Stücken und `lastsep` vor dem letzten.

### Wie viele

```spx-good
[<minsize=2;maxsize=2>rot|grün|blau]  →  Grün blau
```

`minsize` ist der Boden und `maxsize` die Decke; die Anzahl dazwischen ist zufällig wie die
Reihenfolge. Gleiche Werte nehmen genau so viele. **Ohne beide alle — aber mit nur `maxsize`
liegt der Boden bei eins**, was Leute überrascht:

```spx-good
[<maxsize=3>a|b|c]  →  C
```

Drei Stücke, eine Decke von drei, und eines kam heraus. Schreiben Sie auch `minsize`, wenn Sie
„alle, höchstens drei" meinen. Ein `maxsize` über der Anzahl der Stücke wird stillschweigend auf
sie gesenkt. Ein `minsize` über dem `maxsize` wird wortlos hingenommen, und der Boden gewinnt —
die Decke wird zu ihm angehoben und nicht umgekehrt:

```spx-good
[<minsize=3;maxsize=1>rot|grün|blau]  →  Grün blau rot
```

### Ein Trennzeichen zwischen zwei Stücken

Ein `<…>`, das **zwischen** zwei Stücke geschrieben wird, ist das Trennzeichen für dieses Paar.

```spx-good
[rot|grün<und>|blau]  →  Grün und blau rot
```

Es gehört zu dem Stück **danach** und wandert mit diesem Stück durch das Mischen, taucht also
dort auf, wo dieses Stück landet, statt an einer festen Stelle der Ausgabe. Ein `<…>` hinter dem
**letzten** Stück ist überhaupt kein Trennzeichen und wird als Text gedruckt:

```spx-good
[rot|grün|blau<und>]  →  Grün blau<und> rot
```

## Makros

`#set` gibt einem Stück Text einen Namen. Der Name wird als `%name%` benutzt, und die Anweisung
muss das Erste in ihrer Zeile sein — führende Leerzeichen und Tabulatoren sind erlaubt, alles
andere nicht.

```spx-good
#set %stadt% = Berlin
Flug nach %stadt%.  →  Flug nach Berlin.
```

Namen bestehen aus lateinischen Buchstaben, Ziffern und `_`. Ein Name in einem anderen Alphabet
ist kein Name, worüber das andere Dokument unter `set.malformed` spricht. Umlaute gehören also
nicht in einen Namen — in einen Wert dagegen schon.

### `#set` würfelt erneut, `#def` würfelt einmal

Das ist der ganze Unterschied zwischen beiden, und er zeigt sich nur, wenn der Wert eine Auswahl
enthält.

```spx-good
#set %wahl% = {A|B}
%wahl% %wahl% %wahl%  →  A A B
```

```spx-good
#def %wahl% = {A|B}
%wahl% %wahl% %wahl%  →  A A A
```

Beide Beispiele liefen unter demselben Startwert. `#set` bewahrt die Vorlage auf und würfelt sie
bei jeder Benutzung; `#def` würfelt einmal und behält die Antwort. Nehmen Sie `#def` für etwas,
das mit sich selbst übereinstimmen muss — eine Marke, eine Stadt, einen Namen, eine Anzahl — und
`#set` für Abwechslung.

Ein einzelner Startwert kann die beiden nicht auseinanderhalten: es gibt Startwerte, bei denen
`#set` zufällig dreimal dieselbe Möglichkeit nimmt und die zwei gleich aussehen. Das ist zu
wissen, bevor Sie aus einer einzigen Vorschau schließen, eine Festlegung funktioniere nicht.

## Bedingungen

`{?name?dann|sonst}` fragt, ob ein Makro einen Wert hat.

```spx-good
#set %n% = 5
{?n?wir haben %n%|noch nichts}  →  Wir haben 5
```

Die `sonst`-Hälfte darf fehlen — `{?name?dann}` gibt nichts aus, wenn die Antwort nein ist. Ein
`!` dreht die Frage um:

```spx-good
#set %vip% = 1
{?!vip?Fremder|Freund}  →  Freund
```

Einen Wert zu haben heißt, **mindestens ein Zeichen zu haben, das kein Leerzeichen ist**. Ein
Makro, das auf nichts gesetzt ist oder nur auf Leerzeichen, gilt als ohne Wert.

Der Name einer Bedingung muss mit einem Buchstaben oder `_` **beginnen**, was strenger ist als
bei einem Makro — und das Kapitel über die Stillen sagt, was aus einem Namen wird, der mit einer
Ziffer anfängt.

## Zählung

`{plural %n%: …}` wählt die Wortform, die zu einer Zahl gehört.

```spx-good
#def %n% = 1
%n% {plural %n%: Datei|Dateien}  →  1 Datei
```

```spx-good
#def %n% = 5
%n% {plural %n%: Datei|Dateien}  →  5 Dateien
```

Die Zahl ist hier mit Absicht ein `#def` und kein `#set`, und die Regel lohnt sich zu behalten:
**machen Sie die Zahl zu einer schlichten Ziffer oder einem `#def`, niemals zu einem `#set`.** Was
aus einem `#set` in den Zahl-Platz gelangt, ist der aufbewahrte TEXT, `{5|5}` statt `5` — keine
Zahl also, weshalb das ganze Konstrukt nichts ergibt und die Tafel `plural.count-macro` sagt. Die
Zahl und die Form können sich nicht widersprechen: stattdessen verschwindet das Wort.

```
#set %n% = {5|5}
%n% {plural %n%: Datei|Dateien}  →  5
```

Wie viele Formen es sind, entscheidet die Locale und nicht Sie: unter `de` sind es zwei, unter
`ru` drei. Die falsche Anzahl ist ein Fehler, den die Tafel meldet (`plural.arity`), und die
Maschine druckt dann das ganze Konstrukt zurück, mit breiten Klammern `｛｝` statt der schmalen,
damit man es nicht für Ausgabe hält.

## Ausschnitte

`#include "name"` setzt an dieser Stelle eine andere Vorlage ein, und die Anweisung muss das Erste
in ihrer Zeile sein — auch hier sind führende Leerzeichen und Tabulatoren erlaubt.

```spx-good
#include "intro"  →  Willkommen bei Acme.
```

Der Ausschnitt wird als eigene Vorlage gerendert, eine Auswahl darin wird also frisch getroffen:
`intro` enthält `{Acme|Globex}` und antwortet mit dem einen oder dem anderen.

Der Name wird **genau** verglichen. `Intro` und `intro` sind zwei verschiedene Ausschnitte, und
unter Windows ist das leicht falsch zu machen, weil das Dateisystem es nicht kümmert. Ein
fehlendes Ziel rendert als nichts, und die Tafel sagt `include.unknown-target`; ein Ziel, das sich
nur in der Groß- und Kleinschreibung unterscheidet, bekommt eine Studio-Notiz mit dem Namen, den
Sie vermutlich meinten.

### Ein Ausschnitt sieht Ihre Makros nicht

Er wird als eigene Vorlage gerendert: er hat die Werte der Sitzung, aber nicht die `#set` und
`#def` des Dokuments, das ihn hereingeholt hat.

```
#set %marke% = Acme
#include "shout"  →  Die %marke% ist da.
```

`shout` ist `Die %marke% ist da.`, und der Name muss im Ausschnitt selbst festgelegt sein. Das ist
keine Stille — die Tafel sagt durchaus `variable.undefined` —, aber sie sagt es gegen **`shout`**,
in Zeile 1 jener Datei, und im Dokument, das Sie ansehen, erscheint keine Wellenlinie, weil die
Stelle zu einem anderen Puffer gehört. Lesen Sie die Spalte **Datei**, wenn eine Warnung von einer
Zeile zu handeln scheint, die Sie nicht geschrieben haben.

## Anmerkungen

`/# … #/` ist ein Kommentar: alles zwischen den Marken wird entfernt, bevor irgendetwas anderes
geschieht.

```spx-good
Entwurf /# unsicher ob das bleibt #/ fertig  →  Entwurf fertig
```

Kommentare verschachteln sich nicht. Das erste `#/` schließt den Kommentar, was auch immer davor
stand, ein Kommentar um Text herum, der selbst `#/` enthält, endet also früher als er aussieht.

## Was die Maschine am Ende glättet

Die Ausgabe ist nicht ganz der Text, den die Konstrukte erzeugt haben. Am Ende geschieht ihr
mehreres; zweierlei begegnet Ihnen täglich.

Der erste Buchstabe jedes Satzes wird großgeschrieben:

```spx-good
eins. zwei. drei.  →  Eins. Zwei. Drei.
```

Deshalb antworten die Beispiele in dieser Hilfe so oft mit einem großen Buchstaben, wo die Vorlage
einen kleinen hat. Ein Punkt hinter einer Abkürzung, die die Maschine kennt, beendet keinen Satz,
und ebenso wenig etwas in der Form von `z.B.` oder `d.h.` — **in lateinischen Buchstaben**, was
eine echte Grenze ist und keine Absicherung: die Prüfung „ist das die Mitte eines Wortes" ist eine
ASCII-Prüfung.

```spx-good
z.B. das bleibt klein  →  z.B. das bleibt klein
```

```spx-good
Dr. unsere Preise sind niedrig  →  Dr. unsere Preise sind niedrig
```

Jedes andere Wort beendet einen Satz, wie kurz es auch sei — die Länge hat nichts damit zu tun:

```spx-good
Xyz. unsere Preise sind niedrig  →  Xyz. Unsere Preise sind niedrig
```

Die Liste, die die Maschine kennt, hat 46 Einträge, **29 davon kyrillisch**, und das andere
Dokument geht sie unter **Eine Stille für jede Sprache** durch. Für deutsche Texte steht das
Wichtigste weiter unten bei den Stillen: die Liste ist nicht auf Deutsch eingestellt.

Das zweite alltägliche ist, dass Folgen von Leerzeichen zu einem zusammenfallen. Das ist es, was
Sie eine leere Möglichkeit stehen lassen lässt, ohne die Leerzeichen darum herum zu zählen.

Der Rest in einem Atemzug: ein Leerzeichen vor `,;:!?.` fällt weg und eines wird dahinter
eingesetzt; die ganze Ausgabe wird an den Rändern beschnitten; der große Buchstabe kommt auch nach
einem Zeilenumbruch und nach einem Block-Tag, nicht nur nach einem Punkt; und Adressen mit Schema,
E-Mail-Adressen, nackte Domains und Dezimalzahlen sind geschützt und kommen genau so heraus, wie
sie getippt wurden.

Für den letzten Punkt gilt dieselbe ASCII-Grenze wie für die Abkürzungen oben. Eine nackte Domain
ist geschützt, wenn sie in lateinischen Buchstaben geschrieben ist; `сайт.рф` ist es nicht, und
der Feinschliff setzt ein Leerzeichen und einen großen Buchstaben hinein.

```spx-good
hallo , Welt  →  Hallo, Welt
```

```spx-good
eins.zwei  →  eins.zwei
```

## Stillen

Jeder Fall unten rendert, ergibt etwas anderes als er aussieht und zieht **überhaupt keine
Diagnose** nach sich. Sie sind hier gesammelt, weil nichts sonst im Fenster sie je erwähnen wird.

**Die deutschen Abkürzungen stehen nicht in der Liste der Maschine.** Das ist die Stille, die
deutsche Autoren als Erstes treffen. Geschützt sind nur die Wörter, die sich mit der englischen
Hälfte der Liste decken — `Dr.` und `Prof.` oben —, während `Nr.`, `bzw.`, `usw.`, `Str.` und
`ca.` einen Satz beenden und das nächste Wort großschreiben:

```spx-good
bzw. unsere Preise sind niedrig  →  Bzw. Unsere Preise sind niedrig
```

Die Formen mit mehreren Punkten sind davon nicht betroffen: `z.B.`, `d.h.` und `u.a.` gehen durch
die Regel für mehrere Punkte und bleiben unangetastet. Für die einzelnen Wörter hilft nur,
umzuformulieren oder den Punkt zu vermeiden.

**Ein `#include`, das nicht allein in seiner Zeile steht, ist gewöhnlicher Text.**

```spx-good
Vorher. #include "intro"  →  Vorher. #include "intro"
```

Dasselbe gilt für eine Anweisung mit etwas dahinter und für `#include"intro"` ohne Leerzeichen.
Die Regel ist die der Familie und nicht die dieser Maschine, und sie ist es, die eine Anweisung
erkennbar macht, ohne die ganze Zeile zu zerlegen.

**Eine Bedingung, deren Name mit einer Ziffer beginnt, ist keine Bedingung.** Sie wird zu einer
gewöhnlichen Auswahl zwischen `?1x?ja` und `nein`:

```spx-good
{?1x?ja|nein}  →  ?1x? Ja
```

**Ein `<…>` am Kopf eines späteren Stücks ist kein Trennzeichen** und wird gedruckt, wie es
dasteht:

```spx-good
[rot|<und>grün]  →  <und>Grün rot
```

Der Block am Kopf des **ersten** Stücks ist das Trennzeichen — das ist die Schreibweise, mit der
das Kapitel über das Mischen beginnt:

```spx-good
[<und>rot|grün]  →  Grün und rot
```

Irgendwo hinter einem `|` ist er gewöhnlicher Text, und ein Trennzeichen zwischen zwei Stücken
gehört ans **Ende** des ersten.

**Ein nacktes Tag am Ende eines Stücks wird als Trennzeichen dieses Paares genommen** und als
eigener Text gedruckt:

```spx-good
[eins<br>|zwei]  →  Zwei eins
```

Unter diesem Startwert landeten die zwei in der anderen Reihenfolge, das Trennzeichen kam also gar
nicht heraus. Mit einem dritten Stück gibt es einen Platz für es, und es erscheint:

```spx-good
[rot|grün<br>|blau]  →  Grün br blau rot
```

Das `<br>` sitzt zwischen `grün` und dem, was darauf folgt, wohin das Mischen dieses Paar auch
setzt. Ein schließendes Tag (`</b>`), ein selbstschließendes (`<br/>`), eines mit Attributen
(`<br class="x">`) und ein Tag mitten in einem Stück bleiben alle unangetastet.

**Ein nicht geschlossener Kommentar ist gewöhnlicher Text** — er öffnet nichts, und das `/#` wird
gedruckt:

```spx-good
vorher /# der Rest davon  →  Vorher /# der Rest davon
```

Er ist aber immer noch die Hälfte eines Paares. Erscheint weiter unten im Dokument ein `#/`,
finden die beiden einander, und alles dazwischen geht — samt allem, was der Autor dazwischen
geschrieben hat:

```
{a /# ups|b} Mitte #/ Schwanz  →  {a Schwanz
```

Die Auswahl oben verlor ihre zweite Alternative und ihre schließende Klammer, und keine Diagnose
sagt es: das ist, was der Text BEDEUTET, und kein Fehler, den die Maschine sehen kann. Wenn ein
`/#` wörtlich gemeint ist, ist der sichere Platz dafür der Wert einer Variablen und nicht der
Vorlagentext.

## Wo als Nächstes nachsehen

Das andere Dokument, **Was die Tafel „Diagnose" Ihnen sagt**, hat einen Artikel je Zeile, die die
Tafel zeigen kann — was sie bedeutet, was sie auslöst und was die Maschine mit der Vorlage macht,
solange sie dasteht. Drücken Sie F1 mit dem Cursor in einem Konstrukt, und die Hilfe öffnet beim
Kapitel dieses Konstrukts **in jenem Dokument**: eine geschweifte Klammer bei **Klammern**, ein
`[…]` bei **Mischungen**, eine `#set`-Zeile bei **Festlegungen**.
