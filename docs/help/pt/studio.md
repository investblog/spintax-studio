# Spintax Studio

Este programa é um editor de modelos. Um modelo é texto comum com alguns pontos marcados dentro, e
um só modelo pode produzir muitíssimos textos diferentes — é esse todo o sentido de escrever um em
vez de escrever os textos.

A janela são duas metades. À esquerda o seu modelo, aquilo que edita. À direita um dos textos que
dele saem, redesenhado enquanto escreve. No meio não há nada a premir: o que vê à direita é o que
o motor devolve para o que está à esquerda nesse instante.

```spx-fixture
locale: pt
seed: 7
empty: (vazio)
```

O motor vai dentro deste programa e é o membro Pascal de uma família: a mesma linguagem é também
publicada para JavaScript, PHP e Python. Os quatro são programas independentes sujeitos a um mesmo
conjunto de casos de teste, de modo que aquilo que um modelo SIGNIFICA é igual em todos: as
construções, o veredicto sobre a validade, os retoques finais. Um modelo que esta janela chama
válido também o é lá.

O que não se promete, e a diferença conta quando se compara: o sorteio. Uma semente torna a
pré-visualização repetível AQUI — a mesma semente e o mesmo modelo dão amanhã o mesmo texto —, mas
a mesma semente no motor JavaScript pode tirar outra alternativa. As sementes servem para
reproduzir o seu próprio trabalho, não para bater certo com outro motor.

Tudo aqui funciona sem ligação de rede. Não há conta, não há sessão para iniciar e não há nada
para activar: abra o programa e já está a correr.

## As duas metades

Escreve-se à esquerda. A metade direita redesenha-se após uma pausa curta, para que a
pré-visualização acompanhe uma frase e não cada letra.

Um modelo com uma escolha lá dentro não tem uma única resposta, e a pré-visualização mostra uma
delas:

```spx-good
{Olá|Bom dia} a todos.  →  Olá a todos.
```

**Outra**, por cima da metade direita, traz outra. Se quiser sempre a mesma — enquanto
compara duas alterações, por exemplo — marque **seed**, e a pré-visualização fica quieta até a
desmarcar ou mudar o número.

O seletor sobre a metade direita oferece **Página** e **Origem**. Os modelos costumam ser HTML, e as duas
perguntas «que aspecto tem» e «que marcação saiu» não se respondem uma à outra: uma etiqueta
partida dá uma disposição um pouco torta que o olho salta, ao passo que prosa cheia de etiquetas
não se lê como prosa. O interruptor por cima da metade muda o que está a ver.

Seleccione uma parte do modelo e só essa parte é composta — no âmbito do documento inteiro, de
modo que um excerto que use uma variável definida em cima sai como sairá no seu lugar.

## Localizar e substituir

**Ctrl+F** abre um campo de pesquisa no cabeçalho. O contador ao lado diz quantas vezes o
texto ocorre e em que ocorrência está; **Enter** avança, **Shift+Enter** recua, F3 funciona
diretamente do documento. As maiúsculas só contam com a caixa marcada junto ao campo — e a
dobragem é a do motor, pelo que uma letra cirílica ou acentuada coincide com a sua outra
caixa exatamente onde a pré-visualização as tem por uma só letra.

**Ctrl+H** — ou o item de menu **Substituir…** — dá à barra uma segunda linha: a
substituição e dois botões. **Substituir** muda a ocorrência em que está e passa à seguinte;
enquanto nada estiver encontrado, a primeira pressão apenas procura. **Substituir tudo**
percorre o documento inteiro de uma vez, e a barra de estado diz quantos lugares mudaram; um
único Ctrl+Z desfaz o percurso todo.

A substituição é literal. Pode estar vazia — isso apaga — e pode conter o texto procurado
sem pôr o percurso em círculo: os lugares decidem-se antes, sobre o texto tal como estava.
Quando as ocorrências se sobrepõem, o contador conta cada uma que um passo pode visitar, mas
o percurso só muda as que não partilham letras — «substituídos» pode assim dizer
honestamente um número menor.

Um documento substituído passa pelo mesmo motor que o texto escrito: a pré-visualização
redesenha-se e o diagnóstico responde sobre o que lá está agora.

## Inserir as marcas

Tudo o que põe no documento as marcas da própria linguagem está no menu **Inserir**.

Os três comandos de envolvimento tomam a seleção como está: **Envolver em {…}** faz dela uma escolha,
**Envolver em […]** um baralhar, **Envolver em /#…#/** (Ctrl+/) um comentário. O envolvimento em comentário recusa quando um `#/` dentro ou à volta da seleção — ou um
comentário já aberto nesse ponto — terminaria um comentário cedo demais: o primeiro fecho ganha
onde quer que esteja, texto cairia fora; a barra de estado di-lo, porque o motor se cala. Sem seleção, Ctrl+/ insere o par e deixa o cursor lá dentro.

As construções abaixo caem exatamente como o menu as lê. **#set %nome% = valor**, **#def %nome% = {a|b}** e **#include "nome"** tomam uma
linha própria — uma diretiva só conta quando abre a sua linha, o texto antes do cursor fica
por isso acima e o de depois desce — e o nome sai selecionado, pronto a ser escrito por
cima. Mantenha os nomes em letras latinas: um nome noutro alfabeto, silenciosamente, não é
um nome. O alvo de `#include` é a exceção — é comparado com os nomes dos seus fragmentos
exatamente como está escrito.

**{?nome?então|senão}** vive dentro da linha. Com uma seleção, o texto selecionado torna-se a metade «então» —
uma forma de tornar condicional o que já está escrito; sem seleção entra a forma inteira.
Uma seleção com um `|` solto, um parêntese por fechar ou um comentário aberto é recusada: o
envolvimento mudaria o que ela diz em vez de a emoldurar.

O último item põe no documento o exemplo aberto na ajuda — o botão do próprio painel de
ajuda, tornado alcançável pelo teclado.

## Os painéis de baixo

A barra de ferramentas ao lado abre quatro painéis, um de cada vez.

**Diagnóstico** enumera o que o motor achou errado, cada coisa com a linha e a coluna em que
começa. Um clique numa linha põe lá o cursor. É o mesmo veredicto que o motor dá em todo o lado, e
não uma segunda opinião do editor: por isso um modelo que este painel chama válido é aceite pelos
outros motores.

**Variáveis** mostra os nomes que o seu documento define e os que apenas usa. Um nome que usa e
que nada define pode preenchê-lo aqui para a sessão: escreva um valor ao lado e a
pré-visualização apanha-o. Marque **como texto** quando o valor for texto que se significa a si
mesmo e não um pequeno modelo por sua vez.

**Variantes** gera muitos textos de uma vez. Diga quantos, gere-os e leia-os na lista antes de
exportar. Os quase duplicados podem ser descartados à medida que nascem, e uma semente torna todo
o lote repetível: a mesma semente e o mesmo modelo dão amanhã as mesmas variantes.

Ao lado desses campos o painel diz quantas variantes o modelo pode dar ao todo: `{a|b} e {c|d}` dá
quatro. Esse número avisa-o de que um modelo é pobre antes de gerar cinquenta e dar por isso a
lê-las.

É uma conta exacta só enquanto cada escolha ficar ao acaso. Uma condição, uma forma de número ou
um `#include` cujo alvo o conjunto não tenha são decididos por outra coisa — um valor que o
utilizador forneça, um número, um excerto que talvez chegue —, e então o painel diz **pelo
menos**. É a palavra honesta: fornecer um valor só pode acrescentar textos, nunca tirá-los. Um
número grande demais para se ler pára num bilião e diz **pelo menos** pela mesma razão.

Uma variante é um modelo preenchido — uma escolha feita em cada construção — e isso não é o mesmo
que um texto que se leia de outra maneira. `{a|a}` são duas variantes e um texto, e é de
propósito: as duas possibilidades podem deixar de coincidir depois de uma só alteração, e juntá-las
obrigaria a gerar antes todas as combinações, que é justamente o trabalho que este número lhe
poupa. Um `#def` conta da mesma forma: o motor tira-o uma vez por composição, use ou não o ramo
que seguiu.

A exportação escreve-as de três maneiras: como livro XLSX, como texto simples com uma variante por
linha, ou como um ficheiro por variante numa pasta à sua escolha.

**Rascunho de IA** é por onde um modelo começa quando prefere não escrever cada variante à mão.
Diga no resumo o que quer, enumere as variáveis que o modelo pode usar e carregue em **Copiar o pedido**.
A aplicação não fala com nenhum modelo nem guarda chaves: escreve o pedido para que o leve àquele
que já utiliza. Traga a resposta e carregue em **Inserir no documento** — o motor desta janela diz então o
que lhe parece, no painel de diagnósticos, tal como faz com tudo o que escreve. Se houver erros,
**Copiar o pedido de correção** constrói um segundo pedido: leva o documento inteiro com as linhas numeradas e nomeia os
pontos exatos de que o motor se queixou. A resposta é o documento corrigido por inteiro,
portanto traga-a e carregue em **Substituir o documento**: **Inserir no documento** deixaria o
estragado onde está e poria uma cópia corrigida ao lado.

A coluna do caso é a parte que vale a pena preencher. Uma variável é inserida tal como está, nada
a declina: numa língua com casos a frase tem de ser construída à volta da forma que o valor já
tem, e um modelo só escolhe bem se lhe disserem que forma tem cada nome. Do nome não se deduz:
num conjunto de modelos real as formas instrumentais estavam numa variável cujo nome dizia
acusativo.

## O editor de grupos

Ponha o cursor dentro de um `{a|b|c}` e abra o editor de grupos a partir da barra de ferramentas.
Enumera as alternativas em linhas: altere-as, acrescente uma, tire outra, e o documento é reescrito
em conformidade.

Recusa alterações que mudariam aquilo que o grupo SIGNIFICA em vez do que diz: um `|` escrito
dentro de uma alternativa faria de uma duas, e um `}` fecharia o grupo cedo demais. Quando recusa,
di-lo e deixa o documento em paz.

## Definições

Estão no menu Ver, e todas são lembradas de uma sessão para outra: o idioma da interface e se
segue o modelo, de que lado fica a barra de ferramentas, o tema, o tipo de letra do editor e o seu
tamanho, se a pré-visualização mostra a página ou o código, o interruptor da importação GSA, que
painel está aberto e as larguras dos painéis que se abrem de lado.

A interface fala catorze idiomas, escolhidos nesse mesmo menu. Isso é coisa distinta do idioma do
seu modelo, que é o que decide as formas de número e se define por cima da metade direita.

## Importar um modelo GSA

Esta parte está desligada até a ligar, em **Ver**, **Importação GSA**, porque a maioria de quem
escreve modelos nunca usou o GSA Search Engine Ranker. Ligada, **Ficheiro**, **Importar modelo
GSA…** lê um modelo SER e converte-o para esta linguagem.

A conversão é cuidadosa de uma maneira precisa. Aquilo que não consegue exprimir com fidelidade
recusa e diz-lho, em vez de o transformar em silêncio em algo que se compõe. As construções que
seriam mal lidas se ficassem no texto — parênteses BBCode, um `#` dentro de uma ligação, uma macro
`#file[...]` — são retiradas para variáveis, e o resumo diz quantas.

Duas coisas a saber sobre o resultado:

- **Os valores retirados são valores de sessão.** Aparecem no painel Variáveis e não são gravados
  com o documento. Grave o modelo convertido, abra-o amanhã e verá `%…%` onde estava o texto
  retirado. Do ficheiro importado não se perde nada — esse fica intacto —, mas o documento
  convertido não se basta a si próprio.
- **É composto sem a passagem de retoque.** Qualquer outro documento aqui recebe os retoques
  descritos no guia da linguagem; um modelo convertido não, porque não é texto nosso para alisar.
  É de outra pessoa, costuma ir a caminho de volta para o GSA, e tem de sobreviver caractere a
  caractere.

O documento importado está sem título e por gravar, como um novo. O ficheiro que escolheu fica
exactamente como estava.
