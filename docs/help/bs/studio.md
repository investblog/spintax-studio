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

Urednik, provjera, pregled, pravljenje varijanti i izvoz rade bez mreže — sav svakodnevni
posao. Nema računa ni prijave: otvorite program i on radi. Jedina funkcija koja zna na mrežu,
AI nacrt, isključena je dok je ne uključite, i ima niže svoje poglavlje.

## Dvije polovine

Kuca se lijevo. Desna polovina se ponovo iscrtava nakon kratke pauze, da pregled stiže za
rečenicom, a ne za svakim slovom.

Šablon s izborom unutra nema jedan odgovor, i pregled pokazuje jedan od njih:

```spx-good
{Zdravo|Pozdrav} svima.  →  Zdravo svima.
```

**Druga** iznad desne polovine daje sljedeću. Ako vam treba uvijek ista — dok poredite dvije
izmjene, recimo — označite **seed**, i pregled će stajati dok je ne skinete ili ne promijenite broj.

Prebacivač iznad desne polovine nudi **Stranica** i **Izvor**. Šabloni su uglavnom HTML, i dva pitanja
«kako ovo izgleda» i «kakva je razmjetnica ispala» ne odgovaraju jedno na drugo: pokvaren tag daje
malo krivu stranicu koju oko preskoči, a proza s tagovima unutra ne čita se kao proza. Prebacivač
iznad polovine mijenja ono u šta gledate.

Označite dio šablona i odigrat će se samo on, u okviru cijelog dokumenta, pa odlomak koji koristi
varijablu definisanu gore izlazi onako kako izlazi na svom mjestu.

## Pretraga i zamjena

Pritisnite **Ctrl+F** — u zaglavlju se otvara polje pretrage. Brojač pored njega kaže koliko
se puta tekst javlja i na kojem ste pojavljivanju; **Enter** korača naprijed, **Shift+Enter**
nazad, F3 radi direktno iz dokumenta. Velika i mala slova ne broje se dok se ne uključi
kućica uz polje — a slova sklapa motor, pa se ćirilično ili naglašeno slovo poklapa sa
svojim parom tačno tamo gdje ih i pregled smatra jednim slovom.

Pritisnite **Ctrl+H** — ili stavku menija **Zamijeni…** — i traka dobija drugi red: zamjenu
i dva dugmeta. **Zamijeni** mijenja pojavljivanje na kojem stojite i korača na sljedeće; dok
ništa nije nađeno, prvi pritisak samo traži. **Zamijeni sve** prolazi cijeli dokument
odjednom, a statusna traka kaže koliko se mjesta promijenilo; jedan Ctrl+Z vraća cijeli
prolaz.

Zamjena je doslovna. Može biti prazna — to briše — i može sadržavati traženi tekst, a da
prolaz ne uđe u krug: mjesta se odlučuju unaprijed, nad tekstom kakav je bio. Kad se
pojavljivanja preklapaju, brojač broji svako koje korak može posjetiti, ali prolaz mijenja
samo ona koja ne dijele slova — pa „zamijenjeno“ može pošteno reći manji broj.

Zamijenjeni dokument prolazi isti put motora kao i otkucani: pregled se iscrtava iznova, a
dijagnostika odgovara o onome što sada stoji.

## Umetanje oznaka

Sve što u dokument stavlja oznake samog jezika skupljeno je u meniju **Umetanje**.

Tri naredbe umotavanja uzimaju odabir kakav jest: **Umotaj u {…}** ga čini izborom, **Umotaj u […]** —
miješanjem, **Umotaj u /#…#/** (Ctrl+/) — komentarom. Umotavanje u komentar odbija kad bi `#/` u odabiru ili oko njega — ili komentar već otvoren na
tom mjestu — završio komentar prerano: prva zatvarajuća oznaka pobjeđuje gdje god stajala, tekst
bi ispao van; to kaže statusna traka, jer motor šuti. Bez odabira Ctrl+/ umeće par i
ostavlja pokazivač unutra.

Konstrukcije ispod padaju tačno onako kako ih meni čita. **#set %name% = vrijednost**, **#def %name% = {a|b}** i **#include "name"** zauzimaju
vlastiti red — direktiva se računa samo kad otvara svoj red, pa tekst prije pokazivača
ostaje iznad, a tekst poslije silazi niže — a ime izlazi odabrano, spremno za kucanje preko.
Držite imena latinicom: ime u drugom pismu, šutke, nije ime. Cilj `#include` je izuzetak —
poredi se s imenima vaših fragmenata tačno kako je napisan.

**{?name?onda|inače}** živi unutar reda. S odabirom odabrani tekst postaje polovina „onda" — način da se već
napisano učini uslovnim; bez odabira ulazi cijeli oblik. Odabir s golom `|`, nezatvorenom zagradom ili otvorenim komentarom biva odbijen: umotavanje bi
promijenilo šta kaže umjesto da ga uokviri.

Posljednja stavka stavlja u dokument primjer otvoren u pomoći — dugme samog panela pomoći,
učinjeno dohvatljivim s tastature.

## Ploče dolje

Traka alata sa strane otvara četiri ploče, po jednu u isto vrijeme.

**Dijagnostika** nabraja ono što motor smatra pogrešnim, svaki put s redom i kolonom gdje počinje.
Klik na red vodi kursor tamo. To je ista presuda koju motor donosi svugdje, a ne drugo mišljenje
uređivača — zato šablon koji ova ploča nazove ispravnim prihvataju i ostali motori.

**Promjenljive** pokazuju imena koja vaš dokument definiše i ona koja samo koristi. Ime koje on koristi
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

**AI nacrt** piše prvi nacrt šablona za vas — iz teksta koji već imate, ili iz
zadatka. Zaslužio je vlastiti odjeljak: sljedeći.

## AI nacrt

Šablon obično počinje tekstom koji već postoji — opis proizvoda, pismo, stranica. Panel
**AI nacrt** pretvara taj tekst u prvi šablon: otvorite ga s trake s alatima, ostavite zaglavlje
lijeve kolone na **Tekst za pretvaranje**, zalijepite tekst i pritisnite **Generiši**. Nacrt pada u **Odgovor modela**, već provjeren — usput je prošao kroz motor ovog prozora.
Primjena je vaša: **Umetni u dokument** stavlja ga na mjesto vašeg odabira (ili kod kursora ako
ništa nije odabrano), **Zamijeni dokument** mijenja cijeli tekst — i ništa ne dira vaš dokument
dok ne pritisnete jedno od dva dugmeta. Jedan Ctrl+Z nakon bilo kojeg od njih vraća stari tekst.

Ako nema šta da se zalijepi, prebacite zaglavlje na **Zadatak** i opišite šta želite. Polja
iznad vode nacrt u oba režima: **Kanal** — pismo, SMS i push obavještenje pišu se u
različitim registrima; **Varijativnost** — koliko varijante smiju da se raziđu; jezik odgovora; i
**Varijable koje model smije koristiti**, navedene poimence. Kolona padeža je dio koji vrijedi popuniti. Varijabla se unosi doslovno, ništa je ne mijenja po padežima, pa se u jeziku s padežima rečenica mora graditi oko oblika koji vrijednost već ima, a model bira tačno samo ako mu se kaže koji oblik drži svako ime. Iz imena se to ne može izvesti: u jednom stvarnom skupu šablona instrumental je stajao u varijabli čije je ime govorilo akuzativ.

Odgovoru se ne vjeruje — on se provjerava: nacrt prolazi kroz motor ovog prozora prije nego
što se približi dokumentu, a nađe li presuda greške, petlja sama traži od modela da ih
popravi — statusna traka broji runde — prije nego što išta preda. Odgovor nikad sam ne piše u urednik: uvijek čeka u **Odgovor modela**, a statusni red kaže kako
je završilo — čist nacrt javlja da je spreman, onaj koji petlja nije mogla sasvim popraviti
imenuje šta je ostalo, a ako se dokument — ili bilo šta drugo prema čemu je provjeravan — mijenjao dok je odgovor
letio, red upozorava da je presuda bila o prijašnjem stanju. Dok radi, na dugmetu **Generiši** piše **Zaustavi** — pritisnite da napustite rundu — runda zaustavljena usred provjere može u polju ostaviti tekst
koji provjeru nije prošao.

**Popravi** je ista petlja uperena u trenutni dokument: budi se kad dijagnostika nađe greške,
šalje dokument zajedno s tačnim primjedbama a ispravljena verzija čeka u istom polju odgovora — njeno je mjesto obično **Zamijeni
dokument**.

### Veza, i čiji ključ

Kako je instalirana, aplikacija ne šalje ništa nikuda. **Generiši** i **Popravi** izlaze na mrežu
tek nakon što u podnožju panela postavite vezu i dozvolite je. Izaberite **Format** kojim
govori vaš endpoint — **Anthropic Messages** ili **OpenAI-compatible** —, adresu **Endpoint** i
ime u polju **Model** — za Anthropic spisak pod strelicom nudi aktuelna imena; inače
upišite ime koje vaš endpoint očekuje.
**Autorizacija** kaže putuje li ključ: **API ključ** za hostovane provajdere, **nema** za
servere koji ga ne traže.

Ključ je vaš, napravljen na vašem računu — aplikacija nikada nema svoj:

- **Anthropic** — ključ se pravi na `console.anthropic.com`, odjeljak API keys.
- **OpenAI** — `platform.openai.com`, odjeljak API keys; za slanje račun mora imati
  uključenu naplatu.
- **OpenAI-compatible** je porodica, ne jedna firma: OpenRouter odgovara u istom obliku s
  mnogo modela pod jednim ključem, a serveri na vašem vlastitom računaru — Ollama, LM Studio
  — obično ne traže ključ uopšte: postavite **Autorizacija** na **nema**.

**Priveži ključ** sprema ključ u Windowsov upravljač akreditivima, šifrovan za vaš Windows račun —
ne u datoteku i nikada u dokument. Polje potom pokazuje prve znakove ključa i njegova
posljednja četiri — počeci su slični, rep je ono što ključeve razlikuje; tako se vidi koji
je privezan, a **Zaboravi ključ** ga uklanja. Ključ je privezan za mjesto za koje je unesen — shemu, host i port: promijenite bilo šta od
toga i panel će ga zatražiti ponovo.

Prvi pritisak pita otvoreno — **Slati na ovaj endpoint?** — imenujući primaoca. Putuje upit sastavljen od vašeg zadatka
ili teksta — zajedno s izabranim kanalom, varijativnošću i jezikom —, navedene varijable, pri
popravci trenutni šablon sa svojom dijagnostikom, ime modela iz vašeg profila s gornjom
granicom dužine odgovora, a pod autorizacijom **API ključ** — ključ u zaglavljima zahtjeva; ništa više i ni u kojem drugom trenutku. Primalac se ne mijenja bez vas: preusmjeravanje se odbija umjesto da se slijedi, a nešifrovana `http` adresa prima se samo
na ovoj mašini. Dozvola se veže gdje i ključ — za shemu, host i port — i vidi se kao kvačica **Slanje dozvoljeno** u
postavkama — skinite je bilo kad: ništa novo ne
polazi, a odgovor koji je već u letu slijeće, najviše, u polje odgovora. Šta softver na izabranoj adresi radi s tekstom, na njegovom je operateru
da kaže: zahtjev ide na adresu iz vašeg profila i nikuda više.

### Ista petlja, bez mreže

Upitima ne trebaju ni ključ ni veza — to je isti put kad vaš model živi u prozoru za
ćaskanje, a petlju ovdje okrećete vi: motor sudi poslije lijepljenja, ne prije. **Kopiraj upit** stavlja cijeli upit u međuspremnik; odnesite ga modelu koji koristite,
zalijepite odgovor u polje **Odgovor modela** i pritisnite **Umetni u dokument**. Nađe li dijagnostika greške,
**Kopiraj upit za popravku** sastavlja drugi upit: nosi cijeli dokument s numerisanim redovima i imenuje tačna
mjesta kojima se motor usprotivio. Odgovor na njega je ispravljen dokument u cjelini —
vratite ga i pritisnite **Zamijeni dokument**; **Umetni u dokument** bi slomljeni ostavio na mjestu i stavio ispravljenu kopiju pored (osim ako
je tekst odabran — tada umetanje zamjenjuje baš njega).

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
šablone nikada nije koristila GSA Search Engine Ranker. Uključeno, **Datoteka**, **Uvezi GSA predložak…** čita SER šablon i prevodi ga na ovaj jezik.

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
