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
      'Document remplacé. Le verdict est dans le panneau des diagnostics.'
  );

implementation

end.
