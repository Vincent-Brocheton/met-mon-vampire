# Notifications (sous-projet 10a) : conception

## Objectif

Chacun voit dans l’application ce qui s’est passé pour lui depuis sa dernière visite : une cloche avec un point rouge dans la barre de navigation, et une page « Notifications ».

Le sous-projet 10 est découpé en lots, chacun avec sa spec, son plan et sa branche :
- **10a Notifications** (ce document) ;
- 10b Journal de la chronique ;
- 10c Import de fiches.

Maquettes (canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp) : `C-Notifications`, `J-Notifications` et leurs versions mobiles.

## Décisions

- **Pas d’e-mail.** Le forfait Spark n’a pas de Cloud Functions : aucun serveur ne peut envoyer d’e-mail. Le panneau « Recevoir aussi par e-mail » des maquettes est retiré, ainsi que les préférences de notifications de « Mon compte ».
- **Fil calculé, rien n’est stocké.** Les notifications sont lues dans les données que l’application tient déjà (comptes, demandes, fiches, historiques, parties, PNJ confiés, wiki). Aucune action existante n’écrit de notification ; aucune ne peut être oubliée ; les événements passés apparaissent dès la mise en ligne.
- **Lu jusqu’à une date.** Un seul champ `notifSeenAt` sur `users/{uid}`, écrit par chacun pour lui-même. Une notification est « non lue » si sa date est postérieure à ce champ (toutes sont non lues tant qu’il est absent). Pas d’état lu notification par notification.

## Le fil

Une notification : type, titre, détail, date, lien. Le fil est trié de la plus récente à la plus ancienne et limité aux 60 derniers jours.

### Conte

| Notification | Source | Date | Lien | Qui |
|---|---|---|---|---|
| « Demande d’accès : {nom} » ; détail : le message de la demande, sinon « Nouveau compte en attente. » | comptes au rôle `pending` | `createdAt` | `/conteur/comptes` | conteur, principal |
| « {n} demandes à traiter » (une seule ligne ; « 1 demande à traiter ») ; détail « Dépenses d’XP et demandes en attente. » | demandes au statut `pending` | la plus récente `submittedAt` | `/conteur/demandes` | conteur, principal, narrateur |
| « {fiche} soumise à validation » ; détail : nom du joueur | fiches au statut `review` | `submittedAt` | `/conteur/demandes` | conteur, principal, narrateur |
| « {auteur} a publié une page du wiki » ; détail « « {titre} », version {n}. » | pages publiées (`wiki`) dont `updatedByUid` n’est pas le lecteur | `updatedAt` | `/conteur/wiki/edition/{id}/historique` | conteur, principal, narrateur |

Le narrateur ne lit pas les comptes : il n’a pas la ligne « Demande d’accès ».

### Joueur

| Notification | Source | Date | Lien |
|---|---|---|---|
| « Une demande a été validée » ; détail : la fiche | ses demandes au statut validé | `decidedAt` | `/joueur/demandes` |
| « Une demande a été refusée » ; détail : « Le conte a laissé un motif. Votre XP réservée vous est rendue. » | ses demandes au statut refusé | `decidedAt` | `/joueur/demandes` |
| « XP reçue : +{n} » ; détail : la fiche | entrées d’historique de ses fiches dont `xpEarned` est positif | `at` | `/joueur/personnages/{id}/historique` |
| « Fiches figées pour la partie du {date} » ; détail « Jusqu’au {date} à {heure}, vos demandes restent en attente. » | partie en cours (gel non levé, avant `until`) | `frozenAt` | `/joueur/personnages` |
| « Un PNJ vous a été confié » ; détail : le nom du PNJ | ses prêts de PNJ | `from` | `/joueur/pnj/{id}` |
| « Nouvelle page du wiki » (version 1) ou « Page du wiki mise à jour » ; détail « « {titre} » » | pages du wiki qu’il peut lire (requête existante) | `updatedAt` | `/joueur/wiki/page/{id}` |

Les noms exacts des statuts, champs et routes sont relevés dans le code au moment du plan ; le tableau donne l’intention.

## Données et règles

- `users/{uid}.notifSeenAt` : timestamp, heure du serveur.
- Règles : la branche `selfUpdate` accepte aussi `notifSeenAt`, à condition qu’il vaille `request.time`. Aucune autre règle ne change : chaque source est déjà lisible par ceux qui la reçoivent.
- `AppUser.notifSeenAt` lu par `fromDoc`.

## Calcul (pur)

`lib/notifications/notification_rules.dart` :
- `AppNotification` : `kind`, `title`, `detail`, `at`, `link` ;
- une fonction par source (`accessRequests`, `pendingSummary`, `reviewQueue`, `wikiByOthers`, `decidedRequests`, `xpReceived`, `freeze`, `npcLoans`, `wikiForPlayer`) qui rend des `AppNotification` ;
- `feed(List<AppNotification>, {required DateTime now})` : tri décroissant, 60 jours ;
- `unreadCount(feed, seenAt)`.

Un provider par espace (`staffNotificationsProvider`, `playerNotificationsProvider`) assemble les sources à partir des providers existants ; une source en erreur ou en chargement est simplement absente du fil (elle n’empêche pas les autres).

## Écrans

- `/joueur/notifications` et `/conteur/notifications` remplacent « À venir » : titre « Notifications », sous-titre « {n} non lues. La cloche en haut de l’écran les signale. » (« Aucune notification non lue. » à zéro), bouton « Tout marquer comme lu » (désactivé à zéro), liste : point rouge si non lue, titre en gras si non lue, détail, date courte ; un clic ouvre le lien. Liste vide : « Rien de nouveau pour l’instant. »
- La cloche de `AppShell` porte un point rouge s’il y a au moins une notification non lue (Web et mobile).
- Écran à 390 px sans débordement.

## Erreurs et cas limites

- Écriture de `notifSeenAt` refusée ou hors ligne : message « Enregistrement refusé : réessayez. » ; le fil ne change pas.
- Horloge de l’appareil en avance : `notifSeenAt` est l’heure du serveur ; le point rouge se calcule contre elle.
- Un membre de l’équipe qui joue un PJ : son espace est celui du conte, il reçoit le fil du conte (les notifications de joueur viendraient de `/joueur`, qu’il ne visite pas).

## Tests

- Unitaires : chaque source (dates, libellés, singulier et pluriel, auteur exclu, narrateur sans demandes d’accès), `feed` (tri, 60 jours), `unreadCount` (champ absent, date).
- Widgets : page conte et page joueur (liste, non lues, « Tout marquer comme lu », vide), point rouge de la cloche, 390 px.
- Règles : `notifSeenAt` écrit par soi à l’heure du serveur ; refusé pour un autre compte, avec une autre date, ou mêlé à un autre champ.

## Hors périmètre

| Élément | Raison ou suite |
|---|---|
| E-mails, résumé quotidien | pas de serveur (forfait Spark) |
| État lu notification par notification | « lu jusqu’à » suffit |
| « Votre fiche est prête pour le hors ligne » | ne concerne que l’appareil qui prépare |
| Notifications push | pas de serveur |
| Préférences de notifications dans « Mon compte » | sans objet sans e-mail |
