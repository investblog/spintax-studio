# El lenguaje, construcción por construcción

Una plantilla es texto corriente con unos pocos lugares marcados dentro. Todo lo que no está
marcado sale tal cual; las marcas son lo que permite a una plantilla producir muchos textos.

Son seis, y ese es todo el lenguaje: una **elección** entre alternativas, una **baraja** de varios
trozos, una **macro** que usted define una vez y usa por su nombre, una **condición**, una
**cuenta** que toma la forma de palabra adecuada, y una **inclusión** que trae otra plantilla. Los
comentarios son una séptima marca que no produce nada en absoluto.

> Cada ejemplo de abajo pasa por el motor que trae esta copia de Studio, cada vez que se compila
> el programa, y a la derecha está exactamente lo que devolvió. Nada aquí se recuerda ni se
> adivina; una respuesta que dejara de ser cierta detendría la compilación. La versión del motor
> está en **Ayuda**, **Acerca de**.

El otro documento de esta ayuda, **Qué le está diciendo la pestaña Diagnóstico**, trata de lo que
va mal. Este trata de lo que hacen las construcciones cuando nada va mal, incluidos los varios
sitios donde una plantilla hace algo sorprendente y nada lo avisa.

## Cómo leer los ejemplos

La flecha `→` separa la plantilla de lo que el motor devolvió. `(vacío)` quiere decir que no
imprimió nada en absoluto. El texto tras la salida, separado por tres espacios, es una nota y no
parte de la respuesta.

Las condiciones se declaran en vez de suponerse, porque sin ellas la mitad de las respuestas de
abajo no podría reproducirse:

```spx-fixture
locale: es
seed: 7
empty: (vacío)
include intro: Bienvenido a {Acme|Globex}.
include shout: La %marca% está aquí.
```

`seed` fija el sorteo. Una plantilla con una elección dentro no tiene una única respuesta, así que
un ejemplo sin semilla imprimiría algo distinto en cada pasada y no habría nada que comprobar. En
la ventana es la casilla **Semilla** encima de la mitad derecha; márquela y al lado aparece un
campo numérico, y el avance se queda quieto mientras usted trabaja.

`locale` decide las formas de número, y es el selector encima de la mitad derecha, no el idioma de
la interfaz. El español y el inglés piden dos formas; el ruso, el ucraniano, el bielorruso, el
serbio, el croata y el bosnio piden tres.

## Elecciones

Llaves con `|` en medio: el motor toma **una**.

```spx-good
Una sala {pequeña|grande}.  →  Una sala pequeña.
```

El sorteo es aleatorio, así que la misma plantilla da `Una sala grande.` en otra pasada. La
elección en sí deja en paz el texto de alrededor, aunque el retoque descrito hacia el final de
este documento sí llega hasta él.

### Anidamiento

Una elección puede contener otra, a cualquier profundidad.

```spx-good
Acme {Pro {Plus|Max}|Lite}  →  Acme Pro Plus
```

La elección interior solo se hace si la exterior toma la rama en que está: si sale `Lite`, a
`Plus|Max` no se le consulta nunca, y —esto es medible— ni siquiera se le pide un número al azar.

### Una posibilidad vacía

Una posibilidad puede estar vacía. Es la manera corriente de hacer que algo aparezca solo a veces.

```spx-good
Una sala {|muy }grande.  →  Una sala grande.
```

Escribir el espacio dentro de la posibilidad, `{|muy }` en vez de `{|muy} `, es costumbre y no
obligación: el retoque junta el espacio doble de todos modos.

## Barajas

Los corchetes toman varios trozos, eligen cuántos, los ponen en orden aleatorio y los unen.

```spx-good
[rojo|verde|azul]  →  Verde azul rojo
```

A su aire los toma todos y los une con un espacio. Todo lo demás sobre una baraja se fija en un
bloque `<…>` inmediatamente tras el corchete de apertura.

### El separador

```spx-good
[<, >rojo|verde|azul]  →  Verde, azul, rojo
```

Un bloque `<…>` es el separador mismo, salvo que **nombre un ajuste**: uno de `sep`, `lastsep`,
`minsize` o `maxsize`, como palabra propia y con un `=` detrás. Todo lo demás en ese sitio es un
separador, por mucho que parezca un ajuste: una clave sin su `=`:

```spx-good
[<maxsize 2>rojo|verde|azul]  →  Verdemaxsize 2azulmaxsize 2rojo
```

o una clave con algo pegado delante:

```
[<xmaxsize=1>rojo|verde|azul]  →  Verdexmaxsize=1azulxmaxsize=1rojo
```

El segundo merece una segunda mirada: el panel **sí** llama a `xmaxsize` clave desconocida, y el
motor imprime igualmente el bloque entero entre los trozos. El diagnóstico y la salida responden a
preguntas distintas.

Escriba los ajustes enteros cuando quiera dos separadores distintos:

```spx-good
[<sep=", ";lastsep=" y ">rojo|verde|azul]  →  Verde, azul y rojo
```

`sep` va entre los trozos y `lastsep` antes del último.

### Cuántos

```spx-good
[<minsize=2;maxsize=2>rojo|verde|azul]  →  Verde azul
```

`minsize` es el suelo y `maxsize` el techo; la cantidad entre ambos es aleatoria, como el orden.
Valores iguales toman exactamente esos. **Sin ninguno de los dos, todos; pero con solo `maxsize`
el suelo queda en uno**, lo cual sorprende:

```spx-good
[<maxsize=3>a|b|c]  →  C
```

Tres trozos, un techo de tres, y salió uno. Escriba también `minsize` cuando quiera decir «todos,
como mucho tres». Un `maxsize` mayor que el número de trozos se rebaja calladamente a ese número.
Un `minsize` mayor que el `maxsize` se acepta sin decir palabra, y gana el suelo: el techo se sube
hasta él y no al revés:

```spx-good
[<minsize=3;maxsize=1>rojo|verde|azul]  →  Verde azul rojo
```

### Un separador entre dos trozos

Un `<…>` escrito **entre** dos trozos es el separador de esa pareja.

```spx-good
[rojo|verde<y>|azul]  →  Verde y azul rojo
```

Pertenece al trozo **posterior** y viaja con él por la baraja, así que asoma donde caiga ese trozo
y no en un sitio fijo de la salida. Un `<…>` tras el **último** trozo no es separador en absoluto
y se imprime como texto:

```spx-good
[rojo|verde|azul<y>]  →  Verde azul<y> rojo
```

## Macros

`#set` da nombre a un trozo de texto. El nombre se usa como `%nombre%`, y la directiva debe ser lo
primero de su línea: se permiten espacios y tabuladores delante, nada más.

```spx-good
#set %ciudad% = Madrid
Vuelo a %ciudad%.  →  Vuelo a Madrid.
```

Los nombres se componen de letras latinas, cifras y `_`. Un nombre en otro alfabeto no es un
nombre, de lo que habla el otro documento bajo `set.malformed`. Las tildes y la `ñ`, por tanto, no
caben en un nombre; en un valor sí.

### `#set` vuelve a tirar, `#def` tira una vez

Esa es toda la diferencia entre los dos, y solo se ve cuando el valor contiene una elección.

```spx-good
#set %eleccion% = {A|B}
%eleccion% %eleccion% %eleccion%  →  A A B
```

```spx-good
#def %eleccion% = {A|B}
%eleccion% %eleccion% %eleccion%  →  A A A
```

Los dos ejemplos corrieron bajo la misma semilla. `#set` guarda la plantilla y la tira en cada
uso; `#def` tira una vez y se queda con la respuesta. Use `#def` para algo que deba concordar
consigo mismo —una marca, una ciudad, un nombre, una cuenta— y `#set` para la variedad.

Una sola semilla no permite distinguirlos: hay semillas en las que `#set` saca por casualidad tres
veces la misma posibilidad y los dos se parecen. Conviene saberlo antes de concluir, desde un solo
avance, que una definición no funciona.

## Condiciones

`{?nombre?entonces|si no}` pregunta si una macro tiene valor.

```spx-good
#set %n% = 5
{?n?tenemos %n%|nada aún}  →  Tenemos 5
```

La mitad `si no` puede faltar: `{?nombre?entonces}` no imprime nada cuando la respuesta es no. Un
`!` da la vuelta a la pregunta:

```spx-good
#set %vip% = 1
{?!vip?desconocido|amigo}  →  Amigo
```

Tener valor significa tener **al menos un carácter que no sea un espacio**. Una macro puesta a
nada, o solo a espacios, cuenta como sin valor.

El nombre de una condición debe **empezar** por letra o `_`, lo cual es más estricto que para una
macro; y el capítulo de los silencios dice en qué se convierte un nombre que empieza por cifra.

## Cuenta

`{plural %n%: …}` toma la forma de palabra que va con un número.

```spx-good
#def %n% = 1
%n% {plural %n%: archivo|archivos}  →  1 archivo
```

```spx-good
#def %n% = 5
%n% {plural %n%: archivo|archivos}  →  5 archivos
```

La cuenta aquí es un `#def` y no un `#set`, a propósito, y la regla merece guardarse: **haga que
la cuenta sea una cifra simple o un `#def`, nunca un `#set`.** Lo que llega al hueco de la cuenta
desde un `#set` es el TEXTO guardado, `{5|5}` y no `5` —no un número, por tanto—, de modo que la
construcción entera no produce nada y el panel dice `plural.count-macro`. La cuenta y la forma no
pueden contradecirse: lo que desaparece es la palabra.

```
#set %n% = {5|5}
%n% {plural %n%: archivo|archivos}  →  5
```

Cuántas formas hay lo decide la locale y no usted: bajo `es` son dos, bajo `ru` tres. El número
equivocado es un error que el panel señala (`plural.arity`), y el motor reimprime entonces la
construcción entera con las llaves cambiadas por unas anchas `｛｝`, para que no se confunda con la
salida.

## Fragmentos

`#include "nombre"` pone otra plantilla en ese punto, y la directiva debe ser lo primero de su
línea; también aquí se permiten espacios y tabuladores delante.

```spx-good
#include "intro"  →  Bienvenido a Acme.
```

El fragmento se renderiza como plantilla propia, así que una elección dentro de él se hace de
nuevo: `intro` contiene `{Acme|Globex}` y responde con una u otra.

El nombre se compara **exactamente**. `Intro` e `intro` son dos fragmentos distintos, y en Windows
es fácil equivocarse porque al sistema de archivos le da igual. Una diana ausente se renderiza
como nada y el panel dice `include.unknown-target`; una diana que solo difiere en mayúsculas
recibe una nota de Studio con el nombre que usted seguramente quería.

### Un fragmento no ve sus macros

Se renderiza como plantilla propia: tiene los valores de la sesión, pero no los `#set` ni los
`#def` del documento que lo trajo.

```
#set %marca% = Acme
#include "shout"  →  La %marca% está aquí.
```

`shout` vale `La %marca% está aquí.`, y el nombre ha de definirse en el fragmento mismo. Esto no
es un silencio —el panel sí dice `variable.undefined`—, pero lo dice contra **`shout`**, en la
línea 1 de ese archivo, y en el documento que usted mira no aparece ningún subrayado, porque la
posición pertenece a otro búfer. Lea la columna **Archivo** cuando un aviso parezca referirse a
una línea que usted no escribió.

## Comentarios

`/# … #/` es un comentario: todo lo que hay entre las marcas se quita antes que cualquier otra
cosa.

```spx-good
borrador /# no seguro de esto #/ listo  →  Borrador listo
```

Los comentarios no se anidan. El primer `#/` cierra el comentario, hubiera lo que hubiera antes,
así que un comentario envuelto alrededor de un texto que contenga `#/` acaba antes de lo que
parece.

## Lo que el motor pule al final

La salida no es del todo el texto que produjeron las construcciones. Al final le pasan varias
cosas; dos se encuentra usted a diario.

La primera letra de cada oración se pone en mayúscula:

```spx-good
uno. dos. tres.  →  Uno. Dos. Tres.
```

Por eso los ejemplos de esta ayuda responden tan a menudo con mayúscula donde la plantilla lleva
minúscula. Un punto tras una abreviatura que el motor conoce no termina una oración, y tampoco lo
hace nada con la forma de `e.g.` o `U.S.` —**en letras latinas**, que es un límite real y no una
cautela: la comprobación de «esto es mitad de palabra» es una comprobación ASCII.

```spx-good
etc. nuestros precios son bajos  →  etc. nuestros precios son bajos
```

```spx-good
Sr. nuestros precios son bajos  →  Sr. nuestros precios son bajos
```

Cualquier otra palabra termina una oración, por corta que sea: la longitud no tiene nada que ver:

```spx-good
Xyz. nuestros precios son bajos  →  Xyz. Nuestros precios son bajos
```

La lista que el motor conoce tiene 46 entradas, **29 de ellas cirílicas**, y el otro documento la
recorre bajo **Un silencio en todos los idiomas**. Para el español lo importante está más abajo,
en los silencios: la lista no está pensada para el español.

Lo segundo de cada día es que las series de espacios se reducen a uno. Eso es lo que le permite
dejar una posibilidad vacía sin contar los espacios de alrededor.

El resto de un tirón: un espacio delante de `,;:!?.` se quita y se inserta uno detrás; la salida
entera se recorta por los bordes; la mayúscula llega también tras un salto de línea y tras una
etiqueta de bloque, no solo tras un punto; y las direcciones con esquema, los correos
electrónicos, los dominios desnudos y los números decimales están protegidos y salen exactamente
como se escribieron.

Ese último punto lleva el mismo límite ASCII que las abreviaturas de arriba. Un dominio desnudo
está protegido si se escribe en letras latinas; `сайт.рф` no lo está, y el retoque le mete dentro
un espacio y una mayúscula.

```spx-good
hola , mundo  →  Hola, mundo
```

```spx-good
uno.dos  →  uno.dos
```

## Silencios

Cada caso de abajo se renderiza, produce algo distinto de lo que aparenta y no provoca **ningún
diagnóstico**. Están reunidos aquí porque nada más en la ventana va a mencionarlos nunca.

**Las abreviaturas españolas no están en la lista del motor.** Es el silencio con el que primero
se topa quien escribe en español. Solo están protegidas las palabras que coinciden con la mitad
latina de la lista —`Sr.`, `Dr.`, `Prof.` y `etc.` de arriba—, mientras que `Sra.`, `núm.` y
`pág.` terminan una oración y ponen en mayúscula la palabra siguiente:

```spx-good
pág. nuestros precios son bajos  →  Pág. Nuestros precios son bajos
```

`p. ej.`, con su espacio, atraviesa el retoque sin daño, lo cual vale más mostrarlo que
explicarlo:

```spx-good
p. ej. esto sigue en minúscula  →  p. ej. esto sigue en minúscula
```

Escrito junto, `p.ej.`, se protege a sí mismo por la regla de los varios puntos, pero la palabra
que sigue ya no:

```spx-good
p.ej. esto sigue en minúscula  →  p.ej. Esto sigue en minúscula
```

**Un `#include` que no está solo en su línea es texto corriente.**

```spx-good
Antes. #include "intro"  →  Antes. #include "intro"
```

Lo mismo vale para una directiva con algo detrás y para `#include"intro"` sin espacio. La regla es
de la familia y no de este motor, y es lo que hace reconocible una directiva sin analizar la línea
entera.

**Una condición cuyo nombre empieza por cifra no es una condición.** Se convierte en una elección
corriente entre `?1x?sí` y `no`:

```spx-good
{?1x?sí|no}  →  ?1x? Sí
```

**Un `<…>` a la cabeza de un trozo que no es el primero no es un separador** y se imprime tal
cual:

```spx-good
[rojo|<y>verde]  →  <y>Verde rojo
```

El bloque a la cabeza del **primer** trozo sí es el separador: es la escritura con que empieza el
capítulo de las barajas:

```spx-good
[<y>rojo|verde]  →  Verde y rojo
```

En cualquier sitio tras un `|` es texto corriente, y un separador entre dos trozos va al **final**
del primero.

**Una etiqueta desnuda al final de un trozo se toma por el separador de esa pareja** y se imprime
como texto propio:

```spx-good
[uno<br>|dos]  →  Dos uno
```

Bajo esta semilla los dos cayeron en el otro orden, así que el separador no salió en absoluto. Con
un tercer trozo hay dónde caer, y aparece:

```spx-good
[rojo|verde<br>|azul]  →  Verde br azul rojo
```

El `<br>` se coloca entre `verde` y lo que le siga, dondequiera que la baraja ponga esa pareja.
Una etiqueta de cierre (`</b>`), una autocerrada (`<br/>`), una con atributos
(`<br class="x">`) y una etiqueta en mitad de un trozo quedan todas intactas.

**Un comentario sin cerrar es texto corriente**: no abre nada, y el `/#` se imprime:

```spx-good
antes /# el resto de esto  →  Antes /# el resto de esto
```

Pero sigue siendo la mitad de una pareja. Si más abajo en el documento aparece un `#/`, los dos se
encuentran y todo lo que hay entre ellos se va, incluido lo que el autor escribiera en medio:

```
{a /# ups|b} medio #/ cola  →  {a cola
```

La elección de arriba perdió su segunda alternativa y su llave de cierre, y ningún diagnóstico lo
dice: eso es lo que el texto SIGNIFICA, y no un fallo que el motor pueda ver. Cuando un `/#` va en
serio, su sitio seguro es el valor de una variable y no el cuerpo de la plantilla.

## Dónde mirar después

El otro documento, **Qué le está diciendo la pestaña Diagnóstico**, tiene un artículo por cada
línea que el panel puede mostrar: qué significa, qué la provoca y qué hace el motor con la
plantilla mientras está ahí. Pulse F1 con el cursor dentro de una construcción y la ayuda se abre
en el capítulo de esa construcción **en aquel documento**: una llave en **Corchetes**, un `[…]` en
**Barajas**, una línea `#set` en **Definiciones**.
