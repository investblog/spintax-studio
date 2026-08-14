# Spintax Studio

Dieses Programm ist ein Editor für Vorlagen. Eine Vorlage ist gewöhnlicher Text mit ein paar
markierten Stellen darin, und eine einzige Vorlage kann sehr viele verschiedene Texte ergeben —
genau darum schreibt man eine, statt die Texte einzeln zu schreiben.

Das Fenster besteht aus zwei Hälften. Links steht Ihre Vorlage, das, was Sie bearbeiten. Rechts
steht einer der Texte, die daraus entstehen, neu gezeichnet während Sie tippen. Dazwischen ist
nichts zu drücken: rechts sehen Sie das, was die Maschine in diesem Augenblick für das links
Stehende zurückgibt.

```spx-fixture
locale: de
seed: 7
empty: (leer)
```

Die Maschine steckt in diesem Programm und ist das Pascal-Mitglied einer Familie: dieselbe
Sprache erscheint auch für JavaScript, PHP und Python. Die vier sind eigenständige Programme,
die an einem gemeinsamen Satz von Prüffällen gemessen werden — was eine Vorlage BEDEUTET, ist
also in allen gleich: die Konstrukte, das Urteil über ihre Gültigkeit, der abschließende
Feinschliff. Eine Vorlage, die dieses Fenster gültig nennt, ist auch dort gültig.

Was nicht versprochen wird, und der Unterschied zählt beim Vergleichen: die zufällige Wahl. Ein
Startwert macht die Vorschau HIER wiederholbar — derselbe Startwert und dieselbe Vorlage geben
morgen denselben Text —, aber derselbe Startwert kann in der JavaScript-Maschine eine andere
Alternative ziehen. Startwerte sind dazu da, Ihre eigene Arbeit zu reproduzieren, nicht dazu,
eine andere Maschine zu treffen.

Alles hier funktioniert ohne Netzverbindung. Es gibt kein Konto, keine Anmeldung und nichts
einzuschalten: Programm öffnen, und es läuft.

## Die zwei Hälften

Getippt wird links. Die rechte Hälfte zeichnet nach einer kurzen Pause neu, damit die Vorschau
einem Satz folgt und nicht jedem Buchstaben.

Eine Vorlage mit einer Auswahl darin hat keine einzelne Antwort, und die Vorschau zeigt eine
davon:

```spx-good
{Hallo|Guten Tag} zusammen.  →  Hallo zusammen.
```

**Würfeln** über der rechten Hälfte holt die nächste. Wenn Sie immer dieselbe wollen — etwa
während Sie zwei Änderungen vergleichen —, setzen Sie den Haken bei **Seed**, und die
Vorschau steht still, bis Sie ihn wieder entfernen oder die Zahl ändern.

Der Schalter über der rechten Hälfte bietet **Seite** und **Quelltext**. Vorlagen sind meist HTML,
und die beiden Fragen „wie sieht das aus" und „welches Markup kam heraus" beantworten einander
nicht: ein kaputtes Tag ergibt ein leicht schiefes Layout, über das das Auge hinwegsieht,
während Prosa mit Tags darin sich nicht wie Prosa liest. Der Schalter über der Hälfte wechselt,
was Sie gerade ansehen.

Markieren Sie einen Teil der Vorlage, und nur dieser Teil wird gerendert — im Geltungsbereich
des ganzen Dokuments, sodass ein Ausschnitt, der eine oben definierte Variable benutzt, so
herauskommt, wie er es an seiner Stelle tun wird.

## Suchen und Ersetzen

**Strg+F** öffnet ein Suchfeld in der Kopfzeile. Der Zähler daneben sagt, wie oft der Text
vorkommt und auf welchem Treffer Sie stehen; **Enter** springt vorwärts, **Umschalt+Enter**
zurück, F3 funktioniert direkt aus dem Dokument. Groß- und Kleinschreibung zählt erst mit dem
Häkchen neben dem Feld — und die Faltung ist die der Maschine selbst, sodass ein kyrillischer
oder akzentuierter Buchstabe genau dort seiner anderen Form entspricht, wo auch die Vorschau
beide für einen Buchstaben hält.

**Strg+H** — oder der Menüpunkt **Ersetzen…** — gibt der Leiste eine zweite Zeile: die
Ersetzung und zwei Schaltflächen. **Ersetzen** ändert den Treffer, auf dem Sie stehen, und
springt zum nächsten; solange noch nichts gefunden ist, sucht der erste Druck nur. **Alle
ersetzen** geht in einem Zug durch das ganze Dokument, und die Statusleiste sagt, wie viele
Stellen sich geändert haben; ein einziges Strg+Z nimmt den ganzen Durchgang zurück.

Die Ersetzung ist wörtlich. Sie darf leer sein — das löscht — und sie darf den gesuchten Text
enthalten, ohne den Durchgang im Kreis zu schicken: die Stellen werden vorab bestimmt, am
Text, wie er war. Überlappen sich Treffer, zählt der Zähler jeden, den ein Schritt besuchen
kann, der Durchgang ändert aber nur die, die sich keine Buchstaben teilen — „ersetzt“ darf
darum ehrlich eine kleinere Zahl nennen.

Ein ersetztes Dokument nimmt denselben Weg durch die Maschine wie getipptes: die Vorschau
wird neu gezeichnet, und die Diagnose antwortet über das, was jetzt dasteht.

## Die Markierungen einfügen

Alles, was die Markierungen dieser Sprache ins Dokument setzt, sammelt das Menü **Einfügen**.

Die drei Einfass-Befehle nehmen die Auswahl, wie sie steht: **In {…} einfassen** macht sie zur Auswahl,
**In […] einfassen** zum Mischen, **In /#…#/ einfassen** (Strg+/) zum Kommentar. Das Einfassen in einen Kommentar lehnt ab, wenn ein `#/` in oder um die Auswahl — oder ein an
dieser Stelle bereits offener Kommentar — einen Kommentar zu früh beenden würde: das erste
Schlusszeichen gewinnt, wo immer es steht, Text fiele heraus; die Statusleiste sagt es, weil die
Maschine schweigt. Ohne Auswahl fügt Strg+/ das Paar ein und lässt die Schreibmarke
darin stehen.

Die Konstrukte darunter landen genau so, wie das Menü sie liest. **#set %name% = Wert**, **#def %name% = {a|b}** und **#include "name"**
nehmen eine eigene Zeile — eine Direktive zählt nur, wenn sie ihre Zeile beginnt, Text vor
der Schreibmarke bleibt also oben und Text danach rückt nach unten — und der Name ist danach
ausgewählt, bereit zum Überschreiben. Namen bleiben in lateinischen Buchstaben: ein Name in
einem anderen Alphabet ist stillschweigend keiner. Die Ausnahme ist das Ziel von `#include` —
es wird buchstabengetreu mit den Fragmentnamen verglichen.

**{?name?dann|sonst}** steht in der Zeile selbst. Mit Auswahl wird der ausgewählte Text zur „dann“-Hälfte —
so wird bereits Geschriebenes bedingt; ohne Auswahl geht die ganze Form hinein. Eine Auswahl mit einem nackten `|`, einer unausgeglichenen Klammer oder einem offenen Kommentar
wird abgelehnt: das Einfassen würde den Sinn ändern statt ihn zu rahmen.

Der letzte Punkt setzt das in der Hilfe geöffnete Beispiel ins Dokument — die Schaltfläche
der Hilfe selbst, von der Tastatur aus erreichbar gemacht.

## Die Tafeln am unteren Rand

Die Werkzeugleiste an der Seite öffnet vier Tafeln, immer eine davon.

**Diagnose** listet auf, was die Maschine beanstandet, jeweils mit Zeile und Spalte des Anfangs.
Ein Klick auf eine Zeile setzt den Cursor dorthin. Das ist dasselbe Urteil, das die Maschine
überall sonst fällt, keine zweite Meinung des Editors — deshalb wird eine Vorlage, die diese
Tafel gültig nennt, auch von den anderen Maschinen angenommen.

**Variablen** zeigt die Namen, die Ihr Dokument definiert, und die, die es nur benutzt. Einen
Namen, den es benutzt und den nichts definiert, können Sie hier für die Sitzung ausfüllen:
Schreiben Sie einen Wert daneben, und die Vorschau nimmt ihn auf. Setzen Sie den Haken bei
**als Text**, wenn der Wert Text ist, der sich selbst meint, und nicht eine kleine Vorlage für
sich.

**Varianten** erzeugt viele Texte auf einmal. Sagen Sie wie viele, erzeugen Sie sie und lesen Sie
sie in der Liste, bevor Sie exportieren. Beinahe-Dubletten lassen sich schon beim Erzeugen
verwerfen, und ein Startwert macht den ganzen Satz wiederholbar: derselbe Startwert und dieselbe
Vorlage geben morgen dieselben Varianten.

Neben diesen Feldern sagt die Tafel, wie viele Varianten die Vorlage überhaupt hergeben kann:
`{a|b} und {c|d}` ergibt vier. Diese Zahl sagt Ihnen, dass eine Vorlage dünn ist, bevor Sie
fünfzig Stück erzeugen und es beim Lesen merken.

Eine genaue Zahl ist es nur, solange jede Wahl dem Zufall überlassen bleibt. Eine Bedingung, eine
Zahlform oder ein `#include`, dessen Ziel der Satz nicht hat, wird von etwas anderem entschieden
— von einem Wert, den Sie liefern, von einer Zahl, von einem Ausschnitt, der noch kommen mag —,
und dann sagt die Tafel **mindestens**. Das ist das ehrliche Wort: einen Wert zu liefern kann
Texte nur hinzufügen, niemals wegnehmen. Eine Zahl, die zum Lesen viel zu groß wäre, hört bei
einer Billion auf und sagt aus demselben Grund **mindestens**.

Eine Variante ist eine ausgefüllte Vorlage — an jedem Konstrukt eine getroffene Wahl —, und das
ist nicht dasselbe wie ein Text, der sich anders liest. `{a|a}` sind zwei Varianten und ein Text,
und zwar mit Absicht: die beiden Möglichkeiten können nach einer einzigen Änderung verschieden
sein, und sie zusammenzuziehen hieße, erst jede Kombination zu erzeugen — also gerade die
Arbeit, die diese Zahl Ihnen ersparen soll. Ein `#def` zählt genauso: die Maschine zieht es
einmal je Durchgang, ob der eingeschlagene Zweig es benutzt oder nicht.

Der Export schreibt sie auf drei Arten heraus: als XLSX-Mappe, als reinen Text mit einer Variante
je Zeile oder als eine Datei je Variante in einem Ordner Ihrer Wahl.

**KI-Entwurf** ist der Anfang einer Vorlage, wenn Sie nicht jede Variante von Hand
schreiben wollen. Beschreiben Sie im Briefing, was Sie brauchen, führen Sie die Variablen auf,
die das Modell verwenden darf, und drücken Sie **Prompt kopieren**. Die Anwendung spricht mit keinem
Modell und hält keinen Schlüssel: sie schreibt den Prompt, damit Sie ihn zu dem Modell tragen,
das Sie ohnehin benutzen. Bringen Sie die Antwort zurück und drücken Sie **In das Dokument einfügen** — die
Maschine in diesem Fenster sagt dann im Diagnosebereich, was sie davon hält, genau wie bei allem
anderen, was Sie selbst tippen. Gibt es Fehler, baut **Reparatur-Prompt kopieren** einen zweiten Prompt: er trägt das ganze Dokument mit nummerierten Zeilen und benennt genau
die Stellen, an denen die Maschine Anstoß nahm. Die Antwort darauf ist das vollständige
korrigierte Dokument — bringen Sie es zurück und drücken Sie **Dokument ersetzen**;
**In das Dokument einfügen** ließe das kaputte stehen und legte eine korrigierte Kopie daneben.

Die Fallspalte ist der Teil, den auszufüllen sich lohnt. Eine Variable wird wörtlich eingesetzt,
nichts beugt sie — in einer Sprache mit Fällen muss der Satz also um die Form herum gebaut
werden, die der Wert schon hat, und ein Modell wählt nur dann richtig, wenn ihm gesagt wird,
welche Form jeder Name trägt. Aus dem Namen ergibt sich das nicht: in einem echten Vorlagensatz
standen die instrumentalen Formen in einer Variablen, deren Name Akkusativ sagte.

## Der Gruppeneditor

Setzen Sie den Cursor in ein `{a|b|c}` und öffnen Sie den Gruppeneditor über die Werkzeugleiste.
Er listet die Alternativen als Zeilen auf: ändern, eine hinzufügen, eine entfernen — und das
Dokument wird passend umgeschrieben.

Er verweigert Änderungen, die verändern würden, was die Gruppe BEDEUTET, statt was sie sagt: ein
in eine Alternative getipptes `|` würde aus einer Möglichkeit zwei machen, und ein `}` würde die
Gruppe zu früh beenden. Wenn er verweigert, sagt er es und lässt das Dokument in Ruhe.

## Einstellungen

Sie stehen im Menü Ansicht, und jede einzelne wird über Sitzungen hinweg behalten: die Sprache
der Oberfläche und ob sie der Vorlage folgt, auf welcher Seite die Werkzeugleiste steht, das
Farbschema, Schrift und Schriftgröße des Editors, ob die Vorschau die Seite oder den Quelltext
zeigt, der Schalter für den GSA-Import, welche Tafel offen ist und die Breiten der Tafeln, die
sich ausfahren.

Die Oberfläche spricht vierzehn Sprachen, gewählt im selben Menü. Das ist getrennt von der
Sprache Ihrer Vorlage, die über die Zahlformen entscheidet und über der rechten Hälfte
eingestellt wird.

## Eine GSA-Vorlage einlesen

Dieses Stück ist aus, bis Sie es einschalten, unter **Ansicht**, **GSA-Import**, weil die
meisten, die Vorlagen schreiben, den GSA Search Engine Ranker nie benutzt haben. Ist es an, liest
**Datei**, **GSA-Vorlage importieren…** eine SER-Vorlage und wandelt sie in diese Sprache um.

Die Umwandlung ist auf eine bestimmte Weise vorsichtig. Was sie nicht getreu ausdrücken kann,
verweigert sie und sagt es Ihnen, statt es still in etwas zu verwandeln, das rendert. Konstrukte,
die im Text falsch gelesen würden — BBCode-Klammern, ein `#` in einem Link, ein `#file[...]`
Makro —, werden in Variablen ausgelagert, und die Zusammenfassung sagt, wie viele.

Zwei Dinge über das Ergebnis:

- **Die ausgelagerten Werte sind Sitzungswerte.** Sie erscheinen in der Tafel Variablen und
  werden nicht mit dem Dokument gespeichert. Speichern Sie die umgewandelte Vorlage, öffnen Sie
  sie morgen, und Sie sehen `%…%` dort, wo der ausgelagerte Text stand. Aus der eingelesenen
  Datei geht nichts verloren — die bleibt unberührt —, aber das umgewandelte Dokument steht
  nicht für sich allein.
- **Es wird ohne den Feinschliff gerendert.** Jedes andere Dokument hier bekommt die
  abschließenden Handgriffe, die der Sprachführer beschreibt; eine umgewandelte Vorlage nicht,
  denn sie ist nicht unser Text zum Glätten. Sie gehört jemand anderem, ist meist auf dem Weg
  zurück zu GSA und muss Zeichen für Zeichen überstehen.

Das eingelesene Dokument ist unbenannt und ungespeichert, wie ein neues. Die Datei, die Sie
ausgewählt haben, bleibt genau so, wie sie war.
