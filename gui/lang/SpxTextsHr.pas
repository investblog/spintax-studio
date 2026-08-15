(*
 * SpxTextsHr -- the window in Croatian.
 *
 * One language, one file. The order is TSpxStr's and nothing else: this is a positional
 * array, so a line moved here moves a caption on screen.
 *)
unit SpxTextsHr;

{$mode objfpc}{$H+}

interface

uses
  SpxStrIds;

const
  TEXTS_HR: array[TSpxStr] of string = (
      'Datoteka', 'Nova', 'Otvori…', 'Spremi', 'Spremi kao…', 'Ponovno učitaj skup',
      'Izlaz',
      'Uređivanje', 'Nađi…', 'Nađi sljedeće', 'Nađi prethodno',
      'Prikaz', 'Alati lijevo', 'Alati desno',
      'Jezik sučelja', 'English', 'Русский', 'Kao predložak',
      'G', 'Grupa pod pokazivačem',
      'Pokazivač nije unutar grupe.', 'Primijeni',
      'Odbijeno: rezultat bi rekao nešto drugo od ovog popisa — varijanta ne smije nositi ' +
        '| } { ili /#.',
      'Jedna varijanta sadrži prijelom retka, pa je grupa prikazana ali se ne mijenja.',
      'Izbor', 'Uvjet', 'Množina', 'Permutacija',
      'D', 'V', 'Vr',
      'Omotaj u {…}', 'Omotaj u […]', 'Prikaži drugu varijantu', 'Kopiraj rezultat',
      'Odaberi sve',

      'seed', 'Druga', 'Kopiraj', 'Stranica', 'Izvor',
      'prikazan odlomak', 'odlomak ne daje ništa',

      'Vel./mala', 'nema pogotka', 'nađeno %d', '%d/%d', 'x',

      'Dijagnostika', 'Varijable', 'Varijante',
      'Razina', 'Datoteka', 'Mjesto', 'Poruka',
      'greška', 'upozorenje', 'Studio napomena', 'dokument',

      ' Definicije — žive u dokumentu',
      ' Vrijednosti sesije — obrađuju se kao spintax, u dokument se ne upisuju',
      'Vrsta', 'Ime', 'Vrijednost', 'kao tekst',

      'Koliko', 'seed', 'nasumičan', 'Generiraj', 'Zaustavi',
      'Ukloni slične', 'Samo točni duplikati', 'Zadrži sve', 'shingle', 'prag',
      'U .xlsx', 'U .txt', 'Datoteka po tekstu', 'seed u .txt',
      'ništa nije generirano', 'u tijeku…', 'zaustavljam…',
      '%d varijanti, odbačeno %d, renderiranja %d, sljedeći seed %d',
      '%d od %d — predložak ne daje više uz ovaj prag (odbačeno %d, renderiranja %d)',
      'zaustavljeno: %d varijanti, odbačeno %d, renderiranja %d',
      '%d od %d, odbačeno %d, renderiranja %d',
      'dokument je promijenjen — ovaj skup je od ranijeg teksta; ',
      'upisano %d redaka u %s',
      'upisano %d redaka; u %d varijanti prijelomi redaka postali su razmaci — za tekst ' +
        'kakav jest, uzmite .xlsx ili datoteku po tekstu',
      'upisano %d datoteka u %s', 'upisano %d datoteka, dalje nije uspjelo',
      'datoteku nije bilo moguće upisati',
      '#', 'seed', 'duljina', 'tekst',

      'Otvori predložak', 'Spremi predložak', 'Spintax predlošci|*%s|Sve datoteke|*.*',
      'Excel radna knjiga|*.xlsx', 'Tekst|*.txt',
      'Izvoz u .xlsx', 'Izvoz u .txt', 'Kamo smjestiti datoteke', 'Varijante',
      'seed', 'varijanta',
      'Spintax Studio', 'Dokument ima nespremljene promjene. Spremiti ih?', 'Bez naslova',
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
      'Još nema umetanja — #include "fragment" povlači drugu datoteku, i samo s početka retka.',

      'Predložak pišete lijevo, a desno vidite što proizvodi. Provjera, varijable, uključivanja, generiranje varijanti i izvoz: sve offline, bez računa, bez mreže i bez izvršnog okruženja.',
      'Licence i zahvale',

      'GSA uvoz',
      'Uvezi GSA predložak…',
      'GSA predlošci|*.txt;*.spintax|Sve datoteke|*.*',
      'Izneseno u varijable: %d.',
      'To su vrijednosti sesije: vide se u panelu varijabli i NE spremaju se uz dokument. Prikaz se računa bez naknadne obrade, pa predložak ostaje onakav kakvim ga je GSA napisao.',
      'Odbijeno blokova: %d — ostavljeni točno kakvi su bili.',
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
      'Kopiraj upit za popravak',
      'Umetni u dokument',
      'Padež',
      'Napomena',
      'Upit je kopiran. Odnesite ga svom modelu i vratite odgovor.',
      'Upit za popravak je kopiran. Pokazuje na točna mjesta.',
      'Nacrt je umetnut. Presuda je u ploči dijagnostike.',
      'Najprije napišite zadatak.',
      'Najprije zalijepite odgovor modela.',
      'Nema pogrešaka za popravak.',
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
         Croatian help uses throughout. *)
      'Popravi',
      'Postavke AI-ja…',
      'zaustavljeno',
      'upit modelu…',
      'motor provjerava nacrt…',
      'pokušaj popravka %d od %d',
      'Nema grešaka, ali dio probnih rendera izlazi prazan — provjerite oblike množine. Nacrt je u AI ploči, nije primijenjen.',
      'Nacrt je čist, ali uključeni fragment sadrži grešku. Popravite tu datoteku — ponovno generiranje to ne može.',
      'Ostaje %d grešaka nakon %d pokušaja popravka. Nacrt je u AI ploči, nije primijenjen.',
      'Dok je odgovor putovao, promijenilo se ono prema čemu je provjeravan — dokument, vrijednosti ili postavke. Nacrt je u polju odgovora, nije primijenjen.',
      'Ovaj se profil autentificira, a ključ nije privezan. Unesite ključ u AI ploči.',
      'Endpoint traži drugu adresu (%s). Nije slijeđena; promijenite profil ako je to namjerno.',
      'Otvoreni http izvan ovog računala poslao bi ključ i tekst u čistom obliku. Koristite https.',
      'Endpoint je odbio ključ. Provjerite ga u AI ploči.',
      'Endpoint javlja ograničenje zahtjeva ili iscrpljenu kvotu. Pokušajte kasnije.',
      'Upit je dulji nego što ovaj model prihvaća.',
      'Zahtjev nije prošao: %s',
      'Endpoint je odgovorio, ali u obliku koji ova aplikacija ne može pročitati: %s',
      'Odgovor nije nosio nikakav predložak.',
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
      'endpoint se promijenio — unesite ključ ponovno da ga privežete uz novu adresu',
      'Slanje dopušteno',
      'Slati na ovaj endpoint?',
      '"Generiraj" i "Popravi" šalju zadatak, trenutačni predložak i deklarirane varijable na endpoint ovog profila:'#10'%s'#10#10'Uz autorizaciju API ključem ključ putuje u zaglavljima zahtjeva. Ništa se ne šalje ni u kojem drugom trenutku, a adresa se nikad ne mijenja sama: preusmjeravanje se odbija i prikazuje. Što softver na toj adresi radi s tekstom, određuje njegov operater.'#10#10'Ovo možete isključiti u bilo kojem trenutku u postavkama AI-ja.',

      (* R1-5: the report channel (Store policy 11.16) *)
      'Prijavi neprimjeren AI izlaz…',

      (* the brief column's two modes (UX pass 2026-08-13) *)
      'Tekst za pretvorbu',
      'Najprije zalijepite tekst za pretvorbu.',

      (* find and replace (UX-plan item 8, 2026-08-14) *)
      'Zamijeni…',
      'zamijeni s',
      'Zamijeni',
      'Zamijeni sve',
      'Zamijenjeno: %d',

      'Umetanje',
      'Omotaj u /#…#/',
      '#set %name% = vrijednost',
      '#def %name% = {a|b}',
      '#include "name"',
      '{?name?onda|inače}',
      'Nije omotano: #/ u odabiru ili oko njega završio bi komentar prerano.',
      'Nije omotano: samostalna |, nezatvorena zagrada ili otvoren komentar promijenili bi smisao uvjeta.',
      'Nije umetnuto: pokazivač siječe oznaku komentara napola.',
      'Endpoint adresa se ne može pročitati — ispravite je, pa privežite ključ.',
      'Nacrt je provjeren i čeka u odgovoru — umetnite ili zamijenite sami.'
  );

implementation

end.
