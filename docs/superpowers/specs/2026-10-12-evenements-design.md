# Événements (sous-projet 7a) : conception

## Objectif

Chaque fiche a une chronologie d'événements marquants, tenue par le conte :
- le conte ajoute, modifie et supprime des événements datés, avec trois niveaux de visibilité ;
- le joueur voit, dans l'onglet « Récit », les événements qui lui sont ouverts ;
- la validation d'une fiche et l'étreinte écrivent leur événement automatiquement.

Le sous-projet 7 est découpé en lots :
- 7a Événements (ce document) ;
- 7b Moralité ;
- 7c Liens de sang ;
- 7d Titres ;
- 7e Récit.

Les lots 7b à 7d ajouteront leurs propres événements (péché, gorgée, titre).

Maquettes : C-Evenements, J-Recit, avec leurs versions mobiles (canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp).

## Décisions

- **Visibilité :** `public`, `player` (joueur et conte) ou `staff` (conte seul).
  - Pour l'instant, un événement `public` est vu comme `player` : par le joueur de la fiche et l'équipe.
  - Une chronologie ouverte à tous viendra avec le journal (sous-projet 10).
- **Pas de conséquence sur la fiche :** un événement est un récit daté. Il ne modifie jamais la fiche. Le conte corrige la fiche dans C3 si besoin.
- **Événements automatiques :** « Fiche validée » et « Étreinte », écrits dans le même lot que l'action qui les cause.

## Données

### Collection `characters/{id}/events/{e}`

| Champ | Contenu |
|---|---|
| `type` | une valeur de la liste des types (ci-dessous) |
| `title` | 1 à 80 caractères |
| `description` | 2000 caractères au plus, peut être vide |
| `year` | 1 à 9999, obligatoire |
| `month` | 1 à 12, ou absent |
| `day` | 1 à 31, ou absent ; absent si `month` est absent |
| `visibility` | `public`, `player` ou `staff` |
| `auto` | vrai pour un événement automatique |
| `byUid`, `byName` | auteur de la dernière écriture |
| `createdAt`, `updatedAt` | horodatages du serveur |

**Types :**
- Diablerie ;
- Titre obtenu ;
- Titre perdu ;
- Changement de secte ;
- Voie adoptée ;
- Chasse de sang ;
- Torpeur ;
- Réveil ;
- Mort ultime ;
- Étreinte ;
- Fiche ;
- Intrigue ;
- Renommée ;
- Autre.

Chaque type a une couleur de pastille :
- sang (Diablerie) ;
- titre (Titre obtenu et perdu) ;
- moralité (Voie adoptée) ;
- vie (Étreinte, Fiche, Torpeur, Réveil, Mort ultime) ;
- intrigue (les autres).

**Date à précision variable :** l'année est obligatoire, le mois et le jour sont facultatifs. Exemples : « 1974 », « sept. 2026 », « 20 sept. 2026 ».

**Tri :** du plus récent au plus ancien, par année, puis mois, puis jour. Une valeur absente compte comme la plus petite : « sept. 2026 » s'affiche après « 20 sept. 2026 », et « 2026 » après les deux. En cas d'égalité, le plus récemment créé passe en premier.

**Source affichée :**
- « Automatique » si `auto` ;
- sinon « Saisi par <byName> ».

Les événements n'ont ni version ni historique : la création, la modification et la suppression sont directes.

## Calculs purs (`lib/events/event_rules.dart`)

- `formatEventDate(e)` : la date selon sa précision.
- `compareEvents(a, b)` : l'ordre de la chronologie.
- `eventChecks(e)` renvoie les erreurs :
  - « Titre obligatoire » ;
  - « Titre : 80 caractères au plus » ;
  - « Année invalide » ;
  - « Mois invalide » ;
  - « Jour invalide » ;
  - « Jour sans mois » ;
  - « Description : 2000 caractères au plus ».
- `visibleTo(e, {required bool staff})` : l'équipe voit tout, le joueur voit `public` et `player`.
- Libellés de visibilité :
  - pour l'équipe : « Public », « Joueur et conte », « Conte seul » ;
  - pour le joueur : « Public », « Vous et le conte ».

## Règles Firestore

`match /characters/{id}/events/{e}` :
- **lecture :**
  - `isStaff()` ;
  - ou le joueur de la fiche (`get(charPath(id)).data.playerUid == auth.uid`) si `resource.data.visibility in ['public', 'player']`.
  - La requête du joueur filtre donc sur `visibility in ['public', 'player']`.
- **création et modification :**
  - `managesAccounts()` ;
  - clés limitées à la liste ci-dessus ;
  - `type` dans la liste des types ;
  - titre de 1 à 80 caractères ;
  - description de 2000 caractères au plus ;
  - année, mois et jour dans leurs bornes, sans jour en l'absence de mois ;
  - `visibility` dans les trois valeurs ;
  - `auto` booléen ;
  - `byUid == auth.uid`.
- **suppression :** `managesAccounts()`.

Les règles de la fiche ne changent pas. Les écritures automatiques sont faites par le conte, dans le même lot que la modification de la fiche.

## Écrans

### Équipe : onglet « Événements » de la fiche (C-Evenements)

- **Route :** `/conteur/fiches/:id/evenements`.
- **Onglet :**
  - placé entre « Fiche » et « Historique » ;
  - l'onglet « Récit » devient actif pour l'équipe (voir ci-dessous) ;
  - « Moralité & liens » reste « À venir ».
- **Chronologie :**
  - une ligne par événement : pastille de couleur, date, type, titre, description, étiquette de visibilité, source ;
  - filtres : Tous, Public, Joueur et conte, Conte seul, plus une liste « Tous les types » ;
  - vide : « Aucun événement. ».
- **Panneau « Ajouter un événement » à droite :**
  - champs : Type, Année, Mois (facultatif), Jour (facultatif), Titre, « Ce qui s'est passé », « Qui le voit » ;
  - les erreurs de `eventChecks` apparaissent en direct, et le bouton « Ajouter l'événement » reste inactif tant qu'il y en a.
  - **Modifier :** toucher une ligne ouvre le panneau en modification, avec « Enregistrer » et « Supprimer ».
  - **Supprimer :** une confirmation est demandée par une boîte de dialogue de l'application.
- **Narrateur :** chronologie sans panneau.
- **Mobile :** la chronologie en pleine page. « + Ajouter » ou une ligne ouvre le panneau en pleine page, avec « ← Retour ».

### Joueur et équipe : onglet « Récit » (J-Recit)

- **Routes :** `/joueur/personnages/:id/recit` et `/conteur/fiches/:id/recit`.
- **À gauche :**
  - le concept ;
  - le récit de la fiche (`story`) en lecture, ou « Aucun récit. ».
- **À droite :**
  - « Événements marquants · Tenus par le conte » : la chronologie en lecture ;
  - pour le joueur : seulement les événements `public` et `player`, étiquetés « Public » ou « Vous et le conte » ;
  - pour l'équipe : tous les événements.
- **Mobile :** le récit, puis les événements, en une colonne.
- Le bouton « Proposer une modification du récit » arrive au lot 7e.

## Événements automatiques

- **Fiche validée :**
  - déclenchement : `decide` vers `active` ;
  - même lot que la validation ;
  - type « Fiche », titre « Fiche validée », description « Entrée en jeu de <nom>. » ;
  - date du jour, `player`, `auto`.
- **Étreinte :**
  - sur la fiche étreinte ;
  - déclenchement : l'étreinte d'une goule jouée (C3, modification de type `embrace`) et l'étreinte d'un mortel ou d'un serviteur (`embraceFollower`, création de fiche) ;
  - même lot que l'écriture de la fiche ;
  - type « Étreinte », titre « Étreinte par <sire> » (« Étreinte » si le sire n'est pas renseigné) ;
  - date du jour, `player`, `auto`.

## Erreurs et cas limites

- **Refus d'écriture :** « Enregistrement refusé : réessayez. ».
- **Chargement en échec :** l'état d'erreur habituel, avec « Réessayer ».
- **Fiche supprimée :** ses événements restent, sans accès par l'interface.
- **Événement modifié par un autre conte entre-temps :** la dernière écriture l'emporte. C'est accepté : pas de version.

## Tests

- **Calculs purs :**
  - format de date selon la précision ;
  - tri, dont les valeurs absentes et l'égalité ;
  - `eventChecks` ;
  - `visibleTo` et libellés.
- **Règles d'accès :**
  - l'équipe lit tout ;
  - le joueur lit `public` et `player` de sa fiche, pas `staff`, et sa requête sans filtre est refusée ;
  - un autre joueur ne lit rien ;
  - le narrateur ne peut pas écrire ;
  - refus : type inconnu, jour sans mois, titre vide, clé en trop.
- **Écrans :**
  - le conte ajoute, modifie, supprime et filtre ;
  - le narrateur est en lecture seule ;
  - l'onglet Récit du joueur n'affiche pas les événements `staff`.
- **Automatiques :**
  - la validation écrit « Fiche validée » ;
  - l'étreinte (C3 et `embraceFollower`) écrit « Étreinte par … ».

## Hors périmètre

- Les conséquences sur la fiche (génération, péché, aura).
- Une page « Chronique » publique.
- La modification du récit par demande (7e).
- Les événements créés par les péchés (7b), les gorgées (7c) et les titres (7d).
- Les événements de mort ou de retraite décidées depuis C3.
