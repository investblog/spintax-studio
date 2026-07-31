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

      'À propos'
  );

implementation

end.
