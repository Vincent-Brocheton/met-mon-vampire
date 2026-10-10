# Partie hors ligne côté conte (sous-projet 8d) : conception

## Objectif

Pendant une partie, le conte travaille sans réseau sur son appareil. Il consulte les fiches figées et le référentiel, et il saisit les péchés, les événements et les gorgées. Une file montre ce qui attend le réseau et ce qui est parti. Quand deux conteurs ont saisi chacun le même péché hors ligne, l’écran signale le conflit et le fait trancher. Les données de l’appareil s’effacent seules quelque temps après la partie, ou à la demande.

Le sous-projet 8 est découpé en lots :
- 8a Parties et gel (fait) ;
- 8b Impression (fait) ;
- 8c Hors ligne et appareils connectés, côté joueur (fait) ;
- 8d Partie hors ligne côté conte (ce document).

Maquette : `C-HorsLigne` (canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp).

## Décisions

- **Le cache de Firestore fait toujours le hors ligne**, comme au 8c. Pas de base locale, pas de nouveau paquet.
- **La file est déduite des données.**
  - On ne tient pas de journal à part. Les péchés et événements de la partie sont suivis avec `includeMetadataChanges` : un document avec `hasPendingWrites` est « En attente », les autres sont « Envoyé ».
  - Une gorgée écrit aussi un événement « Lien de sang » : la file la montre par lui, sans suivre les liens.
  - La file survit à un rechargement, puisque les écritures en attente restent dans le cache. Une fois les appareils synchronisés, elle montre aussi les saisies des autres conteurs.
- **Hors ligne, on ne modifie pas la fiche.**
  - Toute écriture qui passe par la version de la fiche est refusée tout de suite, avec un message : perte de la soirée, titre, XP, validation, gel, correction urgente.
  - Hors ligne, on ne saisit que des documents à part : péchés, événements, gorgées. Ainsi, aucune saisie n’est refusée par surprise au retour du réseau.
- **Une garde commune plutôt que des boutons grisés.** La garde est posée dans les dépôts par où passent toutes ces écritures. Les boutons restent actifs, et c’est le message qui bloque.
- **Pas de code à l’ouverture.** Sur le Web, aucun stockage n’est sûr. On compte sur le verrou de l’appareil et sur l’effacement programmé.

## Savoir si on est hors ligne

`offlineProvider` (`lib/offline/offline.dart`) :
- suit `games` avec `includeMetadataChanges` ;
- vaut `true` quand l’instantané vient du cache (`isFromCache`) ;
- vaut `false` tant que rien n’est arrivé.

Le badge, le bloc « Hors ligne, on peut » et la garde s’en servent.

## Garde hors ligne

- **Où :**
  - `CharacterRepository` reçoit une fonction `bool Function() offline`, lue par son provider dans `offlineProvider`. `stageEdit` et `_commit` lèvent `OfflineError` quand elle vaut `true` et que l’auteur n’est pas le joueur de la fiche (`by.uid != c.playerUid`).
  - `GamesRepository` fait de même dans `freeze`, `lift` et `correct`.
- **Ce que ça couvre :** passent par `stageEdit` / `_commit` les modifs de fiche du conte, l’XP (dépense, gain, bonus), les titres, la perte de la soirée et la validation de fiche.
- **Message :** `OfflineError.toString()` donne « Pas de réseau : les modifications de la fiche attendent le réseau. ». Les écrans ont leur propre texte d’erreur.
  - Dans leurs blocs `catch`, `refusalText(e, <texte actuel>)` affiche ce message pour une `OfflineError`, et le texte actuel sinon.
  - Le gain mensuel et les bonus groupés (`_eachSheet`) rangent la fiche refusée parmi les fiches refusées.
- **Ce qui ne passe pas par la garde :**
  - le suivi de soirée du joueur (8c) ;
  - les péchés, événements et gorgées ;
  - les brouillons et les demandes du joueur, qui restent en file comme avant. Un membre de l’équipe sur sa propre fiche agit en joueur : il n’est pas bloqué.

## Écran « Partie hors ligne », `/conteur/gel/hors-ligne` (C-HorsLigne)

### Accès

- Un bouton « Partie hors ligne » sur l’écran du gel (C-Figer), visible pendant un gel en cours.
- Sans gel en cours, la route affiche « Aucune partie en cours ».
- La route est réservée à l’équipe. Le narrateur voit tout et peut préparer ou effacer son appareil ; les boutons de conflit sont cachés pour lui.

### En-tête

- Fil « Gel des fiches / Hors ligne », titre « Partie hors ligne ».
- Badge « Hors ligne » quand `offlineProvider` vaut `true`.
- Ligne « Partie du samedi 3 oct. · préparée sur cet appareil à 17h30 · dernière synchronisation à 21h02 ».
  - Sans préparation, le morceau « préparée… » disparaît.
  - « Dernière synchronisation » est l’heure, gardée en mémoire par l’écran, où la file est revenue à zéro en ligne. Sans valeur, ce morceau disparaît.
- Bouton « Synchroniser maintenant » : `enableNetwork()` puis `waitForPendingWrites()`. Il affiche une attente jusqu’à la fin, et « Tout est envoyé. » ensuite.

### Compteurs

Trois cases : « fiches figées » (nombre de `sheetIds`), « saisies en attente », « conflits » (au singulier quand il y en a un).

### Conflits

Un bloc par conflit, au-dessus de la file :
- titre « Conflit · <nom de la fiche> » ;
- phrase « <A> et <B> ont saisi chacun un péché de niveau <n> le <jour>. S’agit-il du même péché ? » ;
- deux cartes : « <byName> · <heure> », le texte du péché, « +<n> trait(s) de Bête » (`sinTraits`) ;
- trois boutons :
  - « Même péché : garder celui de <A> » supprime le péché de B ;
  - « Même péché : garder celui de <B> » supprime le péché de A ;
  - « Deux péchés distincts » écrit `distinct: true` sur les deux, en un lot.
- Une erreur s’affiche sous le bloc.
- Marquer un péché « distinct » passe par `SinsRepository`. Comme toute modification de péché, cela met le conteur qui tranche dans `byUid` / `byName`.

### File de synchronisation

- **Colonnes :** Heure, Par, Action (libellé, puis nom de la fiche en petit), État.
- **Ordre :** du plus récent au plus ancien.
- **États :**
  - « En attente » : `hasPendingWrites` ;
  - « Envoyé » : document reçu du serveur ;
  - « Conflit » : péché pris dans un conflit, sur une ligne teintée.
- **Libellés :**
  - « Péché niveau <n> · <remords> », par exemple « Péché niveau 2 · remords réussi » ;
  - « Événement · <titre> » ;
  - une gorgée apparaît par son événement « Lien de sang ».
- **Heure :** `createdAt`, soit l’heure du serveur, donc celle de l’envoi.
  - Tant que la création attend, l’heure est inconnue et la ligne affiche « — ».
  - L’API Flutter de Firestore ne permet pas d’estimer, dans un flux, l’heure d’une écriture en attente.
  - Les saisies en attente passent en tête de la file.
- **Lien :** une ligne mène à la fiche, sur l’onglet où la saisie se fait (moralité, histoire, liens).
- **File vide :** « Aucune saisie depuis le gel. ».

### « Sur cet appareil »

- **Cases, gardées dans `shared_preferences` :**
  - « Fiches figées », toujours cochée et désactivée, avec « <n> fiches » ;
  - « Référentiel », avec « Atouts, disciplines, titres » ;
  - « Liens de sang et événements », avec « Y compris les secrets » ;
  - « Notes du conte », avec « Lecture seule ».
- **Bouton « Préparer la partie » :**
  - Il lit une fois (`get`) ce qui est coché, pour chaque fiche figée : version figée, péchés, événements, liens, notes privées. Le référentiel est lu par `rulebookProvider`.
  - Il note ensuite la préparation dans le document de l’appareil (`DevicesRepository.prepared`).
  - Il affiche une attente pendant la lecture, puis « Partie préparée sur cet appareil. ».
  - Il est désactivé hors ligne.
- **Phrase fixe :** « Ce que vous ouvrez sur cet appareil reste aussi dans son cache. ».

### « Hors ligne, on peut »

Texte fixe, en trois lignes :
- « Consulter les fiches figées et le référentiel » ;
- « Saisir péchés, événements et gorgées » ;
- « Pas de modification de la fiche, de validation de demande ni d’XP : elles attendent le réseau », en couleur secondaire.

### Sécurité

- **Liste « Effacer les données de l’appareil » :** « 7 jours après la partie » (par défaut), « Au dégel » ou « Jamais ». La valeur est gardée dans `shared_preferences`.
- **Phrase fixe :** « Les appareils des joueurs ne reçoivent que leurs propres fiches, sans notes ni événements secrets. ».
- **Bouton « Effacer maintenant de cet appareil » :**
  - confirmation « Effacer les données de cet appareil ? Vous restez connecté. » ;
  - si des saisies attendent, l’avertissement « Des saisies n’ont pas encore été envoyées : elles seront perdues. » s’ajoute ;
  - puis l’effacement (voir plus bas).

### Mobile, 390 px

Une colonne, dans l’ordre : en-tête, compteurs, conflits, file, « Sur cet appareil », « Hors ligne, on peut », Sécurité. Le tableau de la file devient une liste de lignes : heure et état sur une ligne, l’action dessous.

## Calculs purs

### `lib/morality/morality_rules.dart`

- **`conflicts(List<Sin> sins)` :** elle renvoie les paires `(a, b)` de péchés qui ont :
  - le même jour (`dayOf(date)`) ;
  - le même niveau ;
  - des `byUid` différents et non vides ;
  - ni `lossApplied` ni `distinct`, pour l’un comme pour l’autre.

  Un péché ne figure que dans une seule paire. On les associe dans l’ordre de `createdAt`, et les autres restent sans paire.
- **`Sin` :** il lit en plus `byUid`, `createdAt` (nul en attente) et `distinct`. `toMap()` n’écrit `distinct` que s’il vaut `true`.

### `lib/offline/sync_queue.dart`

- **`QueueLine` :** `at`, `byName`, `label`, `sheetName`, `characterId`, `tab`, `state` (`pending`, `sent`, `conflict`).
- **Lignes :**
  - `sinLine(sin, sheetName, pending, inConflict)` ;
  - `eventLine(event, sheetName, pending)` ;
  - `bondLine(bond, regnantName, thrallName, pending)`.
- **`sinceFreeze(at, game)` :** vrai si `at` est nul (en attente) ou postérieur à `game.frozenAt`. Les péchés sont filtrés par jour (`dayOf(date) == game.date`), les événements et les liens par `sinceFreeze` sur `createdAt` / `updatedAt`.
- **`counters(lines, conflicts)` :** saisies en attente et nombre de conflits.
- **Textes :**
  - la ligne d’en-tête : `headerLine(game, preparedAt, lastSync)` ;
  - « 1 conflit » / « 2 conflits » ;
  - les libellés de remords : « remords réussi », « remords échoué », « sans remords ».

### `lib/offline/wipe.dart`

- **`WipePolicy` :** `week`, `lift` ou `never`, avec le libellé de la liste ; `parse` donne `week` par défaut.
- **`shouldWipe(policy, game, now)` :** les écritures en attente sont vérifiées à part, par `DeviceSession.pendingWrites`.
  - faux si `game` est nul ou si la politique est `never` ;
  - sinon, la fin est `liftedAt`, ou `until` s’il est passé ; sans fin, faux ;
  - `lift` : vrai dès la fin ;
  - `week` : vrai à partir de fin + 7 jours.

## Données et effacement

- **Ce qu’on garde sur l’appareil :** dans `shared_preferences`, les clés `wipePolicy` et `prepare.rulebook`, `prepare.bonds`, `prepare.notes`. Rien ne change dans Firestore.
- **Vérification :** l’écoute du document de l’appareil dans `router.dart` (8c) vérifie `shouldWipe` pour la partie `device.gameId`. Elle le fait au démarrage et à chaque changement de ce document ; les parties sont lues une fois à ce moment-là.
- **Effacement :** quand `shouldWipe` est vrai, ou sur « Effacer maintenant » :
  1. le document de l’appareil reçoit `gameId: null`, `preparedAt: null`. On n’attend pas plus de 3 secondes, comme au 8c ;
  2. le cache est vidé (`wipeCache` : `terminate` puis `clearPersistence`) ;
  3. l’app repart (`restart`) : sur `/` pour l’effacement programmé, sur l’écran pour « Effacer maintenant ». Le compte reste connecté.

  Un échec est journalisé, et on réessaie au prochain démarrage.
- **Joueurs :** la même vérification tourne sur leurs appareils, avec la politique par défaut.

## Règles Firestore

- **`characters/{id}/sins/{s}` :** la liste des clés accepte `distinct`, et `sinValid` vérifie `d.get('distinct', false) is bool`.
- **`users/{uid}/devices/{d}` :** `preparedAt` peut aussi revenir à nul. C’est le cas quand la partie préparée est oubliée avant l’effacement.
- **Aucune autre règle ne change :**
  - la file lit avec les droits actuels de l’équipe ;
  - l’effacement est local.

## Erreurs et cas limites

- **Écran ouvert hors ligne sans préparation :** ce qui n’est pas dans le cache reste en chargement. Un bandeau dit : « Cette partie n’a pas été préparée sur cet appareil : ouvrez-la une fois avec du réseau. ».
- **Modification de fiche hors ligne :** elle est refusée tout de suite par la garde, avec son message ; rien ne part en file.
- **Écriture refusée au retour du réseau :** cela arrive par exemple pour un péché modifié après l’application de la perte par un autre conteur. Firestore annule l’écriture dans le cache et la ligne disparaît de la file. L’écran de saisie, s’il est encore ouvert, montre son erreur.
- **Conflit tranché par deux conteurs à la fois :**
  - si l’un supprime et l’autre marque « distinct », l’écriture sur le document supprimé échoue ; le message s’affiche et la file se met à jour ;
  - si les deux suppriment, chacun garde un péché différent et il ne reste rien. Ce cas rare est assumé ; on peut ressaisir le péché.
- **Gel levé pendant que l’écran est ouvert :** l’écran passe à « Aucune partie en cours ». Le bouton disparaît de l’écran du gel.
- **Effacement :** il est retardé s’il reste des écritures en attente.

## Tests

- **Calculs purs :**
  - `test/morality/morality_rules_test.dart`, `conflicts` :
    - paire trouvée ;
    - même auteur, autre jour, autre niveau : pas de conflit ;
    - `distinct` ou `lossApplied` : pas de conflit ;
    - trois péchés : une seule paire ;
  - `test/offline/sync_queue_test.dart` : libellés, états, `sinceFreeze`, compteurs, ligne d’en-tête ;
  - `test/offline/wipe_test.dart` : `shouldWipe` pour chaque politique, gel non levé, `until` dépassé, écritures en attente, `parse`.
- **Garde :** avec `offline` à vrai, `stageEdit` et `freeze` / `lift` / `correct` lèvent `OfflineError`, et rien n’est écrit (Firestore factice).
- **Règles d’accès (`rules_test/morality.test.js`) :**
  - `distinct: true` est accepté à la création et à la mise à jour ;
  - `distinct: 'oui'` est refusé ;
  - un joueur ne l’écrit pas ;
  - un péché avec `lossApplied` refuse `distinct`.
- **Écrans (`test/offline/offline_game_screen_test.dart`) :**
  - en ligne, puis hors ligne avec `offlineProvider` surchargé ;
  - file avec péché en attente, événement envoyé et ligne en conflit ;
  - conflit et ses trois boutons (dépôt factice) ;
  - narrateur sans boutons ;
  - aucune partie en cours ;
  - « Préparer la partie », « Effacer maintenant » avec confirmation ;
  - 390 px.
- **Écran du gel :** bouton « Partie hors ligne » pendant un gel, absent sinon.
- **Surveillance :** l’effacement programmé se déclenche quand `shouldWipe` est vrai (dépendances factices de `DeviceSession`).
- **Surcharges :** `offlineProvider` dans les tests des écrans qui écrivent la fiche, si leurs dépôts factices passent par la garde ; les providers de la file dans le test de l’écran.
- **À la main :** deux navigateurs connectés en conteur.
  1. Préparer la partie, couper le réseau sur les deux, saisir le même péché sur chacun, rétablir le réseau.
  2. Vérifier la file et le conflit, puis le trancher.
  3. Tenter une perte d’Humanité hors ligne : elle doit être refusée avec le message.
  4. Lancer « Effacer maintenant ».

## Hors périmètre

- Le code à l’ouverture de l’application.
- L’état « Refusé » dans la file : il faudrait faire passer chaque écriture par un relais commun.
- Les boutons grisés écran par écran.
- La taille du cache et son chiffrement : Firestore n’expose ni l’un ni l’autre.
- Le service worker Web (recharger l’app sans réseau).
- Le choix fin des PNJ de la soirée : ce sont des fiches figées comme les autres.
