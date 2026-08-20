# Wat het tabblad Diagnose u vertelt

Elke regel in dat tabblad is een oordeel van de **machine**, en hetzelfde oordeel dat u van de
JavaScript-, PHP- of Python-uitvoering zou krijgen — vier zelfstandige machines die aan één
gedeeld corpus worden gehouden. Het is niet Studio's mening over uw sjabloon. Noemt de machine hier
iets een fout, dan noemt elke andere machine van de familie het ook een fout, en uw sjabloon zal
zich op uw server gedragen als in dit venster.

| wat er staat | wie het zegt | wat het betekent |
|---|---|---|
| **fout** | de machine | het sjabloon doet niet wat het lijkt te doen |
| **waarschuwing** | de machine | het geeft weer, maar waarschijnlijk niet zoals bedoeld |
| **Studio-aantekening** | Studio | de machine zei niets, en het is toch het zeggen waard: een invoeging in een cirkel, een doel met andere hoofdletters, een stuurteken |

De kolom **Waar** is regel en kolom. Een klik op de regel zet de cursor daar.

> Elk voorbeeld hieronder gaat bij elke bouw van het programma door de machine die deze kopie van
> Studio meebrengt, en rechts staat precies wat zij teruggaf. Niets hier is onthouden of geraden;
> een antwoord dat niet langer klopte zou de bouw stilzetten. De versie van de machine staat onder
> **Help**, **Over**.

## Hoe de voorbeelden te lezen

De pijl `→` scheidt het sjabloon van wat de machine teruggaf. `⏎` is een regeleinde binnen een
uitvoer, `(leeg)` betekent dat zij helemaal niets afdrukte, en `…` markeert een uitvoer die te lang
is om volledig te tonen. Tekst na de uitvoer, met drie spaties ervoor, is een aantekening en geen
deel van het antwoord.

De omstandigheden waaronder de voorbeelden liepen staan hier en niet verstopt in de tests — zonder
ze zijn sommige antwoorden niet te herhalen. De verzameling sjablonen telt het zwaarst: anders zou
`#include "frag"` → `Fragment` rusten op iets dat dit document nooit zegt.

```spx-fixture
locale: nl
seed: 7
empty: (leeg)
include frag: Fragment
include loop: #include "loop"
include Intro: Inleiding
```

`seed` legt de loting vast: zonder hem zou een keuze of een schudbeurt elke keer anders antwoorden
en viel er niets te controleren.

**De locale is hier `nl`, en zij bepaalt twee dingen:** hoeveel getalsvormen de machine verwacht en
welke vorm bij welk getal hoort. Het Nederlands en het Engels vragen er twee. Het Russisch, het
Oekraïens, het Wit-Russisch, het Servisch, het Kroatisch en het Bosnisch vragen er drie. De locale
komt van de keuzelijst boven de rechterhelft, niet van de taal van de interface.

---

## Haken

**Zet de cursor op een haak en de constructie toont zich in haar geheel:** waar zij begint, waar
zij eindigt, en **elk van haar scheidingstekens**. Geneste groepen lichten niet mee op — die hebben
eigen scheidingstekens, en die komen wanneer de cursor op hun haak staat. Het is de snelste manier
om te zien waar eindigt wat u bewerkt, vooral in een lange regel waar de `}` twee schermen naar
rechts is verdwenen.

Een scheidingsteken is niet alleen `|`. In een schudbeurt heeft `[a<br>|b]` er twee: de machine
leest `<br>` als scheidingsteken dat **voor het volgende** stuk staat, en de markering toont het
samen met de rest, omdat het deel uitmaakt van hoe de constructie gebouwd is.

### `bracket.unclosed` — een haak wordt geopend en nooit gesloten

```
een prijs {laag|hoog  →  Een prijs {laag|hoog
```

De machine raadt niet waar u wilde sluiten. De tekst blijft zoals hij is, accolade en al, en de
keuze vindt nooit plaats.

### `bracket.mismatched` — gesloten door een haak van een andere soort

```
een prijs {laag|hoog]  →  Een prijs {laag|hoog]
```

`{` wacht op `}` en `[` wacht op `]`. Een schudbeurt die door een accolade wordt gesloten is geen
schudbeurt.

### `bracket.unexpected-closing` — een sluitende haak zonder iets open

```
een prijs laag} en alles  →  Een prijs laag} en alles
```

Hij blijft er als tekst staan. Meestal is het een haak die van een wijziging is overgebleven.

---

## Vastleggingen

### `set.malformed` — deze `#set`-regel volgt de regel niet

```
#set stad = Utrecht
in %stad%  →  #set stad = Utrecht ⏎ In %stad%
```

**De naam hoort tussen procenttekens:** `#set %stad% = Utrecht`. Het is de meest voorkomende eerste
fout, en hij zet meteen twee regels in het paneel — de misvormde regel zelf en «deze variabele is
nergens vastgelegd», want er is geen vastlegging gebeurd en `%stad%` is van niemand.

Kijk naar de uitvoer: de mislukte aanwijzing bleef **zoals geschreven** in de tekst staan. De
machine las hem niet als aanwijzing, dus is het een gewone regel en komt hij in het resultaat.

### `def.malformed` — deze `#def`-regel volgt de regel niet

```
#def paginas = {1|3}
%paginas%  →  #def paginas = 1 ⏎ %paginas%
```

Dezelfde regel en dezelfde prijs. `#def` verschilt van `#set` niet in de schrijfwijze maar in
**wanneer** de waarde wordt uitgevouwen: `#set` vouwt hem bij elke vermelding opnieuw uit, `#def`
één keer per weergave. Een schrijffout kost u beide.

En kijk goed: de `{1|3}` in de mislukte aanwijzing **heeft een mogelijkheid getrokken**. De regel
werd gewone tekst — en gewone tekst wordt weergegeven als gewone tekst, accolades en al. Een
misvormde regel staat niet uit; hij houdt alleen op een aanwijzing te zijn.

### `definition.duplicate-name` — deze naam is hierboven al vastgelegd

```
#set %x% = eerste
#set %x% = tweede
%x%  →  Tweede
```

Het werkt — de **laatste** vastlegging wint — maar de machine noemt het een fout: een document
waarin een naam twee keer wordt gezet leest dubbelzinnig, en over een maand weet u niet meer welke
van de twee regels de levende is. De fout wijst de **tweede** vastlegging aan; de eerste staat
hoger.

### `def.include-in-value` — `#include` in de waarde van een vastlegging

```
#def %x% = #include "frag"
%x%  →  Fragment
```

Een invoeging in een waarde vouwt zich op een ander moment uit dan u zou verwachten, en de familie
verbiedt het. Zet het `#include` op een eigen regel.

---

## Variabelen

### `variable.undefined` — deze variabele is nergens vastgelegd

```
hallo, %naam%  →  Hallo, %naam%
```

Een waarschuwing en geen fout: de machine drukt de naam af zoals hij er staat. Dat is met opzet —
de waarde kan van buiten komen, van het gastprogramma. In Studio levert u zulke waarden aan op het
tabblad Variabelen, onder **Sessiewaarden**.

**De waarde van een vastlegging is in het paneel te wijzigen.** Ga in het bovenste deel op de kolom
Waarde staan en druk op **F2** (of begin gewoon te typen); **Enter** past toe, **Esc** laat het
varen. De wijziging gaat **het document in**, in één stap ongedaan maken: `Ctrl+Z` zet haar terug.

De naam en de soort (`#set` of `#def`) zijn niet te wijzigen — een besluit, geen onafgemaakte hoek.
Vanuit een cel hernoemen breekt elke vermelding van de variabele in het document, en de regel
verwijderen zou de opmerking en de inspringing meenemen. Beide horen in de tekst thuis, waar u ziet
wat u doet.

Precies de waarde verandert. De inspringing, de extra spaties, de hoofdletters van de naam en een
opmerking aan het einde van de regel blijven zoals ze waren:
`   #set  %Merk%   =   Acme   /# rest #/` komt uit een wijziging terug en verschilt alleen in
`Acme`. Het bestand staat in git, en een regel opnieuw opmaken zou daar als uw wijziging
verschijnen.

**Een weigering betekent dat de machine de regel anders zou lezen.** De wijziging wordt niet
stilzwijgend toegepast: de machine leest het resultaat terug, en zegt het niet wat er gevraagd
werd, dan blijft het document met rust en zegt de statusbalk het. Drie echte oorzaken: een `/#` in
de waarde opent een opmerking die de rest van het bestand opeet, een regeleinde beëindigt de
aanwijzing te vroeg, en een opmerking **in** de aanwijzing maakt de regel niet stuksgewijs
wijzigbaar — die wijzigt u in de tekst.

**Twee gebaren op de naam van een variabele.** De naam in het paneel is een verwijzing en geen
etiket:

- **een klik op de naam** brengt de cursor naar de eerste plek waar het document die variabele
  gebruikt, en de regel licht even op. Datzelfde woord in een opmerking of als doel van een
  `#include` telt **niet** — het paneel brengt u waar de variabele echt werkt.
- **Ctrl+klik** schrijft een vastlegging in het document en opent er de groepseditor op. De waarde
  die u al hebt getypt trekt er als eerste mogelijkheid in:

```
#set %merk% = {Vulkan}
casino %merk%  →  Casino Vulkan
```

Het verschil tussen de twee is wat het sluiten van het venster overleeft. Een sessiewaarde niet:
die staat niet in het bestand, niet in git, en geen andere machine van de familie ziet haar. Een
vastlegging wel, en alleen een vastlegging brengt deze waarschuwing voorgoed tot zwijgen. Eén
`Ctrl+Z` zet het document terug.

**Een sessiewaarde is eerst een sjabloon en geen tekst.** Dat is wat de machine met elke waarde van
het gastprogramma doet, en de voorvertoning moet met de server overeenkomen — dus `{laag|hoog}`
getypt in het waardeveld geeft een keuze en niet die tekens. Bedoelde u de tekst zelf, vink dan
**als tekst** aan in de derde kolom: dan blijven accolades en procenttekens tekens.

### `variable.self-reference` — de vastlegging noemt zichzelf

```
#set %x% = a %x% b
%x%  →  A a a … %x% … b b b
```

Vijftig niveaus, dan stoppen. De machine vouwt uit tot de dieptegrens en houdt op, met `%x%` in het
midden. Geen lus, en ook niet wat u wilde.

De `…` hierboven is de afkorting van dit document en niet die van de machine. De echte uitvoer is
207 tekens lang en draagt aan elke kant **eenenvijftig** letters in plaats van vijftig: het
vijftigste niveau stopt en laat de waarde staan zoals hij is, en de waarde bevat er van elk één
meer.

### `variable.circular-reference` — de vastleggingen noemen elkaar in een cirkel

```
#set %x% = %y%
#set %y% = %x%
%x%  →  %y%
```

Elke kant vouwt zich precies **één keer** uit en houdt dan op: `%x%` werd `%y%` en niet `%x%`. De
machine rolt de cirkel af in plaats van hem rond te gaan, en wat overblijft is de andere naam uit
de cirkel — zet `%x% %y%` in een document en het geeft `%y% %x%`, het paar omgedraaid.

Het paneel tekent één regel voor **elke gedefinieerde naam van waaruit de cirkel bereikbaar
is**, niet één regel voor de cirkel en niet één per vermelding. De cirkel twee keer op één
regel noemen verdubbelt de regel niet: `#set %x% = %y% %y%` tegenover `#set %y% = %x%` zijn
twee fouten, één per regel — net als het gewone paar.

**Een naam die alleen maar naar de cirkel leidt, wordt ook gemeld**, en dat is het deel dat
verrast: een keten van definities die een cirkel van twee namen voedt, tekent een regel voor
elke schakel van de keten, en niet twee regels voor de cirkel alleen. Een naam die ALLEEN naar
zichzelf verwijst is een andere fout — `variable.self-reference` — maar een definitie die
zichzelf noemt **én** een cirkel bereikt, tekent ze allebei: `#set %s% = %s% %c1%` boven een
cirkel van twee namen is één zelfverwijzing en drie cirkelregels, waarvan één op diezelfde
regel. En de positie ligt op de definitie die echt geldt: staat de naam twee keer gedefinieerd,
dan is dat de **laatste**.

---

## Invoegingen

### `#include` werkt alleen aan het begin van een regel

```
ervoor #include "frag" erna  →  Ervoor #include "frag" erna
```

```
#include "frag"  →  Fragment
```

Geen diagnose, en dat is nu juist het punt: een `#include` midden in een regel is **geen**
invoeging. De machine leest het als gewone tekst en zegt niets, want er valt niets te klagen — u
schreef tekst en kreeg tekst.

**Het doel mag echter een regel lager staan**, en dat verrast van de andere kant. De ruimte die de
machine tussen het woord en zijn doel toestaat omvat regeleindes, dus dit is een invoeging en zij
werkt:

```spx-good
#include
"frag"  →  Fragment
```

Lege regels ertussen mogen ook. Al het overige mag niet: een woord vóór het doel of iets anders dan
spaties erachter, en het geheel is weer tekst. De editor kleurt het doel op zijn eigen regel maar
laat het woord gewoon tot het doel is gekomen: hij belooft geen aanwijzing waarvan hij het einde
nog niet ziet.

### `include.unknown-target` — geen doel met die naam in de verzameling

```
#include "geen"  →  (leeg)
```

Doelen zijn de `.spintax`-bestanden in de map van het geopende document. Een onbekend doel vouwt
zich uit tot niets — de alinea verdwijnt in plaats van kapot te gaan, en dat is precies waarom het
zo gemakkelijk te missen is.

**Daarom heeft het tabblad Variabelen een derde afdeling, «Includes».** Zij somt elk `#include`
van het document op en, voor elk, of de verzameling zijn doel heeft — één regel per voorkomen, dus
een twee keer genoemd doel zijn twee regels. De afdeling verschijnt alleen als het document
invoegingen heeft. Een klik op een regel brengt de cursor naar het `#include` dat dat doel noemt.

De markering heeft **drie** waarden, en de derde telt: «geen verzameling» betekent niet «het
fragment ontbreekt», maar «er is nog nergens te kijken». De verzameling is de map naast het
document, en een niet-bewaard document heeft geen map — tot de eerste keer bewaren is elk doel dus
zo gemarkeerd. «ONTBREEKT» verschijnt alleen wanneer er een map is en het bestand er werkelijk niet
in zit.

### `note.case-mismatch` — het doel bestaat, met andere hoofdletters

```
#include "intro"  →  (leeg)
```

De verzameling bevat `Intro.spintax` — en de machine zegt toch dat er geen doel met die naam is,
terwijl Studio zijn aantekening over de hoofdletters toevoegt. Die tellen: `intro` en `Intro` zijn
verschillende doelen. Windows zou het bestand in beide gevallen openen, en juist daarom kijkt
Studio in de verzameling en niet in het bestandssysteem: anders zou de voorvertoning de server over
hetzelfde document tegenspreken.

### `note.cycle` — een invoeging in een cirkel

Bevat `loop.spintax` zelf `#include "loop"`, dan:

```
#include "loop"  →  (leeg)
```

De machine zet niets neer in plaats van oneindigheid. De aantekening is er zodat u weet waarom de
alinea verdampte.

De regel staat op naam van **`loop`** en niet van het document waar u naar kijkt — de cirkel is die
van het fragment, en daar gaat de cursor bij het klikken heen. In het geopende document is niets
onderstreept, want aan de regel die u schreef mankeert niets.

---

## Getalsvormen

### `plural.arity` — niet zoveel vormen als de locale vraagt

```
#set %n% = 5
%n% {plural %n%: ding|dingen|dingens}  →  5 ｛plural 5: ding|dingen|dingens｝
```

**Geen leegte — de machine drukt de hele constructie af**, met de accolades vervangen door brede
`｛｝`. Zo zegt zij «ik heb dit gezien en kon het niet toepassen». Onopvallend zou niemand dat
noemen, en maar goed ook: een in stilte verdampte alinea zou meer tijd kosten om te vinden.

Het Nederlands vraagt twee vormen, het Russisch drie. Onder de locale van dit document is
`{plural %n%: ding|dingen}` de juiste.

**Leegte komt door iets anders, en de twee zijn gemakkelijk te verwarren.** Vergelijk deze twee,
die alleen verschillen in hoeveel vormen ze dragen:

```
{plural %n%: ding|dingen}  →  (leeg)   twee vormen: juist voor het Nederlands
{plural %n%: ding|dingen|dingens}  →  (leeg)   drie vormen: onjuist voor het Nederlands
```

Beide drukken niets af, en het paneel behandelt ze verschillend: de eerste trekt alleen
`variable.undefined`, de tweede trekt ook `plural.arity`. Dus **leegte is niet het kenmerk van een
fout in het aantal vormen** — zij komt hier doordat `%n%` niet is vastgelegd, en de machine
controleert de telling voordat zij de vormen telt, en houdt dus op voordat de vraag naar het aantal
zich stelt.

Daarom legt het voorbeeld boven aan dit artikel `%n%` eerst vast. Zonder dat zou de uitvoer bij elk
aantal vormen leeg zijn en over het aantal helemaal niets tonen.

Het paneel en de uitvoer beantwoorden hier verschillende vragen, en dat is geen tegenspraak:
de regel wordt gezet door de **controle**, die de vormen telt die het renderen echt zal
splitsen — een definitie die voor hen instaat wordt eerst opgelost; de leegte komt van het
**renderen**, dat een eigen volgorde heeft. Geef de teller een cijfer, zoals het eerste
voorbeeld doet, en u ziet wat het aantal vormen werkelijk doet.

### `plural.count-macro` — de telling komt uit een `#set`, en die loot bij elke vermelding opnieuw

```
#set %n% = {1|2}
%n% {plural %n%: ding|dingen}  →  1
```

Kijk wat er overbleef: **het getal werd afgedrukt en het zelfstandig naamwoord niet.** De telling
moet een getal zijn wanneer de vorm wordt gekozen, en een `#set` waarvan de waarde zelf een keuze
is wordt er nooit een — de machine zet de waarde neer **zonder haar weer te geven**, zodat op de
plek van de telling de letterlijke tekst `{1|2}` belandt. De telling en de vorm kunnen elkaar niet
tegenspreken; de machine laat in plaats daarvan het woord vallen.

`#def` gedraagt zich anders en vouwt zijn waarde één keer per weergave uit, zodat de plek van de
telling een getal krijgt:

```
#def %n% = {1|2}
%n% {plural %n%: ding|dingen}  →  1 ding
```

Voor die is er helemaal geen regel in het paneel. Vandaar de regel: maak van de telling een gewoon
cijfer of een `#def`, nooit een `#set`.

### `plural.nested-brackets` — haken binnen de vormen

```
{plural %n%: {ding|zaak}|dingen}  →  ｛plural %n%: ｛ding|zaak｝|dingen｝
```

Vormen zijn eenvoudige tekst. Een keuze erin wordt niet uitgevouwen, en in plaats daarvan wordt de
hele constructie tussen brede accolades afgedrukt.

---

## Schudbeurten

### `permutation.unknown-key` — onbekende sleutel in de instelling

```
[<foo=1>a|b|c]  →  Bfoo=1cfoo=1a
```

De bekende sleutels zijn `minsize`, `maxsize`, `sep` en `lastsep`. Een onbekende is geen
instelling — en wanneer hij het enige in het blok is, is het hele blok helemaal geen instelling:
het wordt het scheidingsteken tussen de stukken, wat de uitvoer laat zien.

**Staat er een echte sleutel naast, dan is de afloop volstrekt anders**, en dat is de
waarschijnlijkere fout — één van meerdere sleutels verkeerd getypt:

```
[<sep=", ";foo=1>a|b|c]  →  B, c, a
```

Het blok is een instelling, `sep` wordt opgevolgd, de onbekende sleutel simpelweg laten vallen, en
het paneel zegt er in beide gevallen hetzelfde over. De diagnose vertelt u dus dat een sleutel niet
begrepen is; zij vertelt u niet wat er daarna gebeurde. Lees daarvoor de uitvoer.

### `permutation.minsize-not-integer` — minsize is geen heel getal

```
[<minsize=twee>a|b|c]  →  B c a
```

Een niet-numerieke waarde valt samen met haar grens weg, en de standaardwaarde geldt — namelijk
alle stukken.

### `permutation.maxsize-not-integer` — maxsize is geen heel getal

```
[<maxsize=veel>a|b|c]  →  B c a
```

Precies hetzelfde van het andere eind: de bovengrens verdwijnt, en de uitvoer bevat weer elk stuk.

---

## Studio-aantekeningen zonder iets te tonen

De drie aantekeningen hieronder zijn in dit document niet met een voorbeeld te tonen, en de reden
is telkens een andere en wordt genoemd. Een artikel hebben ze toch: de help is **elke** regel die
het paneel kan tonen een antwoord schuldig, anders leidt een regel in het paneel nergens heen.

### `note.raw-sentinel` — een stuurteken in de tekst

De tekens U+E000–U+E005 zijn wat de machine voor haar eigen opmaak gebruikt, en zij **verwijdert**
ze voor het ontleden. Zijn ze in uw sjabloon terechtgekomen — meestal geplakt uit een andere editor
— dan zegt Studio het: noch de voorvertoning noch de server zal ze tonen.

Hier staat met opzet geen voorbeeld: die tekens zijn onzichtbaar, en een regel die ze draagt zou
leeg lijken. Er zou niets te zien zijn.

### `note.unknown-target` — de verzameling is leeg, er valt niets aan af te meten

Zij verschijnt wanneer de verzameling naast het document **leeg** is: geen enkel sjabloon behalve
dit. Er is niets om het doel aan te toetsen, dus Studio zegt niet «geen doel met die naam» — het
zegt dat het niet kan antwoorden. Leg één sjabloon in die map en de aantekening maakt plaats voor
het gewone `include.unknown-target`, dat inhoudelijk antwoordt.

Een nooit bewaard document heeft **helemaal** geen verzameling, en dat is een derde geval en niet
dit: invoegingen blijven dan letterlijk in de uitvoer staan en het paneel zegt er niets over. Bewaar
het document en ze beginnen te werken.

Hier staat geen voorbeeld omdat het niet kan: de verzameling van dit document staat hierboven
genoemd en is niet leeg.

### `note.too-deep` — invoegingen te diep genest

De machine stopt bij het twintigste niveau geneste `#include` en zet daaronder niets meer neer. De
grens is die van de familie: de JavaScript-, PHP- en Python-machines doen hetzelfde, dus een
document dat hem raakt gedraagt zich overal gelijk.

Hier staat geen voorbeeld vanwege de omvang: er een tonen zou eenentwintig bestanden vergen.

---

## Een stilte in elke taal: afkortingen

### Een afkorting laat het volgende woord klein

```
Dr. onze prijzen zijn laag  →  Dr. onze prijzen zijn laag
Xyz. onze prijzen zijn laag  →  Xyz. Onze prijzen zijn laag
```

Twee regels die in één woord verschillen, en het tweede woord van elk geeft u de regel: na `Dr.`
blijft de zin klein, na `Xyz.` krijgt hij een hoofdletter. De machine zet een hoofdletter na een
punt — behalve na een afkorting die zij kent, en na alles met de vorm van `e.g.` of `U.S.`. Zij is
stil: geen diagnose, geen waarschuwing, en de enige manier om het te merken is de uitvoer lezen.

**De lijst is niet Nederlands, en ook niet Engels.** Zij heeft 46 ingangen, en 29 daarvan zijn
Russisch:

| | |
|---|---|
| Latijns | `etc vs mr mrs ms dr prof sr jr inc ltd co corp no st ave blvd` |
| Cyrillisch | `соц эл см ср ст ул пр пер г р руб коп тыс млн млрд трлн доп напр прим изд обл респ стр табл рис мин макс тел факс` |

Beide helften gelden in **elke** locale — de regel vraagt nooit welke taal u hebt ingesteld. `руб.`
beschermt dus het volgende woord in een Nederlands document, en `Dr.` beschermt het in een
Russisch.

Voor Nederlandse tekst is het gevolg eenvoudig en onaangenaam: van de afkortingen die u dagelijks
schrijft staan alleen `Dr.` en `Prof.` in de lijst, omdat ze toevallig met de Latijnse helft
samenvallen. `Dhr.`, `nr.`, `blz.`, `bijv.` en `bv.` staan er niet in en beëindigen een zin. De
vormen met meerdere punten — `o.a.`, `a.u.b.` — hebben er geen last van; voor de losse woorden
helpt alleen herformuleren.

---

## Hoe de juiste vorm eruitziet

```spx-good
een prijs {laag|hoog}  →  Een prijs laag
```

```spx-good
[<minsize=2;sep=", ">a|b|c]  →  C, b
```

```spx-good
#set %vip% = 1
{?vip?voor u|voor iedereen}  →  Voor u
```

```spx-good
#set %n% = 5
%n% {plural %n%: artikel|artikelen}  →  5 artikelen
```

```spx-good
ervoor /# een notitie #/ erna  →  Ervoor erna
```

Vijf constructies, vijf schone regels: een keuze, een schudbeurt met instellingen, een voorwaarde,
een getalsvorm met een getal ervoor en een opmerking. Geen ervan zet iets in het paneel.

---

## Veelgestelde vragen

**Waarom is de alinea zomaar verdwenen?**
Twee veelvoorkomende oorzaken, beide hierboven: een onbekend `#include`-doel en een invoeging in
een cirkel. Beide drukken niets af. De derde, die men het eerst verdenkt — het verkeerde aantal
getalsvormen — drukt **niet** niets af: de machine drukt de hele constructie tussen brede accolades
`｛｝` af. Leegte komt daar van een niet-numerieke telling en niet van het aantal vormen.

**Waarom werkt mijn variabele met een trema in de naam niet?**
Namen bestaan uit Latijnse letters, cijfers en het onderstrepingsteken. `%één%` is helemaal geen
vermelding van een variabele — de machine leest het als tekst en zegt niets, want vanuit haar
oogpunt valt er niets te melden:

```
hallo %één% en %naam%  →  Hallo %één% en %naam%
```

Beide kwamen ongewijzigd door, en daar zit de valstrik: alleen de tweede trok een regel in het
paneel. De eerste is stil, dus niets vertelt u dat hij nooit zal worden ingevuld. Hernoem hem. In
de **waarde** daarentegen geven trema's en accenten geen enkel probleem.

**Waarom wordt dezelfde fout twee keer getoond?**
Een cirkel van definities trekt een regel voor elke NAAM van waaruit hij bereikbaar is — ten
minste twee plekken om naar te kijken, en meer als andere definities de cirkel voeden.
`#set %x% = %y% %y%` tegenover `#set %y% = %x%` zijn twee regels, één per regel. Het zijn geen
duplicaten: elke regel gaat over een andere naam, en ze worden niet samengevoegd.

**Het paneel zegt fout en de uitvoer lijkt goed. Hoe zit het?**
Allebei. Dat gebeurt bij een twee keer vastgelegde naam: de weergave klopt — de laatste waarde
wint — en het document is dubbelzinnig. Het oordeel gaat over het document en niet over deze ene
uitvoer.

**Ik heb de locale gewisseld en het document werd rood.**
Dat is de locale die haar werk doet. Het demonstratiedocument is Engels en zijn getalsvormen dragen
er twee; zet de locale op Russisch en die twee vormen worden een fout in het aantal, omdat het
Russisch er drie vraagt. Het Nederlands vraagt er twee net als het Engels, dus onder `nl` blijft
het demonstratiedocument rustig. De locale hoort bij het **document**, en daarom wijzigt Studio
haar niet wanneer u de taal van de interface wisselt.

**Komt de voorvertoning overeen met wat mijn server zal produceren?**
Met dezelfde machine, dezelfde versie, dezelfde locale en dezelfde waarden — ja, precies, en juist
daarvoor laat de voorvertoning de echte `spintax-win` draaien en geen benadering ervan. Met een
**andere** machine van de familie — die voor JavaScript, PHP of Python — dragen het oordeel en de
verzameling teksten die het sjabloon kan opleveren over, maar niet welke daarvan een gegeven
startgetal trekt. Diezelfde trekking herhalen belooft de familie niet.
