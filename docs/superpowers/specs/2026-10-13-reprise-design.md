# Reprise de fiches existantes (sous-projet 10c) : conception

## Objectif

Le conte recopie à la main, dans l’application, les fiches que la chronique tient déjà dans un gabarit Google Sheets. Une fiche reprise appartient à son joueur et est active tout de suite ; elle ne passe pas par la création guidée.

Le sous-projet 10 est découpé en lots :
- 10a Notifications ;
- 10b Journal de la chronique ;
- **10c Import de fiches** (ce document).

Maquettes : `C-Import`, `C-Import-mobile`, **non retenues** (voir Décisions).

## Décisions

- **Saisie à la main, pas d’import de fichier.** Les fiches existent sous un gabarit Google Sheets unique ; les recopier dans l’éditeur du conte (C3) est plus simple que lire le gabarit cellule par cellule. La maquette `C-Import` (fichier, colonnes, vérification, solde d’ouverture, correspondances mémorisées) n’est pas implémentée.
- **Ce qui bloque aujourd’hui.** Un PJ créé par « Nouvelle fiche » naît en brouillon. Le conte ne modifie pas un brouillon : l’écran C3 le montre en lecture seule et la règle `staffEdit` le refuse. Il faut donc pouvoir créer un PJ directement actif.
- **Pas de nouvel écran.** Après la création, le conte arrive sur C3 et remplit la fiche avec l’éditeur existant, XP initiale, gagnée et dépensée comprises. Chaque enregistrement est une modification tracée ordinaire.
- **Pas de solde d’ouverture.** L’XP initiale, gagnée et dépensée se recopient telles quelles ; le conte corrige une incohérence comme sur n’importe quelle fiche.

## Dialogue « Nouvelle fiche » (C2)

- Une case à cocher « Fiche existante (reprise) », clé `new-resume`, visible quand le type est PJ ou Goule, décochée par défaut.
- Le texte d’aide, case cochée : « La fiche est active tout de suite, sans création guidée : vous la recopiez ensuite dans l’éditeur. »
- Le joueur reste obligatoire ; le domitor aussi pour une goule.
- Après « Créer », le dialogue renvoie (id, type, nom) comme aujourd’hui ; C2 ouvre la fiche.

## Dépôt

`CharacterRepository.create(..., bool resumed = false)` :
- `resumed` n’a d’effet que pour un PJ : statut `active` au lieu de `draft` ;
- l’entrée d’historique, de type `creation`, dit « Fiche reprise » (« Fiche de goule reprise » pour une goule).

## Règles Firestore

La règle `create` de `characters` accepte un PJ en `draft` **ou** en `active`, avec les mêmes conditions : `playerUid` est une chaîne et n’est pas l’auteur. Le reste ne change pas (version 1, historique `creation`, conte ou principal seulement).

## Tests

- **Règles** (`rules_test/characters.test.js`) : PJ actif créé par le conte avec historique accepté ; PJ actif pour soi-même refusé ; PJ actif par le narrateur refusé. L’assertion actuelle « PJ actif refusé » est remplacée.
- **Dépôt** : le dépôt n’a pas de test unitaire dans ce projet (pas de faux Firestore) ; la forme de son écriture (PJ actif, historique `creation`) est fixée par le test des règles. Le faux dépôt enregistre `resumed`.
- **Dialogue** : la case est visible pour PJ et Goule, absente pour PNJ ; cochée, la création passe `resumed: true`. Mise en page vérifiée à 390 px.
