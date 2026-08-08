# Spintax Studio

Dit programma is een editor voor sjablonen. Een sjabloon is gewone tekst met een paar gemarkeerde
plekken erin, en één sjabloon kan heel veel verschillende teksten opleveren — dat is de hele reden
om er een te schrijven in plaats van de teksten zelf.

Het venster bestaat uit twee helften. Links staat uw sjabloon, wat u bewerkt. Rechts staat een van
de teksten die eruit komen, opnieuw getekend terwijl u typt. Ertussen valt niets in te drukken:
wat u rechts ziet is wat de machine op dat moment teruggeeft voor wat er links staat.

```spx-fixture
locale: nl
seed: 7
empty: (leeg)
```

De machine zit in dit programma en is het Pascal-lid van een familie: dezelfde taal verschijnt ook
voor JavaScript, PHP en Python. De vier zijn zelfstandige programma's die aan één gedeelde reeks
testgevallen worden gehouden, zodat wat een sjabloon BETEKENT in alle vier gelijk is: de
constructies, het oordeel over de geldigheid, de afwerking. Een sjabloon dat dit venster geldig
noemt, is daar ook geldig.

Wat niet wordt beloofd, en het verschil telt bij vergelijken: de loting. Een startgetal maakt de
voorvertoning HIER herhaalbaar — hetzelfde startgetal en hetzelfde sjabloon geven morgen dezelfde
tekst —, maar hetzelfde startgetal in de JavaScript-machine kan een ander alternatief trekken.
Startgetallen dienen om uw eigen werk te herhalen, niet om een andere machine te treffen.

Alles hier werkt zonder netwerkverbinding. Er is geen account, geen aanmelding en niets om aan te
zetten: open het programma en het draait.

## De twee helften

Links wordt getypt. De rechterhelft tekent na een korte pauze opnieuw, zodat de voorvertoning een
zin volgt en niet elke letter.

Een sjabloon met een keuze erin heeft geen enkel antwoord, en de voorvertoning toont er een:

```spx-good
{Hallo|Goedendag} allemaal.  →  Hallo allemaal.
```

**Opnieuw loten** boven de rechterhelft haalt de volgende. Wilt u altijd dezelfde — terwijl u twee
wijzigingen vergelijkt bijvoorbeeld — vink dan **seed** aan, en de voorvertoning staat stil
tot u het weer uitvinkt of het getal verandert.

De schakelaar boven de rechterhelft biedt **Pagina** en **Bron**. Sjablonen zijn meestal HTML, en de
twee vragen «hoe ziet dit eruit» en «welke opmaak kwam eruit» beantwoorden elkaar niet: een kapotte
tag geeft een licht scheve opmaak waar het oog overheen kijkt, terwijl proza vol tags niet als
proza leest. De schakelaar boven de helft wisselt waar u naar kijkt.

Selecteer een deel van het sjabloon en alleen dat deel wordt weergegeven — binnen het bereik van
het hele document, zodat een fragment dat een bovenaan gedefinieerde variabele gebruikt eruit komt
zoals het op zijn plaats zal doen.

## De panelen onderaan

De werkbalk aan de zijkant opent drie panelen, één tegelijk.

**Diagnose** somt op wat de machine verkeerd vond, telkens met de regel en de kolom waar het
begint. Een klik op een regel zet de cursor daar. Het is hetzelfde oordeel dat de machine overal
elders geeft, geen tweede mening van de editor — daarom wordt een sjabloon dat dit paneel geldig
noemt door de andere machines aanvaard.

**Variabelen** toont de namen die uw document definieert en de namen die het alleen gebruikt. Een
naam die het gebruikt en die niets definieert kunt u hier voor de sessie invullen: schrijf er een
waarde naast en de voorvertoning pakt hem op. Vink **als tekst** aan wanneer de waarde tekst is
die zichzelf betekent en niet op zijn beurt een klein sjabloon.

**Varianten** maakt veel teksten in één keer. Zeg hoeveel, maak ze aan en lees ze in de lijst
voordat u exporteert. Bijna-doublures kunnen tijdens het maken worden weggelaten, en een
startgetal maakt de hele partij herhaalbaar: hetzelfde startgetal en hetzelfde sjabloon geven
morgen dezelfde varianten.

Naast die velden zegt het paneel hoeveel varianten het sjabloon in totaal kan opleveren:
`{a|b} en {c|d}` levert er vier. Dat getal vertelt u dat een sjabloon mager is voordat u er vijftig
maakt en het al lezend merkt.

Het is alleen een exact getal zolang elke keuze aan het toeval wordt overgelaten. Een voorwaarde,
een getalsvorm of een `#include` waarvan de verzameling het doel niet heeft, wordt door iets anders
beslist — een waarde die u aanlevert, een getal, een fragment dat misschien nog komt —, en dan zegt
het paneel **ten minste**. Dat is het eerlijke woord: een waarde aanleveren kan alleen teksten
toevoegen, nooit wegnemen. Een getal dat veel te groot is om te lezen stopt bij een biljoen en zegt
om dezelfde reden **ten minste**.

Een variant is één ingevuld sjabloon — bij elke constructie één gemaakte keuze — en dat is niet
hetzelfde als een tekst die anders leest. `{a|a}` zijn twee varianten en één tekst, en dat is met
opzet: de twee mogelijkheden kunnen na één wijziging uit elkaar lopen, en ze samennemen zou
betekenen dat eerst elke combinatie wordt gemaakt, en dat is precies het werk dat dit getal u
bespaart. Een `#def` telt op dezelfde manier: de machine trekt hem één keer per weergave, of de
genomen tak hem nu gebruikt of niet.

De export schrijft ze op drie manieren weg: als XLSX-werkmap, als platte tekst met één variant per
regel, of als één bestand per variant in een map naar keuze.

## De groepseditor

Zet de cursor in een `{a|b|c}` en open de groepseditor vanuit de werkbalk. Hij somt de
alternatieven als regels op: wijzig ze, voeg er een toe, haal er een weg, en het document wordt
overeenkomstig herschreven.

Hij weigert wijzigingen die veranderen wat de groep BETEKENT in plaats van wat hij zegt: een `|`
getypt in een alternatief zou van één mogelijkheid twee maken, en een `}` zou de groep te vroeg
sluiten. Als hij weigert, zegt hij het en laat hij het document met rust.

## Instellingen

Ze staan in het menu Beeld, en elke wordt tussen sessies onthouden: de taal van de interface en of
die het sjabloon volgt, aan welke kant de werkbalk staat, het thema, het lettertype van de editor
en de grootte ervan, of de voorvertoning de pagina of de broncode toont, de schakelaar voor de
GSA-import, welk paneel open staat en de breedtes van de panelen die uitschuiven.

De interface spreekt veertien talen, gekozen in datzelfde menu. Dat staat los van de taal van uw
sjabloon, die de getalsvormen bepaalt en boven de rechterhelft wordt ingesteld.

## Een GSA-sjabloon inlezen

Dit stuk staat uit tot u het aanzet, onder **Beeld**, **GSA-import**, omdat de meeste mensen die
sjablonen schrijven de GSA Search Engine Ranker nooit hebben gebruikt. Staat het aan, dan leest
**Bestand**, **GSA-sjabloon importeren…** een SER-sjabloon en zet het om in deze taal.

De omzetting is op een bepaalde manier voorzichtig. Wat zij niet getrouw kan uitdrukken weigert
zij en meldt zij, in plaats van het stilletjes te veranderen in iets dat weergeeft. Constructies
die verkeerd gelezen zouden worden als ze in de tekst bleven — BBCode-haken, een `#` in een link,
een `#file[...]`-macro — worden in variabelen ondergebracht, en de samenvatting zegt hoeveel.

Twee dingen om te weten over het resultaat:

- **De ondergebrachte waarden zijn sessiewaarden.** Ze verschijnen in het paneel Variabelen en
  worden niet met het document bewaard. Bewaar het omgezette sjabloon, open het morgen, en u ziet
  `%…%` waar de ondergebrachte tekst stond. Uit het ingelezen bestand gaat niets verloren — dat
  blijft onaangeroerd —, maar het omgezette document staat niet op zichzelf.
- **Het wordt weergegeven zonder de afwerkingsronde.** Elk ander document hier krijgt de afwerking
  die de taalgids beschrijft; een omgezet sjabloon niet, want het is niet onze tekst om glad te
  strijken. Hij is van iemand anders, meestal op weg terug naar GSA, en moet teken voor teken
  overleven.

Het ingelezen document is naamloos en niet bewaard, als een nieuw document. Het bestand dat u koos
blijft precies zoals het was.
