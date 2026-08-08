# Što kaže kartica «Dijagnostika»

Svaki je redak na ovoj kartici presuda **motora**, i istu bi presudu dale implementacije za
JavaScript, PHP ili Python: četiri samostalna motora koji se drže jednog zajedničkog korpusa. To
nije mišljenje Studio o vašem predlošku. Ako motor ovdje nešto nazove greškom, svaki drugi motor
obitelji to također naziva greškom, i vaš će se predložak ponašati na vašem poslužitelju isto kao u
ovom prozoru.

| što piše | tko to kaže | što to znači |
|---|---|---|
| **greška** | motor | predložak će raditi nešto drugo nego na što liči |
| **upozorenje** | motor | odigrat će se, ali najvjerojatnije ne onako kako ste mislili |
| **Studio napomena** | Studio | motor nije rekao ništa, a to vrijedi reći: umetanje u krug, cilj u drugoj veličini slova, službeni znak |

Stupac **Mjesto** jest redak i stupac. Klik na redak vodi pokazivač tamo.

> Svaki primjer ispod prolazi kroz motor s kojim je sklopljena ova kopija Studio, pri svakom
> sklapanju programa, i desno stoji točno ono što je on vratio. Ovdje ništa nije zapamćeno ni
> pogođeno; odgovor koji bi prestao biti istinit zaustavio bi sklapanje. Verzija je motora u
> **Pomoć**, **O programu**.

## Kako čitati primjere

Strelica `→` razdvaja predložak od onoga što je motor vratio. `⏎` je prelom retka unutar izlaza,
`(prazno)` znači da nije ispisao ništa, a `…` označava izlaz predugačak da bi se prikazao u
cijelosti. Tekst nakon izlaza, odvojen s tri razmaka, napomena je, a ne dio odgovora.

Uvjeti pod kojima su primjeri trčali stoje ovdje, a nisu skriveni u testovima: bez njih se neki
odgovori ne mogu ponoviti. Najviše znači skup predložaka: inače bi
`#include "frag"` → `Ulomak` počivao na nečemu što ovaj dokument nikada ne kaže.

```spx-fixture
locale: hr
seed: 7
empty: (prazno)
include frag: Ulomak
include loop: #include "loop"
include Intro: Uvod
```

`seed` učvršćuje izvlačenje: bez njega bi izbor ili miješanje odgovarali svaki put drukčije i ne bi
bilo što provjeriti.

**Lokal je ovdje `hr`, i on rješava dvije stvari:** koliko oblika množine motor očekuje i koji oblik
kome pripada. Hrvatskom, srpskom, bosanskom, ruskom, ukrajinskom i bjeloruskom trebaju tri.
Engleskom — dva. Lokal se uzima s prebacivača iznad desne polovice, a ne iz jezika sučelja.

---

## Zagrade

**Stavite pokazivač na zagradu i konstrukcija će se pokazati u cijelosti:** gdje počinje, gdje se
završava i **svi njezini razdjeljivači**. Ugniježđene se grupe pritom ne osvjetljavaju: one imaju
svoje razdjeljivače, i oni će se upaliti kada pokazivač stane na njihovu zagradu. To je najbrži način
da vidite gdje se završava ono što mijenjate — osobito u dugačkom retku, gdje je `}` otišla dva
zaslona udesno.

Razdjeljivačem se ne smatra samo `|`. U miješanju `[a<br>|b]` ih je dva: motor čita `<br>` kao
razdjeljivač postavljen **ispred sljedećeg** komada, i osvjetljenje ga pokazuje zajedno s ostalima,
jer on i jest dio građe konstrukcije.

### `bracket.unclosed` — zagrada je otvorena i nije zatvorena

```
cijena {niska|visoka  →  Cijena {niska|visoka
```

Motor ne pogađa gdje ste htjeli zatvoriti. Tekst ostaje kako jest, zajedno sa zagradom, i izbor se ne
događa nikada.

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

### `set.malformed` — ovaj `#set` redak nije napisan po pravilu

```
#set grad = Zagreb
u %grad%  →  #set grad = Zagreb ⏎ U %grad%
```

**Ime se piše između znakova postotka:** `#set %grad% = Zagreb`. To je najčešća prva greška, i ona
stavlja u ploču odmah dva retka — sam pokvaren redak i «ova varijabla nigdje nije definirana», jer do
definicije nije došlo, a `%grad%` ne pripada nikome.

Pogledajte izlaz: neuspjela je direktiva ostala u tekstu **kako je napisana**. Motor je nije pročitao
kao direktivu, dakle to je običan redak, i on dospijeva u rezultat.

### `def.malformed` — ovaj `#def` redak nije napisan po pravilu

```
#def stranice = {1|3}
%stranice%  →  #def stranice = 1 ⏎ %stranice%
```

Isto pravilo i ista cijena. `#def` se od `#set` razlikuje ne po pisanju, nego po tome **kada** se
vrijednost razvija: `#set` je razvija pri svakom spomenu, `#def` — jednom po odigravanju. Greška u
pisanju košta vas oba.

I pogledajte bolje: `{1|3}` je u neuspjeloj direktivi **izvukao mogućnost**. Redak je postao običan
tekst, a običan se tekst odigrava kao običan tekst, zajedno sa zagradama. Pokvaren redak nije
isključen; on samo prestaje biti direktiva.

### `definition.duplicate-name` — ovo je ime već definirano gore

```
#set %x% = prvo
#set %x% = drugo
%x%  →  Drugo
```

Ono radi — pobjeđuje **posljednja** definicija — ali motor to naziva greškom: dokument u kojemu je
ime zadano dvaput čita se dvosmisleno, i za mjesec dana nećete se sjetiti koji je od ta dva retka
živ. Greška pokazuje na **drugu** definiciju; prva stoji gore.

### `def.include-in-value` — `#include` unutar vrijednosti definicije

```
#def %x% = #include "frag"
%x%  →  Ulomak
```

Umetanje se unutar vrijednosti razvija u drugom trenutku nego što biste očekivali, i obitelj to
zabranjuje. Stavljajte `#include` u zaseban redak.

---

## Varijable

### `variable.undefined` — ova varijabla nigdje nije definirana

```
zdravo, %name%  →  Zdravo, %name%
```

Upozorenje, a ne greška: motor ispisuje ime kako jest. Tako je i zamišljeno — vrijednost može doći
izvana, od programa domaćina. U Studio se takve vrijednosti predaju na kartici «Varijable», u
odjeljku **Vrijednosti sesije**.

**Vrijednost definicije može se mijenjati u ploči.** Stanite u gornjem dijelu na stupac «Vrijednost»
i pritisnite **F2** (ili jednostavno počnite tipkati); **Enter** primjenjuje, **Esc** odustaje.
Izmjena ide **u dokument**, jednim korakom opoziva: `Ctrl+Z` je vraća natrag.

Ime i vrsta (`#set` ili `#def`) ne podliježu izmjeni — i to je odluka, a ne nedovršen kut.
Preimenovanje iz ćelije kida sve spomene varijable u dokumentu, a brisanje retka nosi sa sobom
komentar i uvlaku. I jedno i drugo pripada tekstu, gdje vidite što radite.

Mijenja se **baš vrijednost**. Uvlaka, višak razmaka, veličina slova u imenu i komentar na kraju
retka ostaju kakvi su bili: `   #set  %Brand%   =   Acme   /# rep #/` vraća se iz izmjene razlikujući
se samo u `Acme`. Datoteka leži u gitu, i preformatirati redak značilo bi prikazati to tamo kao vašu
izmjenu.

**Odbijanje znači da bi motor pročitao redak drukčije.** Izmjena se ne primjenjuje šutke: motor
ponovno čita rezultat, i ako on kaže nešto drugo od traženog, dokument se ostavlja na miru, a statusni
redak o tome javlja. Tri stvarna razloga: `/#` u vrijednosti otvara komentar koji pojede ostatak
datoteke; prelom retka završava direktivu prerano; a komentar **unutar** direktive čini redak
neispravnim po dijelovima — taj mijenjajte u tekstu.

**Dva poteza na imenu varijable.** Ime je u ploči poveznica, a ne natpis:

- **klik na ime** vodi pokazivač do prvog mjesta gdje dokument koristi tu varijablu, i redak na tren
  bljesne. Ista riječ unutar komentara ili kao cilj `#include` **ne** računa se: ploča vas vodi tamo
  gdje varijabla stvarno radi.
- **Ctrl+klik** upisuje definiciju u dokument i otvara na njoj uređivač grupa. Vrijednost koju ste već
  otipkali ulazi tamo kao prva mogućnost:

```
#set %brand% = {Vulkan}
kasino %brand%  →  Kasino Vulkan
```

Razlika je među njima ono što preživljava zatvaranje prozora. Vrijednost sesije ne preživljava: nema
je ni u datoteci ni u gitu, i nijedan je drugi motor obitelji ne vidi. Definicija preživljava, i samo
definicija utišava ovo upozorenje zauvijek. Jedan `Ctrl+Z` vraća dokument.

**Vrijednost je sesije najprije predložak, a ne tekst.** Upravo tako motor postupa sa svakom
vrijednošću domaćina, a pregled se mora podudarati s poslužiteljem — pa `{niska|visoka}` otipkano u
polje vrijednosti daje izbor, a ne te znakove. Ako ste mislili na sam tekst, kvačicom
označite **kao tekst** u trećem stupcu: tada vitičaste zagrade i postoci ostaju znaci.

### `variable.self-reference` — definicija upućuje sama na sebe

```
#set %x% = a %x% b
%x%  →  A a a … %x% … b b b
```

Pedeset razina, potom zaustavljanje. Motor razvija do granice dubine i staje, ostavljajući `%x%` u
sredini. To nije krug, i nije ono što ste htjeli.

`…` je gore kratica ovog dokumenta, a ne motora. Stvarni izlaz ima 207 znakova i nosi sa svake strane
**pedeset jedno** slovo, a ne pedeset: pedeseta razina staje i ostavlja vrijednost kako jest, a u
vrijednosti je svakog po jedno više.

### `variable.circular-reference` — definicije upućuju u krug

```
#set %x% = %y%
#set %y% = %x%
%x%  →  %y%
```

Svaka se strana razvija točno **jednom** i staje: `%x%` je postao `%y%`, a ne `%x%`. Motor odmotava
krug, a ne hoda po njemu, i preživljava drugo ime iz kruga — stavite u dokument `%x% %y%` i on će
dati `%y% %x%`, par naopako.

Ploča iscrtava redak za **svaki spomen koji zatvara krug**, a ne jedan po krugu i ne jedan po
definiciji. Definicija koja krug imenuje dvaput dobiva dva retka na svom retku: `#set %x% = %y% %y%`
prema `#set %y% = %x%` — to su tri greške, dvije od njih na prvom. Redci se ne slijevaju. A položaj
pada na definiciju koja stvarno djeluje: ako je ime zadano dvaput, to je **posljednja**.

---

## Umetanja

### `#include` radi samo s početka retka

```
prije #include "frag" poslije  →  Prije #include "frag" poslije
```

```
#include "frag"  →  Ulomak
```

Nijedna dijagnostika, i u tome je cijela poanta: `#include` usred retka umetanje **nije**. Motor ga
čita kao običan tekst i ništa ne kaže, jer nema na što se žaliti — napisali ste tekst i dobili tekst.

**A cilj ipak može stajati redak niže**, i to iznenađuje s druge strane. Razmak koji motor dopušta
između riječi i cilja uključuje prelome redaka, pa je to jedno umetanje, i ono radi:

```spx-good
#include
"frag"  →  Ulomak
```

Prazni su redci između njih također dopušteni. Nije dopušteno sve ostalo: riječ ispred cilja ili bilo
što osim razmaka iza njega — i sve ponovno postaje tekst. Uređivač boji cilj u njegovu vlastitom
retku, a samu riječ ostavlja običnom dok cilj nije došao: on ne obećava direktivu čiji kraj još ne
vidi.

### `include.unknown-target` — takvog cilja u skupu nema

```
#include "nema"  →  (prazno)
```

Ciljevi su `.spintax` datoteke u mapi otvorenog dokumenta. Nepoznat se cilj razvija u ništa: odlomak
nestaje, a ne puca, i upravo je zato to tako lako previdjeti.

**Zbog toga na kartici «Varijable» postoji treći odjeljak, «Uključivanja».** On nabraja svaki `#include`
dokumenta i za svaki — ima li skup njegov cilj; po jedan redak po pojavljivanju, pa cilj imenovan
dvaput daje dva retka. Odjeljak se pojavljuje samo onda kada u dokumentu ima umetanja. Klik na redak
vodi pokazivač do onog `#include` koji imenuje taj cilj.

Oznaka ima **tri** značenja, i treće je važno: «nema skupa» nije «odlomak nedostaje», nego «zasad
nema gdje tražiti». Skup je mapa pored dokumenta, a nespremljen dokument mapu nema; pa je do prvog
spremanja svaki cilj označen upravo tako. «NEDOSTAJE» se pojavljuje samo onda kada mapa postoji, a
datoteke u njoj stvarno nema.

### `note.case-mismatch` — cilj postoji, ali u drugoj veličini slova

```
#include "intro"  →  (prazno)
```

Skup sadrži `Intro.spintax` — a motor svejedno kaže da takvog cilja nema, dok Studio dodaje svoju
napomenu o veličini slova. Veličina je slova važna: `intro` i `Intro` različiti su ciljevi. Windows bi
otvorio datoteku i ovako i onako, i upravo zato Studio gleda u skup, a ne u datotečni sustav: inače bi
pregled proturječio poslužitelju o istom dokumentu.

### `note.cycle` — umetanje u krug

Ako `loop.spintax` i sam sadrži `#include "loop"`, onda:

```
#include "loop"  →  (prazno)
```

Motor podmeće prazninu umjesto beskonačnosti. Napomena je potrebna da biste razumjeli zašto je odlomak
nestao.

Redak je ispisan na **`loop`**, a ne na dokument u koji gledate: krug pripada odlomku, i tamo ide
pokazivač pri kliku. U otvorenom dokumentu ništa nije podcrtano, jer je s retkom koji ste vi napisali
sve u redu.

---

## Oblici množine

### `plural.arity` — oblika nema onoliko koliko lokal zahtijeva

```
#set %n% = 5
%n% {plural %n%: objekt|objekta}  →  5 ｛plural 5: objekt|objekta｝
```

**Nije praznina — motor ispisuje cijelu konstrukciju**, zamijenivši zagrade širokima `｛｝`. Tako on
kaže «ovo sam vidio i nisam mogao primijeniti». Neprimjetnim to nitko neće nazvati, i to je dobro:
odlomak koji je nestao šutke tražio bi se dulje.

Hrvatskom trebaju tri oblika, engleskom — dva. Pod lokalom ovog dokumenta ispravno je
`{plural %n%: objekt|objekta|objekata}`.

**Praznina nastaje iz drugog razloga, i ta se dva lako pomiješaju.** Usporedite ova dva, koja se
razlikuju samo po broju oblika:

```
{plural %n%: objekt|objekta|objekata}  →  (prazno)   tri oblika: ispravno za hrvatski
{plural %n%: objekt|objekta}  →  (prazno)   dva oblika: neispravno za hrvatski
```

Oba ne ispisuju ništa, a ploča se prema njima odnosi drukčije: prvi povlači samo
`variable.undefined`, drugi povlači i `plural.arity`. Dakle, **praznina nije znak greške u broju
oblika** — ovdje je ona otuda što `%n%` nije definirano, a motor provjerava brojač prije nego što
broji oblike, pa staje još prije nego što se pitanje o broju postavi.

Upravo zato primjer na početku ovog članka najprije definira `%n%`. Bez toga bi izlaz bio prazan pri
bilo kojem broju oblika i o broju ne bi pokazao ništa.

Ploča i izlaz ovdje govore o različitom, i to nije proturječje: redak u ploču stavlja **provjera**,
koja broji oblike u tekstu i do brojača joj nije stalo; prazninu daje **odigravanje**, koje ima svoj
redoslijed. Dajte brojaču broj, kao u prvom primjeru, i vidjet ćete što broj oblika stvarno radi.

### `plural.count-macro` — brojač uzima vrijednost iz `#set`-a, a taj izvlači iznova pri svakom spomenu

```
#set %n% = {1|2}
%n% {plural %n%: objekt|objekta|objekata}  →  1
```

Pogledajte što je preživjelo: **broj je ispisan, a imenica nije.** Brojač mora biti broj u trenutku
kada se bira oblik, a `#set` čija je vrijednost i sama izbor brojem ne postaje nikada — motor podmeće
vrijednost **ne odigravajući je**, pa na mjesto brojača leži doslovan tekst `{1|2}`. Brojač i oblik ne
mogu proturječiti jedan drugome; motor umjesto toga ispušta riječ.

`#def` se ponaša drukčije i razvija svoju vrijednost jednom po odigravanju, pa mjesto brojača dobiva
broj:

```
#def %n% = {1|2}
%n% {plural %n%: objekt|objekta|objekata}  →  1 objekt
```

Za to u ploči nema nijednog retka. Otuda i pravilo: radite brojač jednostavnim brojem ili `#def`-om,
nikada `#set`-om.

### `plural.nested-brackets` — zagrade unutar oblika

```
{plural %n%: {objekt|stvar}|objekta|objekata}  →  ｛plural %n%: ｛objekt|stvar｝|objekta|objekata｝
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

**Ako pored stoji pravi ključ, izlaz je sasvim drukčiji** — i to je vjerojatnija greška: jedan je ključ
od nekoliko otipkan pogrešno:

```
[<sep=", ";foo=1>a|b|c]  →  B, c, a
```

Blok ostaje postavka, `sep` se izvršava, nepoznat se ključ prosto odbacuje, a ploča u oba slučaja kaže
jedno te isto. Dakle, dijagnostika javlja da ključ nije shvaćen; ona ne javlja što se dalje dogodilo.
O tome čitajte izlaz.

### `permutation.minsize-not-integer` — minimum nije zadan cijelim brojem

```
[<minsize=dva>a|b|c]  →  B c a
```

Nebrojčana vrijednost otpada zajedno sa svojom granicom, i vrijedi uobičajeno — dakle svi komadi.

### `permutation.maxsize-not-integer` — maksimum nije zadan cijelim brojem

```
[<maxsize=mnogo>a|b|c]  →  B c a
```

Točno isto s drugog kraja: gornja granica nestaje, i izlaz opet sadrži svaki komad.

---

## Studio napomene koje nemaju što pokazati

Tri napomene ispod ne mogu se prikazati primjerom u ovom dokumentu, i razlog je svaki put drugi i
imenovan. Članak ipak imaju: pomoć duguje odgovor **svakom** retku koji ploča može prikazati, inače
redak u ploči vodi u prazno.

### `note.raw-sentinel` — službeni znak u tekstu

Znakovi U+E000–U+E005 jesu ono čime motor obilježava svoje, i on ih **uklanja** prije razlaganja. Ako
su dospjeli u vaš predložak — uglavnom nalijepljeni iz drugog uređivača — Studio o tome javlja: neće
ih prikazati ni pregled ni poslužitelj.

Primjera ovdje namjerno nema: ti su znakovi nevidljivi, i redak bi s njima izgledao prazan. Ne bi
imalo što gledati.

### `note.unknown-target` — skup je prazan, i nema se po čemu suditi

Ona se pojavljuje kada je skup pored dokumenta **prazan**: nijedan predložak osim ovog. Cilj nema s
čime usporediti, pa Studio ne kaže «takvog cilja nema» — ono kaže da ne može odgovoriti. Stavite u tu
mapu jedan jedini predložak i napomena će ustupiti mjesto uobičajenom `include.unknown-target`, koji
odgovara suštinski.

Nikada spremljen dokument nema skup **uopće**, i to je treći slučaj, a ne ovaj: umetanja tada ostaju u
izlazu doslovno, a ploča o njima ne kaže ništa. Spremite dokument i ona će početi raditi.

Primjera ovdje nema po konstrukciji: skup je ovog dokumenta imenovan gore, i nije prazan.

### `note.too-deep` — umetanja su ugniježđena preduboko

Motor staje na dvadesetoj razini ugniježđenih `#include` i niže ne podmeće ništa. Granica pripada
obitelji: motori za JavaScript, PHP i Python rade isto, pa se dokument koji u nju udari ponaša svugdje
jednako.

Primjera nema zbog veličine: prikazati jedan koštalo bi dvadeset jednu datoteku.

---

## Tišina koju susreću svi: kratice

### Kratica ostavlja sljedeću riječ malom

```
dr. Marić naše cijene su niske  →  dr. Marić naše cijene su niske
Xxx. naše cijene su niske  →  Xxx. Naše cijene su niske
```

Dva retka koja se razlikuju u jednoj riječi, i druga riječ svakog daje vam pravilo: nakon `dr.`
rečenica ostaje mala, nakon `Xxx.` — velikim slovom. Motor stavlja veliko slovo nakon točke — osim
nakon kratice koju zna, i nakon svega poput `e.g.` ili `d.o.o.` On šuti: nijedna dijagnostika, nijedno
upozorenje, i jedini je način da se primijeti pročitati izlaz.

**Popis nije hrvatski ni engleski.** U njemu je 46 unosa, i 29 ih je ruskih:

| | |
|---|---|
| latinični | `etc vs mr mrs ms dr prof sr jr inc ltd co corp no st ave blvd` |
| ćirilični | `соц эл см ср ст ул пр пер г р руб коп тыс млн млрд трлн доп напр прим изд обл респ стр табл рис мин макс тел факс` |

Obje polovice vrijede u **bilo kojem** lokalu — pravilo nikada ne pita koji ste jezik postavili. Tako
`ltd.` zaklanja sljedeću riječ u hrvatskom dokumentu, a `г.` je zaklanja u engleskom.

Za hrvatski tekst posljedica je pomiješana: naslovi rade jer stoje na latiničnoj polovici — `dr.`,
`prof.`, `mr.` — a `br.`, `npr.`, `itd.`, `tzv.`, `g.`, `ul.`, `str.` i `tel.` na popisu ne postoje i
završavaju rečenicu. Jezični priručnik dodaje da kratica od više točaka radi u vašu korist, pa
`d.o.o.` prolazi cijelo, i da je gola domena zaklonjena jer je pisana latinicom — a ćirilična nije.

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
%n% {plural %n%: artikl|artikla|artikala}  →  5 artikala
```

```spx-good
prije /# bilješka #/ poslije  →  Prije poslije
```

Pet konstrukcija, pet čistih redaka: izbor, miješanje s postavkama, uvjet, oblik množine s brojem
ispred njega i komentar. Nijedna ne stavlja u ploču ništa.

---

## Često pitaju

**Zašto je odlomak prosto nestao?**
Dva česta razloga, oba gore: nepoznat cilj `#include` i umetanje u krug. Oba daju prazninu. Treći, na
koji se najčešće pomisli — pogrešan broj oblika — prazninu **ne** daje: motor ispisuje konstrukciju u
cijelosti u širokim zagradama `｛｝`. Prazninu tamo daje nebrojčan brojač, a ne broj oblika.

**Zašto moja varijabla s kvačicom u imenu ne radi?**
Imena su varijabli samo ASCII latinica. `%šifra%` motoru uopće nije spomen varijable: on ga ispisuje
kao tekst i **ne izdaje nijednu dijagnostiku**:

```
zdravo, %šifra%  →  Zdravo, %šifra%
```

Usporedite s `%sifra%`, koje redak u ploči ipak povlači. Šutljivo je baš prvo — ništa vam neće reći da
se ono nikada neće podmetnuti. A `#set %šifra% = tajna` već je `set.malformed`. Vrijednosti su pritom
bilo kakve: `#set %grad% = Đakovo` sasvim je normalno.

**Zašto je ista greška prikazana dvaput?**
Krug definicija povlači redak za svaki spomen koji ga zatvara — dva različita mjesta, ponekad tri. To
nisu duplikati, i oni se ne slijevaju.

**Zašto u ploči piše «greška», a izlaz izgleda ispravno?**
Tako biva pri ponovnoj definiciji: odigravanje je korektno — pobjeđuje posljednja vrijednost — ali
dokument je dvosmislen. Presuda je o dokumentu, a ne o konkretnom izlazu.

**Prebacio sam lokal i u dokumentu se pojavila greška. Što sam pokvario?**
Ništa. Broj je oblika svojstvo JEZIKA: engleskom trebaju dva (`page|pages`), hrvatskom tri
(`artikl|artikla|artikala`). Tekst pisan za jedan jezik pri prebacivanju lokala postaje neispravan za
drugi, i motor o tome pošteno kaže. Tako se ponaša i demonstracijski dokument s kojim se Studio
otvara: on je engleski, i na lokalu `hr` njegovo `{plural %pages%: page|pages}` već je greška.

**Podudara li se pregled s onim što će dati moj poslužitelj?**
Na istom motoru, istoj verziji, istom lokalu i s istim vrijednostima — da, točno, i upravo zato pregled
goni pravi `spintax-win`, a ne približenje. Na **drugom** motoru obitelji — za JavaScript, PHP ili
Python — prenosi se presuda i skup tekstova koje predložak može dati, ali ne i to koji će od njih
izvući konkretno sjeme. Ponoviti baš to izvlačenje obitelj ne obećava.
