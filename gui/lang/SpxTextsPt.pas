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

      'pronto', 'válido', 'válido · avisos: %d', 'erros: %d', ' · notas: %d', '%s · %d ms',
      'Mostrar', 'Saída: %d KB — a página não se redesenha sozinha',

      'Fechar',

      'Maior', 'Menor', 'Tamanho normal', 'Claro', 'Escuro',

      'Larguras iguais', 'Duplo clique: larguras iguais',

      'Fonte do editor', 'Automática',

      'Valor não aplicado: o motor leria a diretiva de outra forma',

      'Inclusões — os fragmentos que este documento traz', 'Destino', 'Encontrado', 'sim', 'FALTA', 'sem conjunto',

      'Ajuda', 'Conteúdo', 'Idioma da ajuda', 'Ainda não há ajuda em %s.',

      'da ajuda', 'Inserir no meu documento',

      'Sobre',

      'Ainda não há macros — escreva #set %name% = valor no documento e use %name% no texto.',
      'Ainda não há inclusões — #include "fragmento" traz outro ficheiro, e apenas no início da linha.',

      'Escreva um modelo à esquerda e veja à direita o que ele produz. Validação, variáveis, inclusões, geração de variantes e exportação: tudo offline, sem conta, sem rede e sem runtime.',
      'Licenças e créditos',

      'Importar GSA',
      'Importar modelo GSA…',
      'Modelos GSA|*.txt;*.spintax|Todos os ficheiros|*.*',
      '%d variáveis foram extraídas do modelo.',
      'São valores de sessão: aparecem no painel de variáveis e NÃO são guardados com o documento. A renderização corre sem pós-processamento, para o modelo ficar tal como o GSA o escreveu.',
      '%d blocos foram recusados e deixados tal como estavam.',
      '…e mais %d.',
      'A importação foi descartada: o documento mudou enquanto o modelo era convertido.',

      'Variantes possíveis: %s',
      'Variantes possíveis: pelo menos %s',

      (* the AI panel (ADR 0011) *)
      'Rascunho de IA',
      'Resumo',
      'Variáveis que o modelo pode usar',
      'Resposta do modelo',
      'Canal',
      'Variação',
      'Idioma',
      'Copiar o pedido',
      'Copiar o pedido de correção',
      'Inserir no documento',
      'Caso',
      'Nota',
      'Pedido copiado. Leve-o ao seu modelo e traga a resposta.',
      'Pedido de correção copiado. Aponta os pontos exatos.',
      'Rascunho inserido. O veredicto está no painel de diagnósticos.',
      'Escreva primeiro um resumo.',
      'Cole primeiro a resposta do modelo.',
      'Não há erros para corrigir.',
      'e-mail',
      'SMS',
      'push',
      'página de destino',
      'genérico',
      'prudente',
      'equilibrada',
      'ousada',
      '—',
      'nominativo',
      'genitivo',
      'dativo',
      'acusativo',
      'instrumental',
      'prepositivo',
      'Substituir o documento',
      'Documento substituído. O veredicto está no painel de diagnósticos.',

      (* R1-4: the loop in the window (spec §4.5). Portuguese shares one word for the
         template and the LLM ("modelo"), so what is sent is "o pedido" and "o modelo"
         stays the LLM alone. *)
      'Corrigir',
      'Definições de IA…',
      'parado',
      'a consultar o modelo…',
      'o motor verifica o rascunho…',
      'tentativa de correção %d de %d',
      'Sem erros, mas parte dos renders de teste sai vazia — verifique as formas do plural. O rascunho está no painel de IA, não aplicado.',
      'O rascunho está limpo, mas um fragmento incluído tem um erro. Corrija esse ficheiro — regenerar não o repara.',
      'Restam %d erros após %d tentativas de correção. O rascunho está no painel de IA, não aplicado.',
      'Enquanto a resposta vinha a caminho mudou algo contra que foi verificada — o documento, valores ou definições. O rascunho está na resposta, não aplicado.',
      'Este perfil autentica-se e nenhuma chave está anexada. Introduza a chave no painel de IA.',
      'O endpoint pede para usar outro endereço (%s). Não foi seguido; mude o perfil se for intencional.',
      'Http em claro para lá desta máquina enviaria a chave e o texto às claras. Use https.',
      'O endpoint recusou a chave. Verifique-a no painel de IA.',
      'O endpoint comunica um limite de pedidos ou uma quota esgotada. Tente mais tarde.',
      'O pedido é mais longo do que este modelo aceita.',
      'O pedido não passou: %s',
      'O endpoint respondeu, mas numa forma que esta aplicação não consegue ler: %s',
      'A resposta não trazia nenhum modelo.',
      'O endpoint comunica: %s',
      'Ligação',
      'Formato',
      'Endpoint',
      'Modelo',
      'Autorização',
      'nenhuma',
      'Chave API',
      'Chave',
      'Anexar a chave',
      'Esquecer a chave',
      'há uma chave anexada a este endpoint',
      'nenhuma chave anexada',
      'o endpoint mudou — introduza a chave de novo para a anexar ao novo endereço',
      'Envio permitido',
      'Enviar para este endpoint?',
      '«Gerar» e «Corrigir» enviam o resumo, o modelo atual e as variáveis declaradas para o endpoint deste perfil:'#10'%s'#10#10'Com autorização por chave API, a chave viaja nos cabeçalhos do pedido. Nada mais é enviado em nenhum outro momento, e o endereço nunca muda sozinho: um redirecionamento é recusado e mostrado. O que o software nesse endereço faz com o texto depende do seu operador.'#10#10'Pode desligar isto a qualquer momento nas definições de IA.',

      (* R1-5: the report channel (Store policy 11.16) *)
      'Comunicar uma saída de IA imprópria…',

      (* the brief column's two modes (UX pass 2026-08-13) *)
      'Texto a converter',
      'Cole primeiro o texto a converter.',

      (* find and replace (UX-plan item 8, 2026-08-14) *)
      'Substituir…',
      'substituir por',
      'Substituir',
      'Substituir tudo',
      'Substituídos: %d',

      'Inserir',
      'Envolver em /#…#/',
      '#set %nome% = valor',
      '#def %nome% = {a|b}',
      '#include "nome"',
      '{?nome?então|senão}',
      'Não envolvido: um #/ dentro ou à volta da seleção terminaria o comentário cedo demais.',
      'Não envolvido: uma | solta, um parêntese por fechar ou um comentário aberto mudaria o que a condição diz.',
      'Não inserido: o cursor corta ao meio uma marca de comentário.',
      'O endereço do endpoint não se consegue ler — corrija-o e anexe a chave de novo.',
      'Rascunho verificado. Espera na resposta — insira-o ou substitua você mesmo.'
  );

implementation

end.
