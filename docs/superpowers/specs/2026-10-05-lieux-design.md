# Portail Personnages MET — Sous-projet 6a : Lieux d'intérêt

**Date :** 2026-10-05.

**Statut :** validé en conversation, en attente de relecture.

**Dépend de :**
- sous-projet 2, Fiche (`2026-10-02-fiche-design.md`) ;
- sous-projet 5, Référentiel (`2026-10-03-referentiel-design.md`), catégorie « Qualités de lieu ».

**Maquettes :** `C-Lieux`, `C-Lieux-mobile`, `J-Lieux`, `J-Lieux-mobile`.

**Règles :** MET Volume 2 n° 1, « Stock Locations » (p. 122 et suivantes).

**Découpage du sous-projet 6 :**
- **6a** (ce document) : lieux d'intérêt ;
- **6b** : goules (jouées, serviteurs, animales, mortels suivis).

Les PNJ confiés, les alliés détaillés et les objets sont hors périmètre de l'application, selon le choix de l'utilisateur.

## Objectif

Le conte crée les lieux d'intérêt de la chronique, les décrit avec leurs qualités et les attribue à des personnages. Les joueurs voient les lieux de leurs personnages et ceux que tout le monde connaît.

## Décisions

1. **Seul le conte crée, modifie, attribue et supprime un lieu.** Le joueur lit seulement.
2. **Visibilité côté joueur :**
   - le détail des lieux de ses personnages ;
   - les lieux marqués « connus de tous » : nom, type, ce qui s'en sait, sans contrôleur ni qualités.
3. **Le stockage garantit cette visibilité.** Le lieu est privé ; un résumé public séparé existe pour les lieux connus de tous. Les règles Firestore empêchent un joueur de lire ce qu'il ne doit pas voir.
4. **Les limites avertissent sans bloquer.** Concernées : le nombre de qualités, les qualités permises, la qualité surnaturelle unique, et le nombre de lieux contrôlés par personnage.
5. **Chaque changement d'un lieu laisse une entrée dans son historique**, visible par l'équipe : qui, quand, quoi, motif facultatif.

## Hors périmètre

| Élément | Où |
|---|---|
| Le refuge (Haven) | reste un historique |
| Les quêtes pour prendre, modifier ou saboter un lieu | se jouent en partie ; l'application affiche seulement le type de quête et sa difficulté |
| La page du lieu dans le wiki | sous-projet 9 |
| Les demandes de lieu faites par un joueur | non retenu |
| Les lieux gérés par une autre chronique (contrôle à distance) | non retenu |

## Règles du livre reprises

| Type | Qualités au plus | Quête (obtenir, modifier, toucher) | Contrôle |
|---|---|---|---|
| Standard (`standard`) | rang | simple, difficulté = rang | tout personnage |
| Prestige (`prestige`) | rang × 2 | complexe, difficulté = rang | personnages de la ville seulement |
| Iconique (`iconic`) | rang × 2, qualités iconiques permises | héroïque | au choix du conte |

- **Rang :** de 1 à 5.
- **Infiltration en jeu :** difficulté 5 × rang (maquette).
- **Limite de contrôle :** un personnage contrôle au plus 5 lieux, plus 1 par point de l'historique Serviteurs.
- **Qualités, lues dans le référentiel « Qualités de lieu »**, champ `family` :
  - **standard et iconique :** elles comptent dans le maximum. Une qualité iconique n'est permise que sur un lieu iconique.
  - **surnaturelle :** une seule par lieu, hors du maximum.
  - **négative :** répétable de 1 à `repeatable` fois (3 au plus), hors du maximum.
  - **Élysée :** règle spéciale, hors du maximum.
- **`placeTypes` d'une qualité :** il restreint les types de lieu qui peuvent la porter. Vide : tous les types.
- **Hypothèse retenue :** le maximum ne compte que les qualités standard et iconiques. C'est la présentation de la maquette (« 6 sur 8 », surnaturelle et négatives à part).

## Modèle de données

### `places/{id}` — le lieu (privé)

```
name            string, 1 à 80 caractères
type            'standard' | 'prestige' | 'iconic'
rank            int, 1 à 5
qualities       [{ name: string, count: int }]   count de 1 à 3 ; 1 pour une qualité non répétable
holders         [{ id: string, name: string }]   personnages attribués (PJ ou PNJ)
holderIds       [string]                          les id de holders (requêtes)
holderPlayers   [string]                          playerUid des holders qui en ont un (droit de lecture)
public          bool                              connu de tous
known           string                            ce que savent ceux qui le connaissent
version         int                               +1 à chaque modification
lastHistoryId   string                            dernière entrée d'historique
createdAt, updatedAt, updatedByName
```

- **`places/{id}/private/note` :** `{ text }`, la note secrète du conte.
- **`places/{id}/history/{h}` :** `{ at, byUid, byName, summary: [string], reason: string }`.

### `publicPlaces/{id}` — le résumé public

```
name, type, known
```

- Il est écrit dans le même lot que le lieu quand `public` est vrai, et supprimé dans le même lot quand `public` devient faux ou que le lieu est supprimé.
- Il porte le même identifiant que le lieu.

## Écrans

### « Lieux d'intérêt » (`/conteur/lieux`)

- **Accès :** les conteurs et le principal modifient ; le narrateur lit seulement. Un bouton « Lieux d'intérêt » y mène depuis la page des fiches (C2).
- **Web :**
  - à gauche, la liste : lieu, type, rang en pastilles, attribué à, qualités « N / M », qualités négatives ;
  - à droite, le panneau d'édition.
- **Mobile :** la liste, puis l'édition en page entière.
- **Filtres :**
  - type : tous, standard, prestige, iconique ;
  - contrôle : tous, attribués, non attribués, avec une qualité négative ;
  - recherche sur le nom du lieu ou du personnage.
- **Panneau d'édition :**
  - nom, type, rang ;
  - **personnages attribués :** des puces, avec retrait, et l'ajout par un menu de toutes les fiches (PJ ou PNJ, avec leur statut) ;
  - **qualités :** des puces, et un compteur « N sur M (rang R × 2) ». L'ajout se fait par un menu des qualités standard et iconiques du référentiel. Les qualités brouillon ou interdites ne sont pas proposées, et celles d'un type non permis sont signalées ;
  - **qualité surnaturelle :** un menu (« Aucune » et les qualités de la famille) ;
  - **Élysée :** une case ;
  - **qualités négatives :** chaque qualité de la famille, avec son nombre de 0 à `repeatable` ;
  - **repère calculé :** « Quête complexe, difficulté 4, pour le modifier ou l'atteindre. Infiltration en jeu : difficulté 20. » ;
  - « Ce que savent ceux qui le connaissent », « Connu de tous », « Note secrète du conte » ;
  - les avertissements (section Calculs) ;
  - un motif facultatif, et « Enregistrer » ;
  - « Retirer à tous » et « Supprimer », chacun avec confirmation ;
  - l'historique du lieu (les entrées les plus récentes d'abord).
- **Nouveau lieu :** le panneau s'ouvre vide (type standard, rang 1).

### « Lieux » d'un personnage (`/joueur/personnages/:id/lieux`)

- **Accès :** le joueur du personnage, et l'équipe.
- **Cartes des lieux du personnage :**
  - nom, rang en pastilles, type ;
  - qualités (avec la surnaturelle, l'Élysée et les négatives) ;
  - « Partagé avec … » ou « À vous seul » ;
  - ce que savent ceux qui le connaissent.
- **« Lieux connus de tous » :** nom, type, et ce qui s'en sait, pour les lieux publics que le personnage ne contrôle pas.
- **Rappel :** « Lecture seule. Seul le conte crée un lieu et l'attribue. Votre refuge n'est pas ici : c'est un historique. »

### Fiche du personnage

- **Une section « Lieux » :** les noms des lieux contrôlés, avec un lien vers la page des lieux. Elle s'affiche pour le joueur (J2) et pour le conte (C1).

## Calculs (`lib/places/place_rules.dart`, pur)

- `maxQualities(type, rank)` : le rang (standard), ou le rang × 2 (prestige, iconique).
- `qualityCount(place, rb)` : le nombre de qualités standard et iconiques.
- `questText(type, rank)` : « Quête simple, difficulté R » ; « Quête complexe, difficulté R » ; « Quête héroïque » (iconique).
- `infiltration(rank)` : 5 × rang.
- `placeWarnings(place, rb, places, characters)` — avertissements :
  - « N qualités sur M : trop pour un lieu de rang R » ;
  - « X : qualité iconique, réservée aux lieux iconiques » ;
  - « X : non permise pour un lieu Y » (`placeTypes`) ;
  - « Une seule qualité surnaturelle par lieu » ;
  - « X : hors du référentiel » ;
  - « X est interdite dans la chronique » (état brouillon ou interdit) ;
  - « X : N fois, M au plus » (qualité négative) ;
  - « Nom contrôle N lieux sur L (5 + Serviteurs) » ;
  - « Nom est une fiche retirée ou morte » ;
  - « Le joueur de Nom a changé : enregistrez pour mettre à jour l'accès ».
- `placeChanges(before, after)` : une ligne par changement (nom, type, rang, attribution, qualités, visibilité, ce qui s'en sait, note), pour l'historique.

## Sécurité (`firestore.rules`)

- **`places/{id}` :**
  - **lecture :** `isStaff()`, ou `request.auth.uid in resource.data.holderPlayers` ;
  - **création :** `managesAccounts()`, avec `version == 1`, un lieu valide et son entrée d'historique créée dans le même lot ;
  - **modification :** `managesAccounts()`, avec `version == old + 1`, un lieu valide et une nouvelle entrée d'historique dans le même lot (`lastHistoryId`, comme pour les fiches) ;
  - **suppression :** `managesAccounts()` ;
  - **lieu valide :** `name` est une chaîne de 1 à 80 caractères ; `type` vaut l'une des trois valeurs ; `rank` est un entier de 1 à 5 ; `qualities`, `holders`, `holderIds` et `holderPlayers` sont des listes ; `public` est un booléen.
- **`places/{id}/private/{doc}` :** lecture par `isStaff()`, écriture par `managesAccounts()`.
- **`places/{id}/history/{h}` :** lecture par `isStaff()` ; création par `managesAccounts()`, avec `byUid == auth.uid`, `at == request.time`, et l'entrée référencée par le lieu après écriture.
- **`publicPlaces/{id}` :** lecture si connecté ; écriture par `managesAccounts()`, avec seulement les clés `name`, `type` et `known`.

## Architecture du code

```
lib/places/place.dart              Place, PlaceQuality, PlaceHolder (fromMap, toMap, publicMap)
lib/places/place_rules.dart        calculs et avertissements (pur)
lib/places/places_repository.dart  watchAll (équipe), watchMine (joueur), watchPublic, watchNote, watchHistory,
                                   save (lot : lieu, résumé public, note, historique), delete ; providers
lib/places/places_screen.dart      écran du conte (Web et mobile)
lib/places/character_places_screen.dart   écran du joueur
lib/characters/sheet_widgets.dart  section « Lieux » (liste fournie par l'écran)
lib/router.dart                    /conteur/lieux, /joueur/personnages/:id/lieux
```

- Les qualités sont lues dans le `Rulebook` (`rulebookProvider`, catégorie `placeQualities`).
- L'historique Serviteurs est celui de la fiche (`backgrounds`, nom « Serviteurs »).

## Tests

- **Unitaires :**
  - `maxQualities` et `questText` pour chaque type ;
  - chaque avertissement : un cas qui passe et un cas qui échoue ;
  - la limite de contrôle avec et sans Serviteurs ;
  - `placeChanges` ;
  - l'aller-retour `fromMap` / `toMap`, et `publicMap`.
- **Règles (émulateur) :**
  - un joueur lit le lieu de son personnage, mais pas celui d'un autre ;
  - un joueur ne lit ni la note secrète ni l'historique, et n'écrit rien ;
  - les résumés publics sont lisibles par tout joueur connecté, et rien d'autre n'y est écrit ;
  - une modification sans version + 1, ou sans entrée d'historique, est refusée ;
  - un lieu invalide est refusé (rang 6, type inconnu, nom vide) ;
  - le narrateur lit tout et n'écrit rien.
- **Widgets :**
  - créer un lieu, l'attribuer, ajouter des qualités au-delà du maximum : l'avertissement s'affiche, et l'enregistrement reste possible ;
  - cocher « Connu de tous » écrit le résumé public ; décocher le supprime ;
  - écran du joueur : ses lieux et les lieux publics, sans les lieux privés des autres ;
  - narrateur en lecture seule ;
  - section « Lieux » de la fiche.

## Cas à vérifier à la revue

1. **Un lieu passe de public à privé :** le résumé public disparaît dans le même lot.
2. **Le conte retire un personnage d'un lieu :** le joueur de ce personnage ne peut plus lire le lieu.
3. **Deux conteurs modifient le même lieu :** la version refuse le second, avec « Modifié entre-temps : rechargez ».
4. **Une qualité est supprimée ou interdite dans le référentiel :** le lieu la garde, et un avertissement s'affiche.
5. **Un lieu est attribué à une fiche retirée ou morte :** c'est accepté et signalé.
