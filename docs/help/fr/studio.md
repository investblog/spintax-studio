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

L'éditeur, la validation, l'aperçu, la génération de variantes et l'export fonctionnent sans
connexion réseau — tout le travail quotidien. Il n'y a ni compte ni identifiant : ouvrez le
programme et il tourne. La seule fonction capable d'aller en ligne, le brouillon IA, est
éteinte tant que vous ne l'allumez pas, et a son propre chapitre plus bas.

## Les deux volets

On tape à gauche. Le volet de droite se redessine après une courte pause, pour que l'aperçu suive
une phrase et non chaque lettre.

Un gabarit contenant un choix n'a pas de réponse unique, et l'aperçu en montre une :

```spx-good
{Salut|Bonjour} à tous.  →  Salut à tous.
```

**Relancer** au-dessus du volet de droite en donne une autre. Si vous voulez toujours la même —
pendant que vous comparez deux modifications, par exemple —, cochez **seed**, et l'aperçu cesse
de bouger jusqu'à ce que vous la décochiez ou changiez le nombre.

Le sélecteur au-dessus du volet de droite propose **Page** et **Source**. Les gabarits sont le plus souvent
du HTML, et les deux questions « de quoi cela a-t-il l'air » et « quel balisage est sorti » ne se
répondent pas l'une à l'autre : une balise cassée donne une mise en page légèrement de travers que
l'œil saute, tandis que de la prose truffée de balises ne se lit pas comme de la prose. Le
sélecteur au-dessus du volet change ce que vous regardez.

Sélectionnez une partie du gabarit et seule cette partie est rendue — dans la portée du document
entier, si bien qu'un extrait utilisant une variable définie plus haut sort comme il le fera à sa
place.

## Rechercher et remplacer

**Ctrl+F** ouvre un champ de recherche dans l'en-tête. Le compteur à côté dit combien de fois
le texte apparaît et sur quelle occurrence vous êtes ; **Entrée** avance, **Maj+Entrée**
recule, F3 fonctionne depuis le document. La casse ne compte qu'avec la case cochée près du
champ — et le pliage est celui du moteur, si bien qu'une lettre cyrillique ou accentuée
correspond à son autre casse exactement là où l'aperçu les tient pour une seule lettre.

**Ctrl+H** — ou l'élément de menu **Remplacer…** — donne à la barre une seconde ligne : le
remplacement et deux boutons. **Remplacer** change l'occurrence où vous êtes et passe à la
suivante ; tant que rien n'est trouvé, la première pression ne fait que chercher. **Tout
remplacer** parcourt tout le document d'un coup, et la barre d'état dit combien d'endroits ont
changé ; un seul Ctrl+Z reprend tout le parcours.

Le remplacement est littéral. Il peut être vide — cela supprime — et peut contenir le texte
cherché sans faire tourner le parcours en rond : les endroits sont décidés d'avance, sur le
texte tel qu'il était. Quand des occurrences se chevauchent, le compteur compte chacune qu'un
pas peut visiter, mais le parcours ne change que celles qui ne partagent pas de lettres —
« remplacés » peut donc honnêtement annoncer un nombre plus petit.

Un document remplacé prend le même chemin du moteur que du texte tapé : l'aperçu se
redessine, et le diagnostic répond sur ce qui s'y trouve désormais.

## Insérer les marques

Tout ce qui pose dans le document les marques du langage lui-même se trouve dans le menu
**Insertion**.

Les trois commandes d'entourage prennent la sélection telle quelle : **Entourer de {…}** en fait un
choix, **Entourer de […]** un brassage, **Entourer de /#…#/** (Ctrl+/) un commentaire. L'entourage en commentaire refuse quand un `#/` dans la sélection ou autour d'elle — ou un
commentaire déjà ouvert à cet endroit — terminerait un commentaire trop tôt : la première marque
fermante gagne où qu'elle soit, du texte retomberait dehors ; la barre d'état le dit, parce que
le moteur se tait. Sans sélection, Ctrl+/ insère la paire et laisse le
curseur dedans.

Les constructions en dessous se posent exactement comme le menu les lit. **#set %nom% = valeur**, **#def %nom% = {a|b}** et
**#include "nom"** prennent leur propre ligne — une directive ne compte que si elle ouvre sa ligne, le
texte avant le curseur reste donc au-dessus et le texte après descend — et le nom ressort
sélectionné, prêt à être remplacé. Gardez les noms en lettres latines : un nom dans un autre
alphabet n'en est silencieusement pas un. La cible de `#include` est l'exception — elle est
comparée aux noms de vos fragments exactement telle qu'écrite.

**{?nom?alors|sinon}** s'écrit dans la ligne. Avec une sélection, le texte sélectionné devient la moitié
« alors » — une façon de rendre conditionnel ce qui est déjà écrit ; sans sélection, la forme
entière est insérée. Une sélection portant un `|` nu, un crochet déséquilibré ou un commentaire ouvert est refusée :
l'entourage changerait ce qu'elle dit au lieu de l'encadrer.

Le dernier élément pose dans le document l'exemple ouvert dans l'aide — le bouton du panneau
d'aide lui-même, rendu accessible au clavier.

## Les panneaux du bas

La barre d'outils sur le côté ouvre quatre panneaux, un à la fois.

**Diagnostics** liste ce que le moteur a jugé fautif, chaque fois avec la ligne et la colonne du
début. Un clic sur une ligne y place le curseur. C'est le même verdict que le moteur rend partout
ailleurs, et non un second avis de l'éditeur — c'est pourquoi un gabarit que ce panneau déclare
valide est accepté par les autres moteurs.

**Variables** montre les noms que votre document définit et ceux qu'il ne fait qu'employer. Un nom
qu'il emploie et que rien ne définit, vous pouvez le remplir ici pour la session : écrivez une
valeur à côté et l'aperçu la reprend. Cochez **en texte** quand la valeur est un texte qui se
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

**Brouillon IA** écrit pour vous le premier brouillon d'un gabarit — à partir d'un
texte que vous avez déjà, ou d'un brief. Il mérite sa propre section : la suivante.

## Le brouillon IA

Un gabarit commence le plus souvent par un texte qui existe déjà — une fiche produit, une
lettre, une page. Le panneau **Brouillon IA** en fait un premier gabarit : ouvrez-le depuis la barre
d'outils, laissez l'en-tête de la colonne de gauche sur **Texte à convertir**, collez le texte et pressez
**Générer**. Le brouillon se pose dans **Réponse du modèle**, déjà vérifié — il est passé par le moteur de
cette fenêtre en chemin. L'appliquer vous revient : **Insérer dans le document** le met à la
place de votre sélection (ou au curseur si rien n'est sélectionné), **Remplacer le document**
échange tout le texte — et rien ne touche votre document tant que vous n'avez pas pressé l'un
des deux. Un Ctrl+Z après l'un ou l'autre ramène l'ancien texte.

S'il n'y a rien à coller, passez l'en-tête sur **Brief** et décrivez ce que vous voulez. Les
champs au-dessus guident le brouillon dans les deux modes : **Canal** — une lettre, un SMS et
une notification push ne s'écrivent pas dans le même registre ; **Variation** — jusqu'où les
variantes peuvent s'écarter ; la langue de la réponse ; et **Variables que le modèle peut utiliser**, déclarées par leur
nom. La colonne des cas est la partie qui vaut la peine d'être remplie. Une variable est insérée telle quelle, rien ne la décline : dans une langue à cas, la phrase doit donc être construite autour de la forme que la valeur possède déjà, et un modèle ne choisit correctement que si on lui dit quelle forme porte chaque nom. Cela ne se déduit pas du nom : dans un vrai jeu de modèles, les formes instrumentales se trouvaient dans une variable dont le nom disait accusatif.

La réponse n'est pas crue, elle est vérifiée : le brouillon passe par le moteur de cette
fenêtre avant d'approcher votre document, et si le verdict trouve des erreurs, la boucle
demande elle-même au modèle de les corriger — la barre d'état compte les tours — avant de rien
livrer. La réponse n'écrit jamais d'elle-même dans l'éditeur : elle attend toujours dans **Réponse du
modèle**, et la ligne d'état dit comment cela s'est fini — un brouillon propre se dit prêt, un
que la boucle n'a pas pu réparer entièrement nomme le reste, et si le document — ou quoi que ce soit contre quoi elle était vérifiée — a changé pendant que
la réponse volait, la ligne prévient que le verdict portait sur l'état d'avant. Pendant le travail, **Générer** affiche **Arrêter** — pressez pour abandonner le tour — un tour arrêté en pleine vérification peut laisser dans la
réponse un texte non vérifié.

**Réparer** est la même boucle pointée sur votre document actuel : elle s'éveille quand le
diagnostic trouve des erreurs, envoie le document avec les objections exactes, et la version corrigée attend dans la même réponse — sa place est le plus souvent **Remplacer le
document**.

### La connexion, et la clé de qui

Telle qu'installée, l'application n'envoie rien nulle part. **Générer** et **Réparer** ne vont sur
le réseau qu'après que vous avez configuré la connexion au pied du panneau et l'avez permise.
Choisissez le **Format** que parle votre endpoint — **Anthropic Messages** ou
**OpenAI-compatible** —, l'adresse **Endpoint** et le nom dans **Modèle** — pour Anthropic,
la liste sous la flèche propose des noms actuels ; sinon, tapez le nom que votre endpoint
attend. **Autorisation** dit si une clé voyage :
**Clé API** pour les fournisseurs hébergés, **aucune** pour les serveurs qui n'en
veulent pas.

La clé est la vôtre, créée sur votre propre compte — l'application n'en a jamais une à elle :

- **Anthropic** — créez la clé sur `console.anthropic.com`, rubrique API keys.
- **OpenAI** — `platform.openai.com`, rubrique API keys ; l'envoi demande aussi la
  facturation activée sur le compte.
- **OpenAI-compatible** est une famille, pas une seule société : OpenRouter répond sous la
  même forme avec beaucoup de modèles sous une seule clé, et les serveurs sur votre propre
  machine — Ollama, LM Studio — ne veulent d'ordinaire aucune clé : mettez **Autorisation** sur
  **aucune**.

**Rattacher la clé** range la clé dans le Gestionnaire d'identifiants de Windows, chiffrée pour votre
compte Windows — pas dans un fichier, et jamais dans le document. Le champ montre ensuite les
premiers caractères de la clé et ses quatre derniers — les débuts se ressemblent, c'est la
fin qui distingue les clés, et **Oublier la clé** la retire.
Une clé est rattachée au lieu pour lequel elle a été saisie — le schéma, l'hôte et le port :
changez l'un d'eux et le panneau la redemande.

La première pression demande en toutes lettres — **Envoyer vers cet endpoint ?** — en nommant le destinataire.
Voyage l'invite bâtie sur votre brief ou votre texte — avec le canal, la variation et la
langue choisis —, les variables déclarées, le gabarit courant et son diagnostic lors d'une
réparation, le nom du modèle de votre profil avec un plafond sur la longueur de la réponse,
et, sous l'autorisation **Clé API**, la clé dans les en-têtes de la requête ;
rien d'autre, et à aucun autre moment. Le destinataire ne change pas sans vous :
une redirection est refusée au lieu d'être suivie, et une adresse `http` non chiffrée n'est
acceptée que sur cette machine. La permission se lie là où se lie la clé — le schéma, l'hôte et le port — et se voit à la
coche **Envoi autorisé** dans les réglages — décochez-la à tout moment : rien de
nouveau ne part, et une réponse déjà en vol atterrit, au plus, dans la réponse. Ce que le logiciel à l'adresse choisie fait du texte, c'est à son opérateur de le
dire : la requête va à l'adresse de votre profil et nulle part ailleurs.

### La même boucle, sans réseau

Les invites n'ont besoin ni de clé ni de connexion — c'est le même chemin quand votre modèle
vit dans une fenêtre de chat, et la boucle, ici, c'est vous qui la faites tourner : le moteur
juge après le collage, pas avant. **Copier l'invite** met l'invite complète dans le presse-papiers ;
portez-la au modèle que vous utilisez, collez la réponse dans **Réponse du modèle**, et pressez
**Insérer dans le document**. Si le diagnostic trouve des erreurs, **Copier l'invite de correction** bâtit la seconde invite : elle porte
le document entier avec ses lignes numérotées et nomme les endroits exacts que le moteur a
contestés. Sa réponse est le document corrigé en entier — rapportez-la et pressez
**Remplacer le document** ; **Insérer dans le document** laisserait le document cassé en place et poserait la copie corrigée
à côté (sauf si du texte est sélectionné — l'insertion remplace alors exactement celui-ci).

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
fois allumé, **Fichier**, **Importer un modèle GSA…** lit un gabarit SER et le convertit dans ce
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
