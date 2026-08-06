(*
 * SpxTextsNl -- the window in Dutch.
 *
 * One language, one file. The order is TSpxStr's and nothing else: this is a positional
 * array, so a line moved here moves a caption on screen.
 *)
unit SpxTextsNl;

{$mode objfpc}{$H+}

interface

uses
  SpxStrIds;

const
  TEXTS_NL: array[TSpxStr] of string = (
      'Bestand', 'Nieuw', 'Openen…', 'Opslaan', 'Opslaan als…', 'Set herladen', 'Afsluiten',
      'Bewerken', 'Zoeken…', 'Volgende zoeken', 'Vorige zoeken',
      'Beeld', 'Gereedschap links', 'Gereedschap rechts',
      'Taal van de interface', 'English', 'Русский', 'Zoals het sjabloon',
      'G', 'Groep onder de cursor',
      'De cursor staat niet in een groep.', 'Toepassen',
      'Geweigerd: het resultaat zou iets anders zeggen dan deze lijst — een variant mag ' +
        'geen | } { of /# bevatten.',
      'Een variant bevat een regeleinde, daarom wordt deze groep getoond maar niet bewerkt.',
      'Keuze', 'Voorwaarde', 'Meervoud', 'Permutatie',
      'D', 'V', 'Vr',
      'Omsluiten met {…}', 'Omsluiten met […]', 'Andere variant tonen',
      'Resultaat kopiëren',
      'Alles selecteren',

      'seed', 'Opnieuw', 'Kopiëren', 'Pagina', 'Bron',
      'fragment getoond', 'het fragment levert niets op',

      'Hoofdlt.', 'niet gevonden', 'gevonden %d', '%d/%d', 'x',

      'Diagnose', 'Variabelen', 'Varianten',
      'Niveau', 'Bestand', 'Op', 'Bericht',
      'fout', 'waarschuwing', 'Studio-notitie', 'document',

      ' Definities — die staan in het document',
      ' Sessiewaarden — als spintax weergegeven, nooit in het document geschreven',
      'Soort', 'Naam', 'Waarde', 'als tekst',

      'Aantal', 'seed', 'random', 'Genereren', 'Stoppen',
      'Gelijkende weglaten', 'Alleen exacte duplicaten', 'Alles behouden', 'shingle',
      'grens',
      'Naar .xlsx', 'Naar .txt', 'Elk een bestand', 'seed in .txt',
      'nog niets gegenereerd', 'bezig…', 'stoppen…',
      '%d varianten, %d weggelaten, %d renders, volgende seed %d',
      '%d van %d — meer geeft het sjabloon bij deze grens niet (%d weggelaten, %d renders)',
      'gestopt: %d varianten, %d weggelaten, %d renders',
      '%d van %d, %d weggelaten, %d renders',
      'het document is gewijzigd — deze set komt van de vorige tekst; ',
      '%d regels naar %s geschreven',
      '%d regels geschreven; in %d varianten werden regeleindes spaties — voor de tekst ' +
        'zoals hij is, neem .xlsx of elk een bestand',
      '%d bestanden naar %s geschreven', '%d bestanden geschreven, daarna ging het niet meer',
      'het bestand kon niet worden geschreven',
      '#', 'seed', 'lengte', 'tekst',

      'Sjabloon openen', 'Sjabloon opslaan', 'Spintax-sjablonen|*%s|Alle bestanden|*.*',
      'Excel-werkmap|*.xlsx', 'Tekst|*.txt',
      'Exporteren naar .xlsx', 'Exporteren naar .txt', 'Waar de bestanden komen',
      'Varianten',
      'seed', 'variant',
      'Spintax Studio', 'Het document heeft niet-opgeslagen wijzigingen. Opslaan?',
      'Naamloos',
      '%s — Spintax Studio',

      'gereed', 'geldig', 'geldig, %d waarschuwingen', '%d fouten', ' · %d notities',
      '%s · %d ms',
      'Tonen', 'Uitvoer: %d KB — de pagina tekent zichzelf niet',

      'Sluiten',

      'Groter', 'Kleiner', 'Normale grootte', 'Licht', 'Donker',

      'Gelijke breedte', 'Dubbelklik: gelijke breedte',

      'Editorlettertype', 'Automatisch',

      'Waarde niet toegepast: de engine zou de directive anders lezen',

      'Includes — de fragmenten die dit document ophaalt', 'Doel', 'Gevonden', 'ja', 'ONTBREEKT', 'geen set',

      'Help', 'Inhoud', 'Taal van de help', 'Er is nog geen help in het %s.',

      'uit de Help', 'In mijn document invoegen',

      'Over',

      'Nog geen macro''s — schrijf #set %name% = waarde in het document en gebruik %name% in de tekst.',
      'Nog niets ingevoegd — #include "fragment" haalt een ander bestand op, en alleen aan het begin van een regel.',

      'Schrijf links een sjabloon en zie rechts wat het oplevert. Validatie, variabelen, includes, variantgeneratie en export: allemaal offline, zonder account, zonder netwerk en zonder runtime.',
      'Licenties en dankbetuigingen',

      'GSA-import',
      'GSA-sjabloon importeren…',
      'GSA-sjablonen|*.txt;*.spintax|Alle bestanden|*.*',
      'Uit het sjabloon naar variabelen gehaald: %d.',
      'Dit zijn sessiewaarden: ze staan in het variabelenpaneel en worden NIET met het document opgeslagen. Er wordt zonder nabewerking gerenderd, zodat het sjabloon blijft zoals GSA het schreef.',

      'Mogelijke varianten: %s',
      'Mogelijke varianten: minstens %s'
  );

implementation

end.
