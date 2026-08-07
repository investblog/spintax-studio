# Jezik, konstrukcija po konstrukcija

Šablon je običan tekst s nekoliko označenih mjesta u njemu. Sve što nije označeno izlazi kako jeste;
upravo oznake daju šablonu mogućnost da dâ mnogo tekstova.

Ima ih šest, i to je cijeli jezik: **izbor** između varijanti, **miješanje** nekoliko komada,
**makro** koji definišete jednom i koristite po imenu, **uvjet**, **brojanje** koje uzima potreban
oblik riječi, i **umetanje** koje unosi drugi šablon. Komentari su sedma oznaka, koja ne daje baš
ništa.

> Svaki primjer ispod prolazi kroz motor s kojim je sklopljena ova kopija Studio, pri svakom
> sklapanju programa, i desno stoji tačno ono što je on vratio. Ovdje ništa nije upamćeno ni
> pogođeno; odgovor koji bi prestao biti istinit zaustavio bi sklapanje. Verzija motora je u
> **Pomoć**, **O programu**.

Drugi dokument ove pomoći, **Šta kaže kartica «Dijagnostika»**, govori o onome što ide naopako. Ovaj
govori o tome šta konstrukcije rade kada je sve u redu, uključujući nekoliko mjesta gdje šablon
uradi nešto neočekivano i ništa o tome ne javi.

## Kako čitati primjere

Strelica `→` razdvaja šablon od onoga što je motor vratio. `(prazno)` znači da nije ispisao ništa.
Tekst nakon izlaza, odvojen s tri razmaka, napomena je, a ne dio odgovora.

Uvjeti su imenovani, a ne podrazumijevani, jer se bez njih polovina odgovora ispod ne može ponoviti:

```spx-fixture
locale: bs
seed: 7
empty: (prazno)
include intro: Dobro došli u {Acme|Globex}.
include shout: %brand% je ovdje.
```

`seed` učvršćuje izvlačenje. Šablon s izborom unutra nema jedan odgovor, pa bi primjer bez sjemena
ispisivao svaki put drugo i ne bi bilo šta provjeriti. U prozoru je to kućica **seed** iznad desne
polovine; označite je i pored će se pojaviti polje za broj, a pregled će stajati dok radite.

`locale` rješava oblike množine, i to je prebacivač iznad desne polovine, a ne jezik sučelja.
Bosanskom, hrvatskom, srpskom, ruskom, ukrajinskom i bjeloruskom trebaju tri oblika; engleskom —
dva.

## Izbor

Vitičaste zagrade s `|` između: motor uzima **jedan**.

```spx-good
{Mala|Velika} soba.  →  Mala soba.
```

Izvlačenje je slučajno, pa će isti šablon drugi put dati `Velika soba.` Sam izbor ne dira tekst oko
sebe — iako dotjerivanje, opisano bliže kraju ovog dokumenta, do njega dopire.

### Ugniježđenost

Izbor može sadržavati drugi izbor, na bilo koju dubinu.

```spx-good
Acme {Pro {Plus|Max}|Lite}  →  Acme Pro Plus
```

Unutrašnji se izbor pravi samo onda kada vanjski uzme granu u kojoj on stoji: ako je ispalo `Lite`,
`Plus|Max` se uopće ne pita — i to je mjerljivo: od njega se ne traži ni slučajan broj.

### Prazna mogućnost

Mogućnost može biti prazna. To je uobičajen način da se nešto pojavljuje samo ponekad.

```spx-good
{|Vrlo }velika soba.  →  Velika soba.
```

Pisati razmak unutar mogućnosti, `{|Vrlo }` umjesto `{|Vrlo} `, navika je, a ne zahtjev:
dotjerivanje svejedno svodi dvostruki razmak na jedan.

## Miješanje

Uglaste zagrade uzimaju nekoliko komada, biraju koliko, stavljaju ih u slučajan redoslijed i
spajaju.

```spx-good
[plava|žuta|siva]  →  Žuta siva plava
```

Prepušteno sebi uzima sve i spaja jednim razmakom. Sve ostalo o miješanju zadaje se u bloku `<…>`
odmah nakon otvorene zagrade.

### Razdjeljivač

```spx-good
[<, >plava|žuta|siva]  →  Žuta, siva, plava
```

Blok `<…>` i jeste razdjeljivač, osim ako ne **imenuje postavku**: jednu od `sep`, `lastsep`,
`minsize` ili `maxsize`, zasebnom riječju i sa znakom `=` iza nje. Sve ostalo na tom mjestu jeste
razdjeljivač, ma koliko ličilo na postavku; ključ bez svog `=`:

```spx-good
[<maxsize 2>plava|žuta|siva]  →  Žutamaxsize 2sivamaxsize 2plava
```

ili ključ kojem je sprijeda nešto zalijepljeno:

```
[<xmaxsize=1>plava|žuta|siva]  →  Žutaxmaxsize=1sivaxmaxsize=1plava
```

Drugi zaslužuje drugi pogled: ploča **ipak** naziva `xmaxsize` nepoznatim ključem, a motor svejedno
ispisuje cijeli blok između komada. Dijagnostika i izlaz odgovaraju na različita pitanja.

Kada trebaju dva različita razdjeljivača, postavke se pišu u cijelosti:

```spx-good
[<sep=", ";lastsep=" i ">plava|žuta|siva]  →  Žuta, siva i plava
```

`sep` ide između komada, a `lastsep` — ispred posljednjeg.

### Koliko uzeti

```spx-good
[<minsize=2;maxsize=2>plava|žuta|siva]  →  Žuta siva
```

`minsize` je donja granica, `maxsize` gornja; broj je između njih slučajan, kao i redoslijed.
Jednake vrijednosti uzimaju tačno toliko. **Bez oba — sve, ali sa samo `maxsize` donja je granica
jedan**, i to iznenađuje:

```spx-good
[<maxsize=3>a|b|c]  →  C
```

Tri komada, plafon tri, a ispao je jedan. Kada se misli «sve, ali ne više od tri», pišite i
`minsize`. `maxsize` veći od broja komada tiho se smanjuje na njega. `minsize` veći od `maxsize`
prihvata se bez ijedne riječi, i pobjeđuje donja granica: plafon se podiže do nje, a ne obrnuto:

```spx-good
[<minsize=3;maxsize=1>plava|žuta|siva]  →  Žuta siva plava
```

### Razdjeljivač između dva komada

`<…>` napisan **između** dva komada razdjeljivač je tog para.

```spx-good
[plava|žuta<i>|siva]  →  Žuta i siva plava
```

On pripada komadu **poslije** sebe i putuje s njim kroz miješanje, pa iskrsne tamo gdje taj komad
legne, a ne na stalnom mjestu izlaza. `<…>` poslije **posljednjeg** komada uopće nije razdjeljivač i
ispisuje se kao tekst:

```spx-good
[plava|žuta|siva<i>]  →  Žuta siva<i> plava
```

## Makroi

`#set` daje ime komadu teksta. Ime se koristi kao `%name%`, i direktiva mora biti prva u svom redu —
razmaci i tabulatori ispred nje dozvoljeni su, ništa više.

```spx-good
#set %grad% = Sarajevo
Grad: %grad%.  →  Grad: Sarajevo.
```

Imena se sastoje od latiničnih slova, cifara i `_`. Slovo s kvačicom slovom se ovdje ne smatra:
`%šifra%` nije ime i motor o tome ne kaže ništa — o toj tišini niže, u poglavlju o tišinama.

### `#set` izvlači iznova, `#def` izvlači jednom

To je sva razlika među njima, i vidi se samo onda kada vrijednost sadrži izbor.

```spx-good
#set %izbor% = {A|B}
%izbor% %izbor% %izbor%  →  A A B
```

```spx-good
#def %izbor% = {A|B}
%izbor% %izbor% %izbor%  →  A A A
```

Oba su primjera trčala pod istim sjemenom. `#set` čuva šablon i izvlači ga pri svakom pominjanju;
`#def` izvlači jednom i drži odgovor. Uzimajte `#def` za ono što se mora slagati samo sa sobom —
marka, grad, ime, količina — i `#set` za raznolikost.

Po jednom se sjemenu ne mogu razlikovati: postoje sjemena na kojima `#set` slučajno tri puta uzme
istu mogućnost i oba izgledaju isto. To vrijedi znati prije nego što iz jednog pregleda zaključite
da definicija ne radi.

## Uvjeti

`{?name?onda|inače}` pita ima li makro vrijednost.

```spx-good
#set %n% = 5
{?n?imamo %n%|još ništa}  →  Imamo 5
```

Polovina `inače` može se izostaviti — `{?name?onda}` ne ispisuje ništa kada je odgovor «ne». `!`
preokreće pitanje:

```spx-good
#set %vip% = 1
{?!vip?stranac|prijatelj}  →  Prijatelj
```

Imati vrijednost znači imati **barem jedan znak koji nije razmak**. Makro postavljen na ništa ili
samo na razmake smatra se bez vrijednosti.

Ime uvjeta mora **počinjati** slovom ili `_`, što je strože nego kod makroa — a odjeljak o tišini
kaže u šta se pretvara ime koje počinje cifrom.

## Brojanje

`{plural %n%: …}` uzima oblik riječi koji odgovara broju.

```spx-good
#def %n% = 1
%n% {plural %n%: dokument|dokumenta|dokumenata}  →  1 dokument
```

```spx-good
#def %n% = 2
%n% {plural %n%: dokument|dokumenta|dokumenata}  →  2 dokumenta
```

```spx-good
#def %n% = 5
%n% {plural %n%: dokument|dokumenta|dokumenata}  →  5 dokumenata
```

Brojač je ovdje namjerno `#def`, a ne `#set`, i pravilo vrijedi zapamtiti: **pravite brojač
jednostavnim brojem ili `#def`-om, nikada `#set`-om.** Sa `#set`-om na mjesto brojača dospijeva
sačuvan TEKST, `{5|5}`, a ne `5` — dakle ne broj — pa cijela konstrukcija ne daje ništa, a ploča
kaže `plural.count-macro`. Brojač i oblik ne mogu protivrječiti jedan drugom: umjesto toga nestaje
riječ.

```
#set %n% = {5|5}
%n% {plural %n%: dokument|dokumenta|dokumenata}  →  5
```

Koliko oblika, rješava lokal, a ne vi: pod `bs` ih je tri, pod `en` — dva. Pogrešan je broj greška o
kojoj ploča javlja (`plural.arity`), i motor tada ispisuje cijelu konstrukciju nazad, zamijenivši
zagrade širokim `｛｝` da se ne pomiješa s izlazom.

## Odlomci

`#include "name"` stavlja na to mjesto drugi šablon, i direktiva mora biti prva u svom redu — i
ovdje su razmaci i tabulatori ispred nje dozvoljeni.

```spx-good
#include "intro"  →  Dobro došli u Acme.
```

Odlomak se odigrava kao vlastiti šablon, pa se izbor unutar njega pravi iznova: `intro` sadrži
`{Acme|Globex}` i odgovara jednim ili drugim.

Ime se poredi **tačno**. `Intro` i `intro` dva su različita odlomka, i u Windowsu je tu lako
pogriješiti, jer fajl sistemu to nije važno. Cilj koji nedostaje odigrava se kao ništa, a ploča kaže
`include.unknown-target`; cilj koji se razlikuje samo po veličini slova dobija Studio napomenu s
imenom koje ste najvjerovatnije mislili.

### Odlomak ne vidi vaše makroe

On se odigrava kao vlastiti šablon: ima vrijednosti sesije, ali ne i `#set` i `#def` dokumenta koji
ga je unio.

```
#set %brand% = Acme
#include "shout"  →  %brand% je ovdje.
```

`shout` je `%brand% je ovdje.`, i ime mora biti definisano u samom odlomku. To nije tišina — ploča
ipak kaže `variable.undefined` — ali to kaže protiv **`shout`**, u redu 1 tog fajla, i u dokumentu u
koji gledate ne pojavljuje se nijedna valovita linija, jer položaj pripada drugom baferu. Čitajte
kolonu **Datoteka** kada se upozorenje naizgled tiče reda koji niste pisali.

## Komentari

`/# … #/` je komentar: sve između oznaka uklanja se prije svega ostalog.

```spx-good
nacrt /# nisam siguran #/ gotovo  →  Nacrt gotovo
```

Komentari se ne ugnježđuju. Prvi `#/` zatvara komentar, šta god bilo prije njega, pa se komentar
omotan oko teksta koji i sam sadrži `#/` završava ranije nego što izgleda.

## Šta motor poravnava na kraju

Izlaz nije baš onaj tekst koji su dale konstrukcije. Na kraju mu se desi nekoliko stvari; dvije
srećete svakodnevno.

Prvo slovo svake rečenice postaje veliko:

```spx-good
jedan. dva. tri.  →  Jedan. Dva. Tri.
```

Zbog toga primjeri u ovoj pomoći tako često odgovaraju velikim slovom tamo gdje je u šablonu malo.
Tačka nakon skraćenice koju motor zna ne završava rečenicu, i za bosanski su to upravo titule —
`dr.`, `prof.` i `mr.` svi su na latiničnoj polovini spiska:

```spx-good
dr. Hodžić naše cijene su niske  →  dr. Hodžić naše cijene su niske
```

Isto tako rečenicu ne završava ni skraćenica od više tačaka, pa `d.o.o.` prolazi cijelo:

```spx-good
Acme d.o.o. naše cijene su niske  →  Acme d.o.o. naše cijene su niske
```

Svaka druga riječ završava rečenicu, ma koliko kratka bila — dužina tu nema nikakve veze:

```spx-good
Xxx. naše cijene su niske  →  Xxx. Naše cijene su niske
```

Spisak koji motor zna ima 46 unosa, **29 ćiriličnih**, i drugi dokument prolazi kroz njega pod
naslovom **Tišina koju sreću svi**. Za bosanski tekst najvažnije je niže, u tišinama: spisak nije
sastavljen za bosanski.

Drugo je svakodnevno to da se nizovi razmaka svode na jedan. Upravo to dozvoljava da se ostavi
prazna mogućnost ne računajući razmake oko nje.

Ostalo u jednom dahu: razmak ispred `,;:!?.` uklanja se i ubacuje se jedan poslije; cijeli se izlaz
obrezuje po ivicama; veliko slovo dolazi i nakon preloma reda i nakon blokovskog taga, a ne samo
nakon tačke; a adrese sa shemom, poštanske adrese, goli domeni i decimalni brojevi zaklonjeni su i
izlaze tačno onako kako su otkucani.

Posljednje nosi istu ASCII granicu kao i skraćenice gore, i za bosanski radi u vašu korist: goli je
domen zaklonjen jer je pisan latinicom, dok `сайт.рф` nije i dotjerivanje unutra ubacuje razmak i
veliko slovo. Zbog toga i dvije riječi spojene tačkom prolaze netaknute — motor u njima vidi domen:

```spx-good
zdravo , svijete  →  Zdravo, svijete
```

```spx-good
jedan.dva  →  jedan.dva
```

## Tišina

Svaki se slučaj ispod odigrava, daje nešto drugo od onoga što izgleda, i ne povlači za sobom
**nijednu dijagnostiku**. Skupljeni su ovdje jer ih ništa drugo u prozoru nikada neće pomenuti.

**Bosanske skraćenice na spisku motora uglavnom ne postoje.** Titule su tamo — `dr.`, `prof.`,
`mr.` — ali `br.`, `npr.`, `itd.`, `tzv.`, `god.`, `odn.`, `sl.`, `g.`, `ul.`, `str.` i `tel.` nisu,
i svaki od njih završava rečenicu i sljedeću riječ piše velikim slovom:

```spx-good
npr. naše cijene su niske  →  Npr. Naše cijene su niske
```

**Slovo s kvačicom u imenu varijable slovom se ne smatra.** `%šifra%` motoru uopće nije pominjanje
varijable: on ga ispisuje kao tekst i ne kaže ništa:

```spx-good
zdravo, %šifra%  →  Zdravo, %šifra%
```

Razlog je isti kao gore: provjera «je li ovo sredina riječi» u motoru je ASCII provjera, i `š` za nju
nije slovo. U vrijednosti su kvačice sasvim na mjestu; u imenu ne rade uopće.

**`#include` koji ne stoji sam u svom redu običan je tekst.**

```spx-good
Prije. #include "intro"  →  Prije. #include "intro"
```

Isto vrijedi za direktivu s nečim iza nje i za `#include"intro"` bez razmaka. Pravilo pripada
porodici, a ne ovom motoru, i upravo ono čini direktivu prepoznatljivom bez razlaganja cijelog reda.

**Uvjet čije ime počinje cifrom uvjet nije.** On postaje običan izbor između `?1x?da` i `ne`:

```spx-good
{?1x?da|ne}  →  ?1x? Da
```

**`<…>` na početku komada koji nije prvi razdjeljivač nije** i ispisuje se kako stoji:

```spx-good
[plava|<i>žuta]  →  <i>Žuta plava
```

Blok na početku **prvog** komada upravo je razdjeljivač kojim počinje odjeljak o miješanju:

```spx-good
[<i>plava|žuta]  →  Žuta i plava
```

Bilo gdje nakon `|` on je običan tekst, a razdjeljivač između dva komada piše se na **kraju** prvog.

**Goli tag na kraju komada uzima se za razdjeljivač tog para** i ispisuje se vlastitim tekstom:

```spx-good
[jedan<br>|dva]  →  Dva jedan
```

Na ovom je sjemenu par legao drugim redoslijedom, pa razdjeljivač uopće nije ispao. S trećim komadom
ima gdje leći, i pojavljuje se:

```spx-good
[plava|žuta<br>|siva]  →  Žuta br siva plava
```

`<br>` stoji između `žuta` i onoga što slijedi, gdje god miješanje taj par postavilo. Zatvoreni tag
(`</b>`), samozatvoreni (`<br/>`), tag s atributima (`<br class="x">`) i tag usred komada ostaju
netaknuti.

**Nezatvoren komentar običan je tekst**: on ništa ne otvara, i `/#` se ispisuje:

```spx-good
prije /# ostatak ovoga  →  Prije /# ostatak ovoga
```

Ali on je i dalje polovina para. Ako se dalje u dokumentu pojavi `#/`, to će se dvoje pronaći i sve
između njih nestat će — zajedno s onim što je autor napisao među njima:

```
{a /# ups|b} sredina #/ rep  →  {a rep
```

Izbor je gore izgubio svoju drugu varijantu i zatvorenu zagradu, i nijedna dijagnostika o tome ne
govori: to je ono što tekst ZNAČI, a ne greška koju motor može vidjeti. Kada se `/#` misli doslovno,
sigurno je mjesto za njega vrijednost varijable, a ne tijelo šablona.

## Kuda dalje

Drugi dokument, **Šta kaže kartica «Dijagnostika»**, ima članak za svaki red koji ploča može
prikazati: šta znači, šta ga izaziva i šta motor radi sa šablonom dok taj red postoji. Pritisnite F1
dok je kursor unutar konstrukcije i pomoć će se otvoriti na odjeljku te konstrukcije **u tom
dokumentu**: vitičasta zagrada na **Zagradama**, `[…]` na **Miješanjima**, red `#set` na
**Definicijama**.
