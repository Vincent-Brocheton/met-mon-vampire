# Transformations : mortel en serviteur ou en goule jouée, étreintes (sous-projet 6d) : conception

## Objectif

Le conte transforme les personnages suivis :
- un mortel devient serviteur d'un domitor, ou goule jouée par un joueur ;
- une goule jouée, un mortel ou un serviteur est étreint et devient vampire.

Chaque transformation est une action du conte, avec confirmation et motif.

## Règles du jeu retenues

- **Étreinte :**
  - le sire est choisi parmi les fiches de vampires ;
  - la génération est celle du sire + 1, le rang est déduit du tableau des générations ;
  - le clan est celui du sire ;
  - le personnage reçoit 2, 1 et 1 points gratuits dans les disciplines du clan.
- **Goule jouée étreinte :**
  - ses 5 points de disciplines de goule disparaissent sans remboursement (ils étaient gratuits) ;
  - elle reçoit l'historique Génération au niveau du rang (1 Neonate, 2 Ancilla, 3 Pretender), ainsi que le Sang et le Sang par tour du rang ;
  - son XP dépensée ne change pas. Si son XP disponible devient négative, c'est une dette.
- **Mortel devenu serviteur :** le domitor paie le rang en XP, au coût d'un historique, nouveau niveau × facteur, pour chaque niveau de 1 au rang. Une XP insuffisante devient une dette.

## Les quatre transformations

### 1. Étreinte d'une goule jouée

- **Où :** bouton « Étreindre… » dans C3, sur une fiche de goule active.
- **Fenêtre :**
  - sire, le domitor proposé par défaut ;
  - génération, celle du sire + 1, modifiable ;
  - discipline du clan qui reçoit 2 points ;
  - motif.
- **Effets :** une seule écriture de la fiche, tracée `embrace` :
  - la clé `ghoul` est supprimée, et les disciplines de goule retirées ;
  - `clan`, `sire`, `genRank` et `genNumber` sont posés ;
  - l'historique Génération passe au niveau du rang ;
  - les disciplines du clan passent à 2/1/1, en clan ;
  - `blood` et `bloodPerTurn` reprennent ceux du rang.
- **Avertissement avant confirmation :** « Dette de N XP » si l'XP disponible est négative.

### 2. Mortel devient serviteur

- **Où :** bouton « Devenir serviteur de… » sur la fiche d'un mortel (écran « Goules et mortels »).
- **Fenêtre :**
  - domitor ;
  - type, goule humaine ou animale ;
  - rang de 1 à 5 ;
  - motif ;
  - coût affiché, avec « dette de N XP » le cas échéant.
- **Effets, dans cet ordre :**
  1. fiche du domitor, écriture tracée `xp` avec motif : ajout du serviteur, avec l'identifiant de la fiche du mortel, et du coût à `xpSpent` ;
  2. fiche du mortel : elle devient la fiche détaillée du serviteur (`kind`, `domitorId`, `domitorName`, `holderPlayers`).

### 3. Mortel ou serviteur étreint

- **Où :** bouton « Étreindre… » sur la fiche d'un mortel ou d'un serviteur.
- **Fenêtre :**
  - sire, et génération (sire + 1) ;
  - PNJ actif, ou amorce de PJ pour un joueur ;
  - pour un PNJ, la discipline qui reçoit 2 points ;
  - motif.
- **Effets, dans cet ordre :**
  1. **Nouvelle fiche :** nom repris.
     - PNJ actif : clan, sire, génération, Génération, disciplines 2/1/1, Sang du rang ;
     - amorce de PJ : clé `embrace` posée.
  2. **Fiche d'origine :**
     - mortel : sa fiche est supprimée ;
     - serviteur : il est retiré de la fiche de son domitor (écriture tracée `edit`, avec le motif), et sa fiche détaillée est marquée libérée.

### 4. Mortel devient goule jouée

- **Où :** bouton « Devenir goule jouée… » sur la fiche d'un mortel.
- **Fenêtre :** joueur, domitor.
- **Effets, dans cet ordre :**
  1. une amorce de fiche de goule est créée, comme en 6c, avec le nom repris ;
  2. la fiche du mortel est supprimée.

## Données

Nouvelle clé tardive `embrace` sur `characters/{id}`, sur une amorce de PJ issue d'une étreinte :

| Champ | Contenu |
|---|---|
| `sireId`, `sireName` | fiche du sire |
| `clan` | clan imposé |
| `genNumber` | génération imposée |

La clé est absente sur toute autre fiche, et protégée dans le brouillon du joueur.

## Création guidée d'une amorce étreinte

- **Étape 3 :** « Étreint par X · clan Y », en lecture. Le clan est posé dès la création de l'amorce.
- **Étape 6 :** la génération imposée est affichée.
- **Contrôles :**
  - « Clan imposé par l'étreinte : Y » si le clan diffère (erreur) ;
  - « Génération imposée par l'étreinte : Ne » si le numéro diffère (erreur).

## Règles Firestore

- **`staffEdit` :** les types d'historique acceptés reçoivent `embrace`.
- **`playerDraftSave` :** `embrace` rejoint les clés protégées.
- **Le reste ne change pas :** création de fiche, XP du domitor (tracée `xp`, avec motif), écriture et suppression de `servants/{id}`.

## Erreurs et cas limites

- **Sire sans numéro de génération :** le conte saisit le numéro.
- **Numéro absent du tableau des générations :** l'étreinte est refusée avec un message (« Génération Ne absente du tableau des générations »).
- **Seconde écriture en échec :** un message dit ce qui reste à faire. Les identifiants sont repris, donc relancer l'action ne crée pas de doublon.
- **Dette :** elle est signalée avant la confirmation, sans bloquer.
- **Fiche modifiée entre-temps :** l'écriture est refusée par la version, avec le message « Modifié entre-temps : rechargez la page. ».

## Tests

- **Calculs purs :**
  - fiche de goule étreinte ;
  - fiche de PNJ étreint ;
  - coût et dette de l'achat d'un serviteur ;
  - contrôles de création d'une amorce étreinte ;
  - numéro de génération absent du tableau.
- **Règles d'accès :** édition `embrace` par le conte ; `embrace` protégée dans le brouillon ; suppression de `ghoul`.
- **Écrans :** les quatre fenêtres et leurs appels aux dépôts.

## Hors périmètre

- Étreinte d'un vampire, ou goule d'un PNJ sans fiche.
- Remboursement d'XP à l'étreinte.
