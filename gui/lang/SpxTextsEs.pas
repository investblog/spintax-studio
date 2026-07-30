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

      'listo', 'válido', 'válido, %d advertencias', '%d errores', ' · %d notas', '%s · %d ms',
      'Mostrar', 'Salida: %d KB — la página no se redibuja sola',

      'Cerrar',

      'Más grande', 'Más pequeño', 'Tamaño normal', 'Claro', 'Oscuro',

      'Anchos iguales', 'Doble clic: anchos iguales',

      'Fuente del editor', 'Automática',

      'Valor no aplicado: el motor leería la directiva de otro modo',

      'Inclusiones — los fragmentos que trae este documento', 'Destino', 'Hallado', 'sí', 'FALTA', 'sin conjunto',

      'Ayuda', 'Contenido', 'Idioma de la ayuda', 'Todavía no hay ayuda en %s.'
  );

implementation

end.
