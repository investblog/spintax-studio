# Spintax Studio

Ce programme est un éditeur de gabarits. Un gabarit est du texte ordinaire avec quelques endroits
marqués dedans, et un seul gabarit peut produire un très grand nombre de textes différents — c'est
tout l'intérêt d'en écrire un plutôt que d'écrire les textes.

La fenêtre est faite de deux volets. À gauche votre gabarit, ce que vous modifiez. À droite l'un
des textes qu'il produit, redessiné pendant que vous tapez. Rien à presser entre les deux : ce que
vous voyez à droite est ce que le moteur renvoie pour ce qui est à gauche à cet instant.

```spx-fixture
locale: fr
seed: 7
empty: (vide)
```

Le moteur est intégré à ce programme, et c'est le membre Pascal d'une famille : le même langage
est aussi publié pour JavaScript, PHP et Python. Les quatre sont des programmes indépendants tenus
à un même jeu de cas de test, si bien que ce qu'un gabarit SIGNIFIE est identique dans tous les
quatre — les constructions, le verdict sur sa validité, les finitions. Un gabarit que cette
fenêtre déclare valide l'est aussi là-bas.

Ce qui n'est pas promis, et la différence compte quand on compare : le tirage au sort. Une graine
rend l'aperçu reproductible ICI — la même graine et le même gabarit donnent demain le même texte —
mais la même graine dans le moteur JavaScript peut tirer une autre variante. Les graines servent à
reproduire votre propre travail, pas à retomber sur un autre moteur.

Tout fonctionne ici sans connexion réseau. Il n'y a pas de compte, pas de connexion et rien à
activer : ouvrez le programme et il tourne.

## Les deux volets

On tape à gauche. Le volet de droite se redessine après une courte pause, pour que l'aperçu suive
une phrase et non chaque lettre.

Un gabarit contenant un choix n'a pas de réponse unique, et l'aperçu en montre une :

```spx-good
{Salut|Bonjour} à tous.  →  Salut à tous.
```

**Retirer** au-dessus du volet de droite en donne une autre. Si vous voulez toujours la même —
pendant que vous comparez deux modifications, par exemple —, cochez **Graine**, et l'aperçu cesse
de bouger jusqu'à ce que vous la décochiez ou changiez le nombre.

Le volet de droite montre soit la **page**, soit la **source**. Les gabarits sont le plus souvent
du HTML, et les deux questions « de quoi cela a-t-il l'air » et « quel balisage est sorti » ne se
répondent pas l'une à l'autre : une balise cassée donne une mise en page légèrement de travers que
l'œil saute, tandis que de la prose truffée de balises ne se lit pas comme de la prose. Le
sélecteur au-dessus du volet change ce que vous regardez.

Sélectionnez une partie du gabarit et seule cette partie est rendue — dans la portée du document
entier, si bien qu'un extrait utilisant une variable définie plus haut sort comme il le fera à sa
place.

## Les panneaux du bas

La barre d'outils sur le côté ouvre trois panneaux, un à la fois.

**Diagnostic** liste ce que le moteur a jugé fautif, chaque fois avec la ligne et la colonne du
début. Un clic sur une ligne y place le curseur. C'est le même verdict que le moteur rend partout
ailleurs, et non un second avis de l'éditeur — c'est pourquoi un gabarit que ce panneau déclare
valide est accepté par les autres moteurs.

**Variables** montre les noms que votre document définit et ceux qu'il ne fait qu'employer. Un nom
qu'il emploie et que rien ne définit, vous pouvez le remplir ici pour la session : écrivez une
valeur à côté et l'aperçu la reprend. Cochez **Littéral** quand la valeur est un texte qui se
signifie lui-même plutôt qu'un petit gabarit à son tour.

**Variantes** engendre beaucoup de textes d'un coup. Dites combien, engendrez-les et lisez-les dans
la liste avant d'exporter. Les quasi-doublons peuvent être écartés à la production, et une graine
rend tout le lot reproductible : la même graine et le même gabarit donnent demain les mêmes
variantes.

À côté de ces champs, le panneau dit combien de variantes le gabarit peut donner en tout :
`{a|b} et {c|d}` en fait quatre. Ce nombre vous apprend qu'un gabarit est maigre avant que vous
n'en engendriez cinquante et ne vous en aperceviez en les lisant.

Ce n'est un compte exact que tant que chaque choix est laissé au hasard. Une condition, une forme
de nombre ou un `#include` dont le jeu n'a pas la cible sont décidés par autre chose — une valeur
que vous fournissez, un nombre, un extrait qui viendra peut-être —, et alors le panneau dit **au
moins**. C'est le mot honnête : fournir une valeur ne peut qu'ajouter des textes, jamais en
retirer. Un nombre bien trop grand pour être lu s'arrête à mille milliards et dit **au moins**
pour la même raison.

Une variante est un gabarit rempli — un choix fait à chaque construction —, et ce n'est pas la
même chose qu'un texte qui se lit autrement. `{a|a}` fait deux variantes et un texte, et c'est
voulu : les deux possibilités peuvent cesser de coïncider après une seule modification, et les
confondre voudrait dire engendrer d'abord toutes les combinaisons — justement le travail que ce
nombre doit vous épargner. Un `#def` compte de la même façon : le moteur le tire une fois par
rendu, que la branche empruntée s'en serve ou non.

L'export les écrit de trois manières : en classeur XLSX, en texte brut avec une variante par ligne
ou en un fichier par variante dans un dossier de votre choix.

## L'éditeur de groupe

Placez le curseur dans un `{a|b|c}` et ouvrez l'éditeur de groupe depuis la barre d'outils. Il
liste les variantes en lignes : modifiez-les, ajoutez-en une, retirez-en une, et le document est
réécrit en conséquence.

Il refuse les modifications qui changeraient ce que le groupe SIGNIFIE plutôt que ce qu'il dit :
un `|` tapé dans une variante ferait de l'une deux, et un `}` fermerait le groupe trop tôt.
Lorsqu'il refuse, il le dit et laisse le document tranquille.

## Réglages

Ils sont dans le menu Affichage, et chacun est retenu d'une session à l'autre : la langue de
l'interface et si elle suit le gabarit, de quel côté est la barre d'outils, le thème, la police de
l'éditeur et sa taille, si l'aperçu montre la page ou la source, l'interrupteur de l'import GSA,
quel panneau est ouvert, et les largeurs des panneaux qui se déploient.

L'interface parle quatorze langues, choisies dans le même menu. C'est séparé de la langue de votre
gabarit, qui décide des formes de nombre et se règle au-dessus du volet de droite.

## Importer un gabarit GSA

Celui-ci est éteint tant que vous ne l'allumez pas, sous **Affichage**, **Import GSA**, parce que
la plupart des gens qui écrivent des gabarits n'ont jamais utilisé GSA Search Engine Ranker. Une
fois allumé, **Fichier**, **Importer un gabarit GSA…** lit un gabarit SER et le convertit dans ce
langage.

La conversion est prudente d'une manière précise. Ce qu'elle ne peut exprimer fidèlement, elle le
refuse et vous le dit, plutôt que d'en faire discrètement quelque chose qui se rend. Les
constructions qui seraient mal lues si elles restaient dans le texte — crochets BBCode, un `#`
dans un lien, une macro `#file[...]` — sont sorties dans des variables, et le résumé dit combien.

Deux choses à savoir sur le résultat :

- **Les valeurs sorties sont des valeurs de session.** Elles apparaissent dans le panneau
  Variables et ne sont pas enregistrées avec le document. Enregistrez le gabarit converti,
  rouvrez-le demain, et vous verrez `%…%` là où était le texte sorti. Rien n'est perdu du fichier
  importé — celui-là reste intact —, mais le document converti ne se suffit pas à lui-même.
- **Il est rendu sans la passe de finition.** Tout autre document ici reçoit les finitions
  décrites dans le guide du langage ; un gabarit converti, non, car ce n'est pas notre texte à
  lisser. Il appartient à quelqu'un d'autre, il est le plus souvent en route vers GSA, et il doit
  survivre caractère par caractère.

Le document importé est sans titre et non enregistré, comme un nouveau. Le fichier que vous avez
choisi reste exactement tel qu'il était.
