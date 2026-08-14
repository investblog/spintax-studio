# Spintax Studio

Ovaj program je uređivač predložaka. Predložak je običan tekst s nekoliko označenih mjesta u njemu,
i jedan predložak može dati vrlo mnogo različitih tekstova; upravo se zato i piše, umjesto da se
tekstovi pišu jedan po jedan.

Prozor se sastoji od dvije polovice. Lijevo je vaš predložak, ono što uređujete. Desno je jedan od
tekstova koji iz njega izlaze, iznova iscrtan dok tipkate. Između njih nema što pritisnuti: ono što
vidite desno jest ono što motor u ovom trenutku vraća za ono što je napisano lijevo.

```spx-fixture
locale: hr
seed: 7
empty: (prazno)
```

Motor je ugrađen u ovaj program i Pascal je član obitelji: isti je jezik izdan i za JavaScript, PHP
i Python. Ta su četvorica samostalni programi koji se drže jednog zajedničkog skupa provjera, pa je
ono što predložak ZNAČI isto u svima: konstrukcije, presuda o njegovoj ispravnosti, završno
dotjerivanje. Predložak koji ovaj prozor nazove ispravnim ispravan je i tamo.

Ono što nije obećano, a razlika je važna pri usporedbi: izvlačenje. Sjeme čini pregled ponovljivim
OVDJE — isto sjeme i isti predložak sutra daju isti tekst — ali isto sjeme u JavaScript motoru može
izvući drugu varijantu. Sjemena služe da ponovite vlastiti rad, a ne da pogodite drugi motor.

Sve ovdje radi bez mreže. Nema računa, nema prijave i nema što uključivati: otvorite program i on
radi.

## Dvije polovice

Tipka se lijevo. Desna se polovica iznova iscrtava nakon kratke stanke, da pregled stiže za
rečenicom, a ne za svakim slovom.

Predložak s izborom unutra nema jedan odgovor, i pregled pokazuje jedan od njih:

```spx-good
{Bok|Pozdrav} svima.  →  Bok svima.
```

**Druga** iznad desne polovice daje sljedeću. Ako vam treba uvijek ista — dok uspoređujete dvije
izmjene, recimo — kvačicom označite **seed**, i pregled će stajati dok je ne skinete ili ne
promijenite broj.

Prebacivač iznad desne polovice nudi **Stranica** i **Izvor**. Predlošci su uglavnom HTML, i dva pitanja
«kako ovo izgleda» i «kakva je razmetnica ispala» ne odgovaraju jedno na drugo: pokvaren tag daje
malo krivu stranicu koju oko preskoči, a proza s tagovima unutra ne čita se kao proza. Prebacivač
iznad polovice mijenja ono u što gledate.

Označite dio predloška i odigrat će se samo on, u okviru cijelog dokumenta, pa odlomak koji koristi
varijablu definiranu gore izlazi onako kako izlazi na svom mjestu.

## Traženje i zamjena

Pritisnite **Ctrl+F** — u zaglavlju se otvara polje pretrage. Brojač pokraj njega kaže
koliko se puta tekst javlja i na kojem ste pojavljivanju; **Enter** korača naprijed,
**Shift+Enter** natrag, F3 radi izravno iz dokumenta. Velika i mala slova ne broje se dok se
ne uključi kućica uz polje — a slova sklapa motor, pa se ćirilično ili naglašeno slovo
poklapa sa svojim parom točno ondje gdje ih i pretpregled drži jednim slovom.

Pritisnite **Ctrl+H** — ili stavku izbornika **Zamijeni…** — i traka dobiva drugi red:
zamjenu i dva gumba. **Zamijeni** mijenja pojavljivanje na kojem stojite i korača na
sljedeće; dok ništa nije nađeno, prvi pritisak samo traži. **Zamijeni sve** prolazi cijeli
dokument odjednom, a statusna traka kaže koliko se mjesta promijenilo; jedan Ctrl+Z vraća
cijeli prolaz.

Zamjena je doslovna. Može biti prazna — to briše — i može sadržavati traženi tekst, a da
prolaz ne uđe u krug: mjesta se odlučuju unaprijed, nad tekstom kakav je bio. Kad se
pojavljivanja preklapaju, brojač broji svako koje korak može posjetiti, ali prolaz mijenja
samo ona koja ne dijele slova — pa „zamijenjeno“ može pošteno reći manji broj.

Zamijenjeni dokument prolazi isti put motora kao i otipkani: pretpregled se iscrtava iznova,
a dijagnostika odgovara o onome što sada stoji.

## Ploče dolje

Traka alata sa strane otvara četiri ploče, po jednu u isto vrijeme.

**Dijagnostika** nabraja ono što motor smatra pogrešnim, svaki put s retkom i stupcem gdje počinje.
Klik na redak vodi pokazivač tamo. To je ista presuda koju motor donosi svugdje, a ne drugo
mišljenje uređivača — zato predložak koji ova ploča nazove ispravnim prihvaćaju i ostali motori.

**Varijable** pokazuju imena koja vaš dokument definira i ona koja samo koristi. Ime koje on koristi
a ništa ne definira može se popuniti ovdje za ovu sesiju: upišite vrijednost pored i pregled će je
pokupiti. Kvačicom označite **kao tekst** kada je vrijednost tekst koji znači sam sebe, a ne mali
predložak.

**Varijante** rade mnogo tekstova odjednom. Recite koliko, napravite ih i pročitajte u popisu prije
izvoza. Gotovo iste mogu se odbacivati već tijekom izrade, a seed čini cijeli skup ponovljivim: isto
sjeme i isti predložak sutra daju iste varijante.

Pored tih polja ploča kaže koliko varijanti predložak uopće može dati: `{a|b} i {c|d}` daje četiri.
Taj vam broj javlja da je predložak siromašan još prije nego što napravite pedeset i to primijetite
čitanjem.

Točan je samo dok svaki izbor ostaje slučaju. Uvjet, oblik množine ili `#include` čiji cilj skup
nema rješava nešto drugo — vrijednost koju ćete podmetnuti, broj, odlomak koji tek može doći — i
tada ploča kaže **najmanje**. To je poštena riječ: podmetnuta vrijednost može samo dodati tekstove,
a ne oduzeti ih. Broj prevelik da bi se čitao staje na bilijunu i kaže **najmanje** iz istog
razloga.

Varijanta je jedan popunjen predložak, po jedan izbor u svakoj konstrukciji, i to nije isto što i
tekst koji se drukčije čita. `{a|a}` su dvije varijante i jedan tekst, i tako je zamišljeno: dvije
mogućnosti mogu prestati podudarati se nakon prve izmjene, a da bi se svele, morale bi se najprije
napraviti sve kombinacije — upravo onaj posao radi čije uštede broj i postoji. `#def` se računa
isto: motor ga izvlači jednom po odigravanju, koristila ga izabrana grana ili ne.

Izvoz ih čuva na tri načina: kao XLSX radnu knjigu, kao običan tekst s po jednom varijantom u retku
ili kao po jednu datoteku po varijanti u mapu koju odaberete.

**AI nacrt** je ono čime predložak počinje kad ne želite ispisivati svaku varijantu
rukom. Opišite što tražite u zadatku, navedite varijable koje model smije koristiti i pritisnite
**Kopiraj upit**. Program se nikamo ne obraća i ne čuva ključeve: on sastavlja upit da ga odnesete
modelu kojim se već služite. Vratite odgovor i pritisnite **Umetni u dokument** — motor u ovom prozoru
tada kaže što o njemu misli, u ploči dijagnostike, jednako kao i o bilo kojem tekstu koji sami
utipkate. Ako ima pogrešaka, **Kopiraj upit za popravak** sastavlja drugi upit: nosi cijeli dokument s numeriranim recima i imenuje upravo ona mjesta
na koja se motor požalio. Odgovor je ispravljeni dokument u cijelosti, pa ga vratite i
pritisnite **Zamijeni dokument**: **Umetni u dokument** ostavio bi pokvareni gdje jest i
pokraj njega stavio ispravljenu kopiju.

Stupac padeža dio je koji vrijedi popuniti. Varijabla se unosi doslovno, ništa je ne mijenja po
padežima, pa se u jeziku s padežima rečenica mora graditi oko oblika koji vrijednost već ima, a
model bira točno samo ako mu se kaže koji oblik drži svako ime. Iz imena se to ne može izvesti:
u jednom stvarnom skupu predložaka instrumental je stajao u varijabli čije je ime govorilo
akuzativ.

## Uređivač grupa

Stavite pokazivač unutar `{a|b|c}` i otvorite uređivač grupa s trake alata. On nabraja varijante po
retcima: mijenjajte ih, dodajte jednu, uklonite drugu — i dokument se prepisuje u skladu s tim.

On odbija izmjene koje bi promijenile ono što grupa ZNAČI, a ne ono što kaže: `|` otipkan unutar
varijante napravio bi od jedne mogućnosti dvije, a `}` bi zatvorio grupu prerano. Kada odbije, kaže
to i ostavlja dokument na miru.

## Postavke

One su u izborniku «Prikaz», i svaka se pamti između sesija: jezik sučelja i prati li predložak, s
koje je strane traka alata, tema, font uređivača i njegova veličina, pokazuje li pregled stranicu
ili izvor, prebacivač za GSA uvoz, koja je ploča otvorena i širine ploča koje se izvlače.

Sučelje govori četrnaest jezika, izbor je na istom mjestu. To je odvojeno od jezika vašeg predloška,
koji rješava oblike množine i zadaje se iznad desne polovice.

## Uvoz GSA predloška

Ovaj je dio isključen dok ga ne uključite, u **Prikaz**, **GSA uvoz**, jer većina onih koji pišu
predloške nikada nije koristila GSA Search Engine Ranker. Uključeno, **Datoteka**, **Uvezi GSA predložak…** čita SER predložak i prevodi ga na ovaj jezik.

Pretvaranje je oprezno na određen način. Ono što ne može prenijeti točno, ono odbija i kaže vam o
tome, umjesto da tiho pretvori u nešto što će se odigrati. Konstrukcije koje bi se pogrešno
pročitale da ostanu u tekstu — BBCode zagrade, `#` unutar poveznice, makro `#file[...]` — iznose se
u varijable, i rezultat kaže koliko.

Dvije stvari o rezultatu:

- **Iznesene vrijednosti su vrijednosti sesije.** One se pojavljuju u ploči «Varijable» i ne čuvaju
  se uz dokument. Spremite pretvoren predložak, otvorite ga sutra — i vidjet ćete `%…%` tamo gdje je
  stajao iznesen tekst. Iz uvezene datoteke ništa nije izgubljeno — ona ostaje netaknuta — ali
  pretvoren dokument nije samodostatan.
- **On se odigrava bez prolaza dotjerivanja.** Svaki drugi dokument ovdje dobiva završne poteze
  opisane u jezičnom priručniku; pretvoren predložak — ne, jer to nije naš tekst da ga glačamo. On
  je tuđ, najčešće na putu natrag prema GSA, i mora preživjeti znak po znak.

Uvezen dokument je bez naslova i nije spremljen, kao nov. Datoteka koju ste odabrali ostaje točno
onakva kakva je bila.
