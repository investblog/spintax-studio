# Ce que vous dit l'onglet Diagnostic

Chaque ligne de cet onglet est un verdict du **moteur**, et le même verdict que vous donneraient
les implémentations JavaScript, PHP ou Python — quatre moteurs indépendants tenus à un même
corpus. Ce n'est pas l'avis de Studio sur votre gabarit. Si le moteur appelle ici quelque chose une
erreur, tous les autres moteurs de la famille l'appellent aussi une erreur, et votre gabarit se
comportera sur votre serveur comme dans cette fenêtre.

| ce qui est écrit | qui le dit | ce que cela veut dire |
|---|---|---|
| **erreur** | le moteur | le gabarit ne fera pas ce dont il a l'air |
| **avertissement** | le moteur | il se rend, mais sans doute pas comme vous vouliez |
| **note Studio** | Studio | le moteur n'a rien dit, et cela mérite quand même d'être dit : une inclusion en cercle, une cible dont la casse diffère, un caractère de commande |

La colonne **Où** donne une ligne et une colonne. Un clic sur la ligne y place le curseur.

> Chaque exemple ci-dessous passe par le moteur livré avec cette copie de Studio, à chaque
> construction du programme, et à droite se trouve exactement ce qu'il a renvoyé. Rien ici n'est
> retenu de mémoire ni deviné ; une réponse qui cesserait d'être vraie arrêterait la
> construction. La version du moteur est sous **Aide**, **À propos**.

## Comment lire les exemples

La flèche `→` sépare le gabarit de ce que le moteur a renvoyé. `⏎` est un saut de ligne dans une
sortie, `(vide)` veut dire qu'il n'a rien imprimé du tout, et `…` marque une sortie trop longue
pour être montrée en entier. Un texte après la sortie, détaché par trois espaces, est une remarque
et non une partie de la réponse.

Les conditions dans lesquelles les exemples ont tourné sont ici plutôt que cachées dans les
tests — sans elles certaines réponses ne pourraient être reproduites. Le jeu de gabarits compte le
plus : sinon
`#include "frag"` → `Fragment` reposerait sur quelque chose que ce document ne dit jamais.

```spx-fixture
locale: fr
seed: 7
empty: (vide)
include frag: Fragment
include loop: #include "loop"
include Intro: Introduction
```

`seed` fixe le tirage au sort : sans lui, un choix ou un brassage répondrait autrement à chaque
fois et il n'y aurait rien à vérifier.

**La locale est ici `fr`, et elle décide de deux choses :** combien de formes de nombre le moteur
attend, et quelle forme va avec quel nombre. Le français et l'anglais en demandent deux. Le russe,
l'ukrainien, le biélorusse, le serbe, le croate et le bosnien en demandent trois. La locale vient
du sélecteur au-dessus du volet de droite, non de la langue de l'interface.

---

## Crochets

**Placez le curseur sur un crochet et la construction se montre entière :** où elle commence, où
elle finit, et **chacun de ses séparateurs**. Les groupes imbriqués ne s'allument pas avec elle —
ils ont leurs propres séparateurs, qui viennent quand le curseur se pose sur leur crochet. C'est
le moyen le plus rapide de voir où finit ce que vous modifiez, surtout dans une longue ligne où
la `}` est partie deux écrans vers la droite.

Un séparateur n'est pas seulement `|`. Dans un brassage, `[a<br>|b]` en a deux : le moteur lit
`<br>` comme un séparateur placé **avant le suivant**, et la mise en évidence le montre avec les
autres, parce qu'il fait partie de la construction.

### `bracket.unclosed` — un crochet est ouvert et jamais fermé

```
un prix {bon|cher  →  Un prix {bon|cher
```

Le moteur ne devine pas où vous vouliez fermer. Le texte reste tel quel, accolade comprise, et le
choix n'a jamais lieu.

### `bracket.mismatched` — fermé par un crochet d'une autre sorte

```
un prix {bon|cher]  →  Un prix {bon|cher]
```

`{` attend `}` et `[` attend `]`. Un brassage fermé par une accolade n'est pas un brassage.

### `bracket.unexpected-closing` — un crochet fermant sans rien d'ouvert

```
un prix bon} et tout  →  Un prix bon} et tout
```

Il reste là comme du texte. C'est le plus souvent un crochet resté d'une modification.

---

## Définitions

### `set.malformed` — cette ligne `#set` ne suit pas la règle

```
#set ville = Lyon
dans %ville%  →  #set ville = Lyon ⏎ Dans %ville%
```

**Le nom va entre signes de pourcentage :** `#set %ville% = Lyon`. C'est la première faute la plus
courante, et elle met deux lignes d'un coup dans le panneau — la ligne malformée elle-même et
« cette variable n'est définie nulle part », parce qu'aucune définition n'a eu lieu et que
`%ville%` n'appartient à personne.

Regardez la sortie : la directive ratée est restée dans le texte **telle qu'écrite**. Le moteur ne
l'a pas lue comme une directive ; c'est donc une ligne ordinaire et elle va dans le résultat.

### `def.malformed` — cette ligne `#def` ne suit pas la règle

```
#def pages = {1|3}
%pages%  →  #def pages = 1 ⏎ %pages%
```

La même règle et le même prix. `#def` ne diffère pas de `#set` par l'orthographe mais par le
**moment** où la valeur est déployée : `#set` la déploie à chaque mention, `#def` une fois par
rendu. Une faute d'écriture vous coûte les deux.

Et regardez de près : le `{1|3}` de la directive ratée **a tiré une possibilité**. La ligne est
devenue du texte ordinaire — et le texte ordinaire est rendu comme du texte ordinaire, accolades
comprises. Une ligne malformée n'est pas éteinte ; elle cesse seulement d'être une directive.

### `definition.duplicate-name` — ce nom est déjà défini plus haut

```
#set %x% = premier
#set %x% = second
%x%  →  Second
```

Cela fonctionne — la **dernière** définition gagne — mais le moteur appelle cela une erreur : un
document où un nom est posé deux fois se lit de manière ambiguë, et dans un mois vous ne saurez
plus laquelle des deux lignes est la vivante. L'erreur montre la **seconde** définition ; la
première est plus haut.

### `def.include-in-value` — `#include` dans la valeur d'une définition

```
#def %x% = #include "frag"
%x%  →  Fragment
```

Une inclusion dans une valeur se déploie à un autre moment que vous ne l'attendriez, et la famille
l'interdit. Mettez le `#include` sur une ligne à lui.

---

## Variables

### `variable.undefined` — cette variable n'est définie nulle part

```
bonjour, %nom%  →  Bonjour, %nom%
```

Un avertissement et non une erreur : le moteur imprime le nom tel quel. C'est voulu — la valeur
peut venir de dehors, de l'hôte. Dans Studio vous fournissez ces valeurs dans l'onglet Variables,
sous **Valeurs de session**.

**La valeur d'une définition peut se modifier dans le panneau.** Placez-vous sur la colonne Valeur
dans la partie haute et appuyez sur **F2** (ou commencez simplement à taper) ; **Entrée**
applique, **Échap** abandonne. La modification va **dans le document**, en une seule étape
d'annulation : `Ctrl+Z` la remet.

Le nom et la sorte (`#set` ou `#def`) ne se modifient pas — une décision et non un coin inachevé.
Renommer depuis une cellule casse toutes les mentions de la variable dans le document, et
supprimer la ligne emporterait avec elle le commentaire et l'indentation. Les deux appartiennent
au texte, où vous voyez ce que vous faites.

C'est exactement la valeur qui change. L'indentation, les espaces en trop, la casse du nom et un
commentaire en fin de ligne restent tels qu'ils étaient —
`   #set  %Marque%   =   Acme   /# reste #/` revient d'une modification en ne différant que par
`Acme`. Le fichier est dans git, et reformater une ligne y apparaîtrait comme votre modification.

**Un refus veut dire que le moteur lirait la ligne autrement.** La modification n'est pas
appliquée en silence : le moteur relit le résultat, et s'il ne dit pas ce qui était demandé, le
document est laissé tranquille et la barre d'état le dit. Trois causes réelles : un `/#` dans la
valeur ouvre un commentaire qui mange le reste du fichier, un saut de ligne termine la directive
trop tôt, et un commentaire **dans** la directive rend la ligne non modifiable par morceaux —
celle-là, modifiez-la dans le texte.

**Deux gestes sur le nom d'une variable.** Le nom dans le panneau est un lien et non une
étiquette :

- **un clic sur le nom** amène le curseur au premier endroit où le document emploie cette
  variable, et la ligne s'allume un instant. Le même mot dans un commentaire ou comme cible d'un
  `#include` ne compte **pas** — le panneau vous emmène là où la variable travaille vraiment.
- **Ctrl+clic** écrit une définition dans le document et ouvre dessus l'éditeur de groupe. La
  valeur que vous avez déjà tapée y entre comme première possibilité :

```
#set %marque% = {Vulkan}
casino %marque%  →  Casino Vulkan
```

La différence entre les deux, c'est ce qui survit à la fermeture de la fenêtre. Une valeur de
session, non : elle n'est pas dans le fichier, pas dans git, et aucun autre moteur de la famille
ne la voit. Une définition, oui, et seule une définition fait taire cet avertissement pour de bon.
Un `Ctrl+Z` remet le document.

**Une valeur de session est d'abord un gabarit et non du texte.** C'est ce que le moteur fait de
toute valeur de l'hôte, et l'aperçu doit coller au serveur — `{bon|cher}` tapé dans le champ de
valeur donne donc un choix et non ces neuf caractères. Si vous vouliez le texte lui-même, cochez
**comme texte** dans la troisième colonne : alors accolades et signes de pourcentage restent des
caractères.

### `variable.self-reference` — la définition se nomme elle-même

```
#set %x% = a %x% b
%x%  →  A a a … %x% … b b b
```

Cinquante niveaux, puis arrêt. Le moteur déploie jusqu'à la limite de profondeur et s'arrête, en
laissant `%x%` au milieu. Pas une boucle, et pas non plus ce que vous vouliez.

Le `…` ci-dessus est l'abréviation de ce document et non celle du moteur. La vraie sortie fait 207
caractères et porte **cinquante et une** lettres de chaque côté plutôt que cinquante : le
cinquantième niveau s'arrête et laisse la valeur telle quelle, et la valeur en contient une de
plus de chaque.

### `variable.circular-reference` — les définitions se nomment en cercle

```
#set %x% = %y%
#set %y% = %x%
%x%  →  %y%
```

Chaque côté se déploie exactement **une fois** puis s'arrête : `%x%` est devenu `%y%` et non
`%x%`. Le moteur déroule le cercle au lieu de le parcourir, et ce qui survit est l'autre nom du
cercle — mettez `%x% %y%` dans un document et il sort `%y% %x%`, la paire inversée.

Le panneau trace une ligne pour **chaque mention qui ferme le cercle**, non une ligne pour le
cercle ni une par définition. Une définition qui nomme le cercle deux fois obtient deux lignes sur
sa propre ligne : `#set %x% = %y% %y%` contre `#set %y% = %x%` fait trois erreurs, dont deux sur
la première. Les lignes ne sont pas fusionnées. Et la position se pose sur la définition qui vaut
vraiment : si le nom est défini deux fois, c'est la **dernière**.

---

## Inclusions

### `#include` ne marche qu'en début de ligne

```
avant #include "frag" après  →  Avant #include "frag" après
```

```
#include "frag"  →  Fragment
```

Pas de diagnostic, et c'est bien le propos : un `#include` au milieu d'une ligne n'est **pas** une
inclusion. Le moteur le lit comme du texte ordinaire et ne dit rien, parce qu'il n'y a rien à
signaler — vous avez écrit du texte et obtenu du texte.

**La cible peut cependant se trouver une ligne plus bas**, et cela surprend de l'autre côté.
L'écart que le moteur autorise entre le mot et sa cible comprend les sauts de ligne ; ceci est
donc une inclusion et elle marche :

```spx-good
#include
"frag"  →  Fragment
```

Des lignes vides entre les deux passent aussi. Tout le reste ne passe pas : un mot avant la cible
ou quoi que ce soit d'autre que des espaces derrière — et le tout redevient du texte. L'éditeur
colore la cible sur sa propre ligne mais laisse le mot ordinaire tant que la cible n'est pas
venue : il ne promet pas une directive dont il ne voit pas encore la fin.

### `include.unknown-target` — pas de cible de ce nom dans le jeu

```
#include "aucun"  →  (vide)
```

Les cibles sont les fichiers `.spintax` du dossier du document ouvert. Une cible inconnue se
déploie en rien — le paragraphe disparaît au lieu de casser, ce qui est précisément pourquoi c'est
facile à manquer.

**C'est pourquoi l'onglet Variables a une troisième section, Inclusions.** Elle liste chaque
`#include` du document et, pour chacun, si le jeu a sa cible — une ligne par occurrence, une cible
nommée deux fois fait donc deux lignes. La section n'apparaît que si le document a des inclusions.
Un clic sur une ligne amène le curseur au `#include` qui nomme cette cible.

La marque a **trois** valeurs, et la troisième compte : « pas de jeu » ne veut pas dire
« l'extrait manque », mais « il n'y a encore nulle part où regarder ». Le jeu est le dossier à
côté du document, et un document non enregistré n'a pas de dossier — jusqu'au premier
enregistrement, chaque cible est donc marquée ainsi. « MANQUE » n'apparaît que s'il y a un dossier
et que le fichier n'y est vraiment pas.

### `note.case-mismatch` — la cible existe, dans une autre casse

```
#include "intro"  →  (vide)
```

Le jeu contient `Intro.spintax` — et le moteur dit malgré tout qu'il n'y a pas de cible de ce nom,
tandis que Studio ajoute sa note sur la casse. La casse compte : `intro` et `Intro` sont des
cibles différentes. Windows ouvrirait le fichier dans les deux cas, et c'est précisément pourquoi
Studio regarde dans le jeu et non dans le système de fichiers : sinon l'aperçu contredirait le
serveur sur le même document.

### `note.cycle` — une inclusion en cercle

Si `loop.spintax` contient lui-même `#include "loop"`, alors :

```
#include "loop"  →  (vide)
```

Le moteur ne met rien plutôt que l'infini. La note est là pour que vous sachiez pourquoi le
paragraphe s'est évaporé.

La ligne est portée contre **`loop`** et non contre le document que vous regardez — le cercle
appartient à l'extrait, et c'est là que va le curseur au clic. Dans le document ouvert rien n'est
souligné, car la ligne que vous avez écrite n'a rien de fautif.

---

## Formes de nombre

### `plural.arity` — pas autant de formes que la locale en demande

```
#set %n% = 5
%n% {plural %n%: objet|objets|objetses}  →  5 ｛plural 5: objet|objets|objetses｝
```

**Pas du vide — le moteur imprime la construction entière**, accolades remplacées par de larges
`｛｝`. C'est ainsi qu'il dit « j'ai vu ceci et n'ai pas pu l'appliquer ». Personne n'appellerait
cela discret, et tant mieux : un paragraphe évaporé en silence prendrait plus longtemps à trouver.

Le français demande deux formes, le russe trois. Sous la locale de ce document,
`{plural %n%: objet|objets}` est la bonne.

**Le vide vient d'une autre cause, et les deux se confondent aisément.** Comparez ces deux-là, qui
ne diffèrent que par le nombre de formes :

```
{plural %n%: objet|objets}  →  (vide)   deux formes : juste pour le français
{plural %n%: objet|objets|objetses}  →  (vide)   trois formes : faux pour le français
```

Les deux n'impriment rien, et le panneau les traite différemment : le premier ne tire que
`variable.undefined`, le second tire aussi `plural.arity`. Donc **le vide n'est pas la marque
d'une erreur de nombre de formes** — il vient ici de ce que `%n%` n'est pas défini, et le moteur
vérifie le compte avant de compter les formes ; il s'arrête donc avant que la question du nombre
ne se pose.

C'est pourquoi l'exemple en tête de cet article définit `%n%` d'abord. Sans cela la sortie serait
vide quel que soit le nombre de formes et ne montrerait rien du tout sur le nombre.

Le panneau et la sortie répondent ici à des questions différentes, et ce n'est pas une
contradiction : la ligne est posée par la **vérification**, qui compte les formes dans le texte et
se moque du compte ; le vide vient du **rendu**, qui a son propre ordre. Donnez un chiffre au
compte, comme le fait le premier exemple, et vous voyez ce que le nombre de formes fait vraiment.

### `plural.count-macro` — le compte vient d'un `#set`, et cela retire à chaque mention

```
#set %n% = {1|2}
%n% {plural %n%: objet|objets}  →  1
```

Regardez ce qui a survécu : **le nombre a été imprimé et pas le substantif.** Le compte doit être
un nombre au moment où la forme est prise, et un `#set` dont la valeur est elle-même un choix n'en
devient jamais un — le moteur substitue la valeur **sans la rendre**, si bien qu'arrive à la place
du compte le texte littéral `{1|2}`. Le compte et la forme ne peuvent se contredire ; le moteur
laisse plutôt tomber le mot.

`#def` se comporte autrement et déploie sa valeur une fois par rendu ; la place du compte reçoit
donc un nombre :

```
#def %n% = {1|2}
%n% {plural %n%: objet|objets}  →  1 objet
```

Pour celui-là il n'y a aucune ligne dans le panneau. D'où la règle : faites du compte un chiffre
simple ou un `#def`, jamais un `#set`.

### `plural.nested-brackets` — des crochets dans les formes

```
{plural %n%: {objet|chose}|objets}  →  ｛plural %n%: ｛objet|chose｝|objets｝
```

Les formes sont du texte simple. Un choix à l'intérieur n'est pas déployé, et c'est la
construction entière qui est imprimée en larges accolades.

---

## Brassages

### `permutation.unknown-key` — clé inconnue dans le réglage

```
[<foo=1>a|b|c]  →  Bfoo=1cfoo=1a
```

Les clés connues sont `minsize`, `maxsize`, `sep` et `lastsep`. Une clé inconnue n'est pas un
réglage — et quand elle est la seule chose du bloc, le bloc entier n'est pas un réglage du tout :
il devient le séparateur entre les morceaux, ce que montre la sortie.

**S'il y a une vraie clé à côté, l'issue est tout autre**, et c'est la faute la plus probable —
une clé sur plusieurs mal tapée :

```
[<sep=", ";foo=1>a|b|c]  →  B, c, a
```

Le bloc est un réglage, `sep` est suivi, la clé inconnue simplement laissée tomber, et le panneau
dit la même chose dans les deux cas. Le diagnostic vous dit donc qu'une clé n'a pas été comprise ;
il ne vous dit pas ce qui s'est passé ensuite. Pour cela, lisez la sortie.

### `permutation.minsize-not-integer` — minsize n'est pas un entier

```
[<minsize=deux>a|b|c]  →  B c a
```

Une valeur non numérique tombe avec sa limite, et c'est la valeur par défaut qui vaut — à savoir
tous les morceaux.

### `permutation.maxsize-not-integer` — maxsize n'est pas un entier

```
[<maxsize=beaucoup>a|b|c]  →  B c a
```

Exactement la même chose de l'autre bout : la limite haute disparaît, et la sortie contient de
nouveau chaque morceau.

---

## Notes Studio sans rien à montrer

Les trois notes ci-dessous ne peuvent être montrées par un exemple dans ce document, et la raison
diffère à chaque fois et est donnée. Elles ont quand même leurs articles : l'aide doit une réponse
à **chaque** ligne que le panneau peut montrer, sinon une ligne du panneau ne mène nulle part.

### `note.raw-sentinel` — un caractère de commande dans le texte

Les caractères U+E000–U+E005 sont ce que le moteur emploie pour son propre balisage, et il les
**retire** avant l'analyse. S'ils sont arrivés dans votre gabarit — le plus souvent collés depuis
un autre éditeur —, Studio le dit : ni l'aperçu ni le serveur ne les montreront.

Il n'y a pas d'exemple ici, à dessein : ces caractères sont invisibles, et une ligne qui en porte
aurait l'air vide. Il n'y aurait rien à voir.

### `note.unknown-target` — le jeu est vide, il n'y a rien pour juger

Elle apparaît quand le jeu à côté du document est **vide** : pas un seul gabarit hormis celui-ci.
Il n'y a rien à quoi confronter la cible ; Studio ne dit donc pas « pas de cible de ce nom » — il
dit qu'il ne peut pas répondre. Mettez un seul gabarit dans ce dossier et la note cède la place à
l'ordinaire `include.unknown-target`, qui répond sur le fond.

Un document jamais enregistré n'a **aucun** jeu, et c'est un troisième cas et non celui-ci : les
inclusions restent alors littéralement dans la sortie et le panneau n'en dit rien. Enregistrez le
document et elles se mettent à marcher.

Il n'y a pas d'exemple ici par construction : le jeu de ce document est déclaré plus haut et
n'est pas vide.

### `note.too-deep` — inclusions imbriquées trop profond

Le moteur s'arrête au vingtième niveau de `#include` imbriqués et ne met plus rien en dessous. La
limite appartient à la famille : les moteurs JavaScript, PHP et Python font de même, si bien qu'un
document qui l'atteint se comporte partout pareil.

Il n'y a pas d'exemple à cause de sa taille : en montrer un demanderait vingt et un fichiers.

---

## Un silence dans toutes les langues : les abréviations

### Une abréviation laisse le mot suivant en minuscule

```
Dr. nos prix sont bas  →  Dr. nos prix sont bas
Xyz. nos prix sont bas  →  Xyz. Nos prix sont bas
```

Deux lignes qui diffèrent d'un mot, et le second mot de chacune vous donne la règle : après `Dr.`
la phrase reste en minuscule, après `Xyz.` elle prend la majuscule. Le moteur met la majuscule
après un point — sauf après une abréviation qu'il connaît, et après tout ce qui a la forme de
`e.g.` ou `U.S.`. C'est silencieux : pas de diagnostic, pas d'avertissement, et le seul moyen de
s'en apercevoir est de lire la sortie.

**La liste n'est pas française, et pas anglaise non plus.** Elle compte 46 entrées, dont 29 sont
russes :

| | |
|---|---|
| latin | `etc vs mr mrs ms dr prof sr jr inc ltd co corp no st ave blvd` |
| cyrillique | `соц эл см ср ст ул пр пер г р руб коп тыс млн млрд трлн доп напр прим изд обл респ стр табл рис мин макс тел факс` |

Les deux moitiés valent dans **toutes** les locales — la règle ne demande jamais quelle langue
vous avez réglée. `руб.` protège donc le mot suivant dans un document français, et `Dr.` le
protège dans un document russe.

Pour un texte français la conséquence est simple et désagréable : parmi les abréviations que vous
écrivez tous les jours, seules `Dr.`, `Prof.` et `etc.` sont dans la liste, parce qu'elles
coïncident avec la moitié latine. `cf.`, `env.`, `M.` et `no.` n'y sont pas et terminent une
phrase. Le guide du langage montre en plus deux cas mesurés qui ne se devinent pas : `p. ex.`
traverse la finition sans dommage, et `c.-à-d.` en ressort cassé.

---

## À quoi ressemble la forme correcte

```spx-good
un prix {bon|cher}  →  Un prix bon
```

```spx-good
[<minsize=2;sep=", ">a|b|c]  →  C, b
```

```spx-good
#set %vip% = 1
{?vip?pour vous|pour tous}  →  Pour vous
```

```spx-good
#set %n% = 5
%n% {plural %n%: article|articles}  →  5 articles
```

```spx-good
avant /# une note #/ après  →  Avant après
```

Cinq constructions, cinq lignes propres : un choix, un brassage avec réglages, une condition, une
forme de nombre avec un nombre devant, et un commentaire. Aucune ne met quoi que ce soit dans le
panneau.

---

## Questions fréquentes

**Pourquoi le paragraphe a-t-il simplement disparu ?**
Deux causes courantes, toutes deux plus haut : une cible `#include` inconnue et une inclusion en
cercle. Les deux n'impriment rien. La troisième, que l'on soupçonne d'abord — le mauvais nombre de
formes —, n'imprime **pas** rien : le moteur imprime la construction entière en larges accolades
`｛｝`. Le vide vient là d'un compte non numérique et non du nombre de formes.

**Pourquoi ma variable au nom accentué ne marche-t-elle pas ?**
Les noms se composent de lettres latines, de chiffres et du tiret bas. `%café%` n'est pas du tout
une mention de variable — le moteur le lit comme du texte et ne dit rien, parce que de son point
de vue il n'y a rien à signaler :

```
bonjour %café% et %nom%  →  Bonjour %café% et %nom%
```

Les deux sont passés intacts, et c'est le piège : seul le second a tiré une ligne dans le panneau.
Le premier est silencieux ; rien ne vous dit donc qu'il ne sera jamais substitué. Renommez-le.
Dans la **valeur**, en revanche, les accents ne posent aucun problème.

**Pourquoi la même erreur est-elle montrée deux fois ?**
Un cercle de définitions tire une ligne pour chaque mention qui le ferme — deux endroits à
regarder, parfois trois. Ce ne sont pas des doublons, et ils ne sont pas fusionnés.

**Le panneau dit erreur et la sortie a l'air juste. Alors ?**
Les deux. Cela arrive avec un nom défini deux fois : le rendu est juste — la dernière valeur
gagne — et le document est ambigu. Le verdict porte sur le document et non sur cette sortie-là.

**J'ai changé de locale et le document est devenu rouge.**
C'est la locale qui fait son travail. Le document de démonstration est anglais et ses formes de
nombre en portent deux ; passez la locale au russe et ces deux formes deviennent une erreur de
nombre, parce que le russe en demande trois. Le français en demande deux comme l'anglais ; sous
`fr` le document de démonstration reste donc tranquille. La locale appartient au **document**,
c'est pourquoi Studio ne la change pas quand vous changez la langue de l'interface.

**L'aperçu correspond-il à ce que produira mon serveur ?**
Avec le même moteur, la même version, la même locale et les mêmes valeurs — oui, exactement, et
c'est bien pour cela que l'aperçu fait tourner le vrai `spintax-win` et non une approximation.
Avec un **autre** moteur de la famille — celui pour JavaScript, PHP ou Python — se transportent le
verdict et l'ensemble des textes que le gabarit peut donner, mais pas lequel d'entre eux une
graine donnée tire. Reproduire ce tirage précis, la famille ne le promet pas.
