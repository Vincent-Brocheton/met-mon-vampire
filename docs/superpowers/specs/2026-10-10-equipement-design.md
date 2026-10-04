# Équipement (sous-projet 6f) : conception

## Objectif

Les objets des personnages sont gérés dans l'application :
- le joueur demande un objet construit avec le système de génération d'équipement ;
- le conte le valide ou le refuse, puis le gère : il le donne, le modifie, le confisque ou le détruit.

Le livre de base demande que chaque carte d'objet soit approuvée par le conte avant d'entrer en jeu.

Maquettes :
- C-Objets et J-Equipement, avec leurs versions mobiles ;
- C-Equipement (qualités et règles de base par catégorie) existe déjà dans le référentiel.

## Décisions

- **Collection à part `items/{id}`**, sur le modèle des lieux et des serviteurs : note secrète, historique, version. La fiche du personnage n'est pas modifiée.
- **Demande refusée :** l'objet passe à l'état « Refusée », avec le motif visible par le joueur. Le joueur peut la supprimer et en refaire une.
- **Qualités proposées au joueur :** celles de la catégorie à l'état « Disponible » ou « Accord du conte ». Les secondes sont signalées au conte. Les qualités interdites ne sont jamais proposées.
- **Qualité hors limite :** une au plus, en plus des qualités de la gamme, posée par le conte seul.
- **Historique :** chaque écriture du conte est tracée (date, auteur, résumé, motif).

## Règles du jeu retenues

- **Catégories :** armes de mêlée, armes à distance, protections, matériel divers.
- **Gamme :**
  - un objet courant a 2 qualités au plus ;
  - un objet bon marché ou improvisé en a 1.
  - Les valeurs viennent des règles de base de la catégorie dans le référentiel (`qualitiesNormal`, `qualitiesCheap`). À défaut : 2 et 1.
- **Qualités :**
  - une qualité doit appartenir à la catégorie de l'objet ;
  - deux qualités incompatibles ne vont pas ensemble ;
  - une qualité marquée « ne compte pas dans la limite » (`outsideLimit`) est la qualité hors limite.
- **Aide affichée :** dégâts de base et nombre de mains de la catégorie.

## Données : `items/{id}`

| Champ | Contenu |
|---|---|
| `name` | nom, 80 caractères au plus |
| `category` | `melee`, `ranged`, `armor` ou `gear` |
| `grade` | `normal` (courant) ou `cheap` (bon marché) |
| `qualities` | noms des qualités de la gamme |
| `extraQuality` | qualité hors limite, ou absente |
| `characterId`, `characterName` | porteur, ou vide (réserve du conte) |
| `playerUid` | joueur du porteur, pour l'accès ; vide sinon |
| `state` | `requested`, `active`, `refused`, `confiscated` ou `destroyed` |
| `description` | description de l'objet |
| `origin` | « Comment l'obtient-il ? » (demande du joueur) |
| `refusal` | motif du refus |
| `version`, `lastHistoryId`, `createdAt`, `updatedAt`, `updatedByName` | suivi |

Sous-documents :
- `items/{id}/private/note` : note secrète du conte ;
- `items/{id}/history/{h}` : historique, au format partagé (`TraceEntry`).

## Contrôles (calcul pur, partagé par les deux écrans)

`itemChecks(item, rulebook, {byPlayer})` renvoie des erreurs et des avertissements :

- **Erreurs :**
  - « Nom obligatoire » ;
  - « X qualités au plus pour un objet courant (bon marché) » ;
  - « X : pas une qualité de cette catégorie » ;
  - « X et Y sont incompatibles » ;
  - « X est interdite » ;
  - « X ne compte pas dans la limite : à poser comme qualité hors limite » ;
  - pour le joueur, en plus : « Les qualités hors limite sont posées par le conte ».
- **Avertissement :** « X demande l'accord du conte ».

Une écriture est impossible tant qu'il reste une erreur.

## Règles Firestore

- **Lecture :** l'équipe, ou le joueur de l'objet (`resource.data.playerUid == uid`). La note secrète et l'historique sont réservés à l'équipe.
- **Le joueur crée une demande** si toutes ces conditions sont réunies :
  - `state == 'requested'`, `version == 1` ;
  - `playerUid == uid` ;
  - la fiche `characters/{characterId}` existe et a `playerUid == uid` ;
  - pas d'`extraQuality`, ni de `refusal` ;
  - clés limitées à la liste du tableau ;
  - nom de 1 à 80 caractères.
- **Le joueur supprime** sa demande si elle est à l'état `requested` ou `refused`. Il ne modifie rien.
- **Le conte (`managesAccounts`)** crée, modifie et supprime : version + 1, entrée d'historique avec motif, comme pour les lieux. Le narrateur lit seulement.

## Écrans

### Conte : « Objets en jeu », `/conteur/objets` (C-Objets)

- **Liste :**
  - colonnes : objet, catégorie, qualités, porté par, état ;
  - filtres :
    - catégorie ;
    - état : demandes à valider, en jeu, refusées, confisqués ou détruits ;
  - recherche sur l'objet ou le personnage.
- **Panneau d'édition :**
  - nom, catégorie, gamme ;
  - qualités, selon la gamme ;
  - qualité hors limite ;
  - porteur (fiches actives, ou « Personne (réserve du conte) ») ;
  - état, description, note secrète ;
  - motif de l'enregistrement ;
  - encart des règles de base de la catégorie ;
  - historique.
- **Demande à valider :**
  - affiche « Comment l'obtient-il ? » et les avertissements « accord du conte » ;
  - boutons « Valider » (état « En jeu ») et « Refuser… » (motif obligatoire).
- **« + Nouvel objet »** ouvre le panneau vide. « Supprimer » demande une confirmation.
- **Accès :**
  - depuis la page des fiches, lien « Objets en jeu » ;
  - lien vers le référentiel des qualités.

### Joueur : « Équipement », `/joueur/personnages/:id/equipement` (J-Equipement)

- **Liste des objets du personnage :** catégorie, qualités, gamme, état. Le motif s'affiche sous une demande refusée.
- **Formulaire « Demander un objet » :**
  - nom, catégorie, gamme ;
  - qualités, limitées aux qualités disponibles et à accord de la catégorie ;
  - « Comment l'obtient-il ? » ;
  - les contrôles s'affichent en direct ;
  - le bouton s'intitule « Envoyer la demande ».
- **« Supprimer »** sur une demande en attente ou refusée.
- **Accès :** un lien « Équipement » sur la fiche du joueur (J2), pour une fiche active.

### Fiche C3

Une section « Équipement » liste les objets du personnage (nom, qualités, état), avec un lien vers « Objets en jeu ».

## Erreurs et cas limites

- **Conflit de version :** « Modifié entre-temps : rechargez la page. » ; les autres refus affichent « Enregistrement refusé : réessayez. ».
- **Qualité retirée du référentiel ou devenue interdite :** l'objet garde le nom. Le panneau du conte affiche l'erreur, et le conte doit corriger avant d'enregistrer.
- **Porteur supprimé ou retiré :** l'objet garde le nom du porteur. Le conte peut le donner à un autre personnage ou le placer dans la réserve.
- **Joueur du porteur changé :** l'accès ne suit pas automatiquement. Le conte réenregistre l'objet, et le porteur recopie le joueur de la fiche.

## Tests

- **Calculs purs :**
  - contrôles des qualités : nombre selon la gamme, catégorie, incompatibilités, interdites, accord, hors limite, demande du joueur ;
  - règles de base par défaut.
- **Règles d'accès :**
  - lecture par le joueur de l'objet seulement ;
  - demande du joueur pour son propre personnage seulement, sans qualité hors limite ;
  - le joueur ne modifie pas ;
  - le joueur supprime une demande en attente ou refusée, mais pas un objet en jeu ;
  - écriture du conte avec version et historique ;
  - le narrateur lit seulement.
- **Écrans :**
  - demande du joueur ;
  - validation et refus par le conte ;
  - création, confiscation, suppression ;
  - section de C3.

## Hors périmètre

- Coût en Ressources, acquisition par action d'intermède.
- Modification d'un objet en jeu par le joueur.
- Fiche imprimée (sous-projet 8).
