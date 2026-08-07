# Spintax Studio

Ovaj program je uređivač šablona. Šablon je običan tekst s nekoliko označenih mjesta u njemu, i
jedan šablon može dati vrlo mnogo različitih tekstova; upravo se zato i piše, umjesto da se tekstovi
pišu jedan po jedan.

Prozor se sastoji od dvije polovine. Lijevo je vaš šablon, ono što uređujete. Desno je jedan od
tekstova koji iz njega izlaze, ponovo iscrtan dok kucate. Između njih nema šta pritisnuti: ono što
vidite desno jeste ono što motor u ovom trenutku vraća za ono što je napisano lijevo.

```spx-fixture
locale: bs
seed: 7
empty: (prazno)
```

Motor je ugrađen u ovaj program i Pascal je član porodice: isti jezik izdat je i za JavaScript, PHP
i Python. Ta četverica su samostalni programi koji se drže jednog zajedničkog skupa provjera, pa je
ono što šablon ZNAČI isto u svima: konstrukcije, presuda o njegovoj ispravnosti, završno
dotjerivanje. Šablon koji ovaj prozor nazove ispravnim ispravan je i tamo.

Ono što nije obećano, a razlika je važna pri poređenju: izvlačenje. Sjeme čini pregled ponovljivim
OVDJE — isto sjeme i isti šablon sutra daju isti tekst — ali isto sjeme u JavaScript motoru može
izvući drugu varijantu. Sjemena služe da ponovite vlastiti rad, a ne da pogodite drugi motor.

Sve ovdje radi bez mreže. Nema računa, nema prijave i nema šta uključivati: otvorite program i on
radi.

## Dvije polovine

Kuca se lijevo. Desna polovina se ponovo iscrtava nakon kratke pauze, da pregled stiže za
rečenicom, a ne za svakim slovom.

Šablon s izborom unutra nema jedan odgovor, i pregled pokazuje jedan od njih:

```spx-good
{Zdravo|Pozdrav} svima.  →  Zdravo svima.
```

**Druga** iznad desne polovine daje sljedeću. Ako vam treba uvijek ista — dok poredite dvije
izmjene, recimo — označite **seed**, i pregled će stajati dok je ne skinete ili ne promijenite broj.

Desna polovina pokazuje ili **stranicu** ili **izvor**. Šabloni su uglavnom HTML, i dva pitanja
«kako ovo izgleda» i «kakva je razmjetnica ispala» ne odgovaraju jedno na drugo: pokvaren tag daje
malo krivu stranicu koju oko preskoči, a proza s tagovima unutra ne čita se kao proza. Prebacivač
iznad polovine mijenja ono u šta gledate.

Označite dio šablona i odigrat će se samo on, u okviru cijelog dokumenta, pa odlomak koji koristi
varijablu definisanu gore izlazi onako kako izlazi na svom mjestu.

## Ploče dolje

Traka alata sa strane otvara tri ploče, po jednu u isto vrijeme.

**Dijagnostika** nabraja ono što motor smatra pogrešnim, svaki put s redom i kolonom gdje počinje.
Klik na red vodi kursor tamo. To je ista presuda koju motor donosi svugdje, a ne drugo mišljenje
uređivača — zato šablon koji ova ploča nazove ispravnim prihvataju i ostali motori.

**Varijable** pokazuju imena koja vaš dokument definiše i ona koja samo koristi. Ime koje on koristi
a ništa ne definiše može se popuniti ovdje za ovu sesiju: upišite vrijednost pored i pregled će je
pokupiti. Označite **kao tekst** kada je vrijednost tekst koji znači sam sebe, a ne mali šablon.

**Varijante** prave mnogo tekstova odjednom. Recite koliko, napravite ih i pročitajte u spisku prije
izvoza. Gotovo iste mogu se odbacivati već tokom pravljenja, a seed čini cijeli skup ponovljivim:
isto sjeme i isti šablon sutra daju iste varijante.

Pored tih polja ploča kaže koliko varijanti šablon uopće može dati: `{a|b} i {c|d}` daje četiri. Taj
vam broj javlja da je šablon siromašan još prije nego što napravite pedeset i to primijetite
čitanjem.

Tačan je samo dok svaki izbor ostaje slučaju. Uvjet, oblik množine ili `#include` čiji cilj skup
nema rješava nešto drugo — vrijednost koju ćete podmetnuti, broj, odlomak koji tek može doći — i
tada ploča kaže **najmanje**. To je poštena riječ: podmetnuta vrijednost može samo dodati tekstove,
a ne oduzeti ih. Broj prevelik da bi se čitao staje na bilionu i kaže **najmanje** iz istog razloga.

Varijanta je jedan popunjen šablon, po jedan izbor u svakoj konstrukciji, i to nije isto što i tekst
koji se drugačije čita. `{a|a}` su dvije varijante i jedan tekst, i tako je zamišljeno: dvije
mogućnosti mogu prestati da se poklapaju nakon prve izmjene, a da bi se svele, morale bi se prvo
napraviti sve kombinacije — upravo onaj posao radi čije uštede broj i postoji. `#def` se računa
isto: motor ga izvlači jednom po odigravanju, koristila ga izabrana grana ili ne.

Izvoz ih čuva na tri načina: kao XLSX radnu svesku, kao običan tekst s po jednom varijantom u redu
ili kao po jedan fajl po varijanti u folder koji odaberete.

## Uređivač grupa

Stavite kursor unutar `{a|b|c}` i otvorite uređivač grupa s trake alata. On nabraja varijante po
redovima: mijenjajte ih, dodajte jednu, uklonite drugu — i dokument se prepisuje u skladu s tim.

On odbija izmjene koje bi promijenile ono što grupa ZNAČI, a ne ono što kaže: `|` otkucan unutar
varijante napravio bi od jedne mogućnosti dvije, a `}` bi zatvorio grupu prerano. Kada odbije, kaže
to i ostavlja dokument na miru.

## Postavke

One su u meniju «Prikaz», i svaka se pamti između sesija: jezik sučelja i prati li šablon, s koje je
strane traka alata, tema, font uređivača i njegova veličina, pokazuje li pregled stranicu ili izvor,
prebacivač za GSA uvoz, koja je ploča otvorena i širine ploča koje se izvlače.

Sučelje govori četrnaest jezika, izbor je na istom mjestu. To je odvojeno od jezika vašeg šablona,
koji rješava oblike množine i zadaje se iznad desne polovine.

## Uvoz GSA šablona

Ovaj je dio isključen dok ga ne uključite, u **Prikaz**, **GSA uvoz**, jer većina onih koji pišu
šablone nikada nije koristila GSA Search Engine Ranker. Uključeno, **Datoteka**, **Uvezi GSA
šablon…** čita SER šablon i prevodi ga na ovaj jezik.

Pretvaranje je oprezno na određen način. Ono što ne može prenijeti tačno, ono odbija i kaže vam o
tome, umjesto da tiho pretvori u nešto što će se odigrati. Konstrukcije koje bi se pogrešno
pročitale da ostanu u tekstu — BBCode zagrade, `#` unutar linka, makro `#file[...]` — iznose se u
varijable, i rezultat kaže koliko.

Dvije stvari o rezultatu:

- **Iznesene vrijednosti su vrijednosti sesije.** One se pojavljuju u ploči «Varijable» i ne čuvaju
  se uz dokument. Sačuvajte pretvoren šablon, otvorite ga sutra — i vidjet ćete `%…%` tamo gdje je
  stajao iznesen tekst. Iz uvezenog fajla ništa nije izgubljeno — on ostaje netaknut — ali pretvoren
  dokument nije samodovoljan.
- **On se odigrava bez prolaza dotjerivanja.** Svaki drugi dokument ovdje dobija završne poteze
  opisane u jezičkom priručniku; pretvoren šablon — ne, jer to nije naš tekst da ga glačamo. On je
  tuđ, najčešće na putu nazad prema GSA, i mora preživjeti znak po znak.

Uvezen dokument je bez naslova i nije sačuvan, kao nov. Fajl koji ste odabrali ostaje tačno onakav
kakav je bio.
