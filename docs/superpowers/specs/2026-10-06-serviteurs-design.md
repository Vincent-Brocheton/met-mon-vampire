# Serviteurs, goules animales et mortels (sous-projet 6b) : conception

## Objectif

Le conte suit les serviteurs des personnages (goules humaines et animales) et les mortels du jeu. Un personnage peut avoir plusieurs serviteurs. Chaque serviteur s'achète en XP comme un historique. Les joueurs voient les serviteurs de leurs personnages et en achètent de nouveaux depuis l'écran XP.

Maquettes : C-Goules, C-Animaux, J-Goule (pour 6c), J-Animal (remplacée par l'écran XP).

## Découpage

- **6b (ce document) :** serviteurs humains et animaux, mortels suivis.
- **6c (plus tard) :**
  - goule jouée (fiche de goule, création, coûts d'XP) ;
  - passage d'un mortel à goule ;
  - étreinte.

## Règles du jeu retenues

- **Rang :** un serviteur a un rang N de 1 à 5. Le rang fixe :
  - spécialités : N, choisies parmi les compétences et les disciplines du clan du domitor ;
  - réserve de test : 2 × N ;
  - santé : N niveaux, sans Volonté ;
  - goule animale : en plus, N points de qualités animales (référentiel `animalQualities` : `cost`, `requires`).
- **Coût en XP :** celui d'un historique (nouveau niveau × facteur de la génération), compté séparément pour chaque serviteur.
- **Sang :** vitae de 0 à 5. Lien de sang de 0 à 3.
- **Échéance :** un mois après la dernière gorgée. Une fois l'échéance passée, la fiche affiche « Son âge le rattrape : 10 ans par jour ».
- **Libération ou mort d'un serviteur :** le domitor perd l'accès à ces points pendant 6 semaines. L'application ne compte pas les parties, donc seule la date est affichée.

## Données

### Sur la fiche du personnage

Nouvelle clé tardive `servants` : `[{id, name, kind: 'human'|'animal', rank: 1..5}]`.
- Elle est écrite comme les autres clés tardives : seulement si elle n'est pas vide, ou si elle était déjà présente (`laterKeys` / `draftData`).
- L'identifiant est stable et unique, au format `<characterId>-s<n>`.
- Ce que l'XP touche : l'ajout d'un serviteur et son rang.
- L'historique de la fiche note « + Serviteur Mila ●● », « Serviteur Mila ●● → ●●● » et « − Serviteur Mila ●● ».

**Conversion des anciennes fiches :** à la lecture d'une fiche active, retirée ou morte, l'historique `Serviteurs` devient un serviteur.
- **Nom :** la note de l'historique, ou « Serviteur » s'il n'y en a pas.
- **Rang et identifiant :** même rang que l'historique, identifiant `<id>-s1`.
- **Enregistrement :** il se fait à la prochaine modification de la fiche.
- **Création :** elle ne change pas. La fiche validée devient active, puis la lecture la convertit.

### Collection `servants/{id}`

L'identifiant est le même que celui de l'entrée sur la fiche. Pour un mortel, il est généré.

| Champ | Contenu |
|---|---|
| `kind` | `human`, `animal` ou `mortal` |
| `name` | 1 à 80 caractères (recopié de la fiche pour un serviteur) |
| `domitorId`, `domitorName` | personnage maître (vide pour un mortel) |
| `attachment` | rattachement libre d'un mortel |
| `holderPlayers` | joueur du domitor, ou liste vide |
| `specialties` | noms de compétences ou de disciplines |
| `qualities` | qualités animales `[{name}]` |
| `vitae` | 0 à 5 |
| `bond` | 0 à 3 |
| `lastDrink` | date de la dernière gorgée, ou absent |
| `description` | texte lisible par le joueur |
| `releasedAt` | date de libération, posée quand le serviteur a quitté la fiche |
| `version`, `lastHistoryId`, `updatedAt`, `updatedByName`, `createdAt` | comme pour les lieux |

Sous-documents :
- `servants/{id}/private/note` `{text}` : note secrète du conte ;
- `servants/{id}/history/{h}` `{at, byUid, byName, summary[], reason}`.

## Calculs (purs, testés)

- **Réserve et santé :** `pool(rank) = 2 × rank`, `health(rank) = rank`.
- **Échéance :** `dueDate(lastDrink) = lastDrink + 1 mois`. L'état vaut :
  - « en retard » si l'échéance est passée ;
  - « proche » dans les 7 jours qui la précèdent ;
  - « à jour » sinon.
- **Indisponibilité :** `unavailableUntil(releasedAt) = releasedAt + 42 jours`.
- **Coût XP :** un serviteur passe du rang `from` au rang `to`. Le coût est celui d'un historique.
- **Avertissements (jamais bloquants) :**
  - « N spécialités sur R » quand il y en a plus que le rang ;
  - « X : discipline hors du clan du domitor » ;
  - « Qualités animales : N points sur R » ;
  - « X demande Y » quand le prérequis manque ;
  - « X : hors du référentiel » et « X est interdite dans la chronique » ;
  - « Plus de vitae depuis le … : son âge le rattrape » ;
  - « Le domitor est une fiche retirée ou morte » ;
  - « Le joueur du domitor a changé : enregistrez pour mettre à jour l'accès ».
- **Limite de contrôle des lieux :** 5 + la somme des rangs des serviteurs (au lieu du niveau de l'historique Serviteurs).

## Écrans

### Conte : « Goules et mortels » (`/conteur/goules`)

Un bouton sur la page des fiches y mène. Le narrateur le voit en lecture seule.

- **Liste :**
  - colonnes : nom, type (Goule humaine, Goule animale, Mortel), domitor ou rattachement, rang, vitae, échéance ;
  - contenu : les serviteurs de toutes les fiches, joints à leur fiche détaillée quand elle existe (sinon « à compléter »), les fiches détaillées libérées (« libéré le … ») et les mortels ;
  - filtres : type, échéance dépassée, à compléter ; recherche par nom ou par domitor.
- **Fiche d'un serviteur :**
  - nom, type et rang en lecture (ils se changent par l'XP ou dans C3) ;
  - réserve, santé ;
  - spécialités (liste des compétences, plus les disciplines du clan du domitor) ;
  - qualités animales pour un animal ;
  - vitae, lien, dernière gorgée, avec le bouton « + Gorgée » qui note la date du jour et ajoute 1 à la vitae, 5 au plus ;
  - description, note secrète, motif ;
  - avertissements, historique ;
  - « Enregistrer ».
- **Mortels :**
  - « Nouveau mortel » ;
  - champs : nom, rattachement, description, note ;
  - « Supprimer », qui efface aussi la note et l'historique.

### Conte : fiche du personnage (C3)

Une section « Serviteurs » permet d'ajouter, renommer, changer le type et le rang, ou retirer un serviteur. Le motif est le même que pour le reste de C3.
- **Retrait :** la fiche détaillée reçoit `releasedAt` à l'enregistrement suivant de C3, dans un lot séparé et sans bloquer.
- **Affichage :** la fiche du domitor montre « X : points indisponibles jusqu'au … ».

### Joueur

- **Section « Serviteurs » sur la fiche (J2), aussi sur C3 en lecture :** nom, type, rang, échéance, avec une alerte si elle est proche ou passée. Chaque serviteur mène à sa fiche en lecture : `/joueur/personnages/:id/serviteurs/:sid`, sans la note secrète.
- **Écran XP :** « Nouveau serviteur » (nom, humain ou animal, rang) et « Serviteur X » pour monter de rang. La note de la demande porte la proposition du joueur (espèce, origine, qualités souhaitées). Le conte valide comme toute demande.

## Règles Firestore

- **`servants/{id}` :**
  - lecture : `isStaff()`, ou `auth.uid in holderPlayers` ;
  - création et modification : `managesAccounts()`, fiche valide, version 1 puis version précédente + 1, entrée d'historique dans le même lot ;
  - suppression : `managesAccounts()`.
- **Fiche valide :**
  - `kind` parmi les trois types ;
  - nom de 1 à 80 caractères ;
  - `vitae` entier de 0 à 5, `bond` entier de 0 à 3 ;
  - listes pour `specialties`, `qualities` et `holderPlayers`.
- **`private/{doc}` :** lecture par l'équipe, écriture par le conte.
- **`history/{h}` :**
  - lecture : l'équipe ;
  - création : le conte, avec `byUid`, `at == request.time` et `lastHistoryId == h` ;
  - suppression : le conte.
- **Fiche du personnage :** vérifier qu'aucune règle à liste de clés ne bloque `servants` sur les chemins du conte.

## Erreurs et cas limites

- **Conflit :** la base de l'enregistrement est figée à l'ouverture de la fiche. Si deux conteurs modifient la même fiche, le second voit « Modifié entre-temps : rechargez la page. ». Les autres refus affichent « Enregistrement refusé : réessayez. ».
- **Serviteur sans fiche détaillée :** il apparaît « à compléter ». La fiche détaillée est créée au premier enregistrement du conte.
- **Note secrète illisible :** le formulaire reste masqué, avec un bouton « Réessayer ».
- **Suppression refusée :** message, le bouton est désactivé pendant l'opération.
- **Conversion :** idempotente, avec des identifiants stables ; elle ne crée jamais de doublon.

## Hors périmètre

- Goule jouée, passage de mortel à goule et étreinte : 6c.
- Page de demande dédiée J-Animal : l'écran XP la remplace.
- Décompte des parties pour l'indisponibilité : seule la date de fin (6 semaines) est gérée.
