# A linguagem, construção a construção

Um modelo é texto comum com alguns pontos marcados dentro. Tudo o que não está marcado sai tal e
qual; são as marcas que permitem a um modelo produzir muitos textos.

São seis, e é toda a linguagem: uma **escolha** entre alternativas, um **baralhar** de vários
pedaços, uma **macro** que define uma vez e usa pelo nome, uma **condição**, uma **contagem** que
apanha a forma de palavra certa, e uma **inclusão** que traz outro modelo. Os comentários são uma
sétima marca que não produz absolutamente nada.

> Cada exemplo abaixo passa pelo motor que esta cópia do Studio traz consigo, sempre que o
> programa é compilado, e à direita está exactamente o que ele devolveu. Nada aqui é lembrado nem
> adivinhado; uma resposta que deixasse de ser verdadeira pararia a compilação. A versão do motor
> está em **Ajuda**, **Acerca de**.

O outro documento desta ajuda, **O que lhe está a dizer o separador Diagnóstico**, trata do que
corre mal. Este trata do que as construções fazem quando nada corre mal — incluindo os vários
sítios em que um modelo faz algo surpreendente e nada o assinala.

## Como ler os exemplos

A seta `→` separa o modelo daquilo que o motor devolveu. `(vazio)` quer dizer que não imprimiu
absolutamente nada. O texto a seguir à saída, afastado por três espaços, é uma nota e não parte da
resposta.

As condições são declaradas e não subentendidas, porque sem elas metade das respostas abaixo não
poderia ser reproduzida:

```spx-fixture
locale: pt
seed: 7
empty: (vazio)
include intro: Bem-vindo à {Acme|Globex}.
include shout: A %marca% está aqui.
```

`seed` fixa o sorteio. Um modelo com uma escolha lá dentro não tem uma única resposta, logo um
exemplo sem semente imprimiria coisa diferente em cada passagem e não haveria nada a verificar. Na
janela é a caixa **Semente** por cima da metade direita; marque-a e ao lado aparece um campo
numérico, e a pré-visualização fica quieta enquanto trabalha.

`locale` decide as formas de número, e é o selector por cima da metade direita, não o idioma da
interface. O português e o inglês pedem duas formas; o russo, o ucraniano, o bielorrusso, o sérvio,
o croata e o bósnio pedem três.

## Escolhas

Chavetas com `|` pelo meio: o motor apanha **uma**.

```spx-good
Uma sala {pequena|grande}.  →  Uma sala pequena.
```

O sorteio é aleatório, logo o mesmo modelo dá `Uma sala grande.` noutra passagem. A escolha em si
deixa em paz o texto à sua volta — ainda que o retoque descrito perto do fim deste documento
chegue lá na mesma.

### Encaixe

Uma escolha pode conter outra, a qualquer profundidade.

```spx-good
Acme {Pro {Plus|Max}|Lite}  →  Acme Pro Plus
```

A escolha de dentro só se faz se a de fora apanhar o ramo em que ela está: se sair `Lite`,
`Plus|Max` nunca é consultado — e, coisa que se pode medir, nem sequer lhe é pedido um número ao
acaso.

### Uma possibilidade vazia

Uma possibilidade pode estar vazia. É a maneira comum de fazer aparecer algo só de vez em quando.

```spx-good
Uma sala {|muito }grande.  →  Uma sala grande.
```

Escrever o espaço dentro da possibilidade, `{|muito }` em vez de `{|muito} `, é hábito e não
obrigação: o retoque junta o espaço duplo de qualquer maneira.

## Baralhares

Os parênteses rectos apanham vários pedaços, escolhem quantos, põem-nos em ordem aleatória e
juntam-nos.

```spx-good
[vermelho|verde|azul]  →  Verde azul vermelho
```

Deixado a si mesmo apanha-os todos e junta-os com um espaço. Todo o resto sobre um baralhar
define-se num bloco `<…>` logo a seguir ao parêntese de abertura.

### O separador

```spx-good
[<, >vermelho|verde|azul]  →  Verde, azul, vermelho
```

Um bloco `<…>` é o próprio separador, a não ser que **nomeie uma definição**: uma de `sep`,
`lastsep`, `minsize` ou `maxsize`, como palavra por si e com um `=` atrás. Todo o resto nesse
lugar é um separador, por muito que pareça uma definição — uma chave sem o seu `=`:

```spx-good
[<maxsize 2>vermelho|verde|azul]  →  Verdemaxsize 2azulmaxsize 2vermelho
```

ou uma chave com algo colado à frente:

```
[<xmaxsize=1>vermelho|verde|azul]  →  Verdexmaxsize=1azulxmaxsize=1vermelho
```

O segundo merece um segundo olhar: o painel chama `xmaxsize` chave desconhecida **sim senhor**, e
o motor imprime na mesma o bloco inteiro entre os pedaços. O diagnóstico e a saída respondem a
perguntas diferentes.

Escreva as definições por extenso quando quiser dois separadores diferentes:

```spx-good
[<sep=", ";lastsep=" e ">vermelho|verde|azul]  →  Verde, azul e vermelho
```

`sep` vai entre os pedaços e `lastsep` antes do último.

### Quantos

```spx-good
[<minsize=2;maxsize=2>vermelho|verde|azul]  →  Verde azul
```

`minsize` é o chão e `maxsize` o tecto; o número entre os dois é aleatório como a ordem. Valores
iguais apanham exactamente esses. **Sem nenhum dos dois, todos; mas só com `maxsize` o chão fica em
um**, o que surpreende:

```spx-good
[<maxsize=3>a|b|c]  →  C
```

Três pedaços, um tecto de três, e saiu um. Escreva também `minsize` quando quiser dizer «todos, no
máximo três». Um `maxsize` maior do que o número de pedaços é baixado em silêncio até esse número.
Um `minsize` maior do que o `maxsize` é aceite sem uma palavra, e ganha o chão: o tecto é
levantado até ele e não ao contrário:

```spx-good
[<minsize=3;maxsize=1>vermelho|verde|azul]  →  Verde azul vermelho
```

### Um separador entre dois pedaços

Um `<…>` escrito **entre** dois pedaços é o separador desse par.

```spx-good
[vermelho|verde<e>|azul]  →  Verde e azul vermelho
```

Pertence ao pedaço **seguinte** e viaja com ele pelo baralhar, aparecendo portanto onde esse
pedaço calhar e não num lugar fixo da saída. Um `<…>` depois do **último** pedaço não é separador
nenhum e imprime-se como texto:

```spx-good
[vermelho|verde|azul<e>]  →  Verde azul<e> vermelho
```

## Macros

`#set` dá nome a um pedaço de texto. O nome usa-se como `%nome%`, e a directiva tem de ser a
primeira coisa da sua linha: espaços e tabulações à frente são permitidos, mais nada.

```spx-good
#set %cidade% = Lisboa
Voo para %cidade%.  →  Voo para Lisboa.
```

Os nomes são feitos de letras latinas, algarismos e `_`. Um nome noutro alfabeto não é um nome, do
que trata o outro documento sob `set.malformed`. Os acentos e o `ç`, portanto, não cabem num nome;
num valor cabem.

### `#set` volta a tirar, `#def` tira uma vez

É toda a diferença entre os dois, e só se vê quando o valor contém uma escolha.

```spx-good
#set %escolha% = {A|B}
%escolha% %escolha% %escolha%  →  A A B
```

```spx-good
#def %escolha% = {A|B}
%escolha% %escolha% %escolha%  →  A A A
```

Os dois exemplos correram sob a mesma semente. `#set` guarda o modelo e tira-o a cada uso; `#def`
tira uma vez e fica com a resposta. Use `#def` para algo que tenha de concordar consigo mesmo — uma
marca, uma cidade, um nome, uma contagem — e `#set` para a variedade.

Uma só semente não permite distingui-los: há sementes em que `#set` calha tirar três vezes a mesma
possibilidade e os dois parecem iguais. Vale a pena sabê-lo antes de concluir, de uma só
pré-visualização, que uma definição não está a funcionar.

## Condições

`{?nome?então|senão}` pergunta se uma macro tem valor.

```spx-good
#set %n% = 5
{?n?temos %n%|ainda nada}  →  Temos 5
```

A metade `senão` pode faltar: `{?nome?então}` não imprime nada quando a resposta é não. Um `!`
vira a pergunta do avesso:

```spx-good
#set %vip% = 1
{?!vip?estranho|amigo}  →  Amigo
```

Ter valor significa ter **pelo menos um caractere que não seja um espaço**. Uma macro posta a nada,
ou só a espaços, conta como sem valor.

O nome de uma condição tem de **começar** por letra ou `_`, o que é mais severo do que para uma
macro; e o capítulo dos silêncios diz no que se transforma um nome que comece por algarismo.

## Contagem

`{plural %n%: …}` apanha a forma de palavra que vai com um número.

```spx-good
#def %n% = 1
%n% {plural %n%: ficheiro|ficheiros}  →  1 ficheiro
```

```spx-good
#def %n% = 5
%n% {plural %n%: ficheiro|ficheiros}  →  5 ficheiros
```

A contagem aqui é um `#def` e não um `#set`, de propósito, e a regra vale a pena guardar: **faça
da contagem um algarismo simples ou um `#def`, nunca um `#set`.** O que chega ao lugar da contagem
a partir de um `#set` é o TEXTO guardado, `{5|5}` e não `5` — não um número, portanto —, de modo
que a construção inteira não produz nada e o painel diz `plural.count-macro`. A contagem e a forma
não podem contradizer-se: o que desaparece é a palavra.

```
#set %n% = {5|5}
%n% {plural %n%: ficheiro|ficheiros}  →  5
```

Quantas formas há decide-o a locale e não o utilizador: sob `pt` são duas, sob `ru` três. O número
errado é um erro que o painel assinala (`plural.arity`), e o motor reimprime então a construção
inteira com as chavetas trocadas por umas largas `｛｝`, para que não se confunda com saída.

## Excertos

`#include "nome"` põe outro modelo nesse ponto, e a directiva tem de ser a primeira coisa da sua
linha; também aqui espaços e tabulações à frente são permitidos.

```spx-good
#include "intro"  →  Bem-vindo à Acme.
```

O excerto é composto como modelo próprio, logo uma escolha lá dentro é feita de novo: `intro`
contém `{Acme|Globex}` e responde com um ou com o outro.

O nome é comparado **exactamente**. `Intro` e `intro` são dois excertos diferentes, e no Windows é
fácil enganar-se porque ao sistema de ficheiros tanto lhe faz. Um alvo em falta compõe-se como
nada e o painel diz `include.unknown-target`; um alvo que só difira em maiúsculas recebe uma nota
do Studio com o nome que provavelmente queria.

### Um excerto não vê as suas macros

É composto como modelo próprio: tem os valores da sessão, mas não os `#set` nem os `#def` do
documento que o trouxe.

```
#set %marca% = Acme
#include "shout"  →  A %marca% está aqui.
```

`shout` vale `A %marca% está aqui.`, e o nome tem de estar definido no próprio excerto. Isto não é
um silêncio — o painel diz mesmo `variable.undefined` — mas di-lo contra **`shout`**, na linha 1
desse ficheiro, e no documento que está a ver não aparece qualquer sublinhado, porque a posição
pertence a outro tampão. Leia a coluna **Ficheiro** quando um aviso parecer ser sobre uma linha que
não escreveu.

## Comentários

`/# … #/` é um comentário: tudo o que está entre as marcas é retirado antes de qualquer outra
coisa.

```spx-good
rascunho /# não tenho a certeza #/ pronto  →  Rascunho pronto
```

Os comentários não se encaixam. O primeiro `#/` fecha o comentário, fosse o que fosse que viesse
antes, logo um comentário enrolado à volta de um texto que contenha `#/` acaba mais cedo do que
parece.

## O que o motor alisa no fim

A saída não é bem o texto que as construções produziram. No fim acontecem-lhe várias coisas; duas
encontra-as todos os dias.

A primeira letra de cada frase passa a maiúscula:

```spx-good
um. dois. três.  →  Um. Dois. Três.
```

É por isso que os exemplos desta ajuda respondem tantas vezes com maiúscula onde o modelo tem
minúscula. Um ponto depois de uma abreviatura que o motor conhece não acaba uma frase, e também
não acaba nada com a forma de `e.g.` ou `U.S.` — **em letras latinas**, o que é um limite a sério
e não uma cautela: a verificação de «isto é meio de palavra» é uma verificação ASCII.

```spx-good
Sr. os nossos preços são baixos  →  Sr. os nossos preços são baixos
```

```spx-good
etc. os nossos preços são baixos  →  etc. os nossos preços são baixos
```

Qualquer outra palavra acaba uma frase, por curta que seja: o comprimento não tem nada a ver com
isso:

```spx-good
Xyz. os nossos preços são baixos  →  Xyz. Os nossos preços são baixos
```

A lista que o motor conhece tem 46 entradas, **29 delas cirílicas**, e o outro documento percorre-a
sob **Um silêncio em todas as línguas**. Para o português o essencial está mais abaixo, nos
silêncios: a lista não foi pensada para o português.

A segunda coisa de todos os dias é que as séries de espaços se reduzem a um. É o que lhe permite
deixar uma possibilidade vazia sem contar os espaços à volta.

O resto de um fôlego: um espaço antes de `,;:!?.` é retirado e é inserido um depois; a saída
inteira é aparada nas pontas; a maiúscula chega também depois de uma mudança de linha e depois de
uma etiqueta de bloco, e não só depois de um ponto; e os endereços com esquema, os endereços de
correio, os domínios nus e os números decimais estão protegidos e saem exactamente como foram
escritos.

Este último ponto traz o mesmo limite ASCII das abreviaturas acima. Um domínio nu está protegido se
for escrito em letras latinas; `сайт.рф` não está, e o retoque mete-lhe dentro um espaço e uma
maiúscula.

```spx-good
olá , mundo  →  Olá, mundo
```

```spx-good
um.dois  →  um.dois
```

## Silêncios

Cada caso abaixo compõe-se, produz algo diferente do que aparenta e não puxa **diagnóstico
nenhum**. Estão reunidos aqui porque mais nada na janela alguma vez os mencionará.

**As abreviaturas portuguesas não estão na lista do motor.** É o silêncio com que quem escreve em
português esbarra primeiro. Só estão protegidas as palavras que coincidem com a metade latina da
lista — `Sr.`, `Dr.`, `Prof.` e `etc.` acima —, ao passo que `Sra.` e `pág.` acabam uma frase e
põem em maiúscula a palavra seguinte:

```spx-good
pág. os nossos preços são baixos  →  Pág. Os nossos preços são baixos
```

`p. ex.`, com o seu espaço, atravessa o retoque sem dano, o que vale mais mostrar do que explicar:

```spx-good
p. ex. isto fica em minúscula  →  p. ex. isto fica em minúscula
```

Escrito junto, `p.ex.`, protege-se a si próprio pela regra dos vários pontos, mas a palavra
seguinte já não:

```spx-good
p.ex. isto fica em minúscula  →  p.ex. Isto fica em minúscula
```

E `n.º` sai partido, pelo mesmo motivo ASCII: o `º` não conta como letra para essa verificação, e
o retoque entra dentro da abreviatura:

```spx-good
n.º os nossos preços são baixos  →  N. º os nossos preços são baixos
```

**Um `#include` que não está sozinho na sua linha é texto comum.**

```spx-good
Antes. #include "intro"  →  Antes. #include "intro"
```

O mesmo vale para uma directiva com algo atrás e para `#include"intro"` sem espaço. A regra é da
família e não deste motor, e é ela que torna uma directiva reconhecível sem analisar a linha
inteira.

**Uma condição cujo nome começa por algarismo não é uma condição.** Torna-se uma escolha comum
entre `?1x?sim` e `não`:

```spx-good
{?1x?sim|não}  →  ?1x? Sim
```

**Um `<…>` à cabeça de um pedaço que não seja o primeiro não é separador** e imprime-se tal e
qual:

```spx-good
[vermelho|<e>verde]  →  <e>Verde vermelho
```

O bloco à cabeça do **primeiro** pedaço é que é o separador: é a escrita com que abre o capítulo
dos baralhares:

```spx-good
[<e>vermelho|verde]  →  Verde e vermelho
```

Em qualquer sítio depois de um `|` é texto comum, e um separador entre dois pedaços vai ao **fim**
do primeiro.

**Uma etiqueta nua no fim de um pedaço é tomada pelo separador desse par** e impressa como texto
seu:

```spx-good
[um<br>|dois]  →  Dois um
```

Sob esta semente os dois calharam na outra ordem, pelo que o separador não saiu de todo. Com um
terceiro pedaço há onde calhar, e ele aparece:

```spx-good
[vermelho|verde<br>|azul]  →  Verde br azul vermelho
```

O `<br>` fica entre `verde` e o que se lhe segue, ponha o baralhar esse par onde puser. Uma
etiqueta de fecho (`</b>`), uma que se fecha a si própria (`<br/>`), uma com atributos
(`<br class="x">`) e uma etiqueta a meio de um pedaço ficam todas intactas.

**Um comentário por fechar é texto comum**: não abre nada, e o `/#` é impresso:

```spx-good
antes /# o resto disto  →  Antes /# o resto disto
```

Mas continua a ser metade de um par. Se mais abaixo no documento aparecer um `#/`, os dois
encontram-se e tudo o que está entre eles vai-se — incluindo o que o autor tiver escrito pelo
meio:

```
{a /# ups|b} meio #/ cauda  →  {a cauda
```

A escolha acima perdeu a segunda alternativa e a chaveta de fecho, e nenhum diagnóstico o diz: é
isso que o texto SIGNIFICA, e não um erro que o motor consiga ver. Quando um `/#` é para valer, o
sítio seguro para ele é o valor de uma variável e não o corpo do modelo.

## Onde olhar a seguir

O outro documento, **O que lhe está a dizer o separador Diagnóstico**, tem um artigo por cada
linha que o painel pode mostrar: o que significa, o que a provoca e o que o motor faz ao modelo
enquanto ela lá está. Carregue em F1 com o cursor dentro de uma construção e a ajuda abre no
capítulo dessa construção **naquele documento**: uma chaveta em **Parênteses**, um `[…]` em
**Baralhares**, uma linha `#set` em **Definições**.
