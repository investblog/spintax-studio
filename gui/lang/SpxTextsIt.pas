(*
 * SpxTextsIt -- the window in Italian.
 *
 * One language, one file. The order is TSpxStr's and nothing else: this is a positional
 * array, so a line moved here moves a caption on screen.
 *)
unit SpxTextsIt;

{$mode objfpc}{$H+}

interface

uses
  SpxStrIds;

const
  TEXTS_IT: array[TSpxStr] of string = (
      'File', 'Nuovo', 'Apri…', 'Salva', 'Salva con nome…', 'Ricarica il set', 'Esci',
      'Modifica', 'Trova…', 'Trova successivo', 'Trova precedente',
      'Visualizza', 'Strumenti a sinistra', 'Strumenti a destra',
      'Lingua dell''interfaccia', 'English', 'Русский', 'Come il modello',
      'G', 'Gruppo sotto il cursore',
      'Il cursore non è dentro un gruppo.', 'Applica',
      'Rifiutato: il risultato direbbe altro rispetto a questo elenco — una variante non ' +
        'può contenere | } { o /#.',
      'Una variante contiene un a capo, quindi il gruppo è mostrato ma non modificabile.',
      'Scelta', 'Condizione', 'Plurale', 'Permutazione',
      'D', 'V', 'Vr',
      'Racchiudi in {…}', 'Racchiudi in […]', 'Mostra un''altra variante',
      'Copia il risultato',
      'Seleziona tutto',

      'seed', 'Rilancia', 'Copia', 'Pagina', 'Sorgente',
      'frammento mostrato', 'il frammento non produce nulla',

      'Maiusc.', 'non trovato', 'trovati %d', '%d/%d', 'x',

      'Diagnostica', 'Variabili', 'Varianti',
      'Livello', 'File', 'Dove', 'Messaggio',
      'errore', 'avviso', 'nota di Studio', 'documento',

      ' Definizioni — vivono nel documento',
      ' Valori di sessione — resi come spintax, mai scritti nel documento',
      'Tipo', 'Nome', 'Valore', 'come testo',

      'Quante', 'seed', 'casuale', 'Genera', 'Ferma',
      'Scarta le simili', 'Solo duplicati esatti', 'Tieni tutto', 'shingle', 'soglia',
      'In .xlsx', 'In .txt', 'Un file ciascuna', 'seed nel .txt',
      'niente generato', 'in corso…', 'arresto…',
      '%d varianti, %d scartate, %d render, seed successivo %d',
      '%d di %d — il modello non dà di più a questa soglia (%d scartate, %d render)',
      'fermato: %d varianti, %d scartate, %d render',
      '%d di %d, %d scartate, %d render',
      'il documento è cambiato — questo set viene dal testo precedente; ',
      'scritte %d righe in %s',
      'scritte %d righe; in %d varianti gli a capo sono diventati spazi — per il testo ' +
        'com''è, usa .xlsx o un file ciascuna',
      'scritti %d file in %s', 'scritti %d file, poi non è stato possibile continuare',
      'non è stato possibile scrivere il file',
      '#', 'seed', 'lunghezza', 'testo',

      'Apri un modello', 'Salva il modello', 'Modelli spintax|*%s|Tutti i file|*.*',
      'Cartella Excel|*.xlsx', 'Testo|*.txt',
      'Esporta in .xlsx', 'Esporta in .txt', 'Dove mettere i file', 'Varianti',
      'seed', 'variante',
      'Spintax Studio', 'Il documento ha modifiche non salvate. Salvarle?', 'Senza nome',
      '%s — Spintax Studio',

      'pronto', 'valido', 'valido · avvisi: %d', 'errori: %d', ' · note: %d', '%s · %d ms',
      'Mostra', 'Uscita: %d KB — la pagina non si ridisegna da sola',

      'Chiudi',

      'Più grande', 'Più piccolo', 'Dimensione normale', 'Chiaro', 'Scuro',

      'Larghezze uguali', 'Doppio clic: larghezze uguali',

      'Carattere dell''editor', 'Automatico',

      'Valore non applicato: il motore leggerebbe la direttiva in modo diverso',

      'Inclusioni — i frammenti che questo documento richiama', 'Destinazione', 'Trovato', 'sì', 'MANCA', 'nessun set',

      'Guida', 'Sommario', 'Lingua della guida', 'Non c’è ancora una guida in %s.',

      'dalla guida', 'Inserisci nel mio documento',

      'Informazioni',

      'Ancora nessuna macro — scriva #set %name% = valore nel documento e usi %name% nel testo.',
      'Ancora nessuna inclusione — #include "frammento" richiama un altro file, e solo a inizio riga.',

      'Scrivi un modello a sinistra e guarda a destra che cosa produce. Convalida, variabili, inclusioni, generazione di varianti ed esportazione: tutto offline, senza account, senza rete e senza runtime.',
      'Licenze e riconoscimenti',

      'Importazione GSA',
      'Importa modello GSA…',
      'Modelli GSA|*.txt;*.spintax|Tutti i file|*.*',
      '%d variabili sono state estratte dal modello.',
      'Sono valori di sessione: compaiono nel pannello delle variabili e NON vengono salvati con il documento. Il rendering avviene senza post-elaborazione, così il modello resta quello scritto da GSA.',
      '%d blocchi sono stati rifiutati e lasciati tali e quali.',
      '…e altri %d.',

      'Varianti possibili: %s',
      'Varianti possibili: almeno %s',

      (* the AI panel (ADR 0011) *)
      'Bozza IA',
      'Brief',
      'Variabili che il modello può usare',
      'Risposta del modello',
      'Canale',
      'Variazione',
      'Lingua',
      'Copia il prompt',
      'Copia il prompt di correzione',
      'Inserisci nel documento',
      'Caso',
      'Nota',
      'Prompt copiato. Portalo al tuo modello e riporta la risposta.',
      'Prompt di correzione copiato. Indica i punti esatti.',
      'Bozza inserita. Il verdetto è nel pannello delle diagnostiche.',
      'Scrivi prima un brief.',
      'Incolla prima la risposta del modello.',
      'Nessun errore da correggere.',
      'e-mail',
      'SMS',
      'push',
      'pagina di destinazione',
      'generico',
      'prudente',
      'equilibrata',
      'audace',
      '—',
      'nominativo',
      'genitivo',
      'dativo',
      'accusativo',
      'strumentale',
      'prepositivo',
      'Sostituisci il documento',
      'Documento sostituito. Il verdetto è nel pannello delle diagnostiche.',

      (* R1-4: the loop in the window (spec §4.5). Italian shares one word for the template
         and the LLM ("modello"), so what is sent is "il prompt" and "il modello" stays the
         LLM alone. *)
      'Correggi',
      'Impostazioni IA…',
      'fermato',
      'richiesta al modello…',
      'il motore verifica la bozza…',
      'tentativo di correzione %d di %d',
      'Nessun errore, ma parte dei render di prova esce vuota — controllate le forme del plurale. La bozza è nel pannello IA, non applicata.',
      'La bozza è pulita, ma un frammento incluso contiene un errore. Correggete quel file — rigenerare non può ripararlo.',
      'Restano %d errori dopo %d tentativi di correzione. La bozza è nel pannello IA, non applicata.',
      'Mentre la risposta era in viaggio è cambiato qualcosa contro cui era verificata — il documento, valori o impostazioni. La bozza è nella risposta, non applicata.',
      'Questo profilo si autentica e nessuna chiave è collegata. Inserite la chiave nel pannello IA.',
      'L''endpoint chiede di rivolgersi a un altro indirizzo (%s). Non è stato seguito; cambiate il profilo se è voluto.',
      'Http in chiaro oltre questa macchina invierebbe la chiave e il testo in chiaro. Usate https.',
      'L''endpoint ha rifiutato la chiave. Controllatela nel pannello IA.',
      'L''endpoint segnala un limite di richieste o una quota esaurita. Riprovate più tardi.',
      'Il prompt è più lungo di quanto questo modello accetti.',
      'La richiesta non è passata: %s',
      'L''endpoint ha risposto, ma in una forma che questa applicazione non può leggere: %s',
      'La risposta non conteneva alcun modello.',
      'L''endpoint segnala: %s',
      'Connessione',
      'Formato',
      'Endpoint',
      'Modello',
      'Autorizzazione',
      'nessuna',
      'Chiave API',
      'Chiave',
      'Collega la chiave',
      'Dimentica la chiave',
      'una chiave è collegata a questo endpoint',
      'nessuna chiave collegata',
      'l''endpoint è cambiato — inserite la chiave di nuovo per collegarla al nuovo indirizzo',
      'Invio consentito',
      'Inviare a questo endpoint?',
      '"Genera" e "Correggi" inviano il brief, il modello attuale e le variabili dichiarate all''endpoint di questo profilo:'#10'%s'#10#10'Con l''autorizzazione a chiave API, la chiave viaggia nelle intestazioni della richiesta. Nient''altro viene inviato in nessun altro momento, e l''indirizzo non cambia mai da solo: un reindirizzamento viene rifiutato e mostrato. Ciò che il software a quell''indirizzo fa del testo dipende dal suo operatore.'#10#10'Potete disattivarlo in qualsiasi momento nelle impostazioni IA.',

      (* R1-5: the report channel (Store policy 11.16) *)
      'Segnala un output IA inappropriato…',

      (* the brief column's two modes (UX pass 2026-08-13) *)
      'Testo da convertire',
      'Prima incolla il testo da convertire.',

      (* find and replace (UX-plan item 8, 2026-08-14) *)
      'Sostituisci…',
      'sostituisci con',
      'Sostituisci',
      'Sostituisci tutto',
      'Sostituiti: %d',

      'Inserisci',
      'Racchiudi in /#…#/',
      '#set %nome% = valore',
      '#def %nome% = {a|b}',
      '#include "nome"',
      '{?nome?allora|altrimenti}',
      'Non racchiuso: un #/ dentro o attorno alla selezione finirebbe il commento troppo presto.',
      'Non racchiuso: una | isolata, una parentesi non chiusa o un commento aperto cambierebbe il senso della condizione.',
      'Non inserito: il cursore taglia in due un segno di commento.',
      'L''indirizzo dell''endpoint non si legge — correggetelo, poi collegate la chiave.',
      'Bozza verificata. Attende nella risposta — inseritela o sostituite voi.'
  );

implementation

end.
