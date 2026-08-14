(*
 * SpxTextsBs -- the window in Bosnian.
 *
 * One language, one file. The order is TSpxStr's and nothing else: this is a positional
 * array, so a line moved here moves a caption on screen.
 *
 * Close to the Croatian file on purpose and separate on purpose: the engine treats bs, hr
 * and sr as three locales with the same plural arity, and a product that silently served one
 * of them another's spelling would be making a claim about the language that is not ours to
 * make.
 *)
unit SpxTextsBs;

{$mode objfpc}{$H+}

interface

uses
  SpxStrIds;

const
  TEXTS_BS: array[TSpxStr] of string = (
      'Datoteka', 'Nova', 'Otvori…', 'Sačuvaj', 'Sačuvaj kao…', 'Ponovo učitaj skup',
      'Izlaz',
      'Uređivanje', 'Nađi…', 'Nađi sljedeće', 'Nađi prethodno',
      'Prikaz', 'Alati lijevo', 'Alati desno',
      'Jezik interfejsa', 'English', 'Русский', 'Kao šablon',
      'G', 'Grupa pod kursorom',
      'Kursor nije unutar grupe.', 'Primijeni',
      'Odbijeno: rezultat bi rekao nešto drugo od ovog spiska — varijanta ne smije nositi ' +
        '| } { ili /#.',
      'Jedna varijanta sadrži prijelom reda, pa je grupa prikazana ali se ne mijenja.',
      'Izbor', 'Uslov', 'Množina', 'Permutacija',
      'D', 'V', 'Vr',
      'Umotaj u {…}', 'Umotaj u […]', 'Prikaži drugu varijantu', 'Kopiraj rezultat',
      'Izaberi sve',

      'seed', 'Druga', 'Kopiraj', 'Stranica', 'Izvor',
      'prikazan odlomak', 'odlomak ne daje ništa',

      'Vel./mala', 'nema pogotka', 'nađeno %d', '%d/%d', 'x',

      'Dijagnostika', 'Promjenljive', 'Varijante',
      'Nivo', 'Datoteka', 'Mjesto', 'Poruka',
      'greška', 'upozorenje', 'Studio napomena', 'dokument',

      ' Definicije — žive u dokumentu',
      ' Vrijednosti sesije — obrađuju se kao spintax, u dokument se ne upisuju',
      'Vrsta', 'Ime', 'Vrijednost', 'kao tekst',

      'Koliko', 'seed', 'nasumičan', 'Generiši', 'Zaustavi',
      'Ukloni slične', 'Samo tačni duplikati', 'Zadrži sve', 'shingle', 'prag',
      'U .xlsx', 'U .txt', 'Datoteka po tekstu', 'seed u .txt',
      'ništa nije generisano', 'u toku…', 'zaustavljam…',
      '%d varijanti, odbačeno %d, renderovanja %d, sljedeći seed %d',
      '%d od %d — šablon ne daje više uz ovaj prag (odbačeno %d, renderovanja %d)',
      'zaustavljeno: %d varijanti, odbačeno %d, renderovanja %d',
      '%d od %d, odbačeno %d, renderovanja %d',
      'dokument je promijenjen — ovaj skup je od ranijeg teksta; ',
      'upisano %d redova u %s',
      'upisano %d redova; u %d varijanti prijelomi redova postali su razmaci — za tekst ' +
        'kakav jeste, uzmite .xlsx ili datoteku po tekstu',
      'upisano %d datoteka u %s', 'upisano %d datoteka, dalje nije uspjelo',
      'datoteku nije bilo moguće upisati',
      '#', 'seed', 'dužina', 'tekst',

      'Otvori šablon', 'Sačuvaj šablon', 'Spintax šabloni|*%s|Sve datoteke|*.*',
      'Excel radna sveska|*.xlsx', 'Tekst|*.txt',
      'Izvoz u .xlsx', 'Izvoz u .txt', 'Gdje smjestiti datoteke', 'Varijante',
      'seed', 'varijanta',
      'Spintax Studio', 'Dokument ima nesačuvane izmjene. Sačuvati ih?', 'Bez naslova',
      '%s — Spintax Studio',

      'spreman', 'ispravno', 'ispravno, %d upozorenja', '%d grešaka', ' · %d napomena',
      '%s · %d ms',
      'Prikaži', 'Izlaz %d KB — stranica se ne iscrtava sama',

      'Zatvori',

      'Veće', 'Manje', 'Uobičajena veličina', 'Svijetla', 'Tamna',

      'Podijeli na pola', 'Dvoklik — na pola',

      'Font uređivača', 'Automatski',

      'Vrijednost nije primijenjena: engine bi direktivu pročitao drugačije',

      'Uključivanja — fragmenti koje ovaj dokument uvlači', 'Cilj', 'Nađeno', 'da', 'NEMA', 'nema skupa',

      'Pomoć', 'Sadržaj', 'Jezik pomoći', 'Pomoć na jeziku %s još ne postoji.',

      'iz pomoći', 'Umetni u moj dokument',

      'O programu',

      'Još nema makroa — upišite u dokument #set %name% = vrijednost i koristite %name% u tekstu.',
      'Još nema umetanja — #include "fragment" povlači drugu datoteku, i samo s početka reda.',

      'Predložak pišete lijevo, a desno vidite šta proizvodi. Provjera, varijable, uključivanja, generisanje varijanti i izvoz: sve offline, bez računa, bez mreže i bez izvršnog okruženja.',
      'Licence i zahvale',

      'GSA uvoz',
      'Uvezi GSA predložak…',
      'GSA predlošci|*.txt;*.spintax|Sve datoteke|*.*',
      'Izneseno u varijable: %d.',
      'To su vrijednosti sesije: vide se u panelu varijabli i NE čuvaju se uz dokument. Prikaz se računa bez naknadne obrade, pa predložak ostaje onakav kakvim ga je GSA napisao.',
      'Odbijeno blokova: %d — ostavljeni tačno kakvi su bili.',
      '…i još %d.',

      'Mogućih varijanti: %s',
      'Mogućih varijanti: najmanje %s',

      (* the AI panel (ADR 0011) *)
      'AI nacrt',
      'Zadatak',
      'Varijable koje model smije koristiti',
      'Odgovor modela',
      'Kanal',
      'Varijativnost',
      'Jezik',
      'Kopiraj upit',
      'Kopiraj upit za popravku',
      'Umetni u dokument',
      'Padež',
      'Napomena',
      'Upit je kopiran. Odnesite ga svom modelu i vratite odgovor.',
      'Upit za popravku je kopiran. Pokazuje na tačna mjesta.',
      'Nacrt je umetnut. Presuda je u ploči dijagnostike.',
      'Prvo napišite zadatak.',
      'Prvo zalijepite odgovor modela.',
      'Nema grešaka za popravku.',
      'e-pošta',
      'SMS',
      'push',
      'stranica',
      'općenito',
      'oprezna',
      'uravnotežena',
      'smjela',
      '—',
      'nominativ',
      'genitiv',
      'dativ',
      'akuzativ',
      'instrumental',
      'lokativ',
      'Zamijeni dokument',
      'Dokument je zamijenjen. Presuda je u ploči dijagnostike.',

      (* R1-4: the loop in the window (spec §4.5). "Motor" is the engine -- the word the
         Bosnian help uses throughout. *)
      'Popravi',
      'Postavke AI-ja…',
      'zaustavljeno',
      'upit modelu…',
      'motor provjerava nacrt…',
      'pokušaj popravke %d od %d',
      'Nema grešaka, ali dio probnih rendera izlazi prazan — provjerite oblike množine. Nacrt je u AI ploči, nije primijenjen.',
      'Nacrt je čist, ali uključeni fragment sadrži grešku. Popravite tu datoteku — ponovno generisanje to ne može.',
      'Ostaje %d grešaka nakon %d pokušaja popravke. Nacrt je u AI ploči, nije primijenjen.',
      'Dokument se promijenio dok je odgovor putovao. Nacrt je u AI ploči, nije primijenjen.',
      'Ovaj se profil autentifikuje, a ključ nije privezan. Unesite ključ u AI ploči.',
      'Endpoint traži drugu adresu (%s). Nije slijeđena; promijenite profil ako je to namjerno.',
      'Otvoreni http izvan ovog računara poslao bi ključ i tekst u čistom obliku. Koristite https.',
      'Endpoint je odbio ključ. Provjerite ga u AI ploči.',
      'Endpoint javlja ograničenje zahtjeva ili iscrpljenu kvotu. Pokušajte kasnije.',
      'Upit je duži nego što ovaj model prihvata.',
      'Zahtjev nije prošao: %s',
      'Endpoint je odgovorio, ali u obliku koji ova aplikacija ne može pročitati: %s',
      'Odgovor nije nosio nikakav šablon.',
      'Endpoint javlja: %s',
      'Veza',
      'Format',
      'Endpoint',
      'Model',
      'Autorizacija',
      'nema',
      'API ključ',
      'Ključ',
      'Priveži ključ',
      'Zaboravi ključ',
      'ključ je privezan uz ovaj endpoint',
      'ključ nije privezan',
      'endpoint se promijenio — unesite ključ ponovo da ga privežete uz novu adresu',
      'Slanje dozvoljeno',
      'Slati na ovaj endpoint?',
      '"Generiši" i "Popravi" šalju zadatak, trenutni šablon i deklarisane varijable na endpoint ovog profila:'#10'%s'#10#10'Uz autorizaciju API ključem ključ putuje u zaglavljima zahtjeva. Ništa se ne šalje ni u kojem drugom trenutku, a adresa se nikad ne mijenja sama: preusmjeravanje se odbija i prikazuje. Šta softver na toj adresi radi s tekstom, određuje njegov operater.'#10#10'Ovo možete isključiti u bilo kojem trenutku u postavkama AI-ja.',

      (* R1-5: the report channel (Store policy 11.16) *)
      'Prijavi neprimjeren AI izlaz…',

      (* the brief column's two modes (UX pass 2026-08-13) *)
      'Tekst za pretvaranje',
      'Prvo zalijepite tekst za pretvaranje.',

      (* find and replace (UX-plan item 8, 2026-08-14) *)
      'Zamijeni…',
      'zamijeni sa',
      'Zamijeni',
      'Zamijeni sve',
      'Zamijenjeno: %d',

      'Umetanje',
      'Umotaj u /#…#/',
      '#set %name% = vrijednost',
      '#def %name% = {a|b}',
      '#include "name"',
      '{?name?onda|inače}',
      'Nije umotano: #/ u odabiru ili oko njega završio bi komentar prerano.',
      'Nije umotano: samostalna |, nezatvorena zagrada ili otvoren komentar promijenili bi smisao uslova.',
      'Nije umetnuto: kursor siječe oznaku komentara napola.'
  );

implementation

end.
