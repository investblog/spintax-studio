# Spintax Studio

Questo programma è un editor di modelli. Un modello è testo comune con qualche punto segnato
dentro, e un solo modello può produrre moltissimi testi diversi: è tutto il senso di scriverne uno
invece di scrivere i testi.

La finestra è fatta di due metà. A sinistra il vostro modello, ciò che modificate. A destra uno
dei testi che ne escono, ridisegnato mentre scrivete. In mezzo non c'è nulla da premere: quello
che vedete a destra è ciò che il motore restituisce per quanto sta a sinistra in quell'istante.

```spx-fixture
locale: it
seed: 7
empty: (vuoto)
```

Il motore è dentro questo programma ed è il membro Pascal di una famiglia: lo stesso linguaggio è
pubblicato anche per JavaScript, PHP e Python. I quattro sono programmi indipendenti tenuti a un
unico insieme di casi di prova, cosicché quel che un modello SIGNIFICA è uguale in tutti: i
costrutti, il verdetto sulla validità, le rifiniture. Un modello che questa finestra chiama valido
lo è anche là.

Ciò che non viene promesso, e la differenza conta quando si confronta: l'estrazione a sorte. Un
seme rende l'anteprima ripetibile QUI — lo stesso seme e lo stesso modello danno domani lo stesso
testo — ma lo stesso seme nel motore JavaScript può pescare un'altra alternativa. I semi servono a
riprodurre il vostro lavoro, non a coincidere con un altro motore.

Tutto qui funziona senza connessione di rete. Non c'è un account, non c'è accesso e non c'è nulla
da attivare: aprite il programma e sta già funzionando.

## Le due metà

Si scrive a sinistra. La metà destra si ridisegna dopo una breve pausa, così l'anteprima segue una
frase e non ogni lettera.

Un modello con una scelta dentro non ha una risposta sola, e l'anteprima ne mostra una:

```spx-good
{Ciao|Salve} a tutti.  →  Ciao a tutti.
```

**Rilancia**, sopra la metà destra, ne prende un'altra. Se ne volete sempre la stessa — mentre
confrontate due modifiche, per esempio — spuntate **seed**, e l'anteprima resta ferma finché non
lo togliete o cambiate il numero.

Il selettore sopra la metà destra offre **Pagina** e **Sorgente**. I modelli sono per lo più HTML, e le due
domande «che aspetto ha» e «quale marcatura è uscita» non si rispondono a vicenda: un tag rotto dà
un impaginato un po' storto che l'occhio salta, mentre la prosa piena di tag non si legge come
prosa. L'interruttore sopra la metà cambia ciò che state guardando.

Selezionate una parte del modello e solo quella viene resa — nell'ambito dell'intero documento,
così che un frammento che usa una variabile definita in alto esca come uscirà al suo posto.

## Trova e sostituisci

**Ctrl+F** apre un campo di ricerca nell'intestazione. Il contatore accanto dice quante volte
il testo compare e su quale occorrenza vi trovate; **Invio** avanza, **Maiusc+Invio** torna
indietro, F3 funziona direttamente dal documento. Le maiuscole contano solo con la casella
accanto al campo — e la piegatura è quella del motore, così una lettera cirillica o accentata
coincide con l'altra sua forma esattamente dove l'anteprima le considera una sola lettera.

**Ctrl+H** — o la voce di menu **Sostituisci…** — dà alla barra una seconda riga: la
sostituzione e due pulsanti. **Sostituisci** cambia l'occorrenza su cui vi trovate e passa
alla successiva; finché non c'è nulla di trovato, la prima pressione cerca soltanto.
**Sostituisci tutto** percorre l'intero documento in una volta, e la barra di stato dice
quanti punti sono cambiati; un solo Ctrl+Z riprende l'intero passaggio.

La sostituzione è letterale. Può essere vuota — questo cancella — e può contenere il testo
cercato senza mandare il passaggio in circolo: i punti si decidono prima, sul testo com'era.
Quando le occorrenze si sovrappongono, il contatore conta ognuna che un passo può visitare,
ma il passaggio cambia solo quelle che non condividono lettere — «sostituiti» può quindi
onestamente dire un numero minore.

Un documento sostituito passa per lo stesso motore del testo digitato: l'anteprima si
ridisegna e la diagnostica risponde su ciò che c'è ora.

## Inserire i segni

Tutto ciò che mette nel documento i segni del linguaggio stesso sta nel menu **Inserisci**.

I tre comandi di racchiusura prendono la selezione così com'è: **Racchiudi in {…}** la rende una scelta,
**Racchiudi in […]** un rimescolamento, **Racchiudi in /#…#/** (Ctrl+/) un commento. La racchiusura in commento rifiuta quando un `#/` dentro o attorno alla selezione — o un
commento già aperto in quel punto — finirebbe un commento troppo presto: il primo segno di
chiusura vince ovunque si trovi, parte del testo ricadrebbe fuori; lo dice la barra di stato,
perché il motore tace. Senza selezione, Ctrl+/ inserisce la coppia e lascia il cursore all'interno.

I costrutti sotto arrivano esattamente come il menu li legge. **#set %nome% = valore**, **#def %nome% = {a|b}** e **#include "nome"** prendono
una riga propria — una direttiva conta solo quando apre la sua riga, quindi il testo prima
del cursore resta sopra e quello dopo scende — e il nome esce selezionato, pronto per essere
sovrascritto. Tenete i nomi in lettere latine: un nome in un altro alfabeto, in silenzio,
non è un nome. La destinazione di `#include` è l'eccezione — viene confrontata con i nomi dei
vostri frammenti esattamente com'è scritta.

**{?nome?allora|altrimenti}** sta dentro la riga. Con una selezione, il testo selezionato diventa la metà «allora» —
un modo per rendere condizionale ciò che è già scritto; senza selezione entra la forma
intera. Una selezione con una `|` nuda, una parentesi non chiusa o un commento aperto viene rifiutata:
la racchiusura cambierebbe ciò che dice invece di incorniciarlo.

L'ultima voce mette nel documento l'esempio aperto nella guida — il pulsante del pannello
della guida stesso, reso raggiungibile dalla tastiera.

## I pannelli in basso

La barra degli strumenti di lato apre quattro pannelli, uno per volta.

**Diagnostica** elenca ciò che il motore ha trovato sbagliato, ogni volta con la riga e la colonna
d'inizio. Un clic su una riga vi porta il cursore. È lo stesso verdetto che il motore dà ovunque
altrove, non un secondo parere dell'editor: per questo un modello che questo pannello chiama
valido viene accettato dagli altri motori.

**Variabili** mostra i nomi che il vostro documento definisce e quelli che soltanto usa. Un nome
che usa e che nulla definisce potete riempirlo qui per la sessione: scrivete un valore accanto e
l'anteprima lo raccoglie. Spuntate **come testo** quando il valore è testo che significa se stesso
e non un piccolo modello a sua volta.

**Varianti** genera molti testi in una volta. Dite quanti, generateli e leggeteli nella lista prima
di esportare. I quasi doppioni si possono scartare mentre nascono, e un seme rende ripetibile
l'intero lotto: lo stesso seme e lo stesso modello danno domani le stesse varianti.

Accanto a quei campi il pannello dice quante varianti il modello può dare in tutto:
`{a|b} e {c|d}` ne fa quattro. Quel numero vi avverte che un modello è povero prima che ne
generiate cinquanta e ve ne accorgiate leggendole.

È un conto esatto solo finché ogni scelta è lasciata al caso. Una condizione, una forma di numero
o un `#include` di cui l'insieme non ha il bersaglio sono decisi da altro — un valore che fornite
voi, un numero, un frammento che forse arriverà —, e allora il pannello dice **almeno**. È la
parola onesta: fornire un valore può solo aggiungere testi, mai toglierne. Un numero troppo grande
per leggerlo si ferma a mille miliardi e dice **almeno** per la stessa ragione.

Una variante è un modello riempito — una scelta fatta a ogni costrutto — e non è la stessa cosa di
un testo che si legge diversamente. `{a|a}` sono due varianti e un testo, ed è voluto: le due
possibilità possono smettere di coincidere dopo una sola modifica, e unirle vorrebbe dire generare
prima ogni combinazione, cioè proprio il lavoro che questo numero vi risparmia. Un `#def` conta
allo stesso modo: il motore lo estrae una volta per resa, che il ramo preso lo usi o no.

L'esportazione li scrive in tre modi: come cartella XLSX, come testo semplice con una variante per
riga, oppure come un file per variante in una cartella a vostra scelta.

**Bozza IA** è il punto da cui parte un modello quando non vuoi scrivere ogni variante a
mano. Di' nel brief che cosa ti serve, elenca le variabili che il modello può usare e premi
**Copia il prompt**. L'applicazione non parla con nessun modello e non conserva chiavi: scrive il prompt
perché tu lo porti a quello che già usi. Riporta la risposta e premi **Inserisci nel documento** — il motore di
questa finestra dice allora che cosa ne pensa, nel pannello delle diagnostiche, esattamente come
per tutto ciò che scrivi tu. Se ci sono errori, **Copia il prompt di correzione** costruisce un secondo prompt: porta l'intero documento con le righe numerate e indica i punti
esatti che il motore ha contestato. La risposta è il documento corretto per intero, quindi
riportala e premi **Sostituisci il documento**: **Inserisci nel documento** lascerebbe quello
rotto dov'è e ne metterebbe una copia corretta accanto.

La colonna del caso è la parte che vale la pena compilare. Una variabile viene inserita alla
lettera, nulla la declina: in una lingua con i casi la frase va costruita attorno alla forma che
il valore ha già, e un modello sceglie bene solo se gli si dice quale forma porta ogni nome. Dal
nome non si ricava: in un vero insieme di modelli le forme strumentali stavano in una variabile
il cui nome diceva accusativo.

## L'editor di gruppi

Mettete il cursore dentro un `{a|b|c}` e aprite l'editor di gruppi dalla barra degli strumenti.
Elenca le alternative come righe: modificatele, aggiungetene una, toglietene una, e il documento
viene riscritto di conseguenza.

Rifiuta le modifiche che cambierebbero ciò che il gruppo SIGNIFICA invece di ciò che dice: un `|`
scritto dentro un'alternativa ne farebbe due, e un `}` chiuderebbe il gruppo troppo presto. Quando
rifiuta, lo dice e lascia stare il documento.

## Impostazioni

Stanno nel menu Visualizza, e ognuna viene ricordata da una sessione all'altra: la lingua
dell'interfaccia e se segue il modello, da che lato sta la barra degli strumenti, il tema, il
carattere dell'editor e la sua dimensione, se l'anteprima mostra la pagina o il sorgente,
l'interruttore dell'importazione GSA, quale pannello è aperto e le larghezze dei pannelli che si
aprono a scorrimento.

L'interfaccia parla quattordici lingue, scelte nello stesso menu. È cosa distinta dalla lingua del
vostro modello, che è quella che decide le forme di numero e si imposta sopra la metà destra.

## Importare un modello GSA

Questa parte è spenta finché non l'accendete, sotto **Visualizza**, **Importazione GSA**, perché
la maggior parte di chi scrive modelli non ha mai usato GSA Search Engine Ranker. Accesa,
**File**, **Importa modello GSA…** legge un modello SER e lo converte in questo linguaggio.

La conversione è prudente in un modo preciso. Ciò che non può esprimere fedelmente lo rifiuta e ve
lo dice, invece di trasformarlo in silenzio in qualcosa che si rende. I costrutti che verrebbero
letti male se restassero nel testo — parentesi BBCode, un `#` dentro un collegamento, una macro
`#file[...]` — vengono estratti in variabili, e il riepilogo dice quanti.

Due cose da sapere sul risultato:

- **I valori estratti sono valori di sessione.** Compaiono nel pannello Variabili e non vengono
  salvati con il documento. Salvate il modello convertito, riapritelo domani e vedrete `%…%` dove
  stava il testo estratto. Dal file importato non si perde nulla — quello resta intatto — ma il
  documento convertito non sta in piedi da solo.
- **Viene reso senza la passata di rifinitura.** Ogni altro documento qui riceve le rifiniture
  descritte nella guida del linguaggio; un modello convertito no, perché non è testo nostro da
  lisciare. È di qualcun altro, di solito è sulla via del ritorno verso GSA, e deve sopravvivere
  carattere per carattere.

Il documento importato è senza titolo e non salvato, come uno nuovo. Il file che avete scelto resta
esattamente com'era.
