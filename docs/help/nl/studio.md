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

**Opnieuw** boven de rechterhelft haalt de volgende. Wilt u altijd dezelfde — terwijl u twee
wijzigingen vergelijkt bijvoorbeeld — vink dan **seed** aan, en de voorvertoning staat stil
tot u het weer uitvinkt of het getal verandert.

De schakelaar boven de rechterhelft biedt **Pagina** en **Bron**. Sjablonen zijn meestal HTML, en de
twee vragen «hoe ziet dit eruit» en «welke opmaak kwam eruit» beantwoorden elkaar niet: een kapotte
tag geeft een licht scheve opmaak waar het oog overheen kijkt, terwijl proza vol tags niet als
proza leest. De schakelaar boven de helft wisselt waar u naar kijkt.

Selecteer een deel van het sjabloon en alleen dat deel wordt weergegeven — binnen het bereik van
het hele document, zodat een fragment dat een bovenaan gedefinieerde variabele gebruikt eruit komt
zoals het op zijn plaats zal doen.

## Zoeken en vervangen

**Ctrl+F** opent een zoekveld in de kopregel. De teller ernaast zegt hoe vaak de tekst
voorkomt en op welk resultaat u staat; **Enter** stapt vooruit, **Shift+Enter** terug, F3
werkt rechtstreeks vanuit het document. Hoofdletters tellen pas met het vinkje naast het
veld — en het vouwen is dat van de machine zelf, zodat een cyrillische of geaccentueerde
letter precies daar met zijn andere vorm samenvalt waar ook het voorbeeld ze één letter
noemt.

**Ctrl+H** — of het menu-item **Vervangen…** — geeft de balk een tweede rij: de vervanging
en twee knoppen. **Vervangen** wijzigt het resultaat waarop u staat en stapt naar het
volgende; zolang er niets gevonden is, zoekt de eerste druk alleen. **Alles vervangen** gaat
in één keer door het hele document, en de statusbalk zegt hoeveel plaatsen er veranderd zijn;
één Ctrl+Z neemt de hele doorgang terug.

De vervanging is letterlijk. Ze mag leeg zijn — dat wist — en mag de gezochte tekst bevatten
zonder de doorgang in een kring te sturen: de plaatsen worden vooraf bepaald, op de tekst
zoals hij was. Overlappen resultaten elkaar, dan telt de teller elk dat een stap kan
bezoeken, maar de doorgang verandert alleen die welke geen letters delen — "vervangen" mag
dus eerlijk een kleiner getal noemen.

Een vervangen document gaat door dezelfde machine als getypte tekst: het voorbeeld tekent
opnieuw en de diagnose antwoordt over wat er nu staat.

## De tekens invoegen

Alles wat de tekens van de taal zelf in het document zet, staat in het menu **Invoegen**.

De drie omsluitopdrachten nemen de selectie zoals ze is: **Omsluiten met {…}** maakt er een keuze van,
**Omsluiten met […]** een schudbeurt, **Omsluiten met /#…#/** (Ctrl+/) een opmerking. Het omsluiten in een opmerking weigert wanneer een `#/` in of rond de selectie — of een op die
plek al open opmerking — een opmerking te vroeg zou beëindigen: het eerste sluitteken wint waar
het ook staat, tekst zou eruit vallen; de statusbalk zegt het, omdat de machine zwijgt. Zonder selectie voegt Ctrl+/ het paar in en laat de cursor erbinnen.

De constructies eronder landen precies zoals het menu ze leest. **#set %naam% = waarde**, **#def %naam% = {a|b}** en **#include "naam"** nemen
een eigen regel — een richtlijn telt alleen wanneer ze haar regel opent, tekst vóór de
cursor blijft dus boven en tekst erna schuift omlaag — en de naam komt geselecteerd
tevoorschijn, klaar om overheen te typen. Houd namen in Latijnse letters: een naam in een
ander alfabet is stilzwijgend geen naam. Het doel van `#include` is de uitzondering — het
wordt precies zoals geschreven met uw fragmentnamen vergeleken.

**{?naam?dan|anders}** staat in de regel zelf. Met een selectie wordt de geselecteerde tekst de "dan"-helft —
een manier om wat er al staat voorwaardelijk te maken; zonder selectie gaat de hele vorm
erin. Een selectie met een kale `|`, een niet-gesloten haak of een open opmerking wordt geweigerd: het
omsluiten zou veranderen wat ze zegt in plaats van het in te kaderen.

Het laatste item zet het in de hulp geopende voorbeeld in het document — de knop van het
hulppaneel zelf, bereikbaar gemaakt vanaf het toetsenbord.

## De panelen onderaan

De werkbalk aan de zijkant opent vier panelen, één tegelijk.

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

**AI-concept** schrijft het eerste concept van een sjabloon voor u — uit tekst die u
al hebt, of uit een briefing. Het verdient een eigen sectie: de volgende.

## Het AI-concept

Een sjabloon begint meestal met tekst die er al is — een productbeschrijving, een brief, een
pagina. Het paneel **AI-concept** maakt daar een eerste sjabloon van: open het vanaf de werkbalk,
laat de kop van de linkerkolom op **Te converteren tekst** staan, plak de tekst en druk op **Genereren**. Het
aangekomen concept vervangt het document, het voorbeeld rendert het en het diagnosepaneel
oordeelt — dezelfde machine en hetzelfde oordeel als voor alles wat u zelf typt. Eén Ctrl+Z
brengt uw oude document terug; bewerk het daarna als eigen tekst, want dat is het.

Valt er niets te plakken, zet de kop dan op **Briefing** en beschrijf wat u wilt. De velden
erboven sturen het concept in beide standen: **Kanaal** — een brief, een sms en een
pushmelding zijn in verschillende registers geschreven; **Variatie** — hoe ver de varianten
uiteen mogen liggen; de taal van het antwoord; en **Variabelen die het model mag gebruiken**, bij naam opgegeven.
De naamvalskolom is het deel dat de moeite van het invullen waard is. Een variabele wordt letterlijk ingevoegd, niets verbuigt haar: in een taal met naamvallen moet de zin dus rond de vorm worden gebouwd die de waarde al heeft, en een model kiest alleen goed als het te horen krijgt welke vorm elke naam draagt. Uit de naam volgt dat niet: in een echte sjabloonverzameling stonden de instrumentalisvormen in een variabele waarvan de naam accusatief zei.

Het antwoord wordt niet geloofd, het wordt gecontroleerd: het concept gaat door de machine van
dit venster voordat het bij uw document in de buurt komt, en vindt het oordeel fouten, dan
vraagt de lus het model ze te herstellen — de statusbalk telt de rondes mee — voordat er iets
wordt overhandigd. Alleen een schoon concept vervangt het document; al het andere belandt in
**Antwoord van het model**, de statusregel zegt waarom, en niets van u wordt overschreven. Uw eigen
wijzigingen zijn net zo beschermd: typte u terwijl een antwoord onderweg was, dan wacht het
concept in het paneel. Tijdens het werk staat op **Genereren** **Stoppen** — druk erop om de ronde
af te breken.

**Herstellen** is dezelfde lus, gericht op uw huidige document: hij ontwaakt wanneer de diagnose
fouten vindt, stuurt het document met de exacte bezwaren mee en past de gecorrigeerde versie
met dezelfde zorg toe.

### De verbinding, en wiens sleutel

Zoals geïnstalleerd verstuurt de toepassing niets, nergens heen. **Genereren** en **Herstellen** gaan
pas het net op nadat u onderaan het paneel de verbinding hebt ingericht en toegestaan. Kies
het **Formaat** dat uw endpoint spreekt — **Anthropic Messages** of **OpenAI-compatible** —, het
**Endpoint**-adres en de naam in **Model** — voor Anthropic biedt de lijst onder de pijl
actuele namen; typ anders de naam die uw endpoint verwacht. **Autorisatie** zegt of er een sleutel meereist: **API-sleutel** voor de gehoste
aanbieders, **geen** voor servers die er geen willen.

De sleutel is de uwe, gemaakt op uw eigen account — de toepassing heeft er nooit een van
zichzelf:

- **Anthropic** — maak de sleutel op `console.anthropic.com`, onder API keys.
- **OpenAI** — `platform.openai.com`, onder API keys; versturen vraagt ook geactiveerde
  facturering op het account.
- **OpenAI-compatible** is een familie, niet één bedrijf: OpenRouter antwoordt in dezelfde
  vorm met veel modellen onder één sleutel, en servers op uw eigen computer — Ollama,
  LM Studio — willen meestal helemaal geen sleutel: zet **Autorisatie** op **geen**.

**Sleutel koppelen** bergt de sleutel op in Windows Referentiebeheer, versleuteld voor uw
Windows-account — niet in een bestand, en nooit in het document. Het veld toont daarna de
eerste tekens van de sleutel, zodat te zien is welke gekoppeld is, en **Sleutel vergeten** haalt hem
weg. Een sleutel hoort bij de plek waarvoor hij is ingevoerd — schema, host en poort: wijzig er
één en het paneel vraagt er opnieuw om.

De eerste druk vraagt het in gewone woorden — **Naar dit endpoint versturen?** — met de ontvanger bij naam. Mee
reist de prompt, gebouwd uit uw briefing of tekst — met het gekozen kanaal, de gekozen
variatie en taal —, de opgegeven variabelen, bij herstel het huidige sjabloon met zijn
diagnose, de modelnaam uit uw profiel met een plafond voor de lengte van het antwoord, en
onder **API-sleutel**-autorisatie de sleutel in de kopregels van het verzoek;
verder niets, en op geen enkel ander moment. De ontvanger verandert niet zonder u: een
omleiding wordt geweigerd in plaats van gevolgd, en een onversleuteld `http`-adres wordt
alleen op deze machine aanvaard. De toestemming bindt zich waar de sleutel dat doet — schema, host en poort — en is zichtbaar
als het vinkje **Versturen toegestaan** in de instellingen — haal het weg wanneer u wilt: niets
nieuws vertrekt, en een antwoord dat al onderweg is wordt nooit toegepast. Wat de software op het gekozen adres met de tekst doet, is
aan zijn beheerder om te zeggen: het verzoek gaat naar het adres uit uw profiel en nergens
anders heen.

### Dezelfde lus, zonder netwerk

De prompts hebben sleutel noch verbinding nodig — het is dezelfde weg wanneer uw model in
een chatvenster leeft, en de lus draait u hier zelf: de machine oordeelt na het plakken, niet
ervoor. **Prompt kopiëren** zet de volledige prompt op het klembord; breng hem
naar het model dat u gebruikt, plak het antwoord in **Antwoord van het model** en druk op **In het document invoegen**. Vindt de
diagnose fouten, dan bouwt **Herstelprompt kopiëren** de tweede prompt: die draagt het hele document met
genummerde regels en noemt de exacte plekken waartegen de machine bezwaar maakte. Het antwoord
erop is het gecorrigeerde document in zijn geheel — breng het terug en druk op **Het document vervangen**;
**In het document invoegen** zou het kapotte laten staan en de gecorrigeerde kopie ernaast zetten.

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
