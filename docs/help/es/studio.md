# Spintax Studio

Este programa es un editor de plantillas. Una plantilla es texto corriente con unos pocos lugares
marcados dentro, y una sola plantilla puede producir muchísimos textos distintos: en eso consiste
escribir una en lugar de escribir los textos.

La ventana son dos mitades. A la izquierda su plantilla, lo que usted edita. A la derecha uno de
los textos que produce, redibujado mientras escribe. No hay nada que pulsar entre medias: lo que
ve a la derecha es lo que el motor devuelve para lo que hay a la izquierda en ese instante.

```spx-fixture
locale: es
seed: 7
empty: (vacío)
```

El motor va dentro de este programa y es el miembro Pascal de una familia: el mismo lenguaje se
publica también para JavaScript, PHP y Python. Los cuatro son programas independientes sujetos a
un mismo juego de casos de prueba, de modo que lo que una plantilla SIGNIFICA es igual en todos:
las construcciones, el veredicto sobre su validez, los retoques finales. Una plantilla que esta
ventana llama válida lo es también allí.

Lo que no se promete, y la diferencia importa al comparar: el sorteo. Una semilla hace el avance
repetible AQUÍ —la misma semilla y la misma plantilla dan mañana el mismo texto—, pero la misma
semilla en el motor de JavaScript puede sacar otra alternativa. Las semillas sirven para
reproducir su propio trabajo, no para coincidir con otro motor.

Todo aquí funciona sin conexión de red. No hay cuenta, no hay inicio de sesión y no hay nada que
activar: abra el programa y ya está funcionando.

## Las dos mitades

Se escribe a la izquierda. La mitad derecha se redibuja tras una pausa breve, para que el avance
siga a una frase y no a cada letra.

Una plantilla con una elección dentro no tiene una única respuesta, y el avance muestra una:

```spx-good
{Hola|Buenas} a todos.  →  Hola a todos.
```

**Otra**, encima de la mitad derecha, saca otra. Si quiere siempre la misma —mientras
compara dos cambios, por ejemplo— marque **seed**, y el avance se queda quieto hasta que la
desmarque o cambie el número.

El selector sobre la mitad derecha ofrece **Página** y **Fuente**. Las plantillas suelen ser HTML, y las dos
preguntas «qué aspecto tiene» y «qué marcado ha salido» no se responden la una a la otra: una
etiqueta rota da una maquetación algo torcida que el ojo se salta, mientras que la prosa con
etiquetas dentro no se lee como prosa. El interruptor sobre la mitad cambia lo que está mirando.

Seleccione una parte de la plantilla y solo esa parte se renderiza —en el ámbito del documento
entero, de modo que un fragmento que usa una variable definida arriba sale como saldrá en su
sitio.

## Los paneles de abajo

La barra de herramientas del lateral abre cuatro paneles, uno cada vez.

**Diagnóstico** enumera lo que el motor ha encontrado mal, cada cosa con la línea y la columna en
que empieza. Un clic en una fila pone ahí el cursor. Es el mismo veredicto que el motor da en
todas partes, no una segunda opinión del editor: por eso una plantilla que este panel llama válida
la aceptan los demás motores.

**Variables** muestra los nombres que su documento define y los que solo usa. Un nombre que usa y
que nada define puede rellenarlo aquí para la sesión: escriba un valor al lado y el avance lo
recoge. Marque **como texto** cuando el valor sea texto que se significa a sí mismo y no una pequeña
plantilla propia.

**Variantes** genera muchos textos de una vez. Diga cuántos, genérelos y léalos en la lista antes
de exportar. Los casi duplicados pueden descartarse según se producen, y una semilla hace todo el
lote repetible: la misma semilla y la misma plantilla dan mañana las mismas variantes.

Junto a esos campos el panel dice cuántas variantes puede dar la plantilla en total:
`{a|b} y {c|d}` da cuatro. Ese número le avisa de que una plantilla es pobre antes de que genere
cincuenta y se dé cuenta leyéndolas.

Es una cuenta exacta solo mientras cada elección quede al azar. Una condición, una forma de número
o un `#include` cuya diana no tenga el juego los decide otra cosa —un valor que usted aporte, un
número, un fragmento que quizá llegue—, y entonces el panel dice **al menos**. Esa es la palabra
honrada: aportar un valor solo puede añadir textos, nunca quitarlos. Un número demasiado grande
para leerlo se detiene en un billón y dice **al menos** por la misma razón.

Una variante es una plantilla rellenada —una elección hecha en cada construcción—, y eso no es lo
mismo que un texto que se lea distinto. `{a|a}` son dos variantes y un texto, y es deliberado: las
dos posibilidades pueden dejar de coincidir tras un solo cambio, y juntarlas obligaría a generar
antes todas las combinaciones, que es justo el trabajo que este número le ahorra. Un `#def` cuenta
igual: el motor lo saca una vez por render, use o no la rama que usted tomó.

La exportación las escribe de tres maneras: como libro XLSX, como texto plano con una variante por
línea, o como un archivo por variante en una carpeta que usted elija.

**Borrador de IA** es por donde empieza una plantilla cuando prefiere no escribir cada variante
a mano. Diga en el encargo lo que quiere, enumere las variables que el modelo puede usar y pulse
**Copiar la instrucción**. La aplicación no habla con ningún modelo ni guarda ninguna clave: redacta la
instrucción para que usted la lleve al que ya utiliza. Traiga la respuesta y pulse **Insertar en el documento**:
el motor de esta ventana dirá entonces qué le parece, en el panel de diagnósticos, igual que con
cualquier cosa que escriba usted mismo. Si hay errores, **Copiar la instrucción de arreglo** construye una segunda instrucción: lleva el documento entero con sus líneas numeradas y
nombra los puntos exactos que el motor objetó. La respuesta es el documento corregido completo,
así que tráigala y pulse **Reemplazar el documento**: **Insertar en el documento** dejaría el
roto donde está y pondría una copia corregida al lado.

La columna de caso es la parte que vale la pena rellenar. Una variable se inserta tal cual, nada
la declina: en una lengua con casos la frase debe construirse alrededor de la forma que el valor
ya tiene, y un modelo solo elige bien si se le dice qué forma lleva cada nombre. Del nombre no
se deduce: en un juego de plantillas real las formas instrumentales estaban en una variable cuyo
nombre decía acusativo.

## El editor de grupos

Ponga el cursor dentro de un `{a|b|c}` y abra el editor de grupos desde la barra de herramientas.
Enumera las alternativas como filas: cámbielas, añada una, quite otra, y el documento se reescribe
en consecuencia.

Rechaza los cambios que alterarían lo que el grupo SIGNIFICA en vez de lo que dice: un `|`
escrito dentro de una alternativa convertiría una en dos, y un `}` cerraría el grupo antes de
tiempo. Cuando rechaza, lo dice y deja el documento en paz.

## Ajustes

Están en el menú Ver, y todos se recuerdan entre sesiones: el idioma de la interfaz y si sigue a
la plantilla, de qué lado está la barra de herramientas, el tema, la fuente del editor y su
tamaño, si el avance muestra la página o el código, el interruptor de la importación GSA, qué
panel está abierto y el ancho de los paneles que se despliegan.

La interfaz habla catorce idiomas, elegidos en ese mismo menú. Eso es aparte del idioma de su
plantilla, que es lo que decide las formas de número y se fija encima de la mitad derecha.

## Importar una plantilla GSA

Esta parte está apagada hasta que usted la encienda, en **Ver**, **Importación GSA**, porque la
mayoría de quienes escriben plantillas nunca han usado GSA Search Engine Ranker. Encendida,
**Archivo**, **Importar plantilla GSA…** lee una plantilla SER y la convierte a este lenguaje.

La conversión es cuidadosa de una manera concreta. Lo que no puede expresar con fidelidad lo
rechaza y se lo dice, en vez de convertirlo calladamente en algo que se renderiza. Las
construcciones que se leerían mal si se quedaran en el texto —corchetes BBCode, una `#` dentro de
un enlace, una macro `#file[...]`— se sacan a variables, y el resumen dice cuántas.

Dos cosas que saber del resultado:

- **Los valores extraídos son valores de sesión.** Aparecen en el panel Variables y no se guardan
  con el documento. Guarde la plantilla convertida, ábrala mañana y verá `%…%` donde estaba el
  texto extraído. Del archivo importado no se pierde nada —ese queda intacto—, pero el documento
  convertido no se basta a sí mismo.
- **Se renderiza sin la pasada de retoque.** Cualquier otro documento de aquí recibe los retoques
  que describe la guía del lenguaje; una plantilla convertida no, porque no es texto nuestro que
  pulir. Es de otra persona, suele ir de vuelta a GSA y tiene que sobrevivir carácter a carácter.

El documento importado está sin título y sin guardar, como uno nuevo. El archivo que usted eligió
queda exactamente como estaba.
