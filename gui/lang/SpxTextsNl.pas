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
      '%d variabelen zijn uit het sjabloon gehaald.',
      'Dit zijn sessiewaarden: ze staan in het variabelenpaneel en worden NIET met het document opgeslagen. Er wordt zonder nabewerking gerenderd, zodat het sjabloon blijft zoals GSA het schreef.',
      '%d blokken zijn geweigerd en precies zo gelaten.',
      '…en nog %d.',

      'Mogelijke varianten: %s',
      'Mogelijke varianten: minstens %s',

      (* the AI panel (ADR 0011) *)
      'AI-concept',
      'Briefing',
      'Variabelen die het model mag gebruiken',
      'Antwoord van het model',
      'Kanaal',
      'Variatie',
      'Taal',
      'Prompt kopiëren',
      'Herstelprompt kopiëren',
      'In het document invoegen',
      'Naamval',
      'Notitie',
      'Prompt gekopieerd. Breng hem naar uw model en het antwoord terug.',
      'Herstelprompt gekopieerd. Hij wijst de precieze plekken aan.',
      'Concept ingevoegd. Het oordeel staat in het diagnosepaneel.',
      'Schrijf eerst een briefing.',
      'Plak eerst het antwoord van het model.',
      'Geen fouten om te herstellen.',
      'e-mail',
      'sms',
      'push',
      'landingspagina',
      'algemeen',
      'behoudend',
      'evenwichtig',
      'gedurfd',
      '—',
      'nominatief',
      'genitief',
      'datief',
      'accusatief',
      'instrumentalis',
      'prepositief',
      'Het document vervangen',
      'Document vervangen. Het oordeel staat in het diagnosepaneel.',

      (* R1-4: the loop in the window (spec §4.5). The Dutch help never names the engine,
         so the verify line speaks of the check itself rather than inventing a term. *)
      'Herstellen',
      'AI-instellingen…',
      'gestopt',
      'het model wordt gevraagd…',
      'het concept wordt gecontroleerd…',
      'herstelpoging %d van %d',
      'Geen fouten, maar een deel van de proefrenders komt leeg terug — controleer de meervoudsvormen. Het concept staat in het AI-paneel, niet toegepast.',
      'Het concept is schoon, maar een ingesloten fragment bevat een fout. Herstel dat bestand — opnieuw genereren kan dat niet.',
      'Er blijven %d fouten over na %d herstelpogingen. Het concept staat in het AI-paneel, niet toegepast.',
      'Het document is veranderd terwijl het antwoord onderweg was. Het concept staat in het AI-paneel, niet toegepast.',
      'Dit profiel authenticeert zich en er is geen sleutel gekoppeld. Voer de sleutel in het AI-paneel in.',
      'Het endpoint vraagt om een ander adres (%s). Het is niet gevolgd; wijzig het profiel als dit de bedoeling is.',
      'Onversleuteld http voorbij deze machine zou de sleutel en de tekst leesbaar versturen. Gebruik https.',
      'Het endpoint heeft de sleutel geweigerd. Controleer hem in het AI-paneel.',
      'Het endpoint meldt een verzoeklimiet of een uitgeput quotum. Probeer het later.',
      'De prompt is langer dan dit model aanneemt.',
      'Het verzoek kwam niet door: %s',
      'Het endpoint antwoordde, maar in een vorm die deze toepassing niet kan lezen: %s',
      'Het antwoord bevatte geen sjabloon.',
      'Het endpoint meldt: %s',
      'Verbinding',
      'Formaat',
      'Endpoint',
      'Model',
      'Autorisatie',
      'geen',
      'API-sleutel',
      'Sleutel',
      'Sleutel koppelen',
      'Sleutel vergeten',
      'er is een sleutel aan dit endpoint gekoppeld',
      'geen sleutel gekoppeld',
      'het endpoint is veranderd — voer de sleutel opnieuw in om hem aan het nieuwe adres te koppelen',
      'Versturen toegestaan',
      'Naar dit endpoint versturen?',
      '"Genereren" en "Herstellen" versturen de briefing, het huidige sjabloon en de gedeclareerde variabelen naar het endpoint van dit profiel:'#10'%s'#10#10'Bij autorisatie met API-sleutel reist de sleutel mee in de headers van het verzoek. Op geen enkel ander moment wordt iets verstuurd, en het adres verandert nooit vanzelf: een omleiding wordt geweigerd en getoond. Wat de software op dat adres met de tekst doet, bepaalt de beheerder ervan.'#10#10'U kunt dit op elk moment uitschakelen in de AI-instellingen.',

      (* R1-5: the report channel (Store policy 11.16) *)
      'Ongepaste AI-uitvoer melden…',

      (* the brief column's two modes (UX pass 2026-08-13) *)
      'Te converteren tekst',
      'Plak eerst de te converteren tekst.',

      (* find and replace (UX-plan item 8, 2026-08-14) *)
      'Vervangen…',
      'vervangen door',
      'Vervangen',
      'Alles vervangen',
      'Vervangen: %d',

      'Invoegen',
      'Omsluiten met /#…#/',
      '#set %naam% = waarde',
      '#def %naam% = {a|b}',
      '#include "naam"',
      '{?naam?dan|anders}',
      'Niet omsloten: een #/ in of rond de selectie zou de opmerking te vroeg beëindigen.',
      'Niet omsloten: een losse |, een niet-gesloten haak of een open opmerking zou de voorwaarde veranderen.',
      'Niet ingevoegd: de cursor splijt een opmerkingsteken in tweeën.',
      'Het endpoint-adres is niet te lezen — herstel het en koppel dan de sleutel.'
  );

implementation

end.
