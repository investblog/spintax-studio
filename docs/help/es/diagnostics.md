# Qué le está diciendo la pestaña Diagnóstico

Cada línea de esa pestaña es un veredicto del **motor**, y el mismo veredicto que le darían las
implementaciones de JavaScript, PHP o Python: cuatro motores independientes sujetos a un mismo
corpus. No es la opinión de Studio sobre su plantilla. Si el motor llama error a algo aquí, todos
los demás motores de la familia también lo llaman error, y su plantilla se comportará en su
servidor como en esta ventana.

| lo que pone | quién lo dice | qué significa |
|---|---|---|
| **error** | el motor | la plantilla no hará lo que aparenta |
| **aviso** | el motor | se renderiza, pero seguramente no como usted quería |
| **nota de Studio** | Studio | el motor no dijo nada, y aun así merece decirse: una inclusión en círculo, una diana con otras mayúsculas, un carácter de control |

La columna **Dónde** es línea y columna. Un clic en la fila pone ahí el cursor.

> Cada ejemplo de abajo pasa por el motor que trae esta copia de Studio, cada vez que se compila
> el programa, y a la derecha está exactamente lo que devolvió. Nada aquí se recuerda ni se
> adivina; una respuesta que dejara de ser cierta detendría la compilación. La versión del motor
> está en **Ayuda**, **Acerca de**.

## Cómo leer los ejemplos

La flecha `→` separa la plantilla de lo que el motor devolvió. `⏎` es un salto de línea dentro de
una salida, `(vacío)` quiere decir que no imprimió nada en absoluto, y `…` marca una salida
demasiado larga para mostrarla entera. El texto tras la salida, separado por tres espacios, es una
nota y no parte de la respuesta.

Las condiciones en que corrieron los ejemplos están aquí y no escondidas en las pruebas: sin ellas
algunas respuestas no podrían reproducirse. El juego de plantillas es lo que más importa: si no,
`#include "frag"` → `Fragmento` descansaría sobre algo que este documento nunca dice.

```spx-fixture
locale: es
seed: 7
empty: (vacío)
include frag: Fragmento
include loop: #include "loop"
include Intro: Introducción
```

`seed` fija el sorteo: sin él una elección o una baraja responderían distinto cada vez y no habría
nada que comprobar.

**La locale aquí es `es`, y decide dos cosas:** cuántas formas de número espera el motor y qué
forma va con qué número. El español y el inglés piden dos. El ruso, el ucraniano, el bielorruso,
el serbio, el croata y el bosnio piden tres. La locale viene del selector encima de la mitad
derecha, no del idioma de la interfaz.

---

## Corchetes

**Ponga el cursor sobre un corchete y la construcción se muestra entera:** dónde empieza, dónde
acaba y **cada uno de sus separadores**. Los grupos anidados no se encienden con ella: tienen sus
propios separadores, y esos llegan cuando el cursor se pone sobre su corchete. Es la manera más
rápida de ver dónde acaba lo que está editando, sobre todo en una línea larga donde la `}` se ha
ido dos pantallas a la derecha.

Un separador no es solo `|`. En una baraja, `[a<br>|b]` tiene dos: el motor lee `<br>` como
separador puesto **antes del siguiente** trozo, y el resaltado lo muestra junto a los demás,
porque forma parte de cómo está hecha la construcción.

### `bracket.unclosed` — un corchete se abre y nunca se cierra

```
un precio {barato|caro  →  Un precio {barato|caro
```

El motor no adivina dónde quería usted cerrar. El texto se queda como está, llave incluida, y la
elección no ocurre nunca.

### `bracket.mismatched` — cerrado por un corchete de otra clase

```
un precio {barato|caro]  →  Un precio {barato|caro]
```

`{` espera `}` y `[` espera `]`. Una baraja cerrada por una llave no es una baraja.

### `bracket.unexpected-closing` — un corchete de cierre sin nada abierto

```
un precio barato} y todo  →  Un precio barato} y todo
```

Se queda ahí como texto. Casi siempre es un corchete que sobró de un cambio.

---

## Definiciones

### `set.malformed` — esta línea `#set` no sigue la regla

```
#set ciudad = Madrid
en %ciudad%  →  #set ciudad = Madrid ⏎ En %ciudad%
```

**El nombre va entre signos de porcentaje:** `#set %ciudad% = Madrid`. Es el primer fallo más
común, y pone dos líneas de golpe en el panel: la línea malformada misma y «esta variable no está
definida en ninguna parte», porque no hubo definición y `%ciudad%` no es de nadie.

Mire la salida: la directiva fallida se quedó en el texto **tal como se escribió**. El motor no la
leyó como directiva, así que es una línea corriente y va al resultado.

### `def.malformed` — esta línea `#def` no sigue la regla

```
#def paginas = {1|3}
%paginas%  →  #def paginas = 1 ⏎ %paginas%
```

La misma regla y el mismo precio. `#def` no se diferencia de `#set` en la escritura sino en
**cuándo** se despliega el valor: `#set` lo despliega en cada mención, `#def` una vez por render.
Un fallo al escribirlo le cuesta las dos cosas.

Y fíjese bien: el `{1|3}` de la directiva fallida **sacó una posibilidad**. La línea se volvió
texto corriente, y el texto corriente se renderiza como texto corriente, llaves incluidas. Una
línea malformada no está apagada; solo deja de ser una directiva.

### `definition.duplicate-name` — este nombre ya está definido arriba

```
#set %x% = primero
#set %x% = segundo
%x%  →  Segundo
```

Funciona —gana la **última** definición—, pero el motor lo llama error: un documento donde un
nombre se pone dos veces se lee de manera ambigua, y dentro de un mes usted no recordará cuál de
las dos líneas es la viva. El error señala la **segunda** definición; la primera está más arriba.

### `def.include-in-value` — `#include` dentro del valor de una definición

```
#def %x% = #include "frag"
%x%  →  Fragmento
```

Una inclusión dentro de un valor se despliega en otro momento del que usted esperaría, y la
familia lo prohíbe. Ponga el `#include` en una línea propia.

---

## Variables

### `variable.undefined` — esta variable no está definida en ninguna parte

```
hola, %nombre%  →  Hola, %nombre%
```

Un aviso y no un error: el motor imprime el nombre tal cual. Es deliberado, porque el valor puede
venir de fuera, del anfitrión. En Studio esos valores se aportan en la pestaña Variables, bajo
**Valores de sesión**.

**El valor de una definición se puede cambiar en el panel.** Sitúese en la columna Valor de la
parte de arriba y pulse **F2** (o simplemente empiece a escribir); **Intro** aplica, **Esc**
descarta. El cambio va **al documento**, en un solo paso de deshacer: `Ctrl+Z` lo devuelve.

El nombre y la clase (`#set` o `#def`) no se pueden cambiar, y es una decisión, no un rincón sin
terminar. Renombrar desde una celda rompe todas las menciones de la variable en el documento, y
borrar la fila se llevaría con ella el comentario y la sangría. Las dos cosas pertenecen al texto,
donde usted ve lo que hace.

Cambia exactamente el valor. La sangría, los espacios de más, las mayúsculas del nombre y un
comentario al final de la línea siguen como estaban:
`   #set  %Marca%   =   Acme   /# resto #/` vuelve de un cambio diferenciándose solo en `Acme`. El
archivo está en git, y reformatear una línea aparecería allí como cambio suyo.

**Una negativa significa que el motor leería la línea de otra manera.** El cambio no se aplica en
silencio: el motor relee el resultado, y si no dice lo pedido, el documento se queda en paz y la
barra de estado lo dice. Tres causas reales: un `/#` en el valor abre un comentario que se come el
resto del archivo, un salto de línea termina la directiva antes de tiempo, y un comentario
**dentro** de la directiva hace la línea no editable a trozos; esa cámbiela en el texto.

**Dos gestos sobre el nombre de una variable.** El nombre en el panel es un enlace y no una
etiqueta:

- **un clic en el nombre** lleva el cursor al primer sitio donde el documento usa esa variable, y
  la línea se ilumina un momento. La misma palabra dentro de un comentario o como diana de un
  `#include` **no** cuenta: el panel le lleva donde la variable de verdad trabaja.
- **Ctrl+clic** escribe una definición en el documento y abre sobre ella el editor de grupos. El
  valor que usted ya haya escrito entra como su primera posibilidad:

```
#set %marca% = {Vulkan}
casino %marca%  →  Casino Vulkan
```

La diferencia entre ambos es qué sobrevive al cerrar la ventana. Un valor de sesión no: no está en
el archivo, no está en git, y ningún otro motor de la familia lo ve. Una definición sí, y solo una
definición calla este aviso para siempre. Un `Ctrl+Z` devuelve el documento.

**Un valor de sesión es primero una plantilla y no texto.** Es lo que el motor hace con cualquier
valor del anfitrión, y el avance tiene que coincidir con el servidor, así que `{barato|caro}`
escrito en el campo de valor da una elección y no esos caracteres. Si quería el texto en sí,
marque **como texto** en la tercera columna: entonces las llaves y los signos de porcentaje siguen
siendo caracteres.

### `variable.self-reference` — la definición se nombra a sí misma

```
#set %x% = a %x% b
%x%  →  A a a … %x% … b b b
```

Cincuenta niveles y parada. El motor despliega hasta el límite de profundidad y se detiene,
dejando `%x%` en medio. No es un bucle, y tampoco es lo que usted quería.

El `…` de arriba es la abreviatura de este documento y no la del motor. La salida real tiene 207
caracteres y lleva **cincuenta y una** letras a cada lado en vez de cincuenta: el nivel cincuenta
se detiene y deja el valor tal cual, y el valor contiene una más de cada.

### `variable.circular-reference` — las definiciones se nombran en círculo

```
#set %x% = %y%
#set %y% = %x%
%x%  →  %y%
```

Cada lado se despliega exactamente **una vez** y se para: `%x%` se volvió `%y%` y no `%x%`. El
motor desenrolla el círculo en vez de recorrerlo, y lo que sobrevive es el otro nombre del
círculo: ponga `%x% %y%` en un documento y saldrá `%y% %x%`, la pareja al revés.

El panel dibuja una fila por **cada mención que cierra el círculo**, no una fila para el círculo
ni una por definición. Una definición que nombra el círculo dos veces recibe dos filas en su
propia línea: `#set %x% = %y% %y%` contra `#set %y% = %x%` son tres errores, dos de ellos en la
primera línea. Las filas no se juntan. Y la posición se pone sobre la definición que de verdad
vale: si el nombre está definido dos veces, esa es la **última**.

---

## Inclusiones

### `#include` solo funciona al principio de línea

```
antes #include "frag" después  →  Antes #include "frag" después
```

```
#include "frag"  →  Fragmento
```

Ningún diagnóstico, y en eso consiste: un `#include` en mitad de una línea **no** es una
inclusión. El motor lo lee como texto corriente y no dice nada, porque no hay nada de qué
quejarse: usted escribió texto y obtuvo texto.

**La diana sí puede estar una línea más abajo**, y eso sorprende por el otro lado. El hueco que el
motor permite entre la palabra y su diana incluye los saltos de línea, así que esto es una
inclusión y funciona:

```spx-good
#include
"frag"  →  Fragmento
```

Las líneas en blanco en medio también valen. Lo demás no vale: una palabra antes de la diana o
cualquier cosa que no sean espacios detrás, y el conjunto vuelve a ser texto. El editor colorea la
diana en su propia línea pero deja la palabra corriente hasta que la diana llega: no promete una
directiva cuyo final aún no ve.

### `include.unknown-target` — no hay diana con ese nombre en el juego

```
#include "ninguno"  →  (vacío)
```

Las dianas son los archivos `.spintax` de la carpeta del documento abierto. Una diana desconocida
se despliega a nada: el párrafo desaparece en vez de romperse, que es justamente por lo que es tan
fácil pasarlo por alto.

**Por eso la pestaña Variables tiene una tercera sección, «Inclusiones».** Enumera cada `#include`
del documento y, para cada uno, si el juego tiene su diana: una fila por aparición, así que una
diana nombrada dos veces son dos filas. La sección aparece solo si el documento tiene inclusiones.
Un clic en una fila lleva el cursor al `#include` que nombra esa diana.

La marca tiene **tres** valores, y el tercero importa: «sin juego» no quiere decir «falta el
fragmento», sino «todavía no hay dónde mirar». El juego es la carpeta junto al documento, y un
documento sin guardar no tiene carpeta: hasta el primer guardado, por tanto, cada diana se marca
así. «FALTA» aparece solo cuando hay carpeta y el archivo de verdad no está en ella.

### `note.case-mismatch` — la diana existe, con otras mayúsculas

```
#include "intro"  →  (vacío)
```

El juego contiene `Intro.spintax`, y aun así el motor dice que no hay diana con ese nombre,
mientras Studio añade su nota sobre las mayúsculas. Importan: `intro` e `Intro` son dianas
distintas. Windows abriría el archivo de las dos maneras, y por eso Studio mira en el juego y no
en el sistema de archivos: si no, el avance contradiría al servidor sobre el mismo documento.

### `note.cycle` — una inclusión en círculo

Si `loop.spintax` contiene a su vez `#include "loop"`, entonces:

```
#include "loop"  →  (vacío)
```

El motor sustituye nada en lugar del infinito. La nota está para que usted sepa por qué el párrafo
se esfumó.

La fila va contra **`loop`** y no contra el documento que usted mira: el círculo es del fragmento,
y allí va el cursor al hacer clic. En el documento abierto no hay nada subrayado, porque la línea
que usted escribió no tiene nada de malo.

---

## Formas de número

### `plural.arity` — no hay tantas formas como pide la locale

```
#set %n% = 5
%n% {plural %n%: objeto|objetos|objetoses}  →  5 ｛plural 5: objeto|objetos|objetoses｝
```

**No es vacío: el motor imprime la construcción entera**, con las llaves cambiadas por unas anchas
`｛｝`. Así dice «he visto esto y no he podido aplicarlo». Nadie lo llamaría discreto, y mejor así:
un párrafo esfumado en silencio costaría más de encontrar.

El español pide dos formas, el ruso tres. Bajo la locale de este documento la correcta es
`{plural %n%: objeto|objetos}`.

**El vacío viene por otra causa, y las dos se confunden con facilidad.** Compare estas dos, que
solo se diferencian en cuántas formas llevan:

```
{plural %n%: objeto|objetos}  →  (vacío)   dos formas: correcto para el español
{plural %n%: objeto|objetos|objetoses}  →  (vacío)   tres formas: incorrecto para el español
```

Las dos imprimen nada, y el panel las trata distinto: la primera solo saca `variable.undefined`,
la segunda saca además `plural.arity`. Así que **el vacío no es la señal de un error de cantidad
de formas**: aquí viene de que `%n%` no está definida, y el motor comprueba la cuenta antes de
contar las formas, de modo que se para antes de que la pregunta por la cantidad llegue a
plantearse.

Por eso el ejemplo del principio de este artículo define `%n%` primero. Sin eso la salida estaría
vacía con cualquier número de formas y no mostraría nada sobre la cantidad.

El panel y la salida responden aquí a preguntas distintas, y no es contradicción: la fila la pone
la **comprobación**, que cuenta las formas del texto y de la cuenta no se ocupa; el vacío lo da el
**render**, que tiene su propio orden. Dele una cifra a la cuenta, como hace el primer ejemplo, y
verá lo que la cantidad de formas hace de verdad.

### `plural.count-macro` — la cuenta viene de un `#set`, y eso vuelve a tirar en cada mención

```
#set %n% = {1|2}
%n% {plural %n%: objeto|objetos}  →  1
```

Mire lo que sobrevivió: **el número se imprimió y el sustantivo no.** La cuenta ha de ser un
número cuando se elige la forma, y un `#set` cuyo valor es a su vez una elección nunca llega a
serlo: el motor sustituye el valor **sin renderizarlo**, así que al hueco de la cuenta llega el
texto literal `{1|2}`. La cuenta y la forma no pueden contradecirse; el motor deja caer la palabra
en su lugar.

`#def` se comporta de otro modo y despliega su valor una vez por render, así que el hueco de la
cuenta recibe un número:

```
#def %n% = {1|2}
%n% {plural %n%: objeto|objetos}  →  1 objeto
```

Para ese no hay fila ninguna en el panel. De ahí la regla: haga que la cuenta sea una cifra simple
o un `#def`, nunca un `#set`.

### `plural.nested-brackets` — corchetes dentro de las formas

```
{plural %n%: {objeto|cosa}|objetos}  →  ｛plural %n%: ｛objeto|cosa｝|objetos｝
```

Las formas son texto simple. Una elección dentro de ellas no se despliega, y lo que se imprime en
su lugar es la construcción entera entre llaves anchas.

---

## Barajas

### `permutation.unknown-key` — clave desconocida en el ajuste

```
[<foo=1>a|b|c]  →  Bfoo=1cfoo=1a
```

Las claves conocidas son `minsize`, `maxsize`, `sep` y `lastsep`. Una desconocida no es un ajuste,
y cuando es lo único que hay en el bloque, el bloque entero no es un ajuste en absoluto: se
convierte en el separador entre los trozos, que es lo que muestra la salida.

**Si hay una clave de verdad al lado, el desenlace es completamente otro**, y ese es el fallo más
probable: una clave de varias mal escrita:

```
[<sep=", ";foo=1>a|b|c]  →  B, c, a
```

El bloque es un ajuste, `sep` se obedece, la clave desconocida simplemente se deja caer, y el
panel dice lo mismo en ambos casos. El diagnóstico le dice, pues, que una clave no se entendió; no
le dice qué pasó después. Para eso lea la salida.

### `permutation.minsize-not-integer` — minsize no es un número entero

```
[<minsize=dos>a|b|c]  →  B c a
```

Un valor no numérico cae junto con su límite, y vale el valor por defecto, que son todos los
trozos.

### `permutation.maxsize-not-integer` — maxsize no es un número entero

```
[<maxsize=muchos>a|b|c]  →  B c a
```

Exactamente lo mismo por el otro extremo: el límite alto desaparece, y la salida vuelve a contener
cada trozo.

---

## Notas de Studio sin nada que mostrar

Las tres notas de abajo no pueden mostrarse con un ejemplo en este documento, y la razón es
distinta en cada caso y se dice. Aun así tienen artículo: la ayuda le debe una respuesta a **cada**
línea que el panel puede mostrar, o una fila del panel no lleva a ninguna parte.

### `note.raw-sentinel` — un carácter de control en el texto

Los caracteres U+E000–U+E005 son los que el motor usa para su propio marcado, y los **quita**
antes de analizar. Si han llegado a su plantilla —normalmente pegados desde otro editor—, Studio
lo dice: ni el avance ni el servidor los mostrarán.

Aquí no hay ejemplo a propósito: esos caracteres son invisibles, y una línea que los llevara
parecería vacía. No habría nada que ver.

### `note.unknown-target` — el juego está vacío, no hay con qué juzgar

Aparece cuando el juego junto al documento está **vacío**: ni una sola plantilla aparte de esta. No
hay nada contra lo que comprobar la diana, así que Studio no dice «no hay diana con ese nombre»:
dice que no puede responder. Ponga una sola plantilla en esa carpeta y la nota deja paso al
corriente `include.unknown-target`, que responde al fondo del asunto.

Un documento nunca guardado no tiene juego **en absoluto**, y ese es un tercer caso y no este: las
inclusiones se quedan entonces literalmente en la salida y el panel no dice nada de ellas. Guarde
el documento y empiezan a funcionar.

Aquí no hay ejemplo por construcción: el juego de este documento se declara arriba y no está
vacío.

### `note.too-deep` — inclusiones anidadas demasiado hondo

El motor se detiene en el vigésimo nivel de `#include` anidados y no sustituye nada por debajo. El
límite es de la familia: los motores de JavaScript, PHP y Python hacen lo mismo, así que un
documento que llegue a él se comporta igual en todas partes.

Aquí no hay ejemplo por su tamaño: mostrar uno pediría veintiún archivos.

---

## Un silencio en todos los idiomas: las abreviaturas

### Una abreviatura deja en minúscula la palabra siguiente

```
Sr. nuestros precios son bajos  →  Sr. nuestros precios son bajos
Xyz. nuestros precios son bajos  →  Xyz. Nuestros precios son bajos
```

Dos líneas que se diferencian en una palabra, y la segunda palabra de cada una le da la regla:
tras `Sr.` la oración sigue en minúscula, tras `Xyz.` se pone en mayúscula. El motor pone
mayúscula tras un punto, salvo tras una abreviatura que conoce y tras cualquier cosa con la forma
de `e.g.` o `U.S.`. Es silencioso: ningún diagnóstico, ningún aviso, y la única manera de notarlo
es leer la salida.

**La lista no es española, y tampoco inglesa.** Tiene 46 entradas, y 29 de ellas son rusas:

| | |
|---|---|
| latinas | `etc vs mr mrs ms dr prof sr jr inc ltd co corp no st ave blvd` |
| cirílicas | `соц эл см ср ст ул пр пер г р руб коп тыс млн млрд трлн доп напр прим изд обл респ стр табл рис мин макс тел факс` |

Las dos mitades valen en **todas** las locales: la regla nunca pregunta qué idioma tiene usted
puesto. `руб.` protege por tanto la palabra siguiente en un documento español, y `Sr.` la protege
en uno ruso.

Para un texto en español la consecuencia es simple y molesta: de las abreviaturas que usted
escribe a diario solo `Sr.`, `Dr.`, `Prof.` y `etc.` están en la lista, porque coinciden con la
mitad latina. `Sra.`, `núm.` y `pág.` no están y terminan una oración. La guía del lenguaje añade
dos casos medidos que no se adivinan: `p. ej.` atraviesa el retoque sin daño, y `p.ej.` se protege
a sí mismo pero deja que la palabra siguiente se ponga en mayúscula.

---

## Qué aspecto tiene la forma correcta

```spx-good
un precio {barato|caro}  →  Un precio barato
```

```spx-good
[<minsize=2;sep=", ">a|b|c]  →  C, b
```

```spx-good
#set %vip% = 1
{?vip?para usted|para todos}  →  Para usted
```

```spx-good
#set %n% = 5
%n% {plural %n%: artículo|artículos}  →  5 artículos
```

```spx-good
antes /# una nota #/ después  →  Antes después
```

Cinco construcciones, cinco líneas limpias: una elección, una baraja con ajustes, una condición,
una forma de número con un número delante y un comentario. Ninguna pone nada en el panel.

---

## Preguntas frecuentes

**¿Por qué el párrafo ha desaparecido sin más?**
Dos causas comunes, las dos más arriba: una diana `#include` desconocida y una inclusión en
círculo. Las dos imprimen nada. La tercera, que es la primera que se sospecha —el número
equivocado de formas—, **no** imprime nada: el motor imprime la construcción entera entre llaves
anchas `｛｝`. El vacío viene allí de una cuenta no numérica y no del número de formas.

**¿Por qué no funciona mi variable con tilde en el nombre?**
Los nombres se componen de letras latinas, cifras y el guion bajo. `%año%` no es en absoluto una
mención de variable: el motor lo lee como texto y no dice nada, porque desde su punto de vista no
hay nada que informar:

```
hola %año% y %nombre%  →  Hola %año% y %nombre%
```

Las dos pasaron intactas, y ahí está la trampa: solo la segunda sacó una fila en el panel. La
primera es silenciosa, así que nada le avisa de que nunca se sustituirá. Cámbiele el nombre. En el
**valor**, en cambio, las tildes y la `ñ` no dan ningún problema.

**¿Por qué se muestra dos veces el mismo error?**
Un círculo de definiciones saca una fila por cada mención que lo cierra: dos sitios que mirar, a
veces tres. No son duplicados y no se juntan.

**El panel dice error y la salida parece correcta. ¿En qué quedamos?**
En las dos cosas. Eso pasa con un nombre definido dos veces: el render es correcto —gana el último
valor— y el documento es ambiguo. El veredicto es sobre el documento, no sobre esta salida
concreta.

**He cambiado la locale y el documento se ha puesto rojo.**
Es la locale haciendo su trabajo. El documento de demostración es inglés y sus formas de número
llevan dos; ponga la locale en ruso y esas dos formas pasan a ser un error de cantidad, porque el
ruso pide tres. El español pide dos como el inglés, así que bajo `es` el documento de
demostración se queda tranquilo. La locale pertenece al **documento**, y por eso Studio no la
cambia cuando usted cambia el idioma de la interfaz.

**¿Coincide el avance con lo que producirá mi servidor?**
Con el mismo motor, la misma versión, la misma locale y los mismos valores, sí, exactamente, y
para eso precisamente el avance hace correr el `spintax-win` de verdad y no una aproximación. Con
**otro** motor de la familia —el de JavaScript, PHP o Python— se transportan el veredicto y el
conjunto de textos que la plantilla puede dar, pero no cuál de ellos saca una semilla concreta.
Reproducir ese sorteo exacto la familia no lo promete.
