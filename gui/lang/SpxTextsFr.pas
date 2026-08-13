(*
 * SpxTextsFr -- the window in French.
 *
 * One language, one file. The order is TSpxStr's and nothing else: this is a positional
 * array, so a line moved here moves a caption on screen.
 *
 * `seed` stays `seed`, as it does in every language here: it is one of the spec's own terms,
 * the help explains it under that name, and a template's author reads the same word in the
 * documentation on the site. Translating it would make the panel and the documentation
 * disagree about what the number is.
 *)
unit SpxTextsFr;

{$mode objfpc}{$H+}

interface

uses
  SpxStrIds;

const
  TEXTS_FR: array[TSpxStr] of string = (
      'Fichier', 'Nouveau', 'Ouvrir…', 'Enregistrer', 'Enregistrer sous…',
      'Recharger le jeu', 'Quitter',
      'Édition', 'Rechercher…', 'Suivant', 'Précédent',
      'Affichage', 'Outils à gauche', 'Outils à droite',
      'Langue de l''interface', 'English', 'Русский', 'Comme le modèle',
      'G', 'Groupe sous le curseur',
      'Le curseur n''est dans aucun groupe.', 'Appliquer',
      'Refusé : le résultat dirait autre chose que cette liste — une variante ne peut pas ' +
        'porter | } { ou /#.',
      'Une variante contient un saut de ligne, ce groupe est donc affiché sans être modifié.',
      'Choix', 'Condition', 'Pluriel', 'Permutation',
      'D', 'V', 'Vr',
      'Entourer de {…}', 'Entourer de […]', 'Montrer une autre variante',
      'Copier le résultat',
      'Tout sélectionner',

      'seed', 'Relancer', 'Copier', 'Page', 'Source',
      'fragment affiché', 'le fragment ne rend rien',

      'Casse', 'introuvable', 'trouvés %d', '%d/%d', 'x',

      'Diagnostics', 'Variables', 'Variantes',
      'Niveau', 'Fichier', 'À', 'Message',
      'erreur', 'avertissement', 'note Studio', 'document',

      ' Définitions — elles vivent dans le document',
      ' Valeurs de session — rendues comme du spintax, jamais écrites dans le document',
      'Type', 'Nom', 'Valeur', 'en texte',

      'Combien', 'seed', 'aléatoire', 'Générer', 'Arrêter',
      'Écarter les proches', 'Doublons exacts seulement', 'Tout garder', 'shingle', 'seuil',
      'Vers .xlsx', 'Vers .txt', 'Un fichier chacun', 'seed dans .txt',
      'rien de généré', 'en cours…', 'arrêt…',
      '%d variantes, %d écartées, %d rendus, seed suivant %d',
      '%d sur %d — le modèle n''en donne pas plus à ce seuil (%d écartées, %d rendus)',
      'arrêté : %d variantes, %d écartées, %d rendus',
      '%d sur %d, %d écartées, %d rendus',
      'le document a changé — ce jeu vient du texte précédent ; ',
      '%d lignes écrites dans %s',
      '%d lignes écrites ; dans %d variantes les sauts de ligne sont devenus des espaces — ' +
        'pour le texte tel quel, prenez .xlsx ou un fichier chacun',
      '%d fichiers écrits dans %s', '%d fichiers écrits, puis impossible de continuer',
      'impossible d''écrire le fichier',
      '#', 'seed', 'longueur', 'texte',

      'Ouvrir un modèle', 'Enregistrer le modèle',
      'Modèles spintax|*%s|Tous les fichiers|*.*',
      'Classeur Excel|*.xlsx', 'Texte|*.txt',
      'Exporter en .xlsx', 'Exporter en .txt', 'Où mettre les fichiers', 'Variantes',
      'seed', 'variante',
      'Spintax Studio', 'Le document a des modifications non enregistrées. Les enregistrer ?',
      'Sans titre',
      '%s — Spintax Studio',

      'prêt', 'valide', 'valide, %d avertissements', '%d erreurs', ' · %d notes',
      '%s · %d ms',
      'Afficher', 'Sortie : %d Ko — la page ne se redessine pas',

      'Fermer',

      'Plus grand', 'Plus petit', 'Taille normale', 'Clair', 'Sombre',

      'Largeurs égales', 'Double-clic : largeurs égales',

      'Police de l''éditeur', 'Auto',

      'Valeur non appliquée : le moteur lirait la directive autrement',

      'Inclusions — les fragments que ce document tire', 'Cible', 'Trouvé', 'oui', 'ABSENT', 'pas de jeu',

      'Aide', 'Sommaire', 'Langue de l’aide', 'Il n’y a pas encore d’aide en %s.',

      'tiré de l''aide', 'Insérer dans mon document',

      'À propos',

      'Aucune macro pour l''instant — écrivez #set %name% = valeur dans le document, puis utilisez %name% dans le texte.',
      'Rien d''inclus pour l''instant — #include "fragment" tire un autre fichier, et seulement en début de ligne.',

      'Écrivez un modèle à gauche et voyez à droite ce qu''il produit. Validation, variables, inclusions, génération de variantes et export : tout hors ligne, sans compte, sans réseau, sans runtime.',
      'Licences et remerciements',

      'Import GSA',
      'Importer un modèle GSA…',
      'Modèles GSA|*.txt;*.spintax|Tous les fichiers|*.*',
      '%d variables ont été extraites du modèle.',
      'Ce sont des valeurs de session : elles figurent dans le panneau des variables et ne sont PAS enregistrées avec le document. Le rendu se fait sans post-traitement, afin que le modèle reste tel que GSA l''a écrit.',
      '%d blocs ont été refusés et laissés tels quels.',
      '…et %d de plus.',

      'Variantes possibles : %s',
      'Variantes possibles : au moins %s',

      (* the AI panel (ADR 0011) *)
      'Brouillon IA',
      'Brief',
      'Variables que le modèle peut utiliser',
      'Réponse du modèle',
      'Canal',
      'Variation',
      'Langue',
      'Copier l''invite',
      'Copier l''invite de correction',
      'Insérer dans le document',
      'Cas',
      'Note',
      'Invite copiée. Portez-la à votre modèle et rapportez la réponse.',
      'Invite de correction copiée. Elle pointe les endroits exacts.',
      'Brouillon inséré. Le verdict est dans le panneau des diagnostics.',
      'Écrivez d''abord un brief.',
      'Collez d''abord la réponse du modèle.',
      'Aucune erreur à corriger.',
      'e-mail',
      'SMS',
      'push',
      'page d''atterrissage',
      'générique',
      'prudente',
      'équilibrée',
      'audacieuse',
      '—',
      'nominatif',
      'génitif',
      'datif',
      'accusatif',
      'instrumental',
      'prépositionnel',
      'Remplacer le document',
      'Document remplacé. Le verdict est dans le panneau des diagnostics.',

      (* R1-4: the loop in the window (spec §4.5). French shares one word for the template
         and the LLM ("modèle"), so the sentences below say "l'invite" for what is sent and
         keep "le modèle" for the LLM alone. *)
      'Réparer',
      'Réglages IA…',
      'arrêté',
      'requête au modèle…',
      'le moteur vérifie le brouillon…',
      'tentative de réparation %d sur %d',
      'Aucune erreur, mais une partie des rendus d''essai ressort vide — vérifiez les formes du pluriel. Le brouillon est dans le panneau IA, non appliqué.',
      'Le brouillon est propre, mais un fragment inclus contient une erreur. Corrigez ce fichier — régénérer ne le réparera pas.',
      'Il reste %d erreurs après %d tentatives de réparation. Le brouillon est dans le panneau IA, non appliqué.',
      'Le document a changé pendant que la réponse voyageait. Le brouillon est dans le panneau IA, non appliqué.',
      'Ce profil s''authentifie, et aucune clé n''est rattachée. Saisissez la clé dans le panneau IA.',
      'L''endpoint demande de passer par une autre adresse (%s). Elle n''a pas été suivie ; changez le profil si c''est voulu.',
      'Du http en clair au-delà de cette machine enverrait la clé et le texte en clair. Utilisez https.',
      'L''endpoint a refusé la clé. Vérifiez-la dans le panneau IA.',
      'L''endpoint signale une limite de requêtes ou un quota épuisé. Réessayez plus tard.',
      'L''invite est plus longue que ce que ce modèle accepte.',
      'La requête n''est pas passée : %s',
      'L''endpoint a répondu, mais sous une forme que cette application ne peut pas lire : %s',
      'La réponse ne contenait aucun modèle.',
      'L''endpoint signale : %s',
      'Connexion',
      'Format',
      'Endpoint',
      'Modèle',
      'Autorisation',
      'aucune',
      'Clé API',
      'Clé',
      'Rattacher la clé',
      'Oublier la clé',
      'une clé est rattachée à cet endpoint',
      'aucune clé rattachée',
      'l''endpoint a changé — saisissez la clé à nouveau pour la rattacher à la nouvelle adresse',
      'Envoi autorisé',
      'Envoyer vers cet endpoint ?',
      '« Générer » et « Réparer » envoient le brief, le modèle actuel et les variables déclarées à l''endpoint de ce profil :'#10'%s'#10#10'Avec l''autorisation par clé API, la clé voyage dans les en-têtes de la requête. Rien n''est envoyé à aucun autre moment, et l''adresse ne change jamais d''elle-même : une redirection est refusée et affichée. Ce que le logiciel à cette adresse fait du texte relève de son opérateur.'#10#10'Vous pouvez désactiver cela à tout moment dans les réglages IA.'
  );

implementation

end.
