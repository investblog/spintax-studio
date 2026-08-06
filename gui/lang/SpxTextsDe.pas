(*
 * SpxTextsDe -- the window in German.
 *
 * One language, one file. The order is TSpxStr's and nothing else: this is a positional
 * array, so a line moved here moves a caption on screen. The compiler counts the entries;
 * what it cannot check is that each one is in its own place, which is why the sections carry
 * the same headings as the id list.
 *
 * German is the length test of this wave: it is the longest of the Latin languages here, and
 * several captions had to be chosen for the box rather than for the dictionary -- "Würfeln"
 * where English says "Reroll", "Grenze" where it says "limit". The suite checks each against
 * its budget, so the choice is recorded rather than remembered.
 *)
unit SpxTextsDe;

{$mode objfpc}{$H+}

interface

uses
  SpxStrIds;

const
  TEXTS_DE: array[TSpxStr] of string = (
      'Datei', 'Neu', 'Öffnen…', 'Speichern', 'Speichern unter…', 'Satz neu laden',
      'Beenden',
      'Bearbeiten', 'Suchen…', 'Weitersuchen', 'Rückwärts suchen',
      'Ansicht', 'Werkzeuge links', 'Werkzeuge rechts',
      'Sprache der Oberfläche', 'English', 'Русский', 'Wie die Vorlage',
      'G', 'Gruppe unter dem Cursor',
      'Der Cursor steht in keiner Gruppe.', 'Übernehmen',
      'Abgelehnt: das Ergebnis würde etwas anderes sagen als diese Liste — eine Variante ' +
        'darf kein | } { oder /# enthalten.',
      'Eine Variante enthält einen Zeilenumbruch, daher wird diese Gruppe nur angezeigt.',
      'Auswahl', 'Bedingung', 'Pluralform', 'Permutation',
      'D', 'V', 'Vr',
      'In {…} einfassen', 'In […] einfassen', 'Andere Variante zeigen', 'Ergebnis kopieren',
      'Alles markieren',

      'Seed', 'Würfeln', 'Kopieren', 'Seite', 'Quelltext',
      'Ausschnitt gezeigt', 'der Ausschnitt ergibt nichts',

      'Groß/klein', 'nichts gefunden', 'Treffer: %d', '%d/%d', 'x',

      'Diagnose', 'Variablen', 'Varianten',
      'Ebene', 'Datei', 'Bei', 'Meldung',
      'Fehler', 'Warnung', 'Studio-Notiz', 'Dokument',

      ' Definitionen — sie stehen im Dokument',
      ' Sitzungswerte — als Spintax gerendert, nie ins Dokument geschrieben',
      'Art', 'Name', 'Wert', 'als Text',

      'Anzahl', 'Seed', 'zufällig', 'Erzeugen', 'Stopp',
      'Ähnliche verwerfen', 'Nur exakte Duplikate', 'Alles behalten', 'Shingle', 'Grenze',
      'Nach .xlsx', 'Nach .txt', 'Je eine Datei', 'Seed in .txt',
      'noch nichts erzeugt', 'läuft…', 'wird gestoppt…',
      '%d Varianten, %d verworfen, %d Renderings, nächster Seed %d',
      '%d von %d — mehr gibt die Vorlage bei dieser Grenze nicht her (%d verworfen, ' +
        '%d Renderings)',
      'gestoppt: %d Varianten, %d verworfen, %d Renderings',
      '%d von %d, %d verworfen, %d Renderings',
      'das Dokument hat sich geändert — dieser Satz stammt vom früheren Text; ',
      '%d Zeilen nach %s geschrieben',
      '%d Zeilen geschrieben; in %d Varianten wurden Zeilenumbrüche zu Leerzeichen — für ' +
        'den Text wie er ist, nehmen Sie .xlsx oder je eine Datei',
      '%d Dateien nach %s geschrieben', '%d Dateien geschrieben, dann ging es nicht weiter',
      'die Datei ließ sich nicht schreiben',
      '#', 'Seed', 'Länge', 'Text',

      'Vorlage öffnen', 'Vorlage speichern', 'Spintax-Vorlagen|*%s|Alle Dateien|*.*',
      'Excel-Mappe|*.xlsx', 'Text|*.txt',
      'Export nach .xlsx', 'Export nach .txt', 'Wohin mit den Dateien', 'Varianten',
      'Seed', 'Variante',
      'Spintax Studio', 'Das Dokument hat ungespeicherte Änderungen. Speichern?',
      'Ohne Titel',
      '%s — Spintax Studio',

      'bereit', 'gültig', 'gültig, %d Warnungen', '%d Fehler', ' · %d Notizen', '%s · %d ms',
      'Anzeigen', 'Ausgabe: %d KB — die Seite zeichnet sich nicht neu',

      'Schließen',

      'Größer', 'Kleiner', 'Normale Größe', 'Hell', 'Dunkel',

      'Gleich breit', 'Doppelklick: gleich breit',

      'Editor-Schrift', 'Automatisch',

      'Wert nicht übernommen: die Engine würde die Direktive anders lesen',

      'Includes — die Fragmente, die dieses Dokument holt', 'Ziel', 'Gefunden', 'ja', 'FEHLT', 'kein Satz',

      'Hilfe', 'Inhalt', 'Sprache der Hilfe', 'Auf %s gibt es noch keine Hilfe.',

      'aus der Hilfe', 'In mein Dokument einfügen',

      'Über das Programm',

      'Noch keine Makros — schreiben Sie #set %name% = Wert ins Dokument und verwenden Sie %name% im Text.',
      'Noch nichts eingebunden — #include "Fragment" holt eine andere Datei, und nur am Zeilenanfang.',

      'Links schreiben Sie eine Vorlage, rechts sehen Sie, was sie erzeugt. Prüfung, Variablen, Includes, Variantengenerierung und Export: alles offline, ohne Konto, ohne Netz, ohne Laufzeitumgebung.',
      'Lizenzen und Danksagungen'
  );

implementation

end.
