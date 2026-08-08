# Le langage, construction par construction

Un gabarit est du texte ordinaire avec quelques endroits marqués dedans. Tout ce qui n'est pas
marqué ressort tel quel ; ce sont les marques qui permettent à un gabarit de produire beaucoup de
textes.

Il y en a six, et c'est tout le langage : un **choix** entre variantes, un **brassage** de
plusieurs morceaux, une **macro** que vous définissez une fois et employez par son nom, une
**condition**, un **compte** qui prend la bonne forme de mot, et une **inclusion** qui fait venir
un autre gabarit. Les commentaires sont une septième marque qui ne produit rien du tout.

> Chaque exemple ci-dessous passe par le moteur livré avec cette copie de Studio, à chaque
> construction du programme, et à droite se trouve exactement ce qu'il a renvoyé. Rien ici n'est
> retenu de mémoire ni deviné ; une réponse qui cesserait d'être vraie arrêterait la
> construction. La version du moteur est sous **Aide**, **À propos**.

L'autre document de cette aide, **Ce que vous dit l'onglet Diagnostic**, parle de ce qui va de
travers. Celui-ci parle de ce que font les constructions quand rien ne va de travers — y compris
les quelques endroits où un gabarit fait une chose surprenante et où rien ne le signale.

## Comment lire les exemples

La flèche `→` sépare le gabarit de ce que le moteur a renvoyé. `(vide)` veut dire qu'il n'a rien
imprimé du tout. Un texte après la sortie, détaché par trois espaces, est une remarque et non une
partie de la réponse.

Les conditions sont énoncées et non supposées, car sans elles la moitié des réponses ci-dessous
ne pourrait être reproduite :

```spx-fixture
locale: fr
seed: 7
empty: (vide)
include intro: Bienvenue chez {Acme|Globex}.
include shout: La %marque% est là.
```

`seed` fixe le tirage au sort. Un gabarit contenant un choix n'a pas de réponse unique ; un
exemple sans graine imprimerait donc autre chose à chaque passage et il n'y aurait rien à
vérifier. Dans la fenêtre, c'est la case **seed** au-dessus du volet de droite ; cochez-la et un
champ de nombre apparaît à côté, et l'aperçu cesse de bouger pendant que vous travaillez.

`locale` décide des formes de nombre, et c'est le sélecteur au-dessus du volet de droite, non la
langue de l'interface. Le français et l'anglais demandent deux formes ; le russe, l'ukrainien, le
biélorusse, le serbe, le croate et le bosnien en demandent trois.

## Choix

Des accolades avec des `|` entre : le moteur en prend **un**.

```spx-good
Une {petite|grande} salle.  →  Une petite salle.
```

Le tirage est aléatoire ; le même gabarit donne donc `Une grande salle.` à un autre passage. Le
choix lui-même laisse tranquille le texte autour — même si la finition décrite vers la fin de ce
document l'atteint quand même.

### Imbrication

Un choix peut en contenir un autre, à n'importe quelle profondeur.

```spx-good
Acme {Pro {Plus|Max}|Lite}  →  Acme Pro Plus
```

Le choix intérieur n'est fait que si l'extérieur prend la branche où il se trouve : si `Lite`
sort, `Plus|Max` n'est jamais consulté — et, c'est mesurable, on ne lui demande même pas un
nombre au hasard.

### Une possibilité vide

Une possibilité peut être vide. C'est la manière ordinaire de faire apparaître quelque chose
seulement de temps en temps.

```spx-good
Une {|très }grande salle.  →  Une grande salle.
```

Écrire l'espace dans la possibilité, `{|très }` plutôt que `{|très} `, est une habitude et non une
obligation : la finition ramène de toute façon le double espace à un seul.

## Brassages

Les crochets prennent plusieurs morceaux, choisissent combien, les mettent dans un ordre aléatoire
et les assemblent.

```spx-good
[rouge|vert|bleu]  →  Vert bleu rouge
```

Laissé à lui-même, il les prend tous et les joint par une espace. Tout le reste au sujet d'un
brassage se règle dans un bloc `<…>` juste après le crochet ouvrant.

### Le séparateur

```spx-good
[<, >rouge|vert|bleu]  →  Vert, bleu, rouge
```

Un bloc `<…>` est lui-même le séparateur, sauf s'il **nomme un réglage** : l'un de `sep`,
`lastsep`, `minsize` ou `maxsize`, comme mot à part entière, avec un `=` derrière. Tout le reste à
cette place est un séparateur, si ressemblant à un réglage soit-il — une clé sans son `=` :

```spx-good
[<maxsize 2>rouge|vert|bleu]  →  Vertmaxsize 2bleumaxsize 2rouge
```

ou une clé à laquelle quelque chose est collé devant :

```
[<xmaxsize=1>rouge|vert|bleu]  →  Vertxmaxsize=1bleuxmaxsize=1rouge
```

Le second mérite un second regard : le panneau appelle **bel et bien** `xmaxsize` une clé
inconnue, et le moteur imprime malgré tout le bloc entier entre les morceaux. Le diagnostic et la
sortie répondent à des questions différentes.

Écrivez les réglages en toutes lettres quand vous voulez deux séparateurs différents :

```spx-good
[<sep=", ";lastsep=" et ">rouge|vert|bleu]  →  Vert, bleu et rouge
```

`sep` va entre les morceaux et `lastsep` avant le dernier.

### Combien

```spx-good
[<minsize=2;maxsize=2>rouge|vert|bleu]  →  Vert bleu
```

`minsize` est le plancher et `maxsize` le plafond ; le nombre entre les deux est aléatoire comme
l'ordre. Des valeurs égales en prennent exactement autant. **Sans les deux, tous — mais avec
`maxsize` seul, le plancher est à un**, ce qui surprend :

```spx-good
[<maxsize=3>a|b|c]  →  C
```

Trois morceaux, un plafond de trois, et un seul est sorti. Écrivez aussi `minsize` quand vous
voulez dire « tous, trois au plus ». Un `maxsize` supérieur au nombre de morceaux est
discrètement ramené à celui-ci. Un `minsize` supérieur au `maxsize` est accepté sans un mot, et
c'est le plancher qui gagne — le plafond est relevé jusqu'à lui et non l'inverse :

```spx-good
[<minsize=3;maxsize=1>rouge|vert|bleu]  →  Vert bleu rouge
```

### Un séparateur entre deux morceaux

Un `<…>` écrit **entre** deux morceaux est le séparateur de cette paire.

```spx-good
[rouge|vert<et>|bleu]  →  Vert et bleu rouge
```

Il appartient au morceau **qui suit** et voyage avec lui à travers le brassage ; il surgit donc là
où ce morceau tombe et non à une place fixe de la sortie. Un `<…>` après le **dernier** morceau
n'est pas du tout un séparateur et s'imprime comme du texte :

```spx-good
[rouge|vert|bleu<et>]  →  Vert bleu<et> rouge
```

## Macros

`#set` donne un nom à un morceau de texte. Le nom s'emploie comme `%nom%`, et la directive doit
être la première chose de sa ligne — les espaces et tabulations de tête sont permis, rien d'autre.

```spx-good
#set %ville% = Lyon
Vol vers %ville%.  →  Vol vers Lyon.
```

Les noms se composent de lettres latines, de chiffres et de `_`. Un nom dans un autre alphabet
n'est pas un nom, ce dont l'autre document parle sous `set.malformed`. Les accents n'ont donc pas
leur place dans un nom — dans une valeur, si.

### `#set` retire, `#def` ne tire qu'une fois

C'est toute la différence entre les deux, et elle ne se voit que si la valeur contient un choix.

```spx-good
#set %choix% = {A|B}
%choix% %choix% %choix%  →  A A B
```

```spx-good
#def %choix% = {A|B}
%choix% %choix% %choix%  →  A A A
```

Les deux exemples ont tourné sous la même graine. `#set` garde le gabarit et le tire à chaque
emploi ; `#def` tire une fois et garde la réponse. Prenez `#def` pour ce qui doit s'accorder avec
soi-même — une marque, une ville, un nom, un compte — et `#set` pour la variété.

Une seule graine ne permet pas de les distinguer : il existe des graines où `#set` tire par hasard
trois fois la même possibilité et où les deux se ressemblent. Bon à savoir avant de conclure d'un
seul aperçu qu'une définition ne marche pas.

## Conditions

`{?nom?alors|sinon}` demande si une macro a une valeur.

```spx-good
#set %n% = 5
{?n?nous avons %n%|rien encore}  →  Nous avons 5
```

La moitié `sinon` peut manquer — `{?nom?alors}` n'imprime rien quand la réponse est non. Un `!`
retourne la question :

```spx-good
#set %vip% = 1
{?!vip?inconnu|ami}  →  Ami
```

Avoir une valeur, c'est avoir **au moins un caractère qui n'est pas une espace**. Une macro mise à
rien, ou à des espaces seulement, compte comme sans valeur.

Le nom d'une condition doit **commencer** par une lettre ou `_`, ce qui est plus strict que pour
une macro — et le chapitre des silences dit ce que devient un nom commençant par un chiffre.

## Compte

`{plural %n%: …}` prend la forme de mot qui va avec un nombre.

```spx-good
#def %n% = 1
%n% {plural %n%: fichier|fichiers}  →  1 fichier
```

```spx-good
#def %n% = 5
%n% {plural %n%: fichier|fichiers}  →  5 fichiers
```

Le compte est ici un `#def` et non un `#set`, à dessein, et la règle mérite d'être retenue :
**faites du compte un chiffre simple ou un `#def`, jamais un `#set`.** Ce qui parvient à la place
du compte depuis un `#set`, c'est le TEXTE gardé, `{5|5}` et non `5` — pas un nombre, donc, si
bien que la construction entière ne produit rien et que le panneau dit `plural.count-macro`. Le
compte et la forme ne peuvent se contredire : c'est le mot qui disparaît.

```
#set %n% = {5|5}
%n% {plural %n%: fichier|fichiers}  →  5
```

Le nombre de formes est décidé par la locale et non par vous : sous `fr` il y en a deux, sous `ru`
trois. Le mauvais nombre est une erreur que le panneau signale (`plural.arity`), et le moteur
réimprime alors la construction entière, accolades remplacées par de larges `｛｝`, pour qu'on ne
la prenne pas pour de la sortie.

## Extraits

`#include "nom"` met un autre gabarit à cet endroit, et la directive doit être la première chose
de sa ligne — là encore, les espaces et tabulations de tête sont permis.

```spx-good
#include "intro"  →  Bienvenue chez Acme.
```

L'extrait est rendu comme son propre gabarit ; un choix qui s'y trouve est donc refait :
`intro` contient `{Acme|Globex}` et répond par l'un ou l'autre.

Le nom est comparé **exactement**. `Intro` et `intro` sont deux extraits différents, et sous
Windows c'est facile à manquer parce que le système de fichiers s'en moque. Une cible absente se
rend comme rien et le panneau dit `include.unknown-target` ; une cible qui ne diffère que par la
casse reçoit une note de Studio nommant celle que vous vouliez sans doute.

### Un extrait ne voit pas vos macros

Il est rendu comme son propre gabarit : il a les valeurs de la session, mais pas les `#set` ni les
`#def` du document qui l'a fait venir.

```
#set %marque% = Acme
#include "shout"  →  La %marque% est là.
```

`shout` vaut `La %marque% est là.`, et le nom doit être défini dans l'extrait lui-même. Ce n'est
pas un silence — le panneau dit bel et bien `variable.undefined` — mais il le dit contre
**`shout`**, à la ligne 1 de ce fichier, et aucun soulignement n'apparaît dans le document que
vous regardez, parce que la position appartient à un autre tampon. Lisez la colonne **Fichier**
quand un avertissement semble porter sur une ligne que vous n'avez pas écrite.

## Remarques

`/# … #/` est un commentaire : tout ce qui se trouve entre les marques est retiré avant quoi que
ce soit d'autre.

```spx-good
brouillon /# pas sûr de ça #/ prêt  →  Brouillon prêt
```

Les commentaires ne s'imbriquent pas. Le premier `#/` ferme le commentaire, quoi qu'il y ait eu
avant ; un commentaire enroulé autour d'un texte contenant lui-même `#/` finit donc plus tôt qu'il
n'en a l'air.

## Ce que le moteur lisse à la fin

La sortie n'est pas tout à fait le texte que les constructions ont produit. Plusieurs choses lui
arrivent à la fin ; deux vous croisent tous les jours.

La première lettre de chaque phrase est mise en majuscule :

```spx-good
un. deux. trois.  →  Un. Deux. Trois.
```

C'est pourquoi les exemples de cette aide répondent si souvent par une majuscule là où le gabarit
a une minuscule. Un point après une abréviation que le moteur connaît ne termine pas une phrase,
pas plus que ce qui a la forme de `e.g.` ou `U.S.` — **en lettres latines**, ce qui est une vraie
limite et non une précaution : le contrôle « est-on au milieu d'un mot » est un contrôle ASCII.

```spx-good
etc. nos prix sont bas  →  etc. nos prix sont bas
```

```spx-good
Dr. nos prix sont bas  →  Dr. nos prix sont bas
```

Tout autre mot termine une phrase, si court soit-il — la longueur n'y est pour rien :

```spx-good
Xyz. nos prix sont bas  →  Xyz. Nos prix sont bas
```

La liste que le moteur connaît compte 46 entrées, **29 d'entre elles cyrilliques**, et l'autre
document la parcourt sous **Un silence dans toutes les langues**. Pour le français, l'essentiel se
trouve plus bas dans les silences : la liste n'est pas réglée sur le français.

La seconde chose quotidienne est que les suites d'espaces se ramènent à une. C'est ce qui vous
laisse une possibilité vide sans compter les espaces autour.

Le reste d'un souffle : une espace devant `,;:!?.` est retirée et une est insérée derrière ;
la sortie entière est rognée ; la majuscule arrive aussi après un saut de ligne et après une
balise de bloc, pas seulement après un point ; et les adresses avec schéma, les adresses
électroniques, les domaines nus et les nombres décimaux sont protégés et ressortent exactement
tels qu'ils ont été tapés.

Ce dernier point porte la même limite ASCII que les abréviations plus haut. Un domaine nu est
protégé s'il est écrit en lettres latines ; `сайт.рф` ne l'est pas, et la finition y glisse une
espace et une majuscule.

```spx-good
bonjour , monde  →  Bonjour, monde
```

```spx-good
un.deux  →  un.deux
```

## Silences

Chaque cas ci-dessous se rend, produit autre chose que ce dont il a l'air et n'entraîne **aucun
diagnostic**. Ils sont réunis ici parce que rien d'autre dans la fenêtre ne les mentionnera jamais.

**Les abréviations françaises ne sont pas dans la liste du moteur.** C'est le silence que les
auteurs francophones rencontrent en premier. Sont protégés seulement les mots qui coïncident avec
la moitié latine de la liste — `Dr.`, `Prof.`, `etc.` plus haut, et `no.`, qui y est aussi —,
tandis que `cf.`, `env.`, `M.` et `av.` terminent une phrase et mettent le mot suivant en
majuscule :

```spx-good
cf. nos prix sont bas  →  Cf. Nos prix sont bas
```

`p. ex.` traverse la finition sans dommage, ce qui vaut d'être montré plutôt qu'expliqué :

```spx-good
p. ex. cela reste en minuscule  →  p. ex. cela reste en minuscule
```

`c.-à-d.` en revanche est cassé, et pour la raison ASCII donnée plus haut : les traits d'union
entourent un `à` qui n'est pas une lettre latine pour ce contrôle, et la finition entre dans
l'abréviation :

```spx-good
c.-à-d. cela reste en minuscule  →  C. -à-d. Cela reste en minuscule
```

**Un `#include` qui n'est pas seul sur sa ligne est du texte ordinaire.**

```spx-good
Avant. #include "intro"  →  Avant. #include "intro"
```

Il en va de même d'une directive suivie de quoi que ce soit, et de `#include"intro"` sans espace.
La règle est celle de la famille et non celle de ce moteur, et c'est elle qui rend une directive
reconnaissable sans analyser la ligne entière.

**Une condition dont le nom commence par un chiffre n'est pas une condition.** Elle devient un
choix ordinaire entre `?1x?oui` et `non` :

```spx-good
{?1x?oui|non}  →  ?1x? Oui
```

**Un `<…>` en tête d'un morceau qui n'est pas le premier n'est pas un séparateur** et s'imprime
tel quel :

```spx-good
[rouge|<et>vert]  →  <et>Vert rouge
```

Le bloc en tête du **premier** morceau est le séparateur — c'est l'écriture par laquelle s'ouvre
le chapitre des brassages :

```spx-good
[<et>rouge|vert]  →  Vert et rouge
```

N'importe où après un `|` c'est du texte ordinaire, et un séparateur entre deux morceaux se met à
la **fin** du premier.

**Une balise nue à la fin d'un morceau est prise pour le séparateur de cette paire** et imprimée
comme son propre texte :

```spx-good
[un<br>|deux]  →  Deux un
```

Sous cette graine les deux sont tombés dans l'autre ordre, si bien que le séparateur n'est pas
sorti du tout. Avec un troisième morceau il a où tomber, et il apparaît :

```spx-good
[rouge|vert<br>|bleu]  →  Vert br bleu rouge
```

Le `<br>` se tient entre `vert` et ce qui le suit, où que le brassage mette cette paire. Une
balise fermante (`</b>`), une auto-fermante (`<br/>`), une portant des attributs
(`<br class="x">`) et une balise au milieu d'un morceau sont toutes laissées tranquilles.

**Un commentaire non fermé est du texte ordinaire** — il n'ouvre rien, et le `/#` est imprimé :

```spx-good
avant /# le reste de tout cela  →  Avant /# le reste de tout cela
```

Il reste cependant la moitié d'une paire. Si un `#/` apparaît plus bas dans le document, les deux
se trouvent et tout ce qui est entre eux s'en va — y compris ce que l'auteur a écrit entre-temps :

```
{a /# oups|b} milieu #/ queue  →  {a queue
```

Le choix ci-dessus a perdu sa seconde variante et son accolade fermante, et aucun diagnostic ne le
dit : c'est ce que le texte SIGNIFIE, et non une faute que le moteur puisse voir. Quand un `/#`
est voulu littéralement, sa place sûre est la valeur d'une variable et non le corps du gabarit.

## Où regarder ensuite

L'autre document, **Ce que vous dit l'onglet Diagnostic**, a un article par ligne que le panneau
peut montrer — ce qu'elle signifie, ce qui la provoque et ce que le moteur fait du gabarit tant
qu'elle est là. Appuyez sur F1 avec le curseur dans une construction et l'aide s'ouvre au chapitre
de cette construction **dans ce document-là** : une accolade sur **Crochets**, un `[…]` sur
**Brassages**, une ligne `#set` sur **Définitions**.
