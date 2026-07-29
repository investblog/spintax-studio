(*
 * SpxTextsPt -- the window in Portuguese.
 *
 * One language, one file. The order is TSpxStr's and nothing else: this is a positional
 * array, so a line moved here moves a caption on screen.
 *)
unit SpxTextsPt;

{$mode objfpc}{$H+}

interface

uses
  SpxStrIds;

const
  TEXTS_PT: array[TSpxStr] of string = (
      'Ficheiro', 'Novo', 'Abrir…', 'Guardar', 'Guardar como…', 'Recarregar o conjunto',
      'Sair',
      'Editar', 'Localizar…', 'Localizar seguinte', 'Localizar anterior',
      'Ver', 'Ferramentas à esquerda', 'Ferramentas à direita',
      'Idioma da interface', 'English', 'Русский', 'Como o modelo',
      'G', 'Grupo sob o cursor',
      'O cursor não está dentro de um grupo.', 'Aplicar',
      'Recusado: o resultado diria algo diferente desta lista — uma variante não pode ' +
        'conter | } { ou /#.',
      'Uma variante contém uma quebra de linha, por isso o grupo é mostrado sem edição.',
      'Escolha', 'Condição', 'Plural', 'Permutação',
      'D', 'V', 'Vr',
      'Envolver em {…}', 'Envolver em […]', 'Mostrar outra variante', 'Copiar o resultado',
      'Selecionar tudo',

      'seed', 'Outra', 'Copiar', 'Página', 'Origem',
      'fragmento mostrado', 'o fragmento não produz nada',

      'Maiúsc.', 'não encontrado', 'achados %d', '%d/%d', 'x',

      'Diagnóstico', 'Variáveis', 'Variantes',
      'Nível', 'Ficheiro', 'Em', 'Mensagem',
      'erro', 'aviso', 'nota do Studio', 'documento',

      ' Definições — vivem no documento',
      ' Valores de sessão — processados como spintax, nunca escritos no documento',
      'Tipo', 'Nome', 'Valor', 'como texto',

      'Quantas', 'seed', 'aleatório', 'Gerar', 'Parar',
      'Descartar parecidas', 'Só duplicados exatos', 'Manter tudo', 'shingle', 'limite',
      'Para .xlsx', 'Para .txt', 'Um ficheiro cada', 'seed no .txt',
      'nada gerado ainda', 'a trabalhar…', 'a parar…',
      '%d variantes, %d descartadas, %d renderizações, próximo seed %d',
      '%d de %d — o modelo não dá mais com este limite (%d descartadas, %d renderizações)',
      'parado: %d variantes, %d descartadas, %d renderizações',
      '%d de %d, %d descartadas, %d renderizações',
      'o documento mudou — este conjunto vem do texto anterior; ',
      'escritas %d linhas em %s',
      'escritas %d linhas; em %d variantes as quebras de linha viraram espaços — para o ' +
        'texto tal como está, use .xlsx ou um ficheiro cada',
      'escritos %d ficheiros em %s', 'escritos %d ficheiros, depois não foi possível seguir',
      'não foi possível escrever o ficheiro',
      '#', 'seed', 'tamanho', 'texto',

      'Abrir um modelo', 'Guardar o modelo', 'Modelos spintax|*%s|Todos os ficheiros|*.*',
      'Livro do Excel|*.xlsx', 'Texto|*.txt',
      'Exportar para .xlsx', 'Exportar para .txt', 'Onde pôr os ficheiros', 'Variantes',
      'seed', 'variante',
      'Spintax Studio', 'O documento tem alterações por guardar. Guardá-las?', 'Sem título',
      '%s — Spintax Studio',

      'pronto', 'válido', 'válido, %d avisos', '%d erros', ' · %d notas', '%s · %d ms',
      'Mostrar', 'Saída: %d KB — a página não se redesenha sozinha',

      'Fechar'
  );

implementation

end.
