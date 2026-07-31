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

      'iz pomoći', 'Umetni u moj dokument'
  );

implementation

end.
