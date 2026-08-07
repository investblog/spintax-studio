# Il linguaggio, costrutto per costrutto

Un modello è testo comune con qualche punto segnato dentro. Tutto ciò che non è segnato esce così
com'è; sono i segni a permettere a un modello di produrre molti testi.

Sono sei, e questo è tutto il linguaggio: una **scelta** fra alternative, un **rimescolamento** di
più pezzi, una **macro** che definite una volta e usate per nome, una **condizione**, un
**conteggio** che prende la forma di parola giusta e un'**inclusione** che porta dentro un altro
modello. I commenti sono un settimo segno che non produce nulla del tutto.

> Ogni esempio qui sotto passa per il motore che questa copia di Studio porta con sé, a ogni
> compilazione del programma, e a destra sta esattamente ciò che ha restituito. Nulla qui è
> ricordato o indovinato; una risposta che smettesse di essere vera fermerebbe la compilazione.
> La versione del motore è sotto **Aiuto**, **Informazioni**.

L'altro documento di questa guida, **Cosa vi sta dicendo la scheda Diagnostica**, parla di ciò che
va storto. Questo parla di ciò che i costrutti fanno quando nulla va storto — compresi i diversi
punti in cui un modello fa qualcosa di sorprendente e nessuno lo segnala.

## Come leggere gli esempi

La freccia `→` separa il modello da ciò che il motore ha restituito. `(vuoto)` vuol dire che non ha
stampato nulla del tutto. Il testo dopo l'uscita, staccato da tre spazi, è una nota e non parte
della risposta.

Le condizioni sono dichiarate e non sottintese, perché senza di esse metà delle risposte qui sotto
non si potrebbe riprodurre:

```spx-fixture
locale: it
seed: 7
empty: (vuoto)
include intro: Benvenuto da {Acme|Globex}.
include shout: Il %marchio% è qui.
```

`seed` fissa l'estrazione. Un modello con una scelta dentro non ha una risposta sola, quindi un
esempio senza seme stamperebbe qualcosa di diverso a ogni passaggio e non ci sarebbe niente da
verificare. Nella finestra è la casella **Seme** sopra la metà destra; spuntatela e accanto compare
un campo numerico, e l'anteprima resta ferma mentre lavorate.

`locale` decide le forme di numero, ed è il selettore sopra la metà destra, non la lingua
dell'interfaccia. L'italiano e l'inglese chiedono due forme; il russo, l'ucraino, il bielorusso, il
serbo, il croato e il bosniaco ne chiedono tre.

## Scelte

Parentesi graffe con `|` in mezzo: il motore ne prende **una**.

```spx-good
Una {piccola|grande} stanza.  →  Una piccola stanza.
```

L'estrazione è casuale, quindi lo stesso modello dà `Una grande stanza.` a un altro passaggio. La
scelta in sé lascia stare il testo intorno — anche se la rifinitura descritta verso la fine di
questo documento ci arriva comunque.

### Annidamento

Una scelta può contenerne un'altra, a qualsiasi profondità.

```spx-good
Acme {Pro {Plus|Max}|Lite}  →  Acme Pro Plus
```

La scelta interna si fa solo se quella esterna prende il ramo in cui sta: se esce `Lite`,
`Plus|Max` non viene mai consultato — e, cosa misurabile, non gli si chiede nemmeno un numero a
caso.

### Una possibilità vuota

Una possibilità può essere vuota. È il modo comune di far comparire qualcosa solo ogni tanto.

```spx-good
Una stanza {|molto }grande.  →  Una stanza grande.
```

Scrivere lo spazio dentro la possibilità, `{|molto }` invece di `{|molto} `, è abitudine e non
obbligo: la rifinitura riduce comunque il doppio spazio.

## Rimescolamenti

Le parentesi quadre prendono più pezzi, scelgono quanti, li mettono in ordine casuale e li
uniscono.

```spx-good
[rosso|verde|blu]  →  Verde blu rosso
```

Lasciato a sé li prende tutti e li unisce con uno spazio. Tutto il resto su un rimescolamento si
imposta in un blocco `<…>` subito dopo la parentesi di apertura.

### Il separatore

```spx-good
[<, >rosso|verde|blu]  →  Verde, blu, rosso
```

Un blocco `<…>` è il separatore stesso, a meno che non **nomini un'impostazione**: una fra `sep`,
`lastsep`, `minsize` o `maxsize`, come parola a sé e con un `=` dietro. Tutto il resto in quel
posto è un separatore, per quanto somigli a un'impostazione — una chiave senza il suo `=`:

```spx-good
[<maxsize 2>rosso|verde|blu]  →  Verdemaxsize 2blumaxsize 2rosso
```

oppure una chiave con qualcosa attaccato davanti:

```
[<xmaxsize=1>rosso|verde|blu]  →  Verdexmaxsize=1bluxmaxsize=1rosso
```

Il secondo merita un secondo sguardo: il pannello chiama `xmaxsize` chiave sconosciuta **eccome**,
e il motore stampa comunque l'intero blocco fra i pezzi. La diagnostica e l'uscita rispondono a
domande diverse.

Scrivete per esteso le impostazioni quando volete due separatori diversi:

```spx-good
[<sep=", ";lastsep=" e ">rosso|verde|blu]  →  Verde, blu e rosso
```

`sep` va fra i pezzi e `lastsep` prima dell'ultimo.

### Quanti

```spx-good
[<minsize=2;maxsize=2>rosso|verde|blu]  →  Verde blu
```

`minsize` è il pavimento e `maxsize` il soffitto; il numero fra i due è casuale come l'ordine.
Valori uguali ne prendono esattamente quelli. **Senza nessuno dei due, tutti; ma con il solo
`maxsize` il pavimento resta a uno**, cosa che sorprende:

```spx-good
[<maxsize=3>a|b|c]  →  C
```

Tre pezzi, un soffitto di tre, ed è uscito uno. Scrivete anche `minsize` quando intendete «tutti,
al massimo tre». Un `maxsize` superiore al numero dei pezzi viene abbassato in silenzio a quel
numero. Un `minsize` superiore al `maxsize` è accettato senza una parola, e vince il pavimento: il
soffitto viene alzato fino a lui e non il contrario:

```spx-good
[<minsize=3;maxsize=1>rosso|verde|blu]  →  Verde blu rosso
```

### Un separatore fra due pezzi

Un `<…>` scritto **fra** due pezzi è il separatore di quella coppia.

```spx-good
[rosso|verde<e>|blu]  →  Verde e blu rosso
```

Appartiene al pezzo **successivo** e viaggia con lui nel rimescolamento, quindi spunta dove quel
pezzo cade e non in un posto fisso dell'uscita. Un `<…>` dopo l'**ultimo** pezzo non è affatto un
separatore e si stampa come testo:

```spx-good
[rosso|verde|blu<e>]  →  Verde blu<e> rosso
```

## Macro

`#set` dà un nome a un pezzo di testo. Il nome si usa come `%nome%`, e la direttiva deve essere la
prima cosa della sua riga: spazi e tabulazioni davanti sono ammessi, nient'altro.

```spx-good
#set %citta% = Milano
Volo per %citta%.  →  Volo per Milano.
```

I nomi sono fatti di lettere latine, cifre e `_`. Un nome in un altro alfabeto non è un nome, di
cui parla l'altro documento sotto `set.malformed`. Le lettere accentate quindi non stanno in un
nome; in un valore sì.

### `#set` rilancia, `#def` estrae una volta

È tutta la differenza fra i due, e si vede solo quando il valore contiene una scelta.

```spx-good
#set %scelta% = {A|B}
%scelta% %scelta% %scelta%  →  A A B
```

```spx-good
#def %scelta% = {A|B}
%scelta% %scelta% %scelta%  →  A A A
```

I due esempi sono girati sotto lo stesso seme. `#set` conserva il modello e lo rilancia a ogni
uso; `#def` estrae una volta e tiene la risposta. Usate `#def` per qualcosa che deve accordarsi
con se stesso — un marchio, una città, un nome, un conteggio — e `#set` per la varietà.

Un solo seme non permette di distinguerli: ci sono semi in cui `#set` pesca per caso tre volte la
stessa possibilità e i due si assomigliano. Vale la pena saperlo prima di concludere, da una sola
anteprima, che una definizione non funziona.

## Condizioni

`{?nome?allora|altrimenti}` chiede se una macro ha un valore.

```spx-good
#set %n% = 5
{?n?abbiamo %n%|ancora niente}  →  Abbiamo 5
```

La metà `altrimenti` può mancare: `{?nome?allora}` non stampa nulla quando la risposta è no. Un
`!` rovescia la domanda:

```spx-good
#set %vip% = 1
{?!vip?estraneo|amico}  →  Amico
```

Avere un valore significa avere **almeno un carattere che non sia uno spazio**. Una macro messa a
nulla, o a soli spazi, conta come priva di valore.

Il nome di una condizione deve **cominciare** con una lettera o `_`, cosa più severa che per una
macro; e il capitolo dei silenzi dice in cosa si trasforma un nome che comincia con una cifra.

## Conteggio

`{plural %n%: …}` prende la forma di parola che va con un numero.

```spx-good
#def %n% = 1
%n% {plural %n%: documento|documenti}  →  1 documento
```

```spx-good
#def %n% = 5
%n% {plural %n%: documento|documenti}  →  5 documenti
```

Il conteggio qui è un `#def` e non un `#set`, di proposito, e la regola vale la pena tenerla:
**fate del conteggio una cifra semplice o un `#def`, mai un `#set`.** Quel che arriva al posto del
conteggio da un `#set` è il TESTO conservato, `{5|5}` e non `5` — non un numero, quindi — cosicché
l'intero costrutto non produce nulla e il pannello dice `plural.count-macro`. Il conteggio e la
forma non possono contraddirsi: a sparire è la parola.

```
#set %n% = {5|5}
%n% {plural %n%: documento|documenti}  →  5
```

Quante forme ci sono lo decide la locale e non voi: sotto `it` sono due, sotto `ru` tre. Il numero
sbagliato è un errore che il pannello segnala (`plural.arity`), e il motore ristampa allora
l'intero costrutto con le graffe sostituite da quelle larghe `｛｝`, perché non si scambi per
uscita.

## Frammenti

`#include "nome"` mette un altro modello in quel punto, e la direttiva deve essere la prima cosa
della sua riga; anche qui spazi e tabulazioni davanti sono ammessi.

```spx-good
#include "intro"  →  Benvenuto da Acme.
```

Il frammento è reso come modello a sé, quindi una scelta al suo interno viene rifatta: `intro`
contiene `{Acme|Globex}` e risponde con l'uno o l'altro.

Il nome è confrontato **esattamente**. `Intro` e `intro` sono due frammenti diversi, e su Windows
è facile sbagliare perché al file system non importa. Un bersaglio mancante si rende come nulla e
il pannello dice `include.unknown-target`; un bersaglio che differisce solo per le maiuscole
riceve una nota di Studio con il nome che probabilmente intendevate.

### Un frammento non vede le vostre macro

È reso come modello a sé: ha i valori della sessione, ma non i `#set` né i `#def` del documento che
l'ha portato dentro.

```
#set %marchio% = Acme
#include "shout"  →  Il %marchio% è qui.
```

`shout` vale `Il %marchio% è qui.`, e il nome va definito nel frammento stesso. Questo non è un
silenzio — il pannello dice eccome `variable.undefined` — ma lo dice contro **`shout`**, alla riga
1 di quel file, e nel documento che state guardando non compare alcuna sottolineatura, perché la
posizione appartiene a un altro buffer. Leggete la colonna **File** quando un avviso sembra
riguardare una riga che non avete scritto.

## Commenti

`/# … #/` è un commento: tutto ciò che sta fra i segni viene tolto prima di qualsiasi altra cosa.

```spx-good
bozza /# non sono sicuro #/ pronto  →  Bozza pronto
```

I commenti non si annidano. Il primo `#/` chiude il commento, qualunque cosa ci fosse prima, così
un commento avvolto attorno a un testo che contiene a sua volta `#/` finisce prima di quanto
sembri.

## Cosa il motore liscia alla fine

L'uscita non è del tutto il testo che i costrutti hanno prodotto. Alla fine le succedono diverse
cose; due le incontrate ogni giorno.

La prima lettera di ogni frase viene messa in maiuscolo:

```spx-good
uno. due. tre.  →  Uno. Due. Tre.
```

Per questo gli esempi di questa guida rispondono così spesso con una maiuscola dove il modello ha
una minuscola. Un punto dopo un'abbreviazione che il motore conosce non chiude una frase, e non la
chiude nemmeno qualcosa nella forma di `e.g.` o `U.S.` — **in lettere latine**, che è un limite
vero e non una cautela: il controllo «siamo in mezzo a una parola» è un controllo ASCII.

```spx-good
Dr. i nostri prezzi sono bassi  →  Dr. i nostri prezzi sono bassi
```

```spx-good
Prof. i nostri prezzi sono bassi  →  Prof. i nostri prezzi sono bassi
```

Ogni altra parola chiude una frase, per corta che sia: la lunghezza non c'entra nulla:

```spx-good
Xyz. i nostri prezzi sono bassi  →  Xyz. I nostri prezzi sono bassi
```

L'elenco che il motore conosce ha 46 voci, **29 delle quali cirilliche**, e l'altro documento lo
percorre sotto **Un silenzio in ogni lingua**. Per l'italiano l'essenziale sta più in basso, nei
silenzi: l'elenco non è pensato per l'italiano.

La seconda cosa quotidiana è che le sequenze di spazi si riducono a uno. È ciò che vi lascia una
possibilità vuota senza contare gli spazi intorno.

Il resto in un fiato: uno spazio davanti a `,;:!?.` viene tolto e uno viene inserito dietro;
l'intera uscita viene rifilata ai bordi; la maiuscola arriva anche dopo un a capo e dopo un tag di
blocco, non solo dopo un punto; e gli indirizzi con schema, gli indirizzi di posta, i domini nudi
e i numeri decimali sono protetti ed escono esattamente come sono stati scritti.

Quest'ultimo punto porta lo stesso limite ASCII delle abbreviazioni sopra. Un dominio nudo è
protetto se è scritto in lettere latine; `сайт.рф` non lo è, e la rifinitura ci infila dentro uno
spazio e una maiuscola.

```spx-good
ciao , mondo  →  Ciao, mondo
```

```spx-good
uno.due  →  uno.due
```

## Silenzi

Ogni caso qui sotto si rende, produce qualcosa di diverso da come appare e non tira **alcuna
diagnostica**. Sono raccolti qui perché nient'altro nella finestra li menzionerà mai.

**Le abbreviazioni italiane non sono nell'elenco del motore.** È il silenzio in cui chi scrive in
italiano inciampa per primo. Sono protette solo le parole che coincidono con la metà latina
dell'elenco — `Dr.` e `Prof.` qui sopra —, mentre `ecc.`, `Dott.`, `Sig.`, `pag.` e `n.` chiudono
una frase e mettono in maiuscolo la parola seguente:

```spx-good
ecc. i nostri prezzi sono bassi  →  Ecc. I nostri prezzi sono bassi
```

`p. es.`, con il suo spazio, attraversa la rifinitura senza danni, il che vale più mostrarlo che
spiegarlo:

```spx-good
p. es. questo resta minuscolo  →  p. es. questo resta minuscolo
```

Scritto unito, `p.es.`, si protegge da sé per la regola dei più punti, ma la parola che segue non
più:

```spx-good
p.es. questo resta minuscolo  →  p.es. Questo resta minuscolo
```

**Un `#include` che non è solo sulla sua riga è testo comune.**

```spx-good
Prima. #include "intro"  →  Prima. #include "intro"
```

Lo stesso vale per una direttiva con qualcosa dietro e per `#include"intro"` senza spazio. La
regola è della famiglia e non di questo motore, ed è ciò che rende una direttiva riconoscibile
senza analizzare l'intera riga.

**Una condizione il cui nome comincia con una cifra non è una condizione.** Diventa una scelta
comune fra `?1x?sì` e `no`:

```spx-good
{?1x?sì|no}  →  ?1x? Sì
```

**Un `<…>` in testa a un pezzo che non è il primo non è un separatore** e si stampa così com'è:

```spx-good
[rosso|<e>verde]  →  <e>Verde rosso
```

Il blocco in testa al **primo** pezzo sì che è il separatore: è la scrittura con cui si apre il
capitolo dei rimescolamenti:

```spx-good
[<e>rosso|verde]  →  Verde e rosso
```

Ovunque dopo un `|` è testo comune, e un separatore fra due pezzi va alla **fine** del primo.

**Un tag nudo alla fine di un pezzo viene preso per il separatore di quella coppia** e stampato
come testo suo:

```spx-good
[uno<br>|due]  →  Due uno
```

Sotto questo seme i due sono caduti nell'altro ordine, quindi il separatore non è uscito affatto.
Con un terzo pezzo c'è dove cadere, e compare:

```spx-good
[rosso|verde<br>|blu]  →  Verde br blu rosso
```

Il `<br>` sta fra `verde` e ciò che lo segue, ovunque il rimescolamento metta quella coppia. Un tag
di chiusura (`</b>`), uno autochiudente (`<br/>`), uno con attributi (`<br class="x">`) e un tag in
mezzo a un pezzo restano tutti intatti.

**Un commento non chiuso è testo comune**: non apre nulla, e il `/#` viene stampato:

```spx-good
prima /# il resto di questo  →  Prima /# il resto di questo
```

Ma resta pur sempre metà di una coppia. Se più in basso nel documento compare un `#/`, i due si
trovano e tutto ciò che sta in mezzo se ne va, compreso quel che l'autore ci ha scritto:

```
{a /# ops|b} mezzo #/ coda  →  {a coda
```

La scelta qui sopra ha perso la seconda alternativa e la graffa di chiusura, e nessuna diagnostica
lo dice: è ciò che il testo SIGNIFICA, e non un errore che il motore possa vedere. Quando un `/#`
è voluto alla lettera, il posto sicuro è il valore di una variabile e non il corpo del modello.

## Dove guardare poi

L'altro documento, **Cosa vi sta dicendo la scheda Diagnostica**, ha un articolo per ogni riga che
il pannello può mostrare: cosa significa, cosa la provoca e cosa il motore fa del modello finché è
lì. Premete F1 con il cursore dentro un costrutto e la guida si apre al capitolo di quel costrutto
**in quel documento**: una graffa su **Parentesi**, un `[…]` su **Rimescolamenti**, una riga `#set`
su **Definizioni**.
