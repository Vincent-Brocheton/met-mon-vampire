# Dérangements (sous-projet 7b2) : conception

## Objectif

La fiche porte des dérangements détaillés, visibles dans l'onglet « Moralité & liens » :
- le conte ajoute, modifie et retire les dérangements d'une fiche, et règle les traits de dérangement en jeu ;
- les handicaps pris à la création qui correspondent à un modèle de dérangement sont signalés « à détailler » ;
- le joueur voit ses dérangements et peut en demander un, validé par le conte, sans gain d'XP.

Lots du sous-projet 7 :
- 7a Événements (fait) ;
- 7b Moralité (fait) ;
- 7b2 Dérangements (ce document) ;
- 7c Liens de sang ;
- 7d Titres ;
- 7e Récit.

Maquettes : bloc « Dérangements » de C-Moralite et J-Moralite, avec leurs versions mobiles ; référentiel C-Derangements, déjà en place (canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp).

## Règles du jeu retenues (maquette C-Derangements)

- Un dérangement est un handicap de 2 points, ou de 3 si son déclencheur est très courant (dérangement sévère).
- Les traits de dérangement vont de 0 à 3. À 3 : réaction extrême, puis retour à 0.
- Un Malkavien n'a jamais moins de 1 trait. Son dérangement de clan est incurable et ne rapporte pas d'XP.

## Décisions

- **Demande du joueur :** sans gain d'XP. C'est une demande de rôle, validée par le conte. Elle réutilise les demandes d'XP sous la forme d'un achat « Dérangement » à 0 XP, comme les alliés (6g).
- **Création inchangée :** le handicap reste dans la liste des handicaps (nom et points). Sur une fiche jouée, il est signalé « à détailler », et le conte crée le dérangement détaillé en un clic, sans mouvement d'XP.
- **Traits en jeu :** un compteur réglé par le conte.

## Données

### Sur la fiche (clés tardives)

Les deux clés tardives sont écrites seulement si elles ne sont pas vides ou si elles étaient déjà présentes. Elles sont protégées dans le brouillon du joueur, et le brouillon ne les écrit jamais.

- **`derangements` :** une liste de `{id, name, type, trigger, severe, clan}` :
  - `id` : stable, `<characterId>-d<horodatage en base 36><compteur>` ;
  - `name` : 1 à 80 caractères ;
  - `type` : `belief`, `incapacity`, `compulsion`, `phobia`, `destruction` ou `obsession`. Ce sont les valeurs du champ `type` du référentiel, affichées Croyance, Incapacité, Compulsion, Phobie, Destruction, Obsession ;
  - `trigger` : déclencheur, 200 caractères au plus, peut être vide ;
  - `severe` : vrai pour 3 points, faux pour 2 ;
  - `clan` : dérangement de clan, incurable, qui ne rapporte pas d'XP.
- **`derangementTraits` :** un entier de 0 à 3.

**Plancher du compteur :** 1 si le clan de la fiche est « Malkavien » (sans tenir compte de la casse), 0 sinon.

**Historique de la fiche :**
- « + Dérangement Peur du feu » ;
- « Dérangement Peur du feu modifié » ;
- « − Dérangement Peur du feu » ;
- « Traits de dérangement : 1 → 2 ».

### Demande du joueur

- Un achat `XpKind.derangement`, au coût de 0. Son nom est celui du dérangement. Il porte le détail dans un champ `derangement` : `{type, trigger, severe, clan: false}`.
- La validation par le conte ajoute le dérangement à la fiche. Elle est refusée si les données sont invalides ou si un dérangement du même nom existe déjà (« Un dérangement porte déjà ce nom »).
- L'annulation par correction retire le dérangement de ce nom.
- Cet achat n'apparaît pas dans l'écran XP habituel. Il se demande depuis la page Moralité.

### À détailler

Sur une fiche active, retirée ou morte, ou sur un PNJ : chaque handicap dont le nom correspond à un modèle du référentiel `derangements`, et qu'aucun dérangement détaillé de la fiche ne porte déjà sous ce nom (sans tenir compte de la casse).

## Calculs purs (`lib/morality/derangement_rules.dart`)

- `derangementTypes` : les six types et leurs libellés.
- `derangementChecks(d, existing)` renvoie les erreurs :
  - « Nom obligatoire » ;
  - « Nom : 80 caractères au plus » ;
  - « Type inconnu » ;
  - « Déclencheur : 200 caractères au plus » ;
  - « Un dérangement porte déjà ce nom », qui ignore le dérangement lui-même lors d'une modification.
- `derangementPoints(d)` : 3 si sévère, 2 sinon.
- `derangementLine(d)` :
  - « Principal · clan » pour un dérangement de clan ;
  - sinon « Sévère · 3 pts » ou « 2 pts ».
- `traitsFloor(c)`, `clampTraits(c, n)`.
- `toDetail(c, rb)` : les handicaps à détailler.
- `fromModel(rb, name)` : un dérangement prérempli depuis un modèle du référentiel (nom, type).

## Règles Firestore

- `derangements` et `derangementTraits` rejoignent les clés protégées de `playerDraftSave`.
- Les chemins du conte (C3, XP, corrections, décision) les acceptent sans changement.
- Aucune nouvelle collection.

## Écrans

Les deux vues sont dans l'onglet « Moralité & liens » (`CharacterMoralityScreen`).

### Conte (bloc « Dérangements »)

- **Liste :**
  - chaque dérangement montre son nom, son type, sa ligne de points (`derangementLine`) et son déclencheur ;
  - un dérangement de clan ajoute « Incurable · ne rapporte pas d'XP » ;
  - « Modifier » et « Retirer » sur chaque dérangement ;
  - vide : « Aucun dérangement. ».
- **« + Ajouter » :** un formulaire avec :
  - un modèle facultatif, parmi les modèles proposés du référentiel, qui préremplit le nom et le type ;
  - nom, type, déclencheur ;
  - « Sévère (3 points) » et « Dérangement de clan » ;
  - les erreurs de `derangementChecks` en direct.
  - Chaque ajout, modification ou retrait est une modification tracée de la fiche, avec motif (dialogue habituel).
- **À détailler :** une ligne « <handicap> · handicap N pts — Détailler » par handicap concerné. « Détailler » ouvre le formulaire prérempli avec le modèle, sévère si le handicap vaut 3 points ou plus.
- **« Traits de dérangement en jeu » :**
  - des pastilles (●○○), avec « − » et « + » entre le plancher et 3 ;
  - « min. 1 (Malkavien) » pour un Malkavien ;
  - à 3 : « Réaction extrême, puis retour à 0. », et un bouton « Revenir au plancher » ;
  - chaque changement est une modification tracée, avec le motif automatique « Traits de dérangement », sans dialogue.
- **Lecture seule :**
  - pour le narrateur et pour le conte sur sa propre fiche (vue du joueur) ;
  - la liste et le compteur, sur une fiche en brouillon ou en validation qui n'est pas un PNJ.

### Joueur (bloc « Dérangements »)

- Ses dérangements, avec les mêmes lignes que pour le conte, en lecture.
- Le compteur, en lecture.
- Les demandes ouvertes, chacune marquée « En attente du conte ».
- **« Demander un dérangement »** (fiche active) : un formulaire avec :
  - un modèle facultatif, puis le nom, le type, le déclencheur et « Sévère (3 points) » ;
  - « Pourquoi ? », qui devient la justification ;
  - « Envoyer la demande », qui crée une demande à un seul achat, envoyée au conte.
- Le rappel : « Handicaps de 2 points, déclencheur au choix. ».

### Mobile

Une seule colonne.

## Erreurs et cas limites

- **Conflit de version :** « Modifié entre-temps : rechargez la page. ».
- **Autres refus :** « Enregistrement refusé : réessayez. ».
- **Clan changé :** le plancher suit le clan actuel. Un compteur sous le nouveau plancher s'affiche au plancher et s'enregistre au plancher au prochain changement.
- **Modèle retiré du référentiel :** les dérangements déjà détaillés restent ; le handicap n'est plus signalé « à détailler ».

## Tests

- **Calculs purs :**
  - contrôles, dont le doublon et la modification sans doublon avec soi-même ;
  - points, ligne, plancher, bornes du compteur ;
  - à détailler ;
  - prérempli depuis un modèle.
- **Fiche :** clés tardives, absentes du brouillon, changements tracés.
- **XP :**
  - demande à 0 XP ;
  - application ;
  - doublon et données invalides refusés à la validation ;
  - annulation ;
  - absent de l'écran XP.
- **Règles d'accès :**
  - les deux clés refusées dans le brouillon du joueur ;
  - brouillon sans elles accepté.
- **Écrans :**
  - le conte ajoute, modifie, retire et détaille un dérangement, et règle le compteur avec son plancher ;
  - le narrateur est en lecture seule ;
  - le joueur envoie une demande, voit « En attente du conte » et sa liste.

## Hors périmètre

- Le rachat d'un dérangement.
- Les dérangements infligés par un pouvoir.
- La modification de la création guidée.
- Les traits liés aux parties (sous-projet 8).
