# Parties et gel des fiches (sous-projet 8a) : conception

## Objectif

Avant une partie, le conte fige les fiches jouées. Une version figée de chaque fiche fait foi pendant la partie : c’est elle qu’on imprimera (8b) et qu’on emportera hors ligne (8c). Pendant le gel, l’XP des fiches figées ne bouge plus : ni dépense, ni gain.

Le sous-projet 8 est découpé en lots :
- 8a Parties et gel (ce document) ;
- 8b Impression ;
- 8c Hors ligne et appareils connectés.

Maquettes (canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp) :
- `C-Figer` (gel des fiches, côté conte), avec sa version mobile ;
- `J-Fiche`, bandeau « Fiche figée pour la partie du … ».

## Décisions

- **Instantané et verrou.** Au gel, une copie de chaque fiche est enregistrée. La fiche vivante reste modifiable, sauf son XP.
- **Gel par un clic du conte.** L’application n’a pas de Cloud Functions. « Figer maintenant » écrit les instantanés et ouvre le gel. Il se lève seul à l’heure prévue (les règles comparent `request.time`), ou plus tôt d’un clic.
- **Le verrou porte sur `xpEarned` et `xpSpent`.** Sont bloqués : la validation d’une dépense, le gain mensuel, l’attribution et la correction d’XP, toute édition qui touche l’XP. Restent permis : les demandes à 0 XP (allié, dérangement), les saisies de jeu (péchés, événements, liens de sang, titres) et les éditions du conte hors XP.
- **Pas de perte de gain.** Les mois du gel sont versés au premier versement après la levée, grâce à `gainedThrough`.
- **Fiches figées :** les PJ actifs et les PNJ qui ont un prêt actif à l’heure du gel. Pas de choix dans le formulaire.
- **Une nouvelle fiche validée pendant le gel n’est pas figée.** Elle joue à la partie suivante ; son XP reste libre.
- **Correction urgente :** le conte recopie la fiche vivante dans l’instantané, avec un motif.

## Données

### `games/{gameId}` : une partie

| Champ | Contenu |
|---|---|
| `date` | jour de la partie (minuit, heure locale) |
| `frozenAt` | heure du gel, égale à `request.time` |
| `until` | levée prévue ; par défaut le lendemain de la partie à 6h |
| `liftedAt` | levée anticipée, ou `null` |
| `liftedByUid` | auteur de la levée anticipée, ou `null` |
| `byUid` | auteur du gel |
| `sheetIds` | identifiants des fiches figées |

Le gel est **en cours** si `liftedAt == null` et que l’heure précède `until`.

### `chronicle/freeze` : pointeur

`{ gameId }` : la dernière partie figée. Les règles le lisent pour trouver le gel en cours en un seul `get`.

### `characters/{id}/frozen/{gameId}` : instantané

| Champ | Contenu |
|---|---|
| `sheet` | la fiche, `toMap()` complet |
| `version` | version de la fiche copiée |
| `gameDate` | date de la partie : l’écran du gel lit les instantanés d’une partie par ce champ (index `frozen.gameDate`, `firestore.indexes.json`) |
| `at` | heure de la copie |
| `byUid` | auteur de la copie |
| `reason` | `null` pour la copie initiale, le motif pour une correction urgente |

### Écritures

- **Figer :** un seul lot avec la partie, le pointeur et un instantané par fiche (environ 42 écritures).
- **Lever le gel :** `liftedAt` et `liftedByUid` sur la partie.
- **Correction urgente :** réécriture de l’instantané (`sheet`, `version`, `at`, `byUid`, `reason`).

## Calculs purs (`game_rules.dart`)

- `sheetsToFreeze(sheets, loans, now)` : les PJ actifs et les PNJ dont un prêt est actif (`loanState == active`).
- `isRunning(game, now)` et `isFrozen(game, characterId, now)`.
- `defaultUntil(date)` : le lendemain de la partie à 6h.
- `previousGame(games, game)` : le dernier gel figé avant celui-ci. Chaque fiche est comparée à son instantané de ce gel ; absente de ce gel, elle affiche « Première version figée ».
- `changeCount(previous, current)` : le nombre de lignes de `describeChanges`.
- **Textes :**
  - « Gel en cours · partie du samedi 3 octobre » ;
  - « Depuis le mardi 29 sept. à 20h, jusqu’au dimanche 4 oct. à 6h » ;
  - « Fiche figée pour la partie du samedi 3 oct. Vos demandes restent en file et seront traitées à partir du 4 oct. » ;
  - « 2 changements », « 1 changement », « Aucun », « Première version figée ».

## Règles Firestore

- **`games/{id}` :**
  - lecture : tout utilisateur connecté ;
  - création : `managesAccounts()` ; clés limitées au tableau ; `frozenAt == request.time` ; `until > request.time` ; `liftedAt` et `liftedByUid` nuls ; `byUid == request.auth.uid` ; `sheetIds` est une liste ; le pointeur désigne cette partie dans le même lot (`getAfter`) ; aucun gel en cours avant (la partie désignée par l’ancien pointeur, s’il existe, est levée ou dépassée) ;
  - mise à jour (levée) : `managesAccounts()` ; seuls `liftedAt` et `liftedByUid` changent ; `liftedAt == request.time` ; `liftedByUid == request.auth.uid` ; le gel était en cours ;
  - suppression : refusée.
- **`chronicle/freeze` :**
  - lecture : tout utilisateur connecté ;
  - écriture : `managesAccounts()`, clé `gameId` seule, et la partie désignée est créée dans le même lot.
- **`characters/{id}/frozen/{gameId}` :**
  - lecture : comme la fiche (son joueur et l’équipe) ;
  - création : `managesAccounts()`, clés limitées au tableau, `reason` nul ;
  - mise à jour : `managesAccounts()`, `reason` non vide ;
  - suppression : refusée.
- **Verrou, dans `staffEdit` :** si le pointeur existe, que la partie désignée contient `id` dans `sheetIds`, que `liftedAt == null` et que `request.time < until`, alors `xpEarned` et `xpSpent` ne changent pas. Coût : deux `get`.

## Écrans

### Conte : « Gel des fiches », `/conteur/gel` (C-Figer)

- **Accès :** un bouton « Gel des fiches » sur la liste des fiches. Fil d’Ariane « Fiches / Gel des fiches ».
- **Sans gel en cours, panneau « Nouveau gel » :**
  - « Partie du » (JJ/MM/AAAA) ;
  - « Lever le » (date et heure), par défaut le lendemain à 06:00 ;
  - « 42 fiches seront figées : 38 PJ actifs et 4 PNJ confiés. » ;
  - « Figer maintenant », avec confirmation. Le bouton est désactivé si aucune fiche n’est à figer.
- **Avec un gel en cours :**
  - **Bandeau :** titre et dates du gel, chiffres « fiches figées » et « demandes en file », bouton « Lever le gel » avec confirmation.
  - **Tableau « Fiches figées pour cette partie » :** fiche (avec PJ ou PNJ), joueur, « Depuis le gel du <date précédente> », demandes en attente. Filtres « Toutes » et « Modifiées ».
  - **Panneau de la fiche choisie :** les lignes de `describeChanges(instantané précédent, instantané)` ; puis « Correction urgente… », qui ouvre un dialogue avec motif obligatoire. Le bouton est désactivé avec « Aucun changement à reporter » si la fiche vivante a la version de l’instantané.
  - **Panneau « Pendant le gel » (texte fixe) :**
    - « Dépenses et gains d’XP bloqués ; les demandes restent en file. » ;
    - « Une nouvelle fiche peut être validée, pour la partie suivante. » ;
    - « Saisies de jeu permises : péchés, événements, liens de sang, titres. » ;
    - « Correction urgente : avec motif, elle met à jour la version figée. ».
- **Narrateur :** lecture seule, sans bouton.
- **Mise à jour :** l’écran se rafraîchit chaque minute ; à l’heure `until`, le gel apparaît levé.

### Conte : écrans existants

- **Fiche (C3) :** bandeau « Figée pour la partie du … ».
- **Validation des demandes :** sur une fiche figée, « Valider » est désactivé pour une demande qui coûte de l’XP, avec « Fiche figée jusqu’au 4 oct. ». Refuser, répondre et valider une demande à 0 XP restent possibles.
- **XP, gain mensuel :** les fiches figées sortent de la liste à verser, avec « 3 fiches figées : leur gain sera versé après le gel. ».
- **XP, attribution et correction :** les fiches figées ne sont pas sélectionnables, avec la même raison.

### Joueur

- **Fiche :** bandeau « Fiche figée pour la partie du samedi 3 oct. Vos demandes restent en file et seront traitées à partir du 4 oct. ».
- **Dépenser de l’XP :** le même rappel ; l’envoi reste permis.
- **PNJ confié :** pas de bandeau.

## Erreurs et cas limites

- **Gel déjà en cours :** la création est refusée par les règles, y compris quand deux membres du conte cliquent en même temps. Message : « Un gel est déjà en cours. ».
- **Horloge de l’appareil décalée :** les règles tranchent. Un refus affiche « Enregistrement refusé : réessayez. ».
- **Fiche morte ou retirée pendant le gel :** elle reste dans `sheetIds`.
- **Prêt de PNJ terminé pendant le gel :** le PNJ reste figé jusqu’à la levée.
- **Fiche absente du gel précédent :** « Première version figée ».
- **Formulaire :** « Partie du » doit être une date valide ; « Lever le » doit tomber après maintenant (« La levée doit être dans le futur. »).
- **Demandes en attente :** leur XP reste réservée, comme aujourd’hui.
- **Conte sur sa propre fiche :** il la voit en joueur, comme ailleurs.
- **Mobile, 390 px :** le tableau devient une liste de cartes ; le panneau de la fiche passe sous la liste ; les rangées de boutons passent en `Wrap`.

## Tests

- **Calculs purs (`test/games/game_rules_test.dart`) :**
  - fiches à figer : PJ actif, PNJ au prêt actif ; ni brouillon, ni fiche morte, ni PNJ sans prêt ou au prêt terminé ;
  - `isRunning`, `isFrozen` : avant `until`, après, levé ;
  - levée par défaut ;
  - instantané précédent ; nombre de changements ;
  - textes des bandeaux.
- **Règles d’accès (`rules_test/games.test.js`) :**
  - création d’une partie : conteur et principal oui ; narrateur et joueur non ; `frozenAt` différent de l’heure refusé ; gel en cours refusé ; permise après une levée ou après `until` ;
  - levée : gel en cours oui ; gel déjà levé non ; autres champs non ;
  - instantanés : création par le conte seul ; mise à jour avec motif seulement ; suppression refusée ; le joueur lit le sien, pas celui d’un autre ;
  - verrou : XP d’une fiche figée refusée ; édition hors XP d’une fiche figée acceptée ; XP d’une fiche hors gel acceptée ; XP acceptée après la levée et après `until`.
- **Écrans :**
  - écran du gel : sans gel, gel en cours, narrateur, correction urgente, 390 px ;
  - bandeau de la fiche, côté joueur et côté conte ;
  - « Valider » désactivé pour une demande qui coûte de l’XP sur une fiche figée ;
  - fiches figées absentes du gain mensuel et non sélectionnables pour l’attribution.
- **Surcharges :** le nouveau provider de la partie en cours est à surcharger dans les tests qui affichent la fiche, la validation ou les écrans XP.

## Hors périmètre

- Le gel d’une fiche seule, hors partie.
- L’historique des parties passées (seul le gel précédent sert, pour la comparaison).
- « Voir la version figée » en entier, la colonne « Imprimée » et l’impression (8b).
- Le hors ligne et les appareils connectés (8c).
- L’option « Prévenir les joueurs » : le bandeau s’affiche toujours.
- Les notifications (sous-projet 10).
