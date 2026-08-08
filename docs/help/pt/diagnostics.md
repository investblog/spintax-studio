# O que lhe está a dizer o separador Diagnóstico

Cada linha desse separador é um veredicto do **motor**, e o mesmo veredicto que lhe dariam as
implementações em JavaScript, PHP ou Python: quatro motores independentes sujeitos a um mesmo
corpo de testes. Não é a opinião do Studio sobre o seu modelo. Se aqui o motor chama erro a alguma
coisa, todos os outros motores da família lhe chamam erro, e o seu modelo comportar-se-á no seu
servidor como nesta janela.

| o que está escrito | quem o diz | o que quer dizer |
|---|---|---|
| **erro** | o motor | o modelo não fará aquilo que aparenta |
| **aviso** | o motor | compõe-se, mas provavelmente não como queria |
| **nota do Studio** | Studio | o motor não disse nada, e vale mesmo assim a pena dizê-lo: uma inclusão em círculo, um alvo com outras maiúsculas, um caractere de controlo |

A coluna **Onde** é linha e coluna. Um clique na linha põe lá o cursor.

> Cada exemplo abaixo passa pelo motor que esta cópia do Studio traz consigo, sempre que o
> programa é compilado, e à direita está exactamente o que ele devolveu. Nada aqui é lembrado nem
> adivinhado; uma resposta que deixasse de ser verdadeira pararia a compilação. A versão do motor
> está em **Ajuda**, **Sobre**.

## Como ler os exemplos

A seta `→` separa o modelo daquilo que o motor devolveu. `⏎` é uma mudança de linha dentro de uma
saída, `(vazio)` quer dizer que não imprimiu absolutamente nada, e `…` marca uma saída comprida
demais para se mostrar inteira. O texto a seguir à saída, afastado por três espaços, é uma nota e
não parte da resposta.

As condições em que os exemplos correram estão aqui e não escondidas nos testes: sem elas algumas
respostas não poderiam ser reproduzidas. O conjunto de modelos é o que mais conta: de outro modo
`#include "frag"` → `Fragmento` assentaria em algo que este documento nunca diz.

```spx-fixture
locale: pt
seed: 7
empty: (vazio)
include frag: Fragmento
include loop: #include "loop"
include Intro: Introdução
```

`seed` fixa o sorteio: sem ele uma escolha ou um baralhar responderiam de outro modo em cada vez e
não haveria nada a verificar.

**A locale aqui é `pt`, e decide duas coisas:** quantas formas de número o motor espera e que
forma vai com que número. O português e o inglês pedem duas. O russo, o ucraniano, o bielorrusso,
o sérvio, o croata e o bósnio pedem três. A locale vem do selector por cima da metade direita, e
não do idioma da interface.

---

## Parênteses

**Ponha o cursor sobre um parêntese e a construção mostra-se inteira:** onde começa, onde acaba e
**cada um dos seus separadores**. Os grupos encaixados não se acendem com ela: têm separadores
próprios, e esses chegam quando o cursor pousa no parêntese deles. É a maneira mais rápida de ver
onde acaba aquilo que está a editar, sobretudo numa linha comprida em que a `}` foi parar dois
ecrãs à direita.

Um separador não é só `|`. Num baralhar, `[a<br>|b]` tem dois: o motor lê `<br>` como separador
posto **antes do pedaço seguinte**, e o realce mostra-o com os outros, porque faz parte de como a
construção está feita.

### `bracket.unclosed` — um parêntese é aberto e nunca fechado

```
um preço {barato|caro  →  Um preço {barato|caro
```

O motor não adivinha onde queria fechar. O texto fica como está, chaveta e tudo, e a escolha nunca
acontece.

### `bracket.mismatched` — fechado por um parêntese de outra espécie

```
um preço {barato|caro]  →  Um preço {barato|caro]
```

`{` espera `}` e `[` espera `]`. Um baralhar fechado por uma chaveta não é um baralhar.

### `bracket.unexpected-closing` — um parêntese de fecho sem nada aberto

```
um preço barato} e tudo  →  Um preço barato} e tudo
```

Fica ali como texto. Quase sempre é um parêntese que sobrou de uma alteração.

---

## Definições

### `set.malformed` — esta linha `#set` não segue a regra

```
#set cidade = Lisboa
em %cidade%  →  #set cidade = Lisboa ⏎ Em %cidade%
```

**O nome vai entre sinais de percentagem:** `#set %cidade% = Lisboa`. É o primeiro erro mais comum,
e põe duas linhas de uma vez no painel: a própria linha malformada e «esta variável não está
definida em lado nenhum», porque não houve definição e `%cidade%` não é de ninguém.

Olhe para a saída: a directiva falhada ficou no texto **tal como foi escrita**. O motor não a leu
como directiva, logo é uma linha comum e vai para o resultado.

### `def.malformed` — esta linha `#def` não segue a regra

```
#def paginas = {1|3}
%paginas%  →  #def paginas = 1 ⏎ %paginas%
```

A mesma regra e o mesmo preço. `#def` não difere de `#set` na escrita mas em **quando** o valor é
desdobrado: `#set` desdobra-o a cada menção, `#def` uma vez por composição. Um erro de escrita
custa-lhe as duas coisas.

E olhe com atenção: o `{1|3}` da directiva falhada **tirou uma possibilidade**. A linha passou a
texto comum — e o texto comum compõe-se como texto comum, chavetas e tudo. Uma linha malformada
não está desligada; apenas deixa de ser uma directiva.

### `definition.duplicate-name` — este nome já está definido acima

```
#set %x% = primeiro
#set %x% = segundo
%x%  →  Segundo
```

Funciona — ganha a **última** definição — mas o motor chama-lhe erro: um documento em que um nome é
posto duas vezes lê-se de modo ambíguo, e daqui a um mês não se lembrará de qual das duas linhas é
a viva. O erro aponta a **segunda** definição; a primeira está mais acima.

### `def.include-in-value` — `#include` dentro do valor de uma definição

```
#def %x% = #include "frag"
%x%  →  Fragmento
```

Uma inclusão dentro de um valor desdobra-se num momento diferente do que esperaria, e a família
proíbe-o. Ponha o `#include` numa linha só dele.

---

## Variáveis

### `variable.undefined` — esta variável não está definida em lado nenhum

```
olá, %nome%  →  Olá, %nome%
```

Um aviso e não um erro: o motor imprime o nome tal e qual. É de propósito, porque o valor pode vir
de fora, do anfitrião. No Studio esses valores fornecem-se no separador Variáveis, em **Valores de
sessão**.

**O valor de uma definição pode alterar-se no painel.** Ponha-se na coluna Valor na parte de cima e
carregue em **F2** (ou comece simplesmente a escrever); **Enter** aplica, **Esc** desiste. A
alteração vai **para o documento**, num único passo de anular: `Ctrl+Z` põe-na de volta.

O nome e a espécie (`#set` ou `#def`) não se alteram — é uma decisão e não um canto por acabar.
Mudar o nome a partir de uma célula parte todas as menções da variável no documento, e apagar a
linha levaria com ela o comentário e a indentação. Ambas as coisas pertencem ao texto, onde vê o
que está a fazer.

Muda exactamente o valor. A indentação, os espaços a mais, as maiúsculas do nome e um comentário
no fim da linha ficam como estavam: `   #set  %Marca%   =   Acme   /# resto #/` volta de uma
alteração diferindo só em `Acme`. O ficheiro está no git, e reformatar uma linha apareceria lá como
alteração sua.

**Uma recusa quer dizer que o motor leria a linha de outra maneira.** A alteração não é aplicada em
silêncio: o motor relê o resultado, e se não disser o que foi pedido, o documento fica em paz e a
barra de estado di-lo. Três causas reais: um `/#` no valor abre um comentário que come o resto do
ficheiro, uma mudança de linha acaba a directiva cedo demais, e um comentário **dentro** da
directiva torna a linha não alterável aos bocados — essa altere-a no texto.

**Dois gestos sobre o nome de uma variável.** O nome no painel é uma ligação e não um rótulo:

- **um clique no nome** leva o cursor ao primeiro sítio em que o documento usa essa variável, e a
  linha acende-se por um instante. A mesma palavra dentro de um comentário ou como alvo de um
  `#include` **não** conta: o painel leva-o aonde a variável trabalha mesmo.
- **Ctrl+clique** escreve uma definição no documento e abre-lhe por cima o editor de grupos. O
  valor que já tiver escrito entra como primeira possibilidade:

```
#set %marca% = {Vulkan}
casino %marca%  →  Casino Vulkan
```

A diferença entre os dois é o que sobrevive a fechar a janela. Um valor de sessão não: não está no
ficheiro, não está no git, e nenhum outro motor da família o vê. Uma definição está, e só uma
definição cala este aviso de vez. Um `Ctrl+Z` põe o documento de volta.

**Um valor de sessão é primeiro um modelo e não texto.** É o que o motor faz com qualquer valor do
anfitrião, e a pré-visualização tem de bater certo com o servidor, logo `{barato|caro}` escrito no
campo do valor dá uma escolha e não esses caracteres. Se queria o texto em si, marque **como
texto** na terceira coluna: então chavetas e sinais de percentagem continuam a ser caracteres.

### `variable.self-reference` — a definição nomeia-se a si própria

```
#set %x% = a %x% b
%x%  →  A a a … %x% … b b b
```

Cinquenta níveis, depois pára. O motor desdobra até ao limite de profundidade e pára, deixando
`%x%` a meio. Não é um ciclo, e também não é o que queria.

O `…` acima é a abreviatura deste documento e não a do motor. A saída verdadeira tem 207 caracteres
e leva **cinquenta e uma** letras de cada lado em vez de cinquenta: o quinquagésimo nível pára e
deixa o valor como está, e o valor contém mais uma de cada.

### `variable.circular-reference` — as definições nomeiam-se em círculo

```
#set %x% = %y%
#set %y% = %x%
%x%  →  %y%
```

Cada lado desdobra-se exactamente **uma vez** e depois pára: `%x%` passou a `%y%` e não a `%x%`. O
motor desenrola o círculo em vez de o percorrer, e o que sobrevive é o outro nome do círculo: ponha
`%x% %y%` num documento e sairá `%y% %x%`, o par trocado.

O painel traça uma linha por **cada menção que fecha o círculo**, e não uma linha para o círculo
nem uma por definição. Uma definição que nomeie o círculo duas vezes recebe duas linhas na sua
própria linha: `#set %x% = %y% %y%` contra `#set %y% = %x%` dá três erros, dois deles na primeira.
As linhas não são juntadas. E a posição assenta na definição que vale mesmo: se o nome estiver
definido duas vezes, é a **última**.

---

## Inclusões

### `#include` só funciona no princípio da linha

```
antes #include "frag" depois  →  Antes #include "frag" depois
```

```
#include "frag"  →  Fragmento
```

Nenhum diagnóstico, e é justamente esse o ponto: um `#include` a meio de uma linha **não** é uma
inclusão. O motor lê-o como texto comum e não diz nada, porque não há nada de que se queixar:
escreveu texto e obteve texto.

**O alvo pode, contudo, ficar uma linha abaixo**, e isso surpreende pelo outro lado. O intervalo
que o motor permite entre a palavra e o seu alvo inclui as mudanças de linha, logo isto é uma
inclusão e funciona:

```spx-good
#include
"frag"  →  Fragmento
```

Linhas vazias pelo meio também servem. O resto não serve: uma palavra antes do alvo ou qualquer
coisa que não sejam espaços atrás, e o conjunto volta a ser texto. O editor colore o alvo na sua
própria linha mas deixa a palavra comum até o alvo chegar: não promete uma directiva de que ainda
não vê o fim.

### `include.unknown-target` — não há alvo com esse nome no conjunto

```
#include "nenhum"  →  (vazio)
```

Os alvos são os ficheiros `.spintax` da pasta do documento aberto. Um alvo desconhecido desdobra-se
em nada: o parágrafo desaparece em vez de partir, que é precisamente por isso que é tão fácil não
dar por ele.

**É por isso que o separador Variáveis tem uma terceira secção, «Inclusões».** Enumera cada
`#include` do documento e, para cada um, se o conjunto tem o seu alvo: uma linha por ocorrência,
logo um alvo nomeado duas vezes dá duas linhas. A secção aparece só se o documento tiver inclusões.
Um clique numa linha leva o cursor ao `#include` que nomeia esse alvo.

A marca tem **três** valores, e o terceiro conta: «sem conjunto» não quer dizer «o excerto falta»,
mas «ainda não há onde procurar». O conjunto é a pasta ao lado do documento, e um documento por
gravar não tem pasta: até à primeira gravação, portanto, cada alvo está marcado assim. «FALTA»
aparece só quando há pasta e o ficheiro mesmo não está lá.

### `note.case-mismatch` — o alvo existe, com outras maiúsculas

```
#include "intro"  →  (vazio)
```

O conjunto contém `Intro.spintax`, e o motor diz mesmo assim que não há alvo com esse nome,
enquanto o Studio acrescenta a sua nota sobre as maiúsculas. Elas contam: `intro` e `Intro` são
alvos diferentes. O Windows abriria o ficheiro das duas maneiras, e é justamente por isso que o
Studio procura no conjunto e não no sistema de ficheiros: de outro modo a pré-visualização
contradiria o servidor sobre o mesmo documento.

### `note.cycle` — uma inclusão em círculo

Se `loop.spintax` contiver ele próprio `#include "loop"`, então:

```
#include "loop"  →  (vazio)
```

O motor põe nada em vez do infinito. A nota está lá para que saiba porque é que o parágrafo se
evaporou.

A linha é passada contra **`loop`** e não contra o documento que está a ver: o círculo é do
excerto, e é para lá que vai o cursor ao clicar. No documento aberto nada está sublinhado, porque a
linha que escreveu não tem nada de errado.

---

## Formas de número

### `plural.arity` — não há tantas formas quantas a locale pede

```
#set %n% = 5
%n% {plural %n%: objeto|objetos|objetoses}  →  5 ｛plural 5: objeto|objetos|objetoses｝
```

**Não é vazio: o motor imprime a construção inteira**, com as chavetas trocadas por umas largas
`｛｝`. É assim que diz «vi isto e não o consegui aplicar». Discreto não lhe chamaria ninguém, e
ainda bem: um parágrafo evaporado em silêncio custaria mais a encontrar.

O português pede duas formas, o russo três. Sob a locale deste documento a certa é
`{plural %n%: objeto|objetos}`.

**O vazio vem de outra causa, e as duas confundem-se com facilidade.** Compare estas duas, que só
diferem em quantas formas levam:

```
{plural %n%: objeto|objetos}  →  (vazio)   duas formas: certo para o português
{plural %n%: objeto|objetos|objetoses}  →  (vazio)   três formas: errado para o português
```

As duas não imprimem nada, e o painel trata-as de modo diferente: a primeira puxa só
`variable.undefined`, a segunda puxa também `plural.arity`. Portanto **o vazio não é o sinal de um
erro no número de formas**: aqui vem de `%n%` não estar definida, e o motor verifica a contagem
antes de contar as formas, parando assim antes de a pergunta pelo número sequer se pôr.

É por isso que o exemplo no topo deste artigo define `%n%` primeiro. Sem isso a saída estaria vazia
com qualquer número de formas e não mostraria nada sobre o número.

O painel e a saída respondem aqui a perguntas diferentes, e não é contradição: a linha é posta pela
**verificação**, que conta as formas no texto e da contagem não trata; o vazio vem da
**composição**, que tem uma ordem sua. Dê um algarismo à contagem, como faz o primeiro exemplo, e
verá o que o número de formas faz mesmo.

### `plural.count-macro` — a contagem vem de um `#set`, e esse volta a tirar a cada menção

```
#set %n% = {1|2}
%n% {plural %n%: objeto|objetos}  →  1
```

Veja o que sobreviveu: **o número foi impresso e o substantivo não.** A contagem tem de ser um
número quando a forma é escolhida, e um `#set` cujo valor é ele próprio uma escolha nunca chega a
sê-lo: o motor substitui o valor **sem o compor**, logo ao lugar da contagem chega o texto literal
`{1|2}`. A contagem e a forma não podem contradizer-se; o motor deixa cair a palavra.

`#def` comporta-se de outro modo e desdobra o seu valor uma vez por composição, logo o lugar da
contagem recebe um número:

```
#def %n% = {1|2}
%n% {plural %n%: objeto|objetos}  →  1 objeto
```

Para esse não há linha nenhuma no painel. Daí a regra: faça da contagem um algarismo simples ou um
`#def`, nunca um `#set`.

### `plural.nested-brackets` — parênteses dentro das formas

```
{plural %n%: {objeto|coisa}|objetos}  →  ｛plural %n%: ｛objeto|coisa｝|objetos｝
```

As formas são texto simples. Uma escolha lá dentro não é desdobrada, e no seu lugar é a construção
inteira que se imprime entre chavetas largas.

---

## Baralhares

### `permutation.unknown-key` — chave desconhecida na definição

```
[<foo=1>a|b|c]  →  Bfoo=1cfoo=1a
```

As chaves conhecidas são `minsize`, `maxsize`, `sep` e `lastsep`. Uma desconhecida não é uma
definição, e quando é a única coisa no bloco, o bloco inteiro não é definição nenhuma: passa a ser
o separador entre os pedaços, que é o que a saída mostra.

**Se ao lado houver uma chave a sério, o desfecho é outro completamente**, e esse é o erro mais
provável: uma chave de várias mal escrita:

```
[<sep=", ";foo=1>a|b|c]  →  B, c, a
```

O bloco é uma definição, `sep` é cumprido, a chave desconhecida simplesmente deixada cair, e o
painel diz o mesmo nos dois casos. O diagnóstico diz-lhe portanto que uma chave não foi entendida;
não lhe diz o que aconteceu a seguir. Para isso leia a saída.

### `permutation.minsize-not-integer` — minsize não é um número inteiro

```
[<minsize=dois>a|b|c]  →  B c a
```

Um valor não numérico cai juntamente com o seu limite, e vale o valor por omissão, que são todos os
pedaços.

### `permutation.maxsize-not-integer` — maxsize não é um número inteiro

```
[<maxsize=muitos>a|b|c]  →  B c a
```

Exactamente o mesmo pelo outro extremo: o limite de cima desaparece, e a saída volta a conter cada
pedaço.

---

## Notas do Studio sem nada para mostrar

As três notas abaixo não se podem mostrar com um exemplo neste documento, e a razão é diferente de
cada vez e é dita. Artigo têm mesmo assim: a ajuda deve uma resposta a **cada** linha que o painel
possa mostrar, ou uma linha do painel não leva a lado nenhum.

### `note.raw-sentinel` — um caractere de controlo no texto

Os caracteres U+E000–U+E005 são os que o motor usa para a sua própria marcação, e ele **retira-os**
antes de analisar. Se foram parar ao seu modelo — normalmente colados de outro editor —, o Studio
di-lo: nem a pré-visualização nem o servidor os mostrarão.

Aqui não há exemplo de propósito: esses caracteres são invisíveis, e uma linha que os levasse
pareceria vazia. Não haveria nada para ver.

### `note.unknown-target` — o conjunto está vazio, não há com que julgar

Aparece quando o conjunto ao lado do documento está **vazio**: nem um único modelo além deste. Não
há nada com que confrontar o alvo, logo o Studio não diz «não há alvo com esse nome»: diz que não
consegue responder. Ponha um só modelo nessa pasta e a nota dá lugar ao comum
`include.unknown-target`, que responde ao fundo da questão.

Um documento nunca gravado não tem conjunto **nenhum**, e esse é um terceiro caso e não este: as
inclusões ficam então à letra na saída e o painel não diz nada sobre elas. Grave o documento e
começam a funcionar.

Aqui não há exemplo por construção: o conjunto deste documento está declarado acima e não está
vazio.

### `note.too-deep` — inclusões encaixadas fundo demais

O motor pára no vigésimo nível de `#include` encaixados e abaixo disso não põe mais nada. O limite
é da família: os motores JavaScript, PHP e Python fazem o mesmo, logo um documento que lá chegue
comporta-se em todo o lado da mesma maneira.

Aqui não há exemplo por causa do tamanho: mostrar um pediria vinte e um ficheiros.

---

## Um silêncio em todas as línguas: as abreviaturas

### Uma abreviatura deixa em minúscula a palavra seguinte

```
Sr. os nossos preços são baixos  →  Sr. os nossos preços são baixos
Xyz. os nossos preços são baixos  →  Xyz. Os nossos preços são baixos
```

Duas linhas que diferem numa palavra, e a segunda palavra de cada uma dá-lhe a regra: depois de
`Sr.` a frase fica em minúscula, depois de `Xyz.` vai para maiúscula. O motor põe maiúscula depois
de um ponto — excepto depois de uma abreviatura que conhece, e depois de qualquer coisa com a forma
de `e.g.` ou `U.S.`. É silencioso: nenhum diagnóstico, nenhum aviso, e a única maneira de dar por
isso é ler a saída.

**A lista não é portuguesa, nem sequer inglesa.** Tem 46 entradas, e 29 delas são russas:

| | |
|---|---|
| latinas | `etc vs mr mrs ms dr prof sr jr inc ltd co corp no st ave blvd` |
| cirílicas | `соц эл см ср ст ул пр пер г р руб коп тыс млн млрд трлн доп напр прим изд обл респ стр табл рис мин макс тел факс` |

As duas metades valem em **todas** as locales: a regra nunca pergunta que idioma tem definido.
`руб.` protege portanto a palavra seguinte num documento português, e `Sr.` protege-a num russo.

Para um texto em português a consequência é simples e incómoda: das abreviaturas que escreve todos
os dias só `Sr.`, `Dr.`, `Prof.` e `etc.` estão na lista, por coincidirem com a metade latina.
`Sra.` e `pág.` não estão e acabam uma frase. O guia da linguagem acrescenta três casos medidos que
não se adivinham: `p. ex.` atravessa o retoque sem dano, `p.ex.` protege-se a si próprio mas deixa
a palavra seguinte ir para maiúscula, e `n.º` sai partido.

---

## Que aspecto tem a forma correcta

```spx-good
um preço {barato|caro}  →  Um preço barato
```

```spx-good
[<minsize=2;sep=", ">a|b|c]  →  C, b
```

```spx-good
#set %vip% = 1
{?vip?para si|para todos}  →  Para si
```

```spx-good
#set %n% = 5
%n% {plural %n%: artigo|artigos}  →  5 artigos
```

```spx-good
antes /# uma nota #/ depois  →  Antes depois
```

Cinco construções, cinco linhas limpas: uma escolha, um baralhar com definições, uma condição, uma
forma de número com um número à frente e um comentário. Nenhuma põe seja o que for no painel.

---

## Perguntas frequentes

**Porque é que o parágrafo desapareceu sem mais?**
Duas causas comuns, ambas acima: um alvo `#include` desconhecido e uma inclusão em círculo. As duas
não imprimem nada. A terceira, a que se suspeita primeiro — o número errado de formas —, **não**
imprime nada disso: o motor imprime a construção inteira entre chavetas largas `｛｝`. O vazio vem
lá de uma contagem não numérica e não do número de formas.

**Porque é que a minha variável com acento no nome não funciona?**
Os nomes são feitos de letras latinas, algarismos e do sublinhado. `%endereço%` não é menção
nenhuma de variável: o motor lê-o como texto e não diz nada, porque do ponto de vista dele não há
nada a assinalar:

```
olá %endereço% e %nome%  →  Olá %endereço% e %nome%
```

Ambas passaram intactas, e a armadilha está aí: só a segunda puxou uma linha no painel. A primeira
é silenciosa, logo nada lhe diz que nunca será substituída. Mude-lhe o nome. No **valor**, pelo
contrário, os acentos não dão problema nenhum.

**Porque é que o mesmo erro é mostrado duas vezes?**
Um círculo de definições puxa uma linha por cada menção que o fecha: dois sítios para ver, às vezes
três. Não são duplicados e não são juntados.

**O painel diz erro e a saída parece certa. Afinal?**
As duas coisas. Acontece com um nome definido duas vezes: a composição está certa — ganha o último
valor — e o documento é ambíguo. O veredicto é sobre o documento e não sobre esta saída em
particular.

**Mudei a locale e o documento ficou vermelho.**
É a locale a fazer o seu trabalho. O documento de demonstração é inglês e as suas formas de número
levam duas; ponha a locale em russo e essas duas formas passam a ser um erro de número, porque o
russo pede três. O português pede duas como o inglês, logo sob `pt` o documento de demonstração
fica sossegado. A locale pertence ao **documento**, e é por isso que o Studio não a muda quando
muda o idioma da interface.

**A pré-visualização bate certo com o que o meu servidor vai produzir?**
Com o mesmo motor, a mesma versão, a mesma locale e os mesmos valores, sim, exactamente, e é
justamente para isso que a pré-visualização corre o `spintax-win` a sério e não uma aproximação.
Com **outro** motor da família — o de JavaScript, PHP ou Python — transportam-se o veredicto e o
conjunto de textos que o modelo pode dar, mas não qual deles uma dada semente tira. Repetir esse
sorteio exacto a família não o promete.
