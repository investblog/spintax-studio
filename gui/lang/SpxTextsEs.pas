(*
 * SpxTextsEs -- the window in Spanish.
 *
 * One language, one file. The order is TSpxStr's and nothing else: this is a positional
 * array, so a line moved here moves a caption on screen.
 *)
unit SpxTextsEs;

{$mode objfpc}{$H+}

interface

uses
  SpxStrIds;

const
  TEXTS_ES: array[TSpxStr] of string = (
      'Archivo', 'Nuevo', 'Abrir…', 'Guardar', 'Guardar como…', 'Recargar el conjunto',
      'Salir',
      'Editar', 'Buscar…', 'Buscar siguiente', 'Buscar anterior',
      'Ver', 'Herramientas a la izquierda', 'Herramientas a la derecha',
      'Idioma de la interfaz', 'English', 'Русский', 'Como la plantilla',
      'G', 'Grupo bajo el cursor',
      'El cursor no está dentro de un grupo.', 'Aplicar',
      'Rechazado: el resultado diría algo distinto de esta lista — una variante no puede ' +
        'llevar | } { ni /#.',
      'Una variante contiene un salto de línea, así que este grupo se muestra sin editarse.',
      'Elección', 'Condición', 'Plural', 'Permutación',
      'D', 'V', 'Vr',
      'Envolver en {…}', 'Envolver en […]', 'Mostrar otra variante', 'Copiar el resultado',
      'Seleccionar todo',

      'seed', 'Otra', 'Copiar', 'Página', 'Fuente',
      'fragmento mostrado', 'el fragmento no produce nada',

      'May/min', 'no encontrado', 'hallados %d', '%d/%d', 'x',

      'Diagnóstico', 'Variables', 'Variantes',
      'Nivel', 'Archivo', 'En', 'Mensaje',
      'error', 'advertencia', 'nota de Studio', 'documento',

      ' Definiciones — viven en el documento',
      ' Valores de sesión — se procesan como spintax, nunca se escriben en el documento',
      'Tipo', 'Nombre', 'Valor', 'como texto',

      'Cuántas', 'seed', 'aleatorio', 'Generar', 'Parar',
      'Descartar parecidas', 'Solo duplicados exactos', 'Conservar todo', 'shingle',
      'límite',
      'A .xlsx', 'A .txt', 'Un archivo cada una', 'seed en .txt',
      'nada generado aún', 'trabajando…', 'parando…',
      '%d variantes, %d descartadas, %d procesados, siguiente seed %d',
      '%d de %d — la plantilla no da más con este límite (%d descartadas, %d procesados)',
      'parado: %d variantes, %d descartadas, %d procesados',
      '%d de %d, %d descartadas, %d procesados',
      'el documento ha cambiado — este conjunto viene del texto anterior; ',
      '%d filas escritas en %s',
      '%d filas escritas; en %d variantes los saltos de línea pasaron a espacios — para el ' +
        'texto tal cual, use .xlsx o un archivo cada una',
      '%d archivos escritos en %s', '%d archivos escritos, después no se pudo continuar',
      'no se pudo escribir el archivo',
      '#', 'seed', 'longitud', 'texto',

      'Abrir una plantilla', 'Guardar la plantilla',
      'Plantillas spintax|*%s|Todos los archivos|*.*',
      'Libro de Excel|*.xlsx', 'Texto|*.txt',
      'Exportar a .xlsx', 'Exportar a .txt', 'Dónde poner los archivos', 'Variantes',
      'seed', 'variante',
      'Spintax Studio', 'El documento tiene cambios sin guardar. ¿Guardarlos?', 'Sin título',
      '%s — Spintax Studio',

      'listo', 'válido', 'válido · advertencias: %d', 'errores: %d', ' · notas: %d', '%s · %d ms',
      'Mostrar', 'Salida: %d KB — la página no se redibuja sola',

      'Cerrar',

      'Más grande', 'Más pequeño', 'Tamaño normal', 'Claro', 'Oscuro',

      'Anchos iguales', 'Doble clic: anchos iguales',

      'Fuente del editor', 'Automática',

      'Valor no aplicado: el motor leería la directiva de otro modo',

      'Inclusiones — los fragmentos que trae este documento', 'Destino', 'Hallado', 'sí', 'FALTA', 'sin conjunto',

      'Ayuda', 'Contenido', 'Idioma de la ayuda', 'Todavía no hay ayuda en %s.',

      'de la ayuda', 'Insertar en mi documento',

      'Acerca de',

      'Aún no hay macros — escriba #set %name% = valor en el documento y use %name% en el texto.',
      'Aún no hay inclusiones — #include "fragmento" trae otro archivo, y solo al principio de la línea.',

      'Escriba una plantilla a la izquierda y vea a la derecha lo que produce. Validación, variables, inclusiones, generación de variantes y exportación: todo sin conexión, sin cuenta, sin red y sin runtime.',
      'Licencias y créditos',

      'Importar GSA',
      'Importar plantilla GSA…',
      'Plantillas GSA|*.txt;*.spintax|Todos los archivos|*.*',
      '%d variables se han extraído de la plantilla.',
      'Son valores de sesión: aparecen en el panel de variables y NO se guardan con el documento. La representación se hace sin posprocesado, para que la plantilla siga siendo la que escribió GSA.',
      '%d bloques han sido rechazados y dejados tal cual.',
      '…y %d más.',

      'Variantes posibles: %s',
      'Variantes posibles: al menos %s',

      (* the AI panel (ADR 0011) *)
      'Borrador de IA',
      'Encargo',
      'Variables que el modelo puede usar',
      'Respuesta del modelo',
      'Canal',
      'Variación',
      'Idioma',
      'Copiar la instrucción',
      'Copiar la instrucción de arreglo',
      'Insertar en el documento',
      'Caso',
      'Nota',
      'Instrucción copiada. Llévela a su modelo y traiga la respuesta.',
      'Instrucción de arreglo copiada. Señala los puntos exactos.',
      'Borrador insertado. El veredicto está en el panel de diagnósticos.',
      'Escriba primero un encargo.',
      'Pegue primero la respuesta del modelo.',
      'No hay errores que arreglar.',
      'correo',
      'SMS',
      'push',
      'página de destino',
      'genérico',
      'prudente',
      'equilibrada',
      'atrevida',
      '—',
      'nominativo',
      'genitivo',
      'dativo',
      'acusativo',
      'instrumental',
      'preposicional',
      'Reemplazar el documento',
      'Documento reemplazado. El veredicto está en el panel de diagnósticos.',

      (* R1-4: the loop in the window (spec §4.5). *)
      'Arreglar',
      'Ajustes de IA…',
      'detenido',
      'consultando al modelo…',
      'el motor comprueba el borrador…',
      'intento de arreglo %d de %d',
      'Sin errores, pero parte de los renders de prueba sale vacía — revise las formas del plural. El borrador está en el panel de IA, sin aplicar.',
      'El borrador está limpio, pero un fragmento incluido tiene un error. Corrija ese archivo — regenerar no puede arreglarlo.',
      'Quedan %d errores tras %d intentos de arreglo. El borrador está en el panel de IA, sin aplicar.',
      'Mientras la respuesta estaba en camino cambió algo contra lo que se verificó — el documento, valores o ajustes. El borrador está en la respuesta, sin aplicar.',
      'Este perfil se autentica y no hay clave adjunta. Introduzca la clave en el panel de IA.',
      'El endpoint pide dirigirse a otra dirección (%s). No se siguió; cambie el perfil si es intencionado.',
      'El http en claro más allá de esta máquina enviaría la clave y el texto sin cifrar. Use https.',
      'El endpoint rechazó la clave. Revísela en el panel de IA.',
      'El endpoint informa de un límite de peticiones o una cuota agotada. Inténtelo más tarde.',
      'La instrucción es más larga de lo que acepta este modelo.',
      'La petición no llegó: %s',
      'El endpoint respondió, pero en una forma que esta aplicación no puede leer: %s',
      'La respuesta no traía ninguna plantilla.',
      'El endpoint informa: %s',
      'Conexión',
      'Formato',
      'Endpoint',
      'Modelo',
      'Autorización',
      'ninguna',
      'Clave API',
      'Clave',
      'Adjuntar la clave',
      'Olvidar la clave',
      'hay una clave adjunta a este endpoint',
      'no hay clave adjunta',
      'el endpoint cambió — introduzca la clave de nuevo para adjuntarla a la nueva dirección',
      'Envío permitido',
      '¿Enviar a este endpoint?',
      '«Generar» y «Arreglar» envían el encargo, la plantilla actual y las variables declaradas al endpoint de este perfil:'#10'%s'#10#10'Con autorización por clave API, la clave viaja en las cabeceras de la petición. No se envía nada en ningún otro momento, y la dirección nunca cambia por sí sola: una redirección se rechaza y se muestra. Lo que el software de esa dirección haga con el texto depende de su operador.'#10#10'Puede desactivarlo en cualquier momento en los ajustes de IA.',

      (* R1-5: the report channel (Store policy 11.16) *)
      'Denunciar una salida de IA inapropiada…',

      (* the brief column's two modes (UX pass 2026-08-13) *)
      'Texto a convertir',
      'Primero pegue el texto a convertir.',

      (* find and replace (UX-plan item 8, 2026-08-14) *)
      'Reemplazar…',
      'reemplazar por',
      'Reemplazar',
      'Reemplazar todo',
      'Reemplazados: %d',

      'Insertar',
      'Envolver en /#…#/',
      '#set %nombre% = valor',
      '#def %nombre% = {a|b}',
      '#include "nombre"',
      '{?nombre?entonces|si no}',
      'No envuelto: un #/ dentro o alrededor de la selección terminaría el comentario antes de tiempo.',
      'No envuelto: una | suelta, un corchete sin cerrar o un comentario abierto cambiaría lo que dice la condición.',
      'No insertado: el cursor parte en dos una marca de comentario.',
      'La dirección del endpoint no se puede leer — corríjala y adjunte la clave de nuevo.',
      'Borrador verificado. Espera en la respuesta — insértelo o reemplace usted mismo.'
  );

implementation

end.
