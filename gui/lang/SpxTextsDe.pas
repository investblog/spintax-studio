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

      'bereit', 'gültig', 'gültig · Warnungen: %d', 'Fehler: %d', ' · Notizen: %d', '%s · %d ms',
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
      'Lizenzen und Danksagungen',

      'GSA-Import',
      'GSA-Vorlage importieren…',
      'GSA-Vorlagen|*.txt;*.spintax|Alle Dateien|*.*',
      '%d Variablen wurden aus der Vorlage herausgezogen.',
      'Es sind Sitzungswerte: Sie stehen in der Variablen-Ansicht und werden NICHT mit dem Dokument gespeichert. Gerendert wird ohne Nachbearbeitung, damit die Vorlage genau so bleibt, wie GSA sie geschrieben hat.',
      '%d Blöcke wurden abgelehnt und unverändert gelassen.',
      '…und %d weitere.',
      'Der Import wurde verworfen: Das Dokument hat sich geändert, während die Vorlage umgewandelt wurde.',

      'Mögliche Varianten: %s',
      'Mögliche Varianten: mindestens %s',

      (* the AI panel (ADR 0011) *)
      'KI-Entwurf',
      'Briefing',
      'Variablen, die das Modell nutzen darf',
      'Antwort des Modells',
      'Kanal',
      'Variation',
      'Sprache',
      'Prompt kopieren',
      'Reparatur-Prompt kopieren',
      'In das Dokument einfügen',
      'Fall',
      'Notiz',
      'Prompt kopiert. Bringen Sie ihn zu Ihrem Modell und die Antwort zurück.',
      'Reparatur-Prompt kopiert. Er zeigt auf die genauen Stellen.',
      'Entwurf eingefügt. Das Urteil steht im Diagnosebereich.',
      'Schreiben Sie zuerst ein Briefing.',
      'Fügen Sie zuerst die Antwort des Modells ein.',
      'Keine Fehler zu reparieren.',
      'E-Mail',
      'SMS',
      'Push',
      'Landingpage',
      'allgemein',
      'zurückhaltend',
      'ausgewogen',
      'offensiv',
      '—',
      'Nominativ',
      'Genitiv',
      'Dativ',
      'Akkusativ',
      'Instrumental',
      'Präpositiv',
      'Dokument ersetzen',
      'Dokument ersetzt. Das Urteil steht im Diagnosebereich.',

      (* R1-4: the loop in the window (spec §4.5). "Maschine" is the engine -- the word the
         German help uses throughout; the computer is "Rechner" so the two cannot collide. *)
      'Reparieren',
      'KI-Einstellungen…',
      'gestoppt',
      'Anfrage an das Modell…',
      'die Maschine prüft den Entwurf…',
      'Reparaturversuch %d von %d',
      'Keine Fehler, aber ein Teil der Proberenders kommt leer heraus — prüfen Sie die Pluralformen. Der Entwurf liegt im KI-Bereich, nicht übernommen.',
      'Der Entwurf ist sauber, aber ein eingebundenes Fragment hat einen Fehler. Reparieren Sie jene Datei — Neugenerieren kann das nicht.',
      '%d Fehler bleiben nach %d Reparaturversuchen. Der Entwurf liegt im KI-Bereich, nicht übernommen.',
      'Während die Antwort unterwegs war, hat sich etwas geändert, wogegen sie geprüft wurde — das Dokument, Werte oder Einstellungen. Der Entwurf liegt im Antwortfeld, nicht übernommen.',
      'Dieses Profil authentifiziert sich, und kein Schlüssel ist angeheftet. Geben Sie den Schlüssel im KI-Bereich ein.',
      'Der Endpunkt verweist an eine andere Adresse (%s). Ihr wurde nicht gefolgt; ändern Sie das Profil, wenn das beabsichtigt ist.',
      'Offenes http, das diesen Rechner verlässt, würde Schlüssel und Text im Klartext senden. Verwenden Sie https.',
      'Der Endpunkt hat den Schlüssel abgelehnt. Prüfen Sie ihn im KI-Bereich.',
      'Der Endpunkt meldet ein Anfragelimit oder ein erschöpftes Kontingent. Versuchen Sie es später.',
      'Der Prompt ist länger, als dieses Modell annimmt.',
      'Die Anfrage kam nicht durch: %s',
      'Der Endpunkt hat geantwortet, aber in einer Form, die diese Anwendung nicht lesen kann: %s',
      'Die Antwort enthielt keine Vorlage.',
      'Der Endpunkt meldet: %s',
      'Verbindung',
      'Format',
      'Endpunkt',
      'Modell',
      'Autorisierung',
      'keine',
      'API-Schlüssel',
      'Schlüssel',
      'Schlüssel anheften',
      'Schlüssel vergessen',
      'ein Schlüssel ist an diesen Endpunkt angeheftet',
      'kein Schlüssel angeheftet',
      'der Endpunkt hat sich geändert — geben Sie den Schlüssel erneut ein, um ihn an die neue Adresse anzuheften',
      'Senden erlaubt',
      'An diesen Endpunkt senden?',
      '„Erzeugen“ und „Reparieren“ senden das Briefing, die aktuelle Vorlage und die deklarierten Variablen an den Endpunkt dieses Profils:'#10'%s'#10#10'Bei Autorisierung mit API-Schlüssel reist der Schlüssel in den Kopfzeilen der Anfrage. Zu keinem anderen Zeitpunkt wird etwas gesendet, und die Adresse ändert sich nie von selbst: eine Umleitung wird abgelehnt und angezeigt. Was die Software an jener Adresse mit dem Text tut, bestimmt ihr Betreiber.'#10#10'Sie können dies jederzeit in den KI-Einstellungen abschalten.',

      (* R1-5: the report channel (Store policy 11.16) *)
      'Unangemessene KI-Ausgabe melden…',

      (* the brief column's two modes (UX pass 2026-08-13) *)
      'Text zum Umwandeln',
      'Zuerst den umzuwandelnden Text einfügen.',

      (* find and replace (UX-plan item 8, 2026-08-14) *)
      'Ersetzen…',
      'ersetzen durch',
      'Ersetzen',
      'Alle ersetzen',
      'Ersetzt: %d',

      'Einfügen',
      'In /#…#/ einfassen',
      '#set %name% = Wert',
      '#def %name% = {a|b}',
      '#include "name"',
      '{?name?dann|sonst}',
      'Nicht eingefasst: ein #/ in oder um die Auswahl würde den Kommentar zu früh beenden.',
      'Nicht eingefasst: ein nacktes |, eine unausgeglichene Klammer oder ein offener Kommentar würde die Bedingung verändern.',
      'Nicht eingefügt: die Schreibmarke zerteilt eine Kommentarmarke.',
      'Die Endpunkt-Adresse lässt sich nicht lesen — korrigieren Sie sie, dann den Schlüssel anheften.',
      'Entwurf geprüft. Er liegt im Antwortfeld — einfügen oder ersetzen Sie selbst.'
  );

implementation

end.
