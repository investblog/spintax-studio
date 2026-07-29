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

      'pronto', 'valido', 'valido, %d avvisi', '%d errori', ' · %d note', '%s · %d ms',
      'Mostra', 'Uscita: %d KB — la pagina non si ridisegna da sola',

      'Chiudi'
  );

implementation

end.
