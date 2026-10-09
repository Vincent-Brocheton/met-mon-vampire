# Hors ligne et appareils connectés (sous-projet 8c) : conception

## Objectif

Pendant une partie, le joueur suit sa fiche figée sans réseau. Il coche sur son appareil le sang, la volonté et la santé dépensés, et il prend des notes de partie. Ce qu’il saisit hors ligne part au conte dès que le réseau revient. Dans « Mon compte », chacun voit les appareils où il est connecté et peut en déconnecter un.

Le sous-projet 8 est découpé en lots :
- 8a Parties et gel (fait) ;
- 8b Impression (fait) ;
- 8c Hors ligne et appareils connectés, côté joueur (ce document) ;
- 8d Partie hors ligne côté conte (plus tard).

Maquettes (canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp) :
- `J-HorsLigne`, avec sa version mobile (écran « En partie » du joueur) ;
- `Compte`, section « Appareils connectés » ;
- `C-HorsLigne` sert au lot 8d.

## Décisions

- **Le cache de Firestore fait le hors ligne.** Pas de base locale maison. Le cache persistant garde ce que l’app a lu, et Firestore met les écritures en file pour les envoyer au retour du réseau.
- **Pas de nouveau paquet de connectivité.** L’état « hors ligne » vient des métadonnées des instantanés (`isFromCache`, `hasPendingWrites`).
- **Le suivi de soirée ne modifie jamais la fiche.** Il est rangé dans un document à part, écrit par le joueur seul, donc sans conflit entre appareils, sans version et sans historique.
- **Web.**
  - Flutter 3.47 ne fournit plus de service worker. Un rechargement sans réseau n’ouvre pas l’app.
  - Le hors ligne marche tant que l’onglet reste ouvert ; l’écran le rappelle.
  - L’app Android, elle, redémarre depuis le cache.
- **Déconnexion à distance sans Cloud Functions.** L’appareil visé surveille son propre document. S’il est marqué, il vide son cache et se déconnecte lui-même. Cela prend effet à son prochain passage en ligne.
- **Une seule dépendance nouvelle :** `shared_preferences`, pour garder l’identifiant de l’appareil.

## Socle

- **`main.dart` :** `FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)`, avec la gestion multi-onglets sur le Web, avant toute lecture.
- **Préparer la partie.** Ouvrir l’écran « En partie » avec du réseau met en cache tout ce qu’il lit : la version figée, le référentiel, l’équipement, les lieux, les alliés, les péchés de la soirée et le suivi. L’écran note alors la préparation dans le document de l’appareil (`gameId`, `preparedAt`).
- **Se déconnecter** vide aussi le cache Firestore de l’appareil (`terminate` puis `clearPersistence`), puis déconnecte le compte.

## Données

### `characters/{id}/night/{gameId}` : suivi de la soirée

| Champ | Contenu |
|---|---|
| `blood` | points de sang dépensés, de 0 au sang de la fiche (Vitae pour une goule : 5) |
| `willpower` | points de volonté dépensés, de 0 à la volonté de la fiche |
| `health` | `[sain, blessé, incapacité]` : cases cochées par groupe, chacune de 0 à la taille du groupe selon `health` de la fiche |
| `notes` | liste de `{ text, at }` ; `text` non vide, 500 caractères au plus ; `at` heure de l’appareil |
| `byUid` | le joueur |
| `at` | heure de la dernière écriture, égale à `request.time` (`FieldValue.serverTimestamp()`, résolue à l’envoi) |

Les bornes viennent de la version figée de la partie. Chaque coche réécrit le document en entier (`set`) : un seul appareil l’écrit, la dernière écriture fait foi.

### `users/{uid}/devices/{deviceId}` : appareils

| Champ | Contenu |
|---|---|
| `name` | « Navigateur · Windows », « Navigateur · Android », « Android »… d’après la plateforme |
| `web` | `true` pour un navigateur |
| `lastSeen` | dernier démarrage de l’app connectée, égal à `request.time` |
| `gameId` | partie préparée sur l’appareil, ou `null` |
| `preparedAt` | heure de la préparation, ou `null` |
| `revokedAt` | heure de la demande de déconnexion, ou `null` |

`deviceId` est un identifiant aléatoire créé au premier lancement et gardé par `shared_preferences`. Le document est écrit à chaque démarrage de l’app une fois connecté (`lastSeen`).

## Calculs purs (`lib/offline/night_rules.dart`)

- **`NightLimits.of(sheet)` :** maxima du sang, de la volonté et des trois groupes de santé. Pour la santé, on lit `health` (« 3 · 3 · 3 ») ; une valeur illisible donne `[3, 3, 3]`.
- **`toggle(night, track, index, limits)` :** cliquer la case n coche jusqu’à n. Cliquer la dernière case cochée la décoche. Le résultat reste dans les bornes.
- **Annulation :** une pile des états précédents, gardée en mémoire par l’écran ; « Annuler le dernier coup » rétablit l’état d’avant.
- **Textes :**
  - « 3 / 12 · reste 9 » ;
  - « Version figée du 29 sept. · préparée sur cet appareil le 3 oct. à 18h » ; sans préparation, « Version figée du 29 sept. » ;
  - « Pas de réseau. Tout ce que vous cochez reste sur cet appareil et part au conte dès que le réseau revient. » ;
  - « Tout est envoyé. » / « Des saisies attendent le réseau. » ;
  - « Gardez cet onglet ouvert pendant la partie : sans réseau, il ne se rechargera pas. » (Web seulement) ;
  - appareils : « Copie hors ligne · partie du 3 oct. », « Connexion web », « Application Android », et la dernière visite (« aujourd’hui », « hier », « 29 sept. »).

## Règles Firestore

- **`characters/{id}/night/{gid}` :**
  - lecture : le joueur de la fiche et l’équipe ;
  - création et mise à jour :
    - le joueur de la fiche seul (`playerUid == request.auth.uid`), `byUid == request.auth.uid` ;
    - clés exactes du tableau ; `at == request.time` ;
    - `blood`, `willpower` entiers entre 0 et la valeur de la version figée `characters/{id}/frozen/{gid}` (un `get`), soit `sheet.blood` (5 si `sheet.ghoul` existe) et `sheet.willpower` ;
    - `health` liste de trois entiers entre 0 et 20 : les règles ne lisent pas le texte `health` de la fiche, la borne par groupe est tenue par l’app ;
    - `notes` liste de 100 éléments au plus ;
    - la partie `games/{gid}` existe et contient `id` dans `sheetIds` (un `get`). L’heure n’est pas vérifiée : une synchronisation tardive, après la levée du gel, reste acceptée ;
  - suppression : refusée.
- **`users/{uid}/devices/{d}` :**
  - lecture, écriture et suppression : `request.auth.uid == uid` seulement ;
  - clés exactes du tableau ; `lastSeen == request.time` à chaque écriture qui le change ; `revokedAt` nul ou égal à `request.time` quand il change.
- La règle `users/{uid}` existante ne couvre pas la sous-collection : il faut un bloc `match` dédié.

## Écrans

### Joueur : « En partie », `/joueur/personnages/:id/partie` (J-HorsLigne)

- **Accès :** un bouton « En partie » dans le bandeau du gel de la fiche du joueur, à côté d’« Imprimer ». Il n’apparaît que si la fiche est figée par la partie en cours. Ailleurs, la route affiche « Cette fiche n’est pas figée pour une partie en cours ».
- **En-tête :**
  - fil « <nom> / En partie », titre « <prénom> en partie » ;
  - badge « Hors ligne » quand les données viennent du cache, rien sinon ;
  - la ligne de version et de préparation ;
  - bouton « Fiche complète (lecture) » vers la fiche.
- **Bandeau :** le texte « Pas de réseau… » quand on est hors ligne ; le rappel « Gardez cet onglet ouvert… » sur le Web.
- **Suivi de la soirée :**
  - « Sang dépensé » (ou « Vitae dépensée ») et ses cases ;
  - « Volonté dépensée » ;
  - « Santé » : trois groupes Sain, Blessé, Incapacité ;
  - « Traits de Bête ce soir » : 5 ronds, en lecture, pleins jusqu’à `eveningTraits` des péchés de la soirée ; avec la phrase « Les traits de Bête sont saisis par le conte. Vous les voyez quand son appareil et le vôtre se sont synchronisés. » ;
  - « Annuler le dernier coup », désactivé quand la pile est vide.
- **Pouvoirs :** les disciplines de la version figée, avec leurs pouvoirs séparés par « · ».
- **Note de partie :**
  - champ et bouton « Ajouter la note » ;
  - les notes déjà prises, les plus récentes en premier ;
  - « Brouillon de demande » mène à l’écran « Dépenser de l’XP ».
- **Équipement, alliés et lieux :** nom et qualités, comme à l’impression.
- **Envoi :** « Tout est envoyé. » ou « Des saisies attendent le réseau. », selon `hasPendingWrites` du suivi.
- **Mobile, 390 px :** une colonne ; le suivi en premier ; les cases passent à la ligne.

### Conte : écran du gel (C-Figer)

Le panneau de la fiche choisie gagne un bloc « Suivi de la soirée » :
- « Sang 3 / 12 · Volonté 1 / 6 · Santé 2 · 0 · 0 » ;
- les notes de partie, avec leur heure ;
- « Aucun suivi pour cette partie » s’il n’y a pas de document.

Lecture seule pour tout le conte, narrateur compris.

### Mon compte : « Appareils connectés » (Compte)

- **Une ligne par appareil :** le nom ; « Cet appareil » pour l’appareil courant ; « Copie hors ligne · partie du 3 oct. » si `gameId` désigne une partie dont le gel n’est pas encore levé, sinon « Connexion web » ou « Application Android » ; la dernière visite.
- **Bouton « Déconnecter » :**
  - sur un autre appareil : écrit `revokedAt`, avec confirmation, puis la ligne affiche « Déconnexion en attente » ;
  - sur l’appareil courant : même effet que « Se déconnecter ».
- **Phrases fixes :**
  - « Déconnecter un appareil efface aussi sa copie hors ligne. » ;
  - « Un appareil hors ligne est déconnecté à son prochain passage en ligne. ».
- **Appareils marqués :** les appareils avec `revokedAt` restent listés jusqu’à ce que l’appareil supprime son document.

### Surveillance de l’appareil

Un provider démarré avec la session :
- écrit le document de l’appareil au démarrage ;
- surveille ce document. S’il voit `revokedAt`, il supprime le document, vide le cache, déconnecte le compte et ramène sur `/connexion` avec « Cet appareil a été déconnecté depuis un autre appareil. ».

## Erreurs et cas limites

- **Écran ouvert hors ligne sans préparation :** les données absentes du cache restent en chargement. Message : « Cette fiche n’a pas été préparée sur cet appareil : ouvrez-la une fois avec du réseau avant la partie. ».
- **Version figée corrigée (correction urgente) pendant la partie :** les bornes suivent la nouvelle version ; une valeur au-delà est ramenée au maximum à la prochaine coche.
- **Écriture refusée au retour du réseau** (fiche retirée du gel, par exemple) : Firestore rejette l’écriture en file. L’écran affiche « Une saisie a été refusée : vérifiez votre suivi. » et l’état revient à celui du serveur.
- **Gel levé :** l’écran reste ouvert et lisible. Le bouton « En partie » disparaît du bandeau, puisque le bandeau disparaît avec le gel.
- **Plusieurs onglets :** le cache est partagé ; la dernière coche envoyée fait foi.
- **Conte sur sa propre fiche :** il la voit en joueur, avec « En partie », comme ailleurs.
- **Déconnexion sur un appareil sans réseau :** le cache est vidé localement. Les saisies non envoyées sont perdues ; une confirmation le dit : « Des saisies n’ont pas encore été envoyées : elles seront perdues. ».

## Tests

- **Calculs purs (`test/offline/night_rules_test.dart`) :**
  - maxima, y compris goule et `health` illisible ;
  - coche, décoche de la dernière case, bornes ;
  - annulation ;
  - textes, y compris les appareils et la dernière visite.
- **Règles d’accès (`rules_test/offline.test.js`) :**
  - suivi :
    - le joueur écrit le sien ; un autre joueur non ; le conte lit, n’écrit pas ;
    - fiche absente de `sheetIds` refusée ; valeurs au-delà de la version figée refusées ; `at` différent de l’heure refusé ; clé en trop refusée ;
    - écriture acceptée après la levée du gel ;
    - suppression refusée ;
  - appareils :
    - chacun lit, écrit et supprime les siens ;
    - personne d’autre, conte compris ;
    - `lastSeen` faux refusé.
- **Écrans :**
  - « En partie » : en ligne, hors ligne (provider d’état surchargé), coches et annulation, notes, fiche non figée, 390 px ;
  - bandeau du gel : bouton « En partie » ;
  - écran du gel : bloc « Suivi de la soirée », avec et sans document ;
  - Mon compte : appareils, « Cet appareil », « Déconnecter » ;
  - la surveillance déconnecte quand `revokedAt` apparaît (dépôt factice).
- **Surcharges :** le provider du suivi est à surcharger dans les tests de l’écran du gel ; les providers des appareils dans ceux de Mon compte.
- **À la main :** sur Chrome et sur l’APK, préparer, couper le réseau, cocher, rétablir, vérifier côté conte ; déconnecter un appareil depuis un autre.

## Hors périmètre

- La partie hors ligne côté conte (8d) :
  - la file de synchronisation détaillée et la résolution des conflits de péchés ;
  - le choix du contenu gardé sur l’appareil ;
  - le code à l’ouverture et l’effacement programmé.
- La file « En attente d’envoi » action par action de la maquette joueur : Firestore ne l’expose pas.
- Le service worker Web (recharger l’app sans réseau).
- La révocation immédiate des sessions (il faudrait des Cloud Functions).
- Les notifications par e-mail et l’export des données de « Mon compte ».
