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
confrontate due modifiche, per esempio — spuntate **Seme**, e l'anteprima resta ferma finché non
lo togliete o cambiate il numero.

La metà destra mostra o la **pagina** o il **sorgente**. I modelli sono per lo più HTML, e le due
domande «che aspetto ha» e «quale marcatura è uscita» non si rispondono a vicenda: un tag rotto dà
un impaginato un po' storto che l'occhio salta, mentre la prosa piena di tag non si legge come
prosa. L'interruttore sopra la metà cambia ciò che state guardando.

Selezionate una parte del modello e solo quella viene resa — nell'ambito dell'intero documento,
così che un frammento che usa una variabile definita in alto esca come uscirà al suo posto.

## I pannelli in basso

La barra degli strumenti di lato apre tre pannelli, uno per volta.

**Diagnostica** elenca ciò che il motore ha trovato sbagliato, ogni volta con la riga e la colonna
d'inizio. Un clic su una riga vi porta il cursore. È lo stesso verdetto che il motore dà ovunque
altrove, non un secondo parere dell'editor: per questo un modello che questo pannello chiama
valido viene accettato dagli altri motori.

**Variabili** mostra i nomi che il vostro documento definisce e quelli che soltanto usa. Un nome
che usa e che nulla definisce potete riempirlo qui per la sessione: scrivete un valore accanto e
l'anteprima lo raccoglie. Spuntate **Letterale** quando il valore è testo che significa se stesso
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
