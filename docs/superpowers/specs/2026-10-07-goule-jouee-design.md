# Goule jouée (sous-projet 6c) : conception

## Objectif

Un joueur peut incarner une goule. Le conte crée la fiche et choisit le domitor. Le joueur la remplit dans la création guidée adaptée, puis la soumet. Ensuite, il dépense son XP selon les règles de goule.

Maquettes : J-Goule, J-Goule-mobile.

## Découpage

- **6c (ce document) :** fiche de goule, création, XP, fiche J2 et C3.
- **6d (plus tard) :** passage d'un mortel à goule, étreinte d'une goule ou d'un mortel.

## Règles du jeu retenues

- **Base :** une goule suit les règles d'un Neonate, sauf les différences suivantes.
- **Généalogie :** ni génération ni clan. L'historique Génération est interdit à la création et n'est plus exigé.
- **Disciplines :** 5 points à répartir entre les disciplines en clan du domitor qu'il possède, sans dépasser son niveau dans chacune (Base p. 296). Les points non placés à la création peuvent l'être plus tard. Elles ne s'achètent jamais en XP.
- **Sang :** 10, dont 5 de vitae au plus, 1 par tour. Volonté 6, Humanité 5, comme un Neonate.
- **Restrictions :** pas de traits de Bête, pas de techniques, pas de pouvoirs d'anciens.
- **Rareté et lignée :** la goule paie l'atout de rareté et de lignée du clan de son domitor (Base p. 296), corrigé après relecture.
- **Humanité :** elle ne peut pas baisser.
- **Échéance de la vitae :** un mois après la dernière gorgée, comme pour les serviteurs. Une fois passée, la fiche affiche « Son âge le rattrape : 10 ans par jour ».

## Données

Nouvelle clé tardive `ghoul` sur `characters/{id}`, présente seulement sur une fiche de goule :

| Champ | Contenu |
|---|---|
| `domitorId`, `domitorName` | fiche du domitor |
| `domitorClan` | clan du domitor (copie) |
| `domitorDisciplines` | `[{name, level}]` : disciplines du domitor (copie) |
| `bond` | lien de sang, 0 à 3 |
| `vitae` | 0 à 5 |
| `lastDrink` | date de la dernière gorgée, ou absent |

- **Copie à la création :** le conte recopie le clan et les disciplines du domitor, parce qu'un joueur ne peut pas lire la fiche d'un autre joueur. C'est la copie qui fait foi. Le conte peut la rafraîchir dans C3.
- **Fiche de vampire :** elle n'a pas la clé `ghoul`. La clé reste absente tant qu'elle est nulle (règle des clés tardives).
- **Champs vides :** `clan` et la génération restent vides sur une fiche de goule.

## Référentiel

Le tableau des générations reçoit un rang « Goule » (`ghoul`). La ligne de ce rang fixe le Sang, le Sang par tour et les facteurs de coût d'une goule.

Sans cette ligne, les valeurs sont celles d'un Neonate, avec :
- Sang 10 et 1 par tour ;
- technique interdite ;
- pouvoirs d'anciens interdits.

## Création guidée

- **Création de la fiche :** sur la page des fiches, « Nouvelle fiche » propose le type « Goule ». Le conte choisit le joueur et le domitor parmi les fiches de vampires actives.
- **Étape du clan :** « Goule de X · clan du domitor : Y » s'affiche en lecture. La secte reste libre.
- **Historiques gratuits :** un à 3, un à 2, un à 1, sans Génération.
- **Étape des disciplines :**
  - 5 points à répartir parmi les disciplines du domitor, au plus son niveau dans chacune ;
  - compteur « N / 5 points » ;
  - pas d'achat de discipline à l'étape 9.
- **Traits dérivés :** Sang 10 (ou la ligne « Goule »), 1 par tour, Volonté 6, Humanité 5.
- **Contrôles :**
  - « Disciplines de goule : N points sur 5 » : avertissement tant qu'il en reste à placer (ils pourront l'être plus tard), erreur au-delà ;
  - « X : niveau N au-delà de celui du domitor (M) » : erreur ;
  - « X : le domitor ne la possède pas » : erreur ;
  - « Une goule n'a pas de Génération » : erreur si l'historique est présent ;
  - les autres contrôles d'un Neonate s'appliquent, sauf ceux du clan et de la génération.

## XP

- **Coûts :** ceux de la ligne « Goule », ou à défaut ceux d'un Neonate.
- **Retirés de l'écran XP :** les disciplines, les techniques et les pouvoirs d'anciens.
- **Achat interdit :** il est refusé avec « Les disciplines d'une goule ne s'achètent pas avec l'XP. » (ou « Une goule n'apprend ni technique ni pouvoir d'ancien. »). La même erreur bloque la validation d'une demande écrite hors de l'application.
- **Tableau des coûts :** « Coûts pour une goule », où ces trois lignes portent « Jamais en XP ».

## Fiche (J2 et C3)

- **En-tête :** « Goule de X · clan du domitor : Y ».
- **Panneau « État de goule » :**
  - lien de sang en pastilles ;
  - vitae N / 5 ;
  - dernière gorgée et échéance, avec une alerte si elle est proche ou passée ;
  - « Génération : aucune » ;
  - « Traits de Bête : jamais » ;
  - « Humanité : ne peut pas baisser ».
- **C3 :**
  - saisie de la vitae, du lien et de la gorgée (« + Gorgée » : date du jour et +1 vitae, 5 au plus) ;
  - bouton « Recopier les disciplines du domitor » ;
  - une Humanité plus basse que celle enregistrée est bloquée (« L'Humanité d'une goule ne peut pas baisser »).
- **Avertissement :** « Le domitor est une fiche retirée ou morte » quand c'est le cas.

## Règles Firestore

- **Création d'une fiche :** la règle accepte déjà une fiche de joueur en brouillon. La clé `ghoul` y est permise, car la création n'a pas de liste fermée de clés.
- **Brouillon du joueur (`playerDraftSave`) :** `ghoul` rejoint les clés protégées, que le joueur ne peut pas modifier.
- **Soumission et décision :** leurs listes fermées ne contiennent pas `ghoul`. La clé ne change pas sur ces chemins.
- **Écritures du conte (C3, XP, gains, corrections) :** inchangées.

## Erreurs et cas limites

- **Domitor retiré, mort ou supprimé :** la copie reste, et un avertissement s'affiche si la fiche du domitor est lisible.
- **Disciplines du domitor modifiées après la création :** la copie fait foi jusqu'au rafraîchissement par le conte.
- **Fiche de goule convertie en vampire :** hors périmètre (étreinte, 6d).

## Tests

- **Calculs purs :**
  - contrôles de création d'une goule ;
  - refus des achats interdits ;
  - ligne « Goule » du référentiel et valeurs par défaut ;
  - Humanité qui ne baisse pas.
- **Règles d'accès :** le joueur ne peut pas modifier `ghoul` dans son brouillon ; le conte crée une fiche de goule.
- **Écrans :**
  - création d'une goule par le conte ;
  - étape des disciplines ;
  - en-tête et panneau de la fiche ;
  - écran XP sans les types interdits.

## Hors périmètre

- Mortel devenu goule, étreinte : 6d.
- Faiblesse du clan du domitor : texte libre écrit par le conte.
