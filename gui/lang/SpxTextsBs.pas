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
      'Prikaži', 'Izlaz %d KB — stranica se ne iscrtava sama'
  );

implementation

end.
