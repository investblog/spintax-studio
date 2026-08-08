# Cosa vi sta dicendo la scheda Diagnostica

Ogni riga di quella scheda è un verdetto del **motore**, e lo stesso verdetto che vi darebbero le
implementazioni JavaScript, PHP o Python: quattro motori indipendenti tenuti a un unico corpus.
Non è l'opinione di Studio sul vostro modello. Se qui il motore chiama errore qualcosa, ogni altro
motore della famiglia lo chiama errore, e il vostro modello si comporterà sul vostro server come
in questa finestra.

| cosa c'è scritto | chi lo dice | cosa significa |
|---|---|---|
| **errore** | il motore | il modello non farà ciò che sembra |
| **avviso** | il motore | si rende, ma probabilmente non come intendevate |
| **nota di Studio** | Studio | il motore non ha detto nulla, e vale comunque la pena dirlo: un'inclusione in cerchio, un bersaglio con altre maiuscole, un carattere di controllo |

La colonna **Dove** è riga e colonna. Un clic sulla riga vi porta il cursore.

> Ogni esempio qui sotto passa per il motore che questa copia di Studio porta con sé, a ogni
> compilazione del programma, e a destra sta esattamente ciò che ha restituito. Nulla qui è
> ricordato o indovinato; una risposta che smettesse di essere vera fermerebbe la compilazione.
> La versione del motore è sotto **Aiuto**, **Informazioni**.

## Come leggere gli esempi

La freccia `→` separa il modello da ciò che il motore ha restituito. `⏎` è un a capo dentro
un'uscita, `(vuoto)` vuol dire che non ha stampato nulla del tutto, e `…` segna un'uscita troppo
lunga da mostrare per intero. Il testo dopo l'uscita, staccato da tre spazi, è una nota e non parte
della risposta.

Le condizioni in cui gli esempi sono girati stanno qui e non nascoste nelle prove: senza di esse
alcune risposte non si potrebbero riprodurre. L'insieme dei modelli conta di più: altrimenti
`#include "frag"` → `Frammento` poggerebbe su qualcosa che questo documento non dice mai.

```spx-fixture
locale: it
seed: 7
empty: (vuoto)
include frag: Frammento
include loop: #include "loop"
include Intro: Introduzione
```

`seed` fissa l'estrazione: senza di esso una scelta o un rimescolamento risponderebbero
diversamente ogni volta e non ci sarebbe niente da verificare.

**La locale qui è `it`, e decide due cose:** quante forme di numero il motore si aspetta e quale
forma va con quale numero. L'italiano e l'inglese ne chiedono due. Il russo, l'ucraino, il
bielorusso, il serbo, il croato e il bosniaco ne chiedono tre. La locale viene dal selettore sopra
la metà destra, non dalla lingua dell'interfaccia.

---

## Parentesi

**Mettete il cursore su una parentesi e il costrutto si mostra intero:** dove comincia, dove
finisce e **ognuno dei suoi separatori**. I gruppi annidati non si accendono con lui: hanno
separatori propri, e quelli arrivano quando il cursore si posa sulla loro parentesi. È il modo più
rapido di vedere dove finisce ciò che state modificando, soprattutto in una riga lunga dove la `}`
è finita due schermi a destra.

Un separatore non è solo `|`. In un rimescolamento `[a<br>|b]` ne ha due: il motore legge `<br>`
come separatore messo **prima del pezzo seguente**, e l'evidenziazione lo mostra insieme agli
altri, perché fa parte di come il costrutto è fatto.

### `bracket.unclosed` — una parentesi è aperta e mai chiusa

```
un prezzo {basso|alto  →  Un prezzo {basso|alto
```

Il motore non indovina dove volevate chiudere. Il testo resta com'è, graffa compresa, e la scelta
non avviene mai.

### `bracket.mismatched` — chiusa da una parentesi di altro tipo

```
un prezzo {basso|alto]  →  Un prezzo {basso|alto]
```

`{` aspetta `}` e `[` aspetta `]`. Un rimescolamento chiuso da una graffa non è un rimescolamento.

### `bracket.unexpected-closing` — una parentesi di chiusura senza nulla di aperto

```
un prezzo basso} e tutto  →  Un prezzo basso} e tutto
```

Resta lì come testo. Quasi sempre è una parentesi avanzata da una modifica.

---

## Definizioni

### `set.malformed` — questa riga `#set` non segue la regola

```
#set citta = Milano
in %citta%  →  #set citta = Milano ⏎ In %citta%
```

**Il nome va fra segni di percentuale:** `#set %citta% = Milano`. È il primo errore più comune, e
mette due righe in una volta nel pannello: la riga malformata stessa e «questa variabile non è
definita da nessuna parte», perché nessuna definizione è avvenuta e `%citta%` non è di nessuno.

Guardate l'uscita: la direttiva fallita è rimasta nel testo **così com'era scritta**. Il motore non
l'ha letta come direttiva, quindi è una riga comune e finisce nel risultato.

### `def.malformed` — questa riga `#def` non segue la regola

```
#def pagine = {1|3}
%pagine%  →  #def pagine = 1 ⏎ %pagine%
```

La stessa regola e lo stesso prezzo. `#def` non differisce da `#set` nella scrittura ma nel
**quando** il valore viene dispiegato: `#set` lo dispiega a ogni menzione, `#def` una volta per
resa. Un errore di scrittura vi costa entrambe le cose.

E guardate bene: il `{1|3}` della direttiva fallita **ha estratto una possibilità**. La riga è
diventata testo comune, e il testo comune si rende come testo comune, graffe comprese. Una riga
malformata non è spenta; smette soltanto di essere una direttiva.

### `definition.duplicate-name` — questo nome è già definito sopra

```
#set %x% = primo
#set %x% = secondo
%x%  →  Secondo
```

Funziona — vince l'**ultima** definizione — ma il motore lo chiama errore: un documento in cui un
nome è posto due volte si legge in modo ambiguo, e fra un mese non ricorderete quale delle due
righe è quella viva. L'errore indica la **seconda** definizione; la prima sta più in alto.

### `def.include-in-value` — `#include` dentro il valore di una definizione

```
#def %x% = #include "frag"
%x%  →  Frammento
```

Un'inclusione dentro un valore si dispiega in un momento diverso da quello che vi aspettereste, e
la famiglia lo vieta. Mettete l'`#include` su una riga sua.

---

## Variabili

### `variable.undefined` — questa variabile non è definita da nessuna parte

```
ciao, %nome%  →  Ciao, %nome%
```

Un avviso e non un errore: il motore stampa il nome così com'è. È voluto, perché il valore può
venire da fuori, dall'ospite. In Studio quei valori si forniscono nella scheda Variabili, sotto
**Valori di sessione**.

**Il valore di una definizione si può modificare nel pannello.** Mettetevi sulla colonna Valore
nella parte alta e premete **F2** (o cominciate semplicemente a scrivere); **Invio** applica,
**Esc** annulla. La modifica va **nel documento**, in un solo passo di annullamento: `Ctrl+Z` la
rimette.

Il nome e il tipo (`#set` o `#def`) non si modificano: è una decisione e non un angolo lasciato a
metà. Rinominare da una cella rompe ogni menzione della variabile nel documento, e cancellare la
riga si porterebbe via il commento e il rientro. Entrambe le cose appartengono al testo, dove
vedete quel che state facendo.

Cambia esattamente il valore. Il rientro, gli spazi in più, le maiuscole del nome e un commento a
fine riga restano com'erano: `   #set  %Marchio%   =   Acme   /# resto #/` torna da una modifica
differendo solo in `Acme`. Il file sta in git, e riformattare una riga vi comparirebbe come vostra
modifica.

**Un rifiuto vuol dire che il motore leggerebbe la riga diversamente.** La modifica non viene
applicata in silenzio: il motore rilegge il risultato, e se non dice quel che era stato chiesto,
il documento resta com'è e la barra di stato lo dice. Tre cause reali: un `/#` nel valore apre un
commento che si mangia il resto del file, un a capo chiude la direttiva troppo presto, e un
commento **dentro** la direttiva rende la riga non modificabile a pezzi; quella modificatela nel
testo.

**Due gesti sul nome di una variabile.** Il nome nel pannello è un collegamento e non un'etichetta:

- **un clic sul nome** porta il cursore al primo punto in cui il documento usa quella variabile, e
  la riga si illumina per un istante. La stessa parola dentro un commento o come bersaglio di un
  `#include` **non** conta: il pannello vi porta dove la variabile lavora davvero.
- **Ctrl+clic** scrive una definizione nel documento e ci apre sopra l'editor di gruppi. Il valore
  che avete già scritto vi entra come prima possibilità:

```
#set %marchio% = {Vulkan}
casinò %marchio%  →  Casinò Vulkan
```

La differenza fra i due è che cosa sopravvive alla chiusura della finestra. Un valore di sessione
no: non sta nel file, non sta in git, e nessun altro motore della famiglia lo vede. Una definizione
sì, e solo una definizione zittisce questo avviso per sempre. Un `Ctrl+Z` rimette il documento.

**Un valore di sessione è prima di tutto un modello e non testo.** È ciò che il motore fa con
qualsiasi valore dell'ospite, e l'anteprima deve coincidere con il server, quindi `{basso|alto}`
scritto nel campo del valore dà una scelta e non quei caratteri. Se intendevate il testo in
sé, spuntate **come testo** nella terza colonna: allora graffe e segni di percentuale restano
caratteri.

### `variable.self-reference` — la definizione nomina se stessa

```
#set %x% = a %x% b
%x%  →  A a a … %x% … b b b
```

Cinquanta livelli, poi stop. Il motore dispiega fino al limite di profondità e si ferma, lasciando
`%x%` in mezzo. Non è un ciclo, e non è nemmeno quel che volevate.

Il `…` qui sopra è l'abbreviazione di questo documento e non quella del motore. L'uscita vera è
lunga 207 caratteri e porta **cinquantuno** lettere per lato invece di cinquanta: il cinquantesimo
livello si ferma e lascia il valore com'è, e il valore ne contiene una in più di ciascuna.

### `variable.circular-reference` — le definizioni si nominano in cerchio

```
#set %x% = %y%
#set %y% = %x%
%x%  →  %y%
```

Ogni lato si dispiega esattamente **una volta** e poi si ferma: `%x%` è diventato `%y%` e non
`%x%`. Il motore srotola il cerchio invece di percorrerlo, e ciò che sopravvive è l'altro nome del
cerchio: mettete `%x% %y%` in un documento e uscirà `%y% %x%`, la coppia rovesciata.

Il pannello traccia una riga per **ogni menzione che chiude il cerchio**, non una riga per il
cerchio né una per definizione. Una definizione che nomina il cerchio due volte riceve due righe
sulla propria riga: `#set %x% = %y% %y%` contro `#set %y% = %x%` fa tre errori, due dei quali sulla
prima. Le righe non vengono unite. E la posizione si posa sulla definizione che vale davvero: se il
nome è definito due volte, è l'**ultima**.

---

## Inclusioni

### `#include` funziona solo a inizio riga

```
prima #include "frag" dopo  →  Prima #include "frag" dopo
```

```
#include "frag"  →  Frammento
```

Nessuna diagnostica, ed è proprio il punto: un `#include` in mezzo a una riga **non** è
un'inclusione. Il motore lo legge come testo comune e non dice nulla, perché non c'è nulla di cui
lamentarsi: avete scritto testo e avete ottenuto testo.

**Il bersaglio però può stare una riga più sotto**, e questo sorprende dall'altro lato. Lo spazio
che il motore concede fra la parola e il suo bersaglio comprende gli a capo, quindi questa è
un'inclusione e funziona:

```spx-good
#include
"frag"  →  Frammento
```

Anche righe vuote in mezzo vanno bene. Tutto il resto no: una parola prima del bersaglio o
qualunque cosa diversa da spazi dietro, e il tutto torna a essere testo. L'editor colora il
bersaglio sulla sua riga ma lascia la parola comune finché il bersaglio non è arrivato: non
promette una direttiva di cui non vede ancora la fine.

### `include.unknown-target` — nessun bersaglio con quel nome nell'insieme

```
#include "nessuno"  →  (vuoto)
```

I bersagli sono i file `.spintax` nella cartella del documento aperto. Un bersaglio sconosciuto si
dispiega in nulla: il paragrafo sparisce invece di rompersi, ed è proprio per questo che è tanto
facile non accorgersene.

**Per questo la scheda Variabili ha una terza sezione, Inclusioni.** Elenca ogni `#include` del
documento e, per ciascuno, se l'insieme ha il suo bersaglio: una riga per occorrenza, quindi un
bersaglio nominato due volte fa due righe. La sezione compare solo se il documento ha inclusioni.
Un clic su una riga porta il cursore all'`#include` che nomina quel bersaglio.

Il segno ha **tre** valori, e il terzo conta: «nessun insieme» non vuol dire «il frammento manca»,
ma «non c'è ancora dove guardare». L'insieme è la cartella accanto al documento, e un documento non
salvato non ha cartella: fino al primo salvataggio ogni bersaglio è dunque segnato così. «MANCA»
compare solo quando c'è una cartella e il file davvero non c'è.

### `note.case-mismatch` — il bersaglio esiste, con altre maiuscole

```
#include "intro"  →  (vuoto)
```

L'insieme contiene `Intro.spintax`, e il motore dice comunque che non c'è un bersaglio con quel
nome, mentre Studio aggiunge la sua nota sulle maiuscole. Contano: `intro` e `Intro` sono bersagli
diversi. Windows aprirebbe il file in entrambi i modi, ed è proprio per questo che Studio guarda
nell'insieme e non nel file system: altrimenti l'anteprima contraddirebbe il server sullo stesso
documento.

### `note.cycle` — un'inclusione in cerchio

Se `loop.spintax` contiene a sua volta `#include "loop"`, allora:

```
#include "loop"  →  (vuoto)
```

Il motore sostituisce nulla invece dell'infinito. La nota c'è perché sappiate perché il paragrafo
è svanito.

La riga è a carico di **`loop`** e non del documento che state guardando: il cerchio è del
frammento, e lì va il cursore al clic. Nel documento aperto non c'è nulla di sottolineato, perché
alla riga che avete scritto non c'è nulla da rimproverare.

---

## Forme di numero

### `plural.arity` — non tante forme quante la locale ne chiede

```
#set %n% = 5
%n% {plural %n%: oggetto|oggetti|oggettesi}  →  5 ｛plural 5: oggetto|oggetti|oggettesi｝
```

**Non vuoto: il motore stampa l'intero costrutto**, con le graffe sostituite da quelle larghe
`｛｝`. Così dice «ho visto questo e non ho potuto applicarlo». Nessuno lo chiamerebbe discreto, e
meglio così: un paragrafo svanito in silenzio costerebbe di più da trovare.

L'italiano chiede due forme, il russo tre. Sotto la locale di questo documento quella giusta è
`{plural %n%: oggetto|oggetti}`.

**Il vuoto viene da un'altra causa, e le due si confondono facilmente.** Confrontate queste due,
che differiscono solo per quante forme portano:

```
{plural %n%: oggetto|oggetti}  →  (vuoto)   due forme: giusto per l'italiano
{plural %n%: oggetto|oggetti|oggettesi}  →  (vuoto)   tre forme: sbagliato per l'italiano
```

Entrambe non stampano nulla, e il pannello le tratta diversamente: la prima tira solo
`variable.undefined`, la seconda tira anche `plural.arity`. Quindi **il vuoto non è il segno di un
errore sul numero di forme**: qui viene dal fatto che `%n%` non è definita, e il motore verifica il
conteggio prima di contare le forme, fermandosi dunque prima che la domanda sul numero si ponga.

Per questo l'esempio in cima a questo articolo definisce `%n%` per primo. Senza, l'uscita sarebbe
vuota con qualsiasi numero di forme e non mostrerebbe nulla sul numero.

Il pannello e l'uscita rispondono qui a domande diverse, e non è una contraddizione: la riga la
mette la **verifica**, che conta le forme nel testo e del conteggio non si occupa; il vuoto lo dà
la **resa**, che ha un ordine suo. Date una cifra al conteggio, come fa il primo esempio, e vedete
cosa il numero di forme fa davvero.

### `plural.count-macro` — il conteggio viene da un `#set`, e quello rilancia a ogni menzione

```
#set %n% = {1|2}
%n% {plural %n%: oggetto|oggetti}  →  1
```

Guardate cosa è sopravvissuto: **il numero è stato stampato e il sostantivo no.** Il conteggio deve
essere un numero quando la forma viene scelta, e un `#set` il cui valore è a sua volta una scelta
non lo diventa mai: il motore sostituisce il valore **senza renderlo**, quindi al posto del
conteggio arriva il testo letterale `{1|2}`. Il conteggio e la forma non possono contraddirsi; il
motore lascia cadere la parola.

`#def` si comporta diversamente e dispiega il suo valore una volta per resa, quindi il posto del
conteggio riceve un numero:

```
#def %n% = {1|2}
%n% {plural %n%: oggetto|oggetti}  →  1 oggetto
```

Per quello non c'è alcuna riga nel pannello. Da qui la regola: fate del conteggio una cifra
semplice o un `#def`, mai un `#set`.

### `plural.nested-brackets` — parentesi dentro le forme

```
{plural %n%: {oggetto|cosa}|oggetti}  →  ｛plural %n%: ｛oggetto|cosa｝|oggetti｝
```

Le forme sono testo semplice. Una scelta al loro interno non viene dispiegata, e al suo posto è
l'intero costrutto a essere stampato fra graffe larghe.

---

## Rimescolamenti

### `permutation.unknown-key` — chiave sconosciuta nell'impostazione

```
[<foo=1>a|b|c]  →  Bfoo=1cfoo=1a
```

Le chiavi note sono `minsize`, `maxsize`, `sep` e `lastsep`. Una sconosciuta non è
un'impostazione, e quando è l'unica cosa nel blocco, l'intero blocco non è affatto
un'impostazione: diventa il separatore fra i pezzi, che è ciò che l'uscita mostra.

**Se accanto c'è una chiave vera, l'esito è tutt'altro**, ed è l'errore più probabile: una chiave
su più scritta male:

```
[<sep=", ";foo=1>a|b|c]  →  B, c, a
```

Il blocco è un'impostazione, `sep` viene rispettato, la chiave sconosciuta semplicemente lasciata
cadere, e il pannello dice la stessa cosa in entrambi i casi. La diagnostica vi dice dunque che una
chiave non è stata capita; non vi dice cosa è successo dopo. Per quello leggete l'uscita.

### `permutation.minsize-not-integer` — minsize non è un numero intero

```
[<minsize=due>a|b|c]  →  B c a
```

Un valore non numerico cade insieme al suo limite, e vale il valore predefinito, cioè tutti i
pezzi.

### `permutation.maxsize-not-integer` — maxsize non è un numero intero

```
[<maxsize=molti>a|b|c]  →  B c a
```

Esattamente lo stesso dall'altro capo: il limite alto sparisce, e l'uscita contiene di nuovo ogni
pezzo.

---

## Note di Studio senza nulla da mostrare

Le tre note qui sotto non si possono mostrare con un esempio in questo documento, e il motivo è
diverso ogni volta ed è detto. Un articolo ce l'hanno comunque: la guida deve una risposta a
**ogni** riga che il pannello può mostrare, altrimenti una riga del pannello non porta da nessuna
parte.

### `note.raw-sentinel` — un carattere di controllo nel testo

I caratteri U+E000–U+E005 sono quelli che il motore usa per la propria marcatura, e li **toglie**
prima di analizzare. Se sono finiti nel vostro modello — di solito incollati da un altro editor —
Studio lo dice: né l'anteprima né il server li mostreranno.

Qui non c'è un esempio di proposito: quei caratteri sono invisibili, e una riga che li portasse
sembrerebbe vuota. Non ci sarebbe nulla da vedere.

### `note.unknown-target` — l'insieme è vuoto, non c'è con cosa giudicare

Compare quando l'insieme accanto al documento è **vuoto**: neppure un modello oltre a questo. Non
c'è nulla con cui confrontare il bersaglio, quindi Studio non dice «nessun bersaglio con quel
nome»: dice che non può rispondere. Mettete un solo modello in quella cartella e la nota cede il
posto al comune `include.unknown-target`, che risponde nel merito.

Un documento mai salvato non ha insieme **affatto**, e questo è un terzo caso e non questo: le
inclusioni restano allora alla lettera nell'uscita e il pannello non ne dice nulla. Salvate il
documento e cominciano a funzionare.

Qui non c'è un esempio per costruzione: l'insieme di questo documento è dichiarato sopra e non è
vuoto.

### `note.too-deep` — inclusioni annidate troppo in profondità

Il motore si ferma al ventesimo livello di `#include` annidati e sotto non sostituisce più nulla.
Il limite è della famiglia: i motori JavaScript, PHP e Python fanno lo stesso, quindi un documento
che lo raggiunge si comporta ovunque allo stesso modo.

Qui non c'è un esempio per via della sua dimensione: mostrarne uno richiederebbe ventun file.

---

## Un silenzio in ogni lingua: le abbreviazioni

### Un'abbreviazione lascia minuscola la parola seguente

```
Dr. i nostri prezzi sono bassi  →  Dr. i nostri prezzi sono bassi
Xyz. i nostri prezzi sono bassi  →  Xyz. I nostri prezzi sono bassi
```

Due righe che differiscono di una parola, e la seconda parola di ciascuna vi dà la regola: dopo
`Dr.` la frase resta minuscola, dopo `Xyz.` va in maiuscolo. Il motore mette la maiuscola dopo un
punto, salvo dopo un'abbreviazione che conosce e dopo qualsiasi cosa nella forma di `e.g.` o
`U.S.`. È silenzioso: nessuna diagnostica, nessun avviso, e l'unico modo di accorgersene è leggere
l'uscita.

**L'elenco non è italiano, e nemmeno inglese.** Ha 46 voci, e 29 di esse sono russe:

| | |
|---|---|
| latine | `etc vs mr mrs ms dr prof sr jr inc ltd co corp no st ave blvd` |
| cirilliche | `соц эл см ср ст ул пр пер г р руб коп тыс млн млрд трлн доп напр прим изд обл респ стр табл рис мин макс тел факс` |

Entrambe le metà valgono in **tutte** le locali: la regola non chiede mai quale lingua avete
impostato. `руб.` protegge dunque la parola seguente in un documento italiano, e `Dr.` la protegge
in uno russo.

Per un testo italiano la conseguenza è semplice e scomoda: fra le abbreviazioni che scrivete ogni
giorno stanno nell'elenco solo `Dr.` e `Prof.`, perché coincidono con la metà latina. `ecc.`,
`Dott.`, `Sig.`, `pag.` e `n.` non ci sono e chiudono una frase. La guida del linguaggio aggiunge
due casi misurati che non si indovinano: `p. es.` attraversa la rifinitura senza danni, mentre
`p.es.` protegge se stesso ma lascia che la parola seguente vada in maiuscolo.

---

## Che aspetto ha la forma corretta

```spx-good
un prezzo {basso|alto}  →  Un prezzo basso
```

```spx-good
[<minsize=2;sep=", ">a|b|c]  →  C, b
```

```spx-good
#set %vip% = 1
{?vip?per lei|per tutti}  →  Per lei
```

```spx-good
#set %n% = 5
%n% {plural %n%: articolo|articoli}  →  5 articoli
```

```spx-good
prima /# una nota #/ dopo  →  Prima dopo
```

Cinque costrutti, cinque righe pulite: una scelta, un rimescolamento con impostazioni, una
condizione, una forma di numero con un numero davanti e un commento. Nessuno mette nulla nel
pannello.

---

## Domande frequenti

**Perché il paragrafo è semplicemente sparito?**
Due cause comuni, entrambe più sopra: un bersaglio `#include` sconosciuto e un'inclusione in
cerchio. Entrambe non stampano nulla. La terza, quella che si sospetta per prima — il numero
sbagliato di forme —, **non** stampa nulla: il motore stampa l'intero costrutto fra graffe larghe
`｛｝`. Il vuoto lì viene da un conteggio non numerico e non dal numero di forme.

**Perché la mia variabile con la lettera accentata nel nome non funziona?**
I nomi sono fatti di lettere latine, cifre e del trattino basso. `%città%` non è affatto una
menzione di variabile: il motore lo legge come testo e non dice nulla, perché dal suo punto di
vista non c'è nulla da segnalare:

```
ciao %città% e %nome%  →  Ciao %città% e %nome%
```

Entrambe sono passate intatte, e qui sta la trappola: solo la seconda ha tirato una riga nel
pannello. La prima è silenziosa, quindi nulla vi dice che non verrà mai sostituita. Rinominatela.
Nel **valore**, invece, le accentate non danno alcun problema.

**Perché lo stesso errore è mostrato due volte?**
Un cerchio di definizioni tira una riga per ogni menzione che lo chiude: due punti da guardare, a
volte tre. Non sono doppioni e non vengono uniti.

**Il pannello dice errore e l'uscita sembra giusta. Come sta la cosa?**
In entrambi i modi. Succede con un nome definito due volte: la resa è giusta — vince l'ultimo
valore — e il documento è ambiguo. Il verdetto riguarda il documento e non questa singola uscita.

**Ho cambiato la locale e il documento è diventato rosso.**
È la locale che fa il suo lavoro. Il documento dimostrativo è inglese e le sue forme di numero ne
portano due; mettete la locale su russo e quelle due forme diventano un errore di numero, perché il
russo ne chiede tre. L'italiano ne chiede due come l'inglese, quindi sotto `it` il documento
dimostrativo resta tranquillo. La locale appartiene al **documento**, ed è per questo che Studio
non la cambia quando cambiate la lingua dell'interfaccia.

**L'anteprima coincide con quello che produrrà il mio server?**
Con lo stesso motore, la stessa versione, la stessa locale e gli stessi valori, sì, esattamente, ed
è proprio per questo che l'anteprima fa girare il vero `spintax-win` e non un'approssimazione. Con
un **altro** motore della famiglia — quello per JavaScript, PHP o Python — si trasportano il
verdetto e l'insieme dei testi che il modello può dare, ma non quale di essi un dato seme estrae.
Riprodurre quella precisa estrazione la famiglia non lo promette.
