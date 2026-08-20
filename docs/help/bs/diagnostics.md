# Šta kaže kartica «Dijagnostika»

Svaki je red na ovoj kartici presuda **motora**, i istu bi presudu dale implementacije za
JavaScript, PHP ili Python: četiri samostalna motora koji se drže jednog zajedničkog korpusa. To
nije mišljenje Studio o vašem šablonu. Ako motor ovdje nešto nazove greškom, svaki drugi motor
porodice to također naziva greškom, i vaš će se šablon ponašati na vašem serveru isto kao u ovom
prozoru.

| šta piše | ko to kaže | šta to znači |
|---|---|---|
| **greška** | motor | šablon će raditi nešto drugo nego na šta liči |
| **upozorenje** | motor | odigrat će se, ali najvjerovatnije ne onako kako ste mislili |
| **Studio napomena** | Studio | motor nije rekao ništa, a to vrijedi reći: umetanje u krug, cilj u drugoj veličini slova, službeni znak |

Kolona **Mjesto** jeste red i kolona. Klik na red vodi kursor tamo.

> Svaki primjer ispod prolazi kroz motor s kojim je sklopljena ova kopija Studio, pri svakom
> sklapanju programa, i desno stoji tačno ono što je on vratio. Ovdje ništa nije upamćeno ni
> pogođeno; odgovor koji bi prestao biti istinit zaustavio bi sklapanje. Verzija motora je u
> **Pomoć**, **O programu**.

## Kako čitati primjere

Strelica `→` razdvaja šablon od onoga što je motor vratio. `⏎` je prelom reda unutar izlaza,
`(prazno)` znači da nije ispisao ništa, a `…` označava izlaz predugačak da bi se prikazao u
cijelosti. Tekst nakon izlaza, odvojen s tri razmaka, napomena je, a ne dio odgovora.

Uvjeti pod kojima su primjeri trčali stoje ovdje, a nisu skriveni u testovima: bez njih se neki
odgovori ne mogu ponoviti. Najviše znači skup šablona: inače bi
`#include "frag"` → `Odlomak` počivao na nečemu što ovaj dokument nikada ne kaže.

```spx-fixture
locale: bs
seed: 7
empty: (prazno)
include frag: Odlomak
include loop: #include "loop"
include Intro: Uvod
```

`seed` učvršćuje izvlačenje: bez njega bi izbor ili miješanje odgovarali svaki put drugačije i ne bi
bilo šta provjeriti.

**Lokal je ovdje `bs`, i on rješava dvije stvari:** koliko oblika množine motor očekuje i koji oblik
kome pripada. Bosanskom, hrvatskom, srpskom, ruskom, ukrajinskom i bjeloruskom trebaju tri.
Engleskom — dva. Lokal se uzima s prebacivača iznad desne polovine, a ne iz jezika sučelja.

---

## Zagrade

**Stavite kursor na zagradu i konstrukcija će se pokazati u cijelosti:** gdje počinje, gdje se
završava i **svi njeni razdjeljivači**. Ugniježđene se grupe pritom ne osvjetljavaju: one imaju svoje
razdjeljivače, i oni će se upaliti kada kursor stane na njihovu zagradu. To je najbrži način da
vidite gdje se završava ono što mijenjate — naročito u dugačkom redu, gdje je `}` otišla dva ekrana
udesno.

Razdjeljivačem se ne smatra samo `|`. U miješanju `[a<br>|b]` ih je dva: motor čita `<br>` kao
razdjeljivač postavljen **ispred sljedećeg** komada, i osvjetljenje ga pokazuje zajedno s ostalima,
jer on i jeste dio građe konstrukcije.

### `bracket.unclosed` — zagrada je otvorena i nije zatvorena

```
cijena {niska|visoka  →  Cijena {niska|visoka
```

Motor ne pogađa gdje ste htjeli zatvoriti. Tekst ostaje kako jeste, zajedno sa zagradom, i izbor se
ne dešava nikada.

### `bracket.mismatched` — zatvorena je zagradom druge vrste

```
cijena {niska|visoka]  →  Cijena {niska|visoka]
```

`{` čeka `}`, a `[` čeka `]`. Miješanje zatvoreno vitičastom zagradom miješanje nije.

### `bracket.unexpected-closing` — zatvorena zagrada bez otvorene

```
cijena niska} i to je to  →  Cijena niska} i to je to
```

Ona ostaje tekst. Najčešće je to zagrada preostala od izmjene.

---

## Definicije

### `set.malformed` — ovaj `#set` red nije napisan po pravilu

```
#set grad = Sarajevo
u %grad%  →  #set grad = Sarajevo ⏎ U %grad%
```

**Ime se piše između znakova procenta:** `#set %grad% = Sarajevo`. To je najčešća prva greška, i ona
stavlja u ploču odmah dva reda — sam pokvaren red i «ova varijabla nigdje nije definisana», jer do
definicije nije došlo, a `%grad%` ne pripada nikome.

Pogledajte izlaz: neuspjela je direktiva ostala u tekstu **kako je napisana**. Motor je nije pročitao
kao direktivu, dakle to je običan red, i on dospijeva u rezultat.

### `def.malformed` — ovaj `#def` red nije napisan po pravilu

```
#def stranice = {1|3}
%stranice%  →  #def stranice = 1 ⏎ %stranice%
```

Isto pravilo i ista cijena. `#def` se od `#set` razlikuje ne po pisanju, nego po tome **kada** se
vrijednost razvija: `#set` je razvija pri svakom pominjanju, `#def` — jednom po odigravanju. Greška u
pisanju košta vas oba.

I pogledajte bolje: `{1|3}` je u neuspjeloj direktivi **izvukao mogućnost**. Red je postao običan
tekst, a običan se tekst odigrava kao običan tekst, zajedno sa zagradama. Pokvaren red nije
isključen; on samo prestaje biti direktiva.

### `definition.duplicate-name` — ovo je ime već definisano gore

```
#set %x% = prvo
#set %x% = drugo
%x%  →  Drugo
```

Ono radi — pobjeđuje **posljednja** definicija — ali motor to naziva greškom: dokument u kojem je ime
zadato dvaput čita se dvosmisleno, i za mjesec dana nećete se sjetiti koji je od ta dva reda živ.
Greška pokazuje na **drugu** definiciju; prva stoji gore.

### `def.include-in-value` — `#include` unutar vrijednosti definicije

```
#def %x% = #include "frag"
%x%  →  Odlomak
```

Umetanje se unutar vrijednosti razvija u drugom trenutku nego što biste očekivali, i porodica to
zabranjuje. Stavljajte `#include` u zaseban red.

---

## Varijable

### `variable.undefined` — ova varijabla nigdje nije definisana

```
zdravo, %name%  →  Zdravo, %name%
```

Upozorenje, a ne greška: motor ispisuje ime kako jeste. Tako je i zamišljeno — vrijednost može doći
izvana, od programa domaćina. U Studio se takve vrijednosti predaju na kartici «Varijable», u
odjeljku **Vrijednosti sesije**.

**Vrijednost definicije može se mijenjati u ploči.** Stanite u gornjem dijelu na kolonu «Vrijednost»
i pritisnite **F2** (ili jednostavno počnite kucati); **Enter** primjenjuje, **Esc** odustaje.
Izmjena ide **u dokument**, jednim korakom opoziva: `Ctrl+Z` je vraća nazad.

Ime i vrsta (`#set` ili `#def`) ne podliježu izmjeni — i to je odluka, a ne nedovršen ćošak.
Preimenovanje iz ćelije kida sva pominjanja varijable u dokumentu, a brisanje reda nosi sa sobom
komentar i uvlaku. I jedno i drugo pripada tekstu, gdje vidite šta radite.

Mijenja se **baš vrijednost**. Uvlaka, višak razmaka, veličina slova u imenu i komentar na kraju reda
ostaju kakvi su bili: `   #set  %Brand%   =   Acme   /# rep #/` vraća se iz izmjene razlikujući se
samo u `Acme`. Fajl leži u gitu, i preformatirati red značilo bi prikazati to tamo kao vašu izmjenu.

**Odbijanje znači da bi motor pročitao red drugačije.** Izmjena se ne primjenjuje šutke: motor
ponovo čita rezultat, i ako on kaže nešto drugo od traženog, dokument se ostavlja na miru, a statusni
red o tome javlja. Tri stvarna razloga: `/#` u vrijednosti otvara komentar koji pojede ostatak fajla;
prelom reda završava direktivu prerano; a komentar **unutar** direktive čini red neispravnim po
dijelovima — taj mijenjajte u tekstu.

**Dva poteza na imenu varijable.** Ime je u ploči link, a ne natpis:

- **klik na ime** vodi kursor do prvog mjesta gdje dokument koristi tu varijablu, i red na tren
  bljesne. Ista riječ unutar komentara ili kao cilj `#include` **ne** računa se: ploča vas vodi tamo
  gdje varijabla stvarno radi.
- **Ctrl+klik** upisuje definiciju u dokument i otvara na njoj uređivač grupa. Vrijednost koju ste već
  otkucali ulazi tamo kao prva mogućnost:

```
#set %brand% = {Vulkan}
kazino %brand%  →  Kazino Vulkan
```

Razlika je među njima ono što preživljava zatvaranje prozora. Vrijednost sesije ne preživljava: nema
je ni u fajlu ni u gitu, i nijedan je drugi motor porodice ne vidi. Definicija preživljava, i samo
definicija utišava ovo upozorenje zauvijek. Jedan `Ctrl+Z` vraća dokument.

**Vrijednost je sesije prvo šablon, a ne tekst.** Upravo tako motor postupa sa svakom vrijednošću
domaćina, a pregled se mora poklapati sa serverom — pa `{niska|visoka}` otkucano u polje vrijednosti
daje izbor, a ne te znakove. Ako ste mislili na sam tekst, označite **kao tekst** u trećoj
koloni: tada vitičaste zagrade i procenti ostaju znaci.

### `variable.self-reference` — definicija upućuje sama na sebe

```
#set %x% = a %x% b
%x%  →  A a a … %x% … b b b
```

Pedeset nivoa, potom zaustavljanje. Motor razvija do granice dubine i staje, ostavljajući `%x%` u
sredini. To nije krug, i nije ono što ste htjeli.

`…` je gore skraćenje ovog dokumenta, a ne motora. Stvarni izlaz ima 207 znakova i nosi sa svake
strane **pedeset jedno** slovo, a ne pedeset: pedeseti nivo staje i ostavlja vrijednost kako jeste, a
u vrijednosti je svakog po jedno više.

### `variable.circular-reference` — definicije upućuju u krug

```
#set %x% = %y%
#set %y% = %x%
%x%  →  %y%
```

Svaka se strana razvija tačno **jednom** i staje: `%x%` je postao `%y%`, a ne `%x%`. Motor odmotava
krug, a ne hoda po njemu, i preživljava drugo ime iz kruga — stavite u dokument `%x% %y%` i on će
dati `%y% %x%`, par naopako.

Panel iscrtava red za **svako definirano ime iz kojeg je krug dostižan**, a ne jedan red za
krug ni jedan po spominjanju. Imenovati krug dvaput u jednom redu ne udvostručuje red:
`#set %x% = %y% %y%` prema `#set %y% = %x%` jesu dvije greške, po jedna u svakom redu — isto
kao kod obična dva imena.

**I ime koje samo vodi u krug biva prijavljeno**, i to je dio koji iznenađuje: lanac
definicija koji hrani krug od dva imena iscrtava red za svaku kariku lanca, a ne dva reda za
sam krug. Ime koje upućuje SAMO na sebe jeste druga greška — `variable.self-reference` — ali
definicija koja imenuje i sebe **i** doseže krug iscrtava obje: `#set %s% = %s% %c1%` nad
krugom od dva imena jeste jedna samoreferenca i tri kružna reda, jedan od njih u tom istom
redu. A položaj leži na definiciji koja zaista vrijedi: ako je ime definirano dvaput, to je
**posljednja**.

---

## Umetanja

### `#include` radi samo s početka reda

```
prije #include "frag" poslije  →  Prije #include "frag" poslije
```

```
#include "frag"  →  Odlomak
```

Nijedna dijagnostika, i u tome je cijela poenta: `#include` usred reda umetanje **nije**. Motor ga
čita kao običan tekst i ništa ne kaže, jer nema na šta da se žali — napisali ste tekst i dobili
tekst.

**A cilj ipak može stajati red niže**, i to iznenađuje s druge strane. Razmak koji motor dopušta
između riječi i cilja uključuje prelome redova, pa je to jedno umetanje, i ono radi:

```spx-good
#include
"frag"  →  Odlomak
```

Prazni su redovi između njih također dozvoljeni. Nije dozvoljeno sve ostalo: riječ ispred cilja ili
bilo šta osim razmaka iza njega — i sve ponovo postaje tekst. Uređivač boji cilj u njegovom vlastitom
redu, a samu riječ ostavlja običnom dok cilj nije došao: on ne obećava direktivu čiji kraj još ne
vidi.

### `include.unknown-target` — takvog cilja u skupu nema

```
#include "nema"  →  (prazno)
```

Ciljevi su `.spintax` fajlovi u folderu otvorenog dokumenta. Nepoznat se cilj razvija u ništa:
pasus nestaje, a ne puca, i upravo je zato to tako lako previdjeti.

**Zbog toga na kartici «Varijable» postoji treći odjeljak, «Uključivanja».** On nabraja svaki `#include`
dokumenta i za svaki — ima li skup njegov cilj; po jedan red po pojavljivanju, pa cilj imenovan
dvaput daje dva reda. Odjeljak se pojavljuje samo onda kada u dokumentu ima umetanja. Klik na red
vodi kursor do onog `#include` koji imenuje taj cilj.

Oznaka ima **tri** značenja, i treće je važno: «nema skupa» nije «odlomak nedostaje», nego «zasad
nema gdje tražiti». Skup je folder pored dokumenta, a nesačuvan dokument folder nema; pa je do prvog
čuvanja svaki cilj označen upravo tako. «NEDOSTAJE» se pojavljuje samo onda kada folder postoji, a
fajla u njemu stvarno nema.

### `note.case-mismatch` — cilj postoji, ali u drugoj veličini slova

```
#include "intro"  →  (prazno)
```

Skup sadrži `Intro.spintax` — a motor svejedno kaže da takvog cilja nema, dok Studio dodaje svoju
napomenu o veličini slova. Veličina je slova važna: `intro` i `Intro` različiti su ciljevi. Windows bi
otvorio fajl i ovako i onako, i upravo zato Studio gleda u skup, a ne u fajl sistem: inače bi pregled
protivrječio serveru o istom dokumentu.

### `note.cycle` — umetanje u krug

Ako `loop.spintax` i sam sadrži `#include "loop"`, onda:

```
#include "loop"  →  (prazno)
```

Motor podmeće prazninu umjesto beskonačnosti. Napomena je potrebna da biste razumjeli zašto je pasus
nestao.

Red je ispisan na **`loop`**, a ne na dokument u koji gledate: krug pripada odlomku, i tamo ide kursor
pri kliku. U otvorenom dokumentu ništa nije podvučeno, jer je s redom koji ste vi napisali sve u redu.

---

## Oblici množine

### `plural.arity` — oblika nema onoliko koliko lokal zahtijeva

```
#set %n% = 5
%n% {plural %n%: objekat|objekta}  →  5 ｛plural 5: objekat|objekta｝
```

**Nije praznina — motor ispisuje cijelu konstrukciju**, zamijenivši zagrade širokim `｛｝`. Tako on
kaže «ovo sam vidio i nisam mogao primijeniti». Neprimjetnim to niko neće nazvati, i to je dobro:
pasus koji je nestao šutke tražio bi se duže.

Bosanskom trebaju tri oblika, engleskom — dva. Pod lokalom ovog dokumenta ispravno je
`{plural %n%: objekat|objekta|objekata}`.

**Praznina nastaje iz drugog razloga, i ta se dva lako pomiješaju.** Uporedite ova dva, koja se
razlikuju samo po broju oblika:

```
{plural %n%: objekat|objekta|objekata}  →  (prazno)   tri oblika: ispravno za bosanski
{plural %n%: objekat|objekta}  →  (prazno)   dva oblika: neispravno za bosanski
```

Oba ne ispisuju ništa, a ploča se prema njima odnosi drugačije: prvi povlači samo
`variable.undefined`, drugi povlači i `plural.arity`. Dakle, **praznina nije znak greške u broju
oblika** — ovdje je ona otuda što `%n%` nije definisano, a motor provjerava brojač prije nego što
broji oblike, pa staje još prije nego što se pitanje o broju postavi.

Upravo zato primjer na početku ovog članka prvo definiše `%n%`. Bez toga bi izlaz bio prazan pri bilo
kojem broju oblika i o broju ne bi pokazao ništa.

Panel i ispis ovdje odgovaraju na različita pitanja, i to nije protivrječnost: red postavlja
**provjera**, koja broji oblike koje će prikaz zaista razdvojiti — definicija koja stoji umjesto
njih najprije se razrješava; prazninu daje **prikaz**, koji ima svoj redoslijed. Dajte brojaču
cifru, kao u prvom primjeru, i vidjet ćete šta broj oblika zaista radi.

### `plural.count-macro` — brojač uzima vrijednost iz `#set`-a, a taj izvlači iznova pri svakom pominjanju

```
#set %n% = {1|2}
%n% {plural %n%: objekat|objekta|objekata}  →  1
```

Pogledajte šta je preživjelo: **broj je ispisan, a imenica nije.** Brojač mora biti broj u trenutku
kada se bira oblik, a `#set` čija je vrijednost i sama izbor brojem ne postaje nikada — motor podmeće
vrijednost **ne odigravajući je**, pa na mjesto brojača leži doslovan tekst `{1|2}`. Brojač i oblik ne
mogu protivrječiti jedan drugom; motor umjesto toga ispušta riječ.

`#def` se ponaša drugačije i razvija svoju vrijednost jednom po odigravanju, pa mjesto brojača dobija
broj:

```
#def %n% = {1|2}
%n% {plural %n%: objekat|objekta|objekata}  →  1 objekat
```

Za to u ploči nema nijednog reda. Otuda i pravilo: pravite brojač jednostavnim brojem ili `#def`-om,
nikada `#set`-om.

### `plural.nested-brackets` — zagrade unutar oblika

```
{plural %n%: {objekat|stvar}|objekta|objekata}  →  ｛plural %n%: ｛objekat|stvar｝|objekta|objekata｝
```

Oblici su prost tekst. Izbor se unutar njih ne razvija, i umjesto toga se cijela konstrukcija ispisuje
u širokim zagradama.

---

## Miješanje

### `permutation.unknown-key` — nepoznat ključ u postavci

```
[<foo=1>a|b|c]  →  Bfoo=1cfoo=1a
```

Poznati su ključevi `minsize`, `maxsize`, `sep` i `lastsep`. Nepoznat postavka nije, i kada je on u
bloku jedini, cijeli blok uopće nije postavka: on postaje razdjeljivač između komada, što izlaz i
pokazuje.

**Ako pored stoji pravi ključ, izlaz je sasvim drugačiji** — i to je vjerovatnija greška: jedan je
ključ od nekoliko otkucan pogrešno:

```
[<sep=", ";foo=1>a|b|c]  →  B, c, a
```

Blok ostaje postavka, `sep` se izvršava, nepoznat se ključ prosto odbacuje, a ploča u oba slučaja kaže
jedno te isto. Dakle, dijagnostika javlja da ključ nije shvaćen; ona ne javlja šta se dalje desilo. O
tome čitajte izlaz.

### `permutation.minsize-not-integer` — minimum nije zadat cijelim brojem

```
[<minsize=dva>a|b|c]  →  B c a
```

Nebrojčana vrijednost otpada zajedno sa svojom granicom, i vrijedi uobičajeno — dakle svi komadi.

### `permutation.maxsize-not-integer` — maksimum nije zadat cijelim brojem

```
[<maxsize=mnogo>a|b|c]  →  B c a
```

Tačno isto s drugog kraja: gornja granica nestaje, i izlaz opet sadrži svaki komad.

---

## Studio napomene koje nemaju šta pokazati

Tri napomene ispod ne mogu se prikazati primjerom u ovom dokumentu, i razlog je svaki put drugi i
imenovan. Članak ipak imaju: pomoć duguje odgovor **svakom** redu koji ploča može prikazati, inače
red u ploči vodi u prazno.

### `note.raw-sentinel` — službeni znak u tekstu

Znakovi U+E000–U+E005 jesu ono čime motor obilježava svoje, i on ih **uklanja** prije razlaganja. Ako
su dospjeli u vaš šablon — uglavnom nalijepljeni iz drugog uređivača — Studio o tome javlja: neće ih
prikazati ni pregled ni server.

Primjera ovdje namjerno nema: ti su znakovi nevidljivi, i red bi s njima izgledao prazan. Ne bi imalo
šta gledati.

### `note.unknown-target` — skup je prazan, i nema se po čemu suditi

Ona se pojavljuje kada je skup pored dokumenta **prazan**: nijedan šablon osim ovog. Cilj nema s čime
uporediti, pa Studio ne kaže «takvog cilja nema» — ono kaže da ne može odgovoriti. Stavite u taj
folder jedan jedini šablon i napomena će ustupiti mjesto uobičajenom `include.unknown-target`, koji
odgovara suštinski.

Nikada sačuvan dokument nema skup **uopće**, i to je treći slučaj, a ne ovaj: umetanja tada ostaju u
izlazu doslovno, a ploča o njima ne kaže ništa. Sačuvajte dokument i ona će početi raditi.

Primjera ovdje nema po konstrukciji: skup je ovog dokumenta imenovan gore, i nije prazan.

### `note.too-deep` — umetanja su ugniježđena preduboko

Motor staje na dvadesetom nivou ugniježđenih `#include` i niže ne podmeće ništa. Granica pripada
porodici: motori za JavaScript, PHP i Python rade isto, pa se dokument koji u nju udari ponaša svugdje
jednako.

Primjera nema zbog veličine: prikazati jedan koštalo bi dvadeset jedan fajl.

---

## Tišina koju sreću svi: skraćenice

### Skraćenica ostavlja sljedeću riječ malom

```
dr. Hodžić naše cijene su niske  →  dr. Hodžić naše cijene su niske
Xxx. naše cijene su niske  →  Xxx. Naše cijene su niske
```

Dva reda koja se razlikuju u jednoj riječi, i druga riječ svakog daje vam pravilo: nakon `dr.`
rečenica ostaje mala, nakon `Xxx.` — velikim slovom. Motor stavlja veliko slovo nakon tačke — osim
nakon skraćenice koju zna, i nakon svega poput `e.g.` ili `d.o.o.` On šuti: nijedna dijagnostika,
nijedno upozorenje, i jedini je način da se primijeti pročitati izlaz.

**Spisak nije bosanski ni engleski.** U njemu je 46 unosa, i 29 ih je ruskih:

| | |
|---|---|
| latinični | `etc vs mr mrs ms dr prof sr jr inc ltd co corp no st ave blvd` |
| ćirilični | `соц эл см ср ст ул пр пер г р руб коп тыс млн млрд трлн доп напр прим изд обл респ стр табл рис мин макс тел факс` |

Obje polovine vrijede u **bilo kojem** lokalu — pravilo nikada ne pita koji ste jezik postavili. Tako
`ltd.` zaklanja sljedeću riječ u bosanskom dokumentu, a `г.` je zaklanja u engleskom.

Za bosanski tekst posljedica je pomiješana: titule rade jer stoje na latiničnoj polovini — `dr.`,
`prof.`, `mr.` — a `br.`, `npr.`, `itd.`, `tzv.`, `god.`, `odn.`, `sl.`, `g.`, `ul.`, `str.` i `tel.`
na spisku ne postoje i završavaju rečenicu. Jezički priručnik dodaje da skraćenica od više tačaka radi
u vašu korist, pa `d.o.o.` prolazi cijelo, i da je goli domen zaklonjen jer je pisan latinicom — a
ćirilični nije.

---

## Kako izgleda ispravno

```spx-good
cijena {niska|visoka}  →  Cijena niska
```

```spx-good
[<minsize=2;sep=", ">a|b|c]  →  C, b
```

```spx-good
#set %vip% = 1
{?vip?za vas|za sve}  →  Za vas
```

```spx-good
#set %n% = 5
%n% {plural %n%: artikal|artikla|artikala}  →  5 artikala
```

```spx-good
prije /# bilješka #/ poslije  →  Prije poslije
```

Pet konstrukcija, pet čistih redova: izbor, miješanje s postavkama, uvjet, oblik množine s brojem
ispred njega i komentar. Nijedna ne stavlja u ploču ništa.

---

## Često pitaju

**Zašto je pasus prosto nestao?**
Dva česta razloga, oba gore: nepoznat cilj `#include` i umetanje u krug. Oba daju prazninu. Treći, na
koji se najčešće pomisli — pogrešan broj oblika — prazninu **ne** daje: motor ispisuje konstrukciju u
cijelosti u širokim zagradama `｛｝`. Prazninu tamo daje nebrojčan brojač, a ne broj oblika.

**Zašto moja varijabla s kvačicom u imenu ne radi?**
Imena su varijabli samo ASCII latinica. `%šifra%` motoru uopće nije pominjanje varijable: on ga
ispisuje kao tekst i **ne izdaje nijednu dijagnostiku**:

```
zdravo, %šifra%  →  Zdravo, %šifra%
```

Uporedite s `%sifra%`, koje red u ploči ipak povlači. Šutljivo je baš prvo — ništa vam neće reći da se
ono nikada neće podmetnuti. A `#set %šifra% = tajna` već je `set.malformed`. Vrijednosti su pritom
bilo kakve: `#set %grad% = Šamac` sasvim je normalno.

**Zašto se ista greška prikazuje dvaput?**
Krug definicija povlači red za svako IME iz kojeg je dostižan — najmanje dva mjesta za
pogledati, a više ako krug hrane druge definicije. `#set %x% = %y% %y%` prema
`#set %y% = %x%` jesu dva reda, po jedan u svakom redu. To nisu duplikati: svaki je red o
drugom imenu i ne spajaju se.

**Zašto u ploči piše «greška», a izlaz izgleda ispravno?**
Tako biva pri ponovnoj definiciji: odigravanje je korektno — pobjeđuje posljednja vrijednost — ali
dokument je dvosmislen. Presuda je o dokumentu, a ne o konkretnom izlazu.

**Prebacio sam lokal i u dokumentu se pojavila greška. Šta sam pokvario?**
Ništa. Broj je oblika svojstvo JEZIKA: engleskom trebaju dva (`page|pages`), bosanskom tri
(`artikal|artikla|artikala`). Tekst pisan za jedan jezik pri prebacivanju lokala postaje neispravan za
drugi, i motor o tome pošteno kaže. Tako se ponaša i demonstracijski dokument s kojim se Studio
otvara: on je engleski, i na lokalu `bs` njegovo `{plural %pages%: page|pages}` već je greška.

**Poklapa li se pregled s onim što će dati moj server?**
Na istom motoru, istoj verziji, istom lokalu i s istim vrijednostima — da, tačno, i upravo zato
pregled goni pravi `spintax-win`, a ne približenje. Na **drugom** motoru porodice — za JavaScript,
PHP ili Python — prenosi se presuda i skup tekstova koje šablon može dati, ali ne i to koji će od njih
izvući konkretno sjeme. Ponoviti baš to izvlačenje porodica ne obećava.
