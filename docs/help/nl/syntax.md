# De taal, constructie voor constructie

Een sjabloon is gewone tekst met een paar gemarkeerde plekken erin. Alles wat niet gemarkeerd is
komt er onveranderd uit; de markeringen zijn wat een sjabloon in staat stelt veel teksten op te
leveren.

Het zijn er zes, en dat is de hele taal: een **keuze** tussen alternatieven, een **schudbeurt** van
meerdere stukken, een **macro** die u één keer vastlegt en op naam gebruikt, een **voorwaarde**,
een **telling** die de juiste woordvorm pakt, en een **invoeging** die een ander sjabloon
binnenhaalt. Opmerkingen zijn een zevende markering die helemaal niets oplevert.

> Elk voorbeeld hieronder gaat bij elke bouw van het programma door de machine die deze kopie van
> Studio meebrengt, en rechts staat precies wat zij teruggaf. Niets hier is onthouden of geraden;
> een antwoord dat niet langer klopte zou de bouw stilzetten. De versie van de machine staat onder
> **Help**, **Over**.

Het andere document in deze help, **Wat het tabblad Diagnose u vertelt**, gaat over wat er misgaat.
Dit gaat over wat de constructies doen wanneer er niets misgaat — met inbegrip van de verschillende
plekken waar een sjabloon iets verrassends doet en niets het meldt.

## Hoe de voorbeelden te lezen

De pijl `→` scheidt het sjabloon van wat de machine teruggaf. `(leeg)` betekent dat zij helemaal
niets afdrukte. Tekst na de uitvoer, met drie spaties ervoor, is een aantekening en geen deel van
het antwoord.

De omstandigheden worden genoemd en niet stilzwijgend aangenomen, want zonder ze zou de helft van
de antwoorden hieronder niet te herhalen zijn:

```spx-fixture
locale: nl
seed: 7
empty: (leeg)
include intro: Welkom bij {Acme|Globex}.
include shout: Het %merk% is er.
```

`seed` legt de loting vast. Een sjabloon met een keuze erin heeft geen enkel antwoord, dus een
voorbeeld zonder startgetal zou bij elke doorgang iets anders afdrukken en er viel niets te
controleren. In het venster is het het vakje **Startgetal** boven de rechterhelft; vink het aan en
er verschijnt een getalveld naast, en de voorvertoning staat stil terwijl u werkt.

`locale` bepaalt de getalsvormen, en het is de keuzelijst boven de rechterhelft, niet de taal van
de interface. Het Nederlands en het Engels vragen twee vormen; het Russisch, het Oekraïens, het
Wit-Russisch, het Servisch, het Kroatisch en het Bosnisch vragen er drie.

## Keuzes

Accolades met `|` ertussen: de machine pakt er **één**.

```spx-good
Een {kleine|grote} kamer.  →  Een kleine kamer.
```

De trekking is willekeurig, dus hetzelfde sjabloon geeft bij een andere doorgang `Een grote
kamer.` De keuze zelf laat de tekst eromheen met rust — al reikt de afwerking die tegen het einde
van dit document wordt beschreven er wel toe.

### Nesting

Een keuze kan een andere bevatten, tot elke diepte.

```spx-good
Acme {Pro {Plus|Max}|Lite}  →  Acme Pro Plus
```

De binnenste keuze wordt alleen gemaakt als de buitenste de tak pakt waarin hij staat: valt `Lite`,
dan wordt `Plus|Max` nooit geraadpleegd — en, meetbaar, er wordt niet eens een willekeurig getal
voor gevraagd.

### Een lege mogelijkheid

Een mogelijkheid mag leeg zijn. Het is de gewone manier om iets slechts af en toe te laten
verschijnen.

```spx-good
Een {|heel }grote kamer.  →  Een grote kamer.
```

De spatie in de mogelijkheid schrijven, `{|heel }` in plaats van `{|heel} `, is gewoonte en geen
voorschrift: de afwerking trekt de dubbele spatie hoe dan ook samen.

## Schudbeurten

Vierkante haken pakken meerdere stukken, kiezen hoeveel, zetten ze in willekeurige volgorde en
voegen ze samen.

```spx-good
[rood|groen|blauw]  →  Groen blauw rood
```

Aan zichzelf overgelaten pakt hij ze allemaal en voegt ze met één spatie samen. Al het overige over
een schudbeurt wordt vastgelegd in een `<…>`-blok direct achter de openende haak.

### Het scheidingsteken

```spx-good
[<, >rood|groen|blauw]  →  Groen, blauw, rood
```

Een `<…>`-blok is zelf het scheidingsteken, tenzij het **een instelling noemt**: een van `sep`,
`lastsep`, `minsize` of `maxsize`, als eigen woord en met een `=` erachter. Al het overige op die
plek is een scheidingsteken, hoezeer het ook op een instelling lijkt — een sleutel zonder zijn `=`:

```spx-good
[<maxsize 2>rood|groen|blauw]  →  Groenmaxsize 2blauwmaxsize 2rood
```

of een sleutel waar vooraan iets aan vastgeplakt zit:

```
[<xmaxsize=1>rood|groen|blauw]  →  Groenxmaxsize=1blauwxmaxsize=1rood
```

De tweede verdient een tweede blik: het paneel noemt `xmaxsize` **wel degelijk** een onbekende
sleutel, en de machine drukt het hele blok toch tussen de stukken af. De diagnose en de uitvoer
beantwoorden verschillende vragen.

Schrijf de instellingen voluit wanneer u twee verschillende scheidingstekens wilt:

```spx-good
[<sep=", ";lastsep=" en ">rood|groen|blauw]  →  Groen, blauw en rood
```

`sep` gaat tussen de stukken en `lastsep` voor het laatste.

### Hoeveel

```spx-good
[<minsize=2;maxsize=2>rood|groen|blauw]  →  Groen blauw
```

`minsize` is de vloer en `maxsize` het plafond; het aantal ertussen is willekeurig, net als de
volgorde. Gelijke waarden pakken er precies zoveel. **Zonder allebei alle, maar met alleen
`maxsize` ligt de vloer op één**, wat mensen verrast:

```spx-good
[<maxsize=3>a|b|c]  →  C
```

Drie stukken, een plafond van drie, en er kwam er één uit. Schrijf ook `minsize` wanneer u «alle,
hoogstens drie» bedoelt. Een `maxsize` boven het aantal stukken wordt stilletjes tot dat aantal
verlaagd. Een `minsize` boven de `maxsize` wordt zonder een woord aanvaard, en de vloer wint: het
plafond wordt naar hem opgetrokken en niet andersom:

```spx-good
[<minsize=3;maxsize=1>rood|groen|blauw]  →  Groen blauw rood
```

### Een scheidingsteken tussen twee stukken

Een `<…>` dat **tussen** twee stukken wordt geschreven, is het scheidingsteken van dat paar.

```spx-good
[rood|groen<en>|blauw]  →  Groen en blauw rood
```

Het hoort bij het stuk **erna** en reist met dat stuk door de schudbeurt mee, dus het duikt op waar
dat stuk terechtkomt en niet op een vaste plek in de uitvoer. Een `<…>` na het **laatste** stuk is
helemaal geen scheidingsteken en wordt als tekst afgedrukt:

```spx-good
[rood|groen|blauw<en>]  →  Groen blauw<en> rood
```

## Macro's

`#set` geeft een stuk tekst een naam. De naam wordt als `%naam%` gebruikt, en de aanwijzing moet
het eerste op haar regel zijn — spaties en tabs ervoor mogen, verder niets.

```spx-good
#set %stad% = Utrecht
Vlucht naar %stad%.  →  Vlucht naar Utrecht.
```

Namen bestaan uit Latijnse letters, cijfers en `_`. Een naam in een ander alfabet is geen naam,
waarover het andere document spreekt onder `set.malformed`. Een trema of accent hoort dus niet in
een naam; in een waarde wel.

### `#set` loot opnieuw, `#def` loot één keer

Dat is het hele verschil tussen de twee, en het blijkt alleen wanneer de waarde een keuze bevat.

```spx-good
#set %keuze% = {A|B}
%keuze% %keuze% %keuze%  →  A A B
```

```spx-good
#def %keuze% = {A|B}
%keuze% %keuze% %keuze%  →  A A A
```

Beide voorbeelden liepen onder hetzelfde startgetal. `#set` bewaart het sjabloon en loot het bij
elk gebruik; `#def` loot één keer en houdt het antwoord. Gebruik `#def` voor iets dat met zichzelf
moet overeenstemmen — een merk, een stad, een naam, een aantal — en `#set` voor afwisseling.

Eén startgetal kan de twee niet uit elkaar houden: er zijn startgetallen waarbij `#set` toevallig
drie keer dezelfde mogelijkheid pakt en de twee er gelijk uitzien. Goed om te weten voordat u uit
één voorvertoning concludeert dat een vastlegging niet werkt.

## Voorwaarden

`{?naam?dan|anders}` vraagt of een macro een waarde heeft.

```spx-good
#set %n% = 5
{?n?we hebben %n%|nog niets}  →  We hebben 5
```

De helft `anders` mag ontbreken — `{?naam?dan}` drukt niets af wanneer het antwoord nee is. Een `!`
draait de vraag om:

```spx-good
#set %vip% = 1
{?!vip?vreemde|vriend}  →  Vriend
```

Een waarde hebben betekent **ten minste één teken hebben dat geen spatie is**. Een macro die op
niets is gezet, of alleen op spaties, telt als zonder waarde.

De naam van een voorwaarde moet met een letter of `_` **beginnen**, wat strenger is dan bij een
macro — en het hoofdstuk over de stiltes zegt waarin een naam verandert die met een cijfer begint.

## Telling

`{plural %n%: …}` pakt de woordvorm die bij een getal hoort.

```spx-good
#def %n% = 1
%n% {plural %n%: bestand|bestanden}  →  1 bestand
```

```spx-good
#def %n% = 5
%n% {plural %n%: bestand|bestanden}  →  5 bestanden
```

De telling is hier met opzet een `#def` en geen `#set`, en de regel is het bewaren waard: **maak
van de telling een gewoon cijfer of een `#def`, nooit een `#set`.** Wat vanuit een `#set` op de
plek van de telling aankomt is de bewaarde TEKST, `{5|5}` en niet `5` — dus geen getal — waardoor
de hele constructie niets oplevert en het paneel `plural.count-macro` zegt. De telling en de vorm
kunnen elkaar niet tegenspreken: in plaats daarvan verdwijnt het woord.

```
#set %n% = {5|5}
%n% {plural %n%: bestand|bestanden}  →  5
```

Hoeveel vormen er zijn bepaalt de locale en niet u: onder `nl` zijn het er twee, onder `ru` drie.
Het verkeerde aantal is een fout die het paneel meldt (`plural.arity`), en de machine drukt dan de
hele constructie terug af met de accolades vervangen door brede `｛｝`, zodat men het niet voor
uitvoer aanziet.

## Fragmenten

`#include "naam"` zet op die plek een ander sjabloon neer, en de aanwijzing moet het eerste op haar
regel zijn — ook hier mogen spaties en tabs ervoor.

```spx-good
#include "intro"  →  Welkom bij Acme.
```

Het fragment wordt als eigen sjabloon weergegeven, dus een keuze erin wordt opnieuw gemaakt:
`intro` bevat `{Acme|Globex}` en antwoordt met de een of de ander.

De naam wordt **precies** vergeleken. `Intro` en `intro` zijn twee verschillende fragmenten, en
onder Windows is dat gemakkelijk mis te hebben omdat het het bestandssysteem niets kan schelen. Een
ontbrekend doel geeft niets weer en het paneel zegt `include.unknown-target`; een doel dat alleen
in hoofdletters verschilt krijgt een Studio-aantekening met de naam die u waarschijnlijk bedoelde.

### Een fragment ziet uw macro's niet

Het wordt als eigen sjabloon weergegeven: het heeft de waarden van de sessie, maar niet de `#set`
en `#def` van het document dat het binnenhaalde.

```
#set %merk% = Acme
#include "shout"  →  Het %merk% is er.
```

`shout` is `Het %merk% is er.`, en de naam moet in het fragment zelf worden vastgelegd. Dit is geen
stilte — het paneel zegt wel degelijk `variable.undefined` — maar het zegt het tegen **`shout`**,
op regel 1 van dat bestand, en in het document waar u naar kijkt verschijnt geen kringellijn, omdat
de positie bij een andere buffer hoort. Lees de kolom **Bestand** wanneer een waarschuwing over een
regel lijkt te gaan die u niet hebt geschreven.

## Opmerkingen

`/# … #/` is een opmerking: alles tussen de tekens wordt verwijderd voordat er iets anders gebeurt.

```spx-good
concept /# nog niet zeker #/ klaar  →  Concept klaar
```

Opmerkingen nesten niet. De eerste `#/` sluit de opmerking, wat er ook voor stond, dus een
opmerking om een tekst heen die zelf `#/` bevat eindigt eerder dan hij eruitziet.

## Wat de machine op het eind gladstrijkt

De uitvoer is niet helemaal de tekst die de constructies opleverden. Op het eind overkomt haar het
een en ander; twee dingen komt u dagelijks tegen.

De eerste letter van elke zin wordt een hoofdletter:

```spx-good
een. twee. drie.  →  Een. Twee. Drie.
```

Daarom antwoorden de voorbeelden in deze help zo vaak met een hoofdletter waar het sjabloon een
kleine letter heeft. Een punt na een afkorting die de machine kent beëindigt geen zin, en evenmin
doet iets dat de vorm van `e.g.` of `U.S.` heeft dat — **in Latijnse letters**, wat een echte grens
is en geen slag om de arm: de controle «zitten we midden in een woord» is een ASCII-controle.

```spx-good
Dr. onze prijzen zijn laag  →  Dr. onze prijzen zijn laag
```

```spx-good
o.a. dit blijft klein  →  o.a. dit blijft klein
```

Elk ander woord beëindigt een zin, hoe kort ook — met lengte heeft het niets te maken:

```spx-good
Xyz. onze prijzen zijn laag  →  Xyz. Onze prijzen zijn laag
```

De lijst die de machine kent heeft 46 ingangen, **29 daarvan Cyrillisch**, en het andere document
loopt hem langs onder **Een stilte in elke taal**. Voor Nederlandse tekst staat het belangrijkste
verderop bij de stiltes: de lijst is niet op het Nederlands ingesteld.

Het tweede alledaagse is dat reeksen spaties tot één samenvallen. Dat is wat u een lege
mogelijkheid laat staan zonder de spaties eromheen te tellen.

De rest in één adem: een spatie voor `,;:!?.` valt weg en er wordt er een achter gezet; de hele
uitvoer wordt aan de randen bijgesneden; de hoofdletter komt ook na een regeleinde en na een
bloktag, niet alleen na een punt; en adressen met schema, e-mailadressen, kale domeinen en
decimale getallen zijn beschermd en komen er precies uit zoals ze zijn getypt.

Voor dat laatste geldt dezelfde ASCII-grens als voor de afkortingen hierboven. Een kaal domein is
beschermd als het in Latijnse letters is geschreven; `сайт.рф` is dat niet, en de afwerking zet er
een spatie en een hoofdletter in.

```spx-good
hallo , wereld  →  Hallo, wereld
```

```spx-good
een.twee  →  een.twee
```

## Stiltes

Elk geval hieronder geeft weer, levert iets anders op dan het eruitziet en trekt **geen enkele
diagnose**. Ze staan hier bijeen omdat niets anders in het venster ze ooit zal noemen.

**De Nederlandse afkortingen staan niet in de lijst van de machine.** Het is de stilte waar
Nederlandse schrijvers als eerste tegenaan lopen. Beschermd zijn alleen de woorden die met de
Latijnse helft van de lijst samenvallen — `Dr.` en `Prof.` hierboven —, terwijl `Dhr.`, `nr.`,
`blz.`, `bijv.` en `bv.` een zin beëindigen en het volgende woord een hoofdletter geven:

```spx-good
bijv. dit blijft klein  →  Bijv. Dit blijft klein
```

De vormen met meerdere punten hebben er geen last van: `o.a.` en `a.u.b.` gaan door de regel voor
meerdere punten en blijven onaangeroerd. Voor de losse woorden helpt alleen herformuleren of de
punt vermijden.

**Een `#include` dat niet alleen op zijn regel staat is gewone tekst.**

```spx-good
Ervoor. #include "intro"  →  Ervoor. #include "intro"
```

Hetzelfde geldt voor een aanwijzing met iets erachter en voor `#include"intro"` zonder spatie. De
regel is die van de familie en niet die van deze machine, en zij is het die een aanwijzing
herkenbaar maakt zonder de hele regel te ontleden.

**Een voorwaarde waarvan de naam met een cijfer begint is geen voorwaarde.** Zij wordt een gewone
keuze tussen `?1x?ja` en `nee`:

```spx-good
{?1x?ja|nee}  →  ?1x? Ja
```

**Een `<…>` aan het hoofd van een later stuk is geen scheidingsteken** en wordt afgedrukt zoals het
er staat:

```spx-good
[rood|<en>groen]  →  <en>Groen rood
```

Het blok aan het hoofd van het **eerste** stuk is wél het scheidingsteken — dat is de schrijfwijze
waarmee het hoofdstuk over schudbeurten opent:

```spx-good
[<en>rood|groen]  →  Groen en rood
```

Overal na een `|` is het gewone tekst, en een scheidingsteken tussen twee stukken hoort aan het
**einde** van het eerste.

**Een kale tag aan het einde van een stuk wordt voor het scheidingsteken van dat paar aangezien**
en als eigen tekst afgedrukt:

```spx-good
[een<br>|twee]  →  Twee een
```

Onder dit startgetal vielen de twee in de andere volgorde, dus het scheidingsteken kwam er
helemaal niet uit. Met een derde stuk is er plaats voor, en het verschijnt:

```spx-good
[rood|groen<br>|blauw]  →  Groen br blauw rood
```

Het `<br>` staat tussen `groen` en wat erop volgt, waar de schudbeurt dat paar ook neerzet. Een
sluitende tag (`</b>`), een zelfsluitende (`<br/>`), een met attributen (`<br class="x">`) en een
tag midden in een stuk blijven allemaal onaangeroerd.

**Een niet-gesloten opmerking is gewone tekst** — hij opent niets, en de `/#` wordt afgedrukt:

```spx-good
ervoor /# de rest hiervan  →  Ervoor /# de rest hiervan
```

Maar hij is nog altijd de helft van een paar. Verschijnt er verderop in het document een `#/`, dan
vinden de twee elkaar en gaat alles ertussen weg — met inbegrip van wat de schrijver ertussen
schreef:

```
{a /# oeps|b} midden #/ staart  →  {a staart
```

De keuze hierboven verloor haar tweede alternatief en haar sluitende accolade, en geen diagnose
zegt het: dit is wat de tekst BETEKENT, en geen fout die de machine kan zien. Wanneer een `/#`
letterlijk is bedoeld, is de veilige plek ervoor de waarde van een variabele en niet de romp van
het sjabloon.

## Waar hierna te kijken

Het andere document, **Wat het tabblad Diagnose u vertelt**, heeft één artikel per regel die het
paneel kan tonen — wat zij betekent, wat haar veroorzaakt en wat de machine met het sjabloon doet
zolang zij er staat. Druk op F1 met de cursor in een constructie en de help opent bij het hoofdstuk
van die constructie **in dat document**: een accolade bij **Haken**, een `[…]` bij
**Schudbeurten**, een `#set`-regel bij **Vastleggingen**.
