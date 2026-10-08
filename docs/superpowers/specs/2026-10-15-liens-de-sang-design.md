# Liens de sang (sous-projet 7c) : conception

## Objectif

Les liens de sang entre fiches sont tenus par le conte, avec des échéances calculées seules :
- le conte enregistre les gorgées et les contacts, depuis la fiche ou depuis une page de la chronique ;
- le niveau d'un lien baisse ou s'efface de lui-même selon les délais des règles ;
- le joueur voit les liens qu'il subit et ceux qu'il exerce, selon ce que le conte lui laisse savoir ;
- le lien d'une goule envers son domitor devient un lien de sang comme les autres.

Lots du sous-projet 7 :
- 7a Événements (fait) ;
- 7b Moralité (fait) ;
- 7b2 Dérangements (fait) ;
- 7c Liens de sang (ce document) ;
- 7d Titres ;
- 7e Récit.

Maquettes : bloc « Liens de sang » de C-Moralite et J-Moralite, avec leurs versions mobiles ; C-Liens et C-Liens-mobile (canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp).

## Décisions

- **Goules :** le niveau saisi à la main sur la fiche d'une goule est remplacé par le lien de sang envers son domitor. Les liens des serviteurs (dossiers séparés, qui ne sont pas des fiches) ne changent pas.
- **Périmètre :** le bloc de la fiche (conte et joueur) et la page « Liens de sang de la chronique ».
- **Délais fixes :** 3 mois, 6 mois et un an, dans le code. Leur réglage dans les paramètres de la chronique viendra plus tard.

## Règles du jeu retenues (maquettes C-Liens et J-Moralite)

- Un lien va de 1 à 3. À 3, c'est un lien complet, qui efface les liens moindres du lié envers d'autres régnants.
- Un lien à 3 redescend à 2 après 3 mois sans boire.
- Un lien à 2 s'efface après 6 mois sans contact.
- Un lien à 1 s'efface après un an sans contact.
- Rappel au joueur : « 2 gorgées : 1 Volonté par heure pour lui nuire. 3 gorgées : lien complet, qui efface les liens moindres. »

## Données

### Collection `bonds/{regnantId}_{thrallId}`

Un document par couple de fiches. Le régnant donne son sang ; le lié boit.

| Champ | Contenu |
|---|---|
| `regnantId`, `regnantName`, `regnantPlayerUid` | fiche du régnant ; joueur absent pour un PNJ |
| `thrallId`, `thrallName`, `thrallPlayerUid` | fiche du lié ; joueur absent pour un PNJ |
| `ghoul` | le lié est la goule du régnant (recopié : « votre goule » pour le joueur) |
| `level` | niveau enregistré, entier de 0 à 3 |
| `lastDrink` | date de la dernière gorgée (jour, minuit heure locale) |
| `lastContact` | date du dernier contact (jour, minuit heure locale) |
| `known` | le lié sait de qui vient le sang |
| `regnantKnows` | le régnant connaît le lien envers lui |
| `byUid`, `byName` | auteur de la dernière écriture |
| `createdAt`, `updatedAt` | horodatages du serveur |

- Les noms et les joueurs sont recopiés, parce qu'un joueur ne peut pas lire la fiche de l'autre. Ils sont rafraîchis à chaque écriture du lien.
- Un lien n'est jamais supprimé : un lien effacé garde son document, au niveau 0.

### Niveau effectif

Calculé à l'affichage, à partir du niveau enregistré et des dates, sans tâche planifiée :
- un lien à 3 vaut 2 à partir de `lastDrink` + 3 mois ;
- un lien à 2 (enregistré, ou redescendu de 3) vaut 0 à partir de `lastContact` + 6 mois ;
- un lien à 1 vaut 0 à partir de `lastContact` + 1 an.

Les mois sont des mois du calendrier : le 31 janvier + 1 mois donne le dernier jour de février.

**Échéance :** la prochaine date de changement, avec sa phrase :
- « Redescend à ●● le 1er déc. » ;
- « S'efface le 20 mars 2027 sans contact » ;
- aucune pour un lien à 0.

**Échéance proche :** dans les 30 jours.

Un lien à 0 effectif n'apparaît dans aucune liste.

### Gorgée

- Données : le régnant, le lié, la date (aujourd'hui par défaut), le nombre de gorgées (1 à 3) et « sait de qui vient ce sang ».
- **Nouveau niveau :** niveau effectif à la date de la gorgée, plus le nombre de gorgées, plafonné à 3.
- `lastDrink` et `lastContact` prennent la date de la gorgée.
- **Lien complet :** quand le nouveau niveau est 3, les autres liens du lié dont le niveau effectif est 1 ou 2 passent à 0, dans le même lot d'écritures.
- **Refus :** si le lié a déjà un lien complet effectif envers un autre régnant : « <lié> est déjà lié complètement à <régnant>. ».
- **Événement :** dans le même lot, un événement sur la fiche du lié :
  - type « Lien de sang » (nouveau type `bond`, pastille sang) ;
  - titre « Boit le sang de <régnant> · ●●○ » ;
  - date de la gorgée ;
  - visibilité « joueur et conte » si `known`, sinon « conte seul » ;
  - automatique.

### Contact

- `lastContact` prend la date du contact.
- `level` prend le niveau effectif à cette date. Un lien déjà effacé n'est pas ravivé par un contact.
- Aucun événement.

### Goules

- Le panneau de la goule affiche le lien envers son domitor, lu dans `bonds`.
- Le champ « Lien de sang » de l'édition de la goule disparaît. Le champ `ghoul.bond` reste lu, mais n'est plus écrit.
- **À dater :** une goule dont `ghoul.bond` vaut 1 ou plus, sans document de lien envers son domitor, est signalée dans le bloc du conte : « Lien de <domitor> ●●○ à dater — Créer le lien ». « Créer le lien » enregistre le lien au niveau de la fiche, daté du jour, connu des deux, sans événement.
- Le bouton « Noter une gorgée » de la goule reste lié à sa vitae. Il n'enregistre pas de gorgée de lien.

## Calculs purs (`lib/bonds/bond_rules.dart`)

- `effectiveLevel(b, day)` : le niveau effectif à une date.
- `nextChange(b, day)` : la prochaine échéance (date et niveau après), ou rien.
- `dueText(b, day)` : la phrase de l'échéance.
- `drinkOutcome(b, others, day, count)` renvoie, au choix :
  - le refus, avec son message ;
  - ou le nouveau niveau et la liste des liens moindres à effacer.
- `contactLevel(b, day)` : le niveau à enregistrer pour un contact.
- `bondChecks(...)` renvoie les erreurs : « Choisissez qui donne son sang », « Choisissez qui boit », « Une fiche ne peut pas se lier elle-même », « Date invalide ».
- `dots(n)` existe déjà pour les pastilles.

## Règles Firestore

`match /bonds/{b}` :
- **Lecture :**
  - `isStaff()` ;
  - ou le joueur du lié si `resource.data.known == true` ;
  - ou le joueur du régnant si `resource.data.regnantKnows == true`.
  - Les requêtes du joueur filtrent donc sur `thrallPlayerUid` et `known`, ou sur `regnantPlayerUid` et `regnantKnows`.
- **Création et modification :**
  - `managesAccounts()` ;
  - aucune des deux fiches n'a pour joueur l'auteur (`getAfter` sur les deux fiches) ;
  - `b == regnantId + '_' + thrallId`, et `regnantId != thrallId` ;
  - clés limitées à la liste ci-dessus ;
  - les joueurs recopiés sont ceux des deux fiches ;
  - `level` entier de 0 à 3, `ghoul` booléen ;
  - `lastDrink` et `lastContact` horodatages ;
  - `known` et `regnantKnows` booléens ;
  - `byUid == auth.uid`.
- **Suppression :** refusée.
- **Événements :** `bond` rejoint la liste des types.

## Écrans

### Conte : bloc « Liens de sang » (C-Moralite)

Dans l'onglet « Moralité & liens » de la fiche.

- **En-tête :** « Liens de sang », avec le lien « Tous les liens de la chronique » vers la page.
- **Subis :** les liens dont la fiche est le lié. Pour chacun :
  - nom du régnant, étiquette (PNJ, goule…), pastilles ;
  - ligne : « Dernière gorgée le 20 sept. · <échéance> » ;
  - « + Gorgée » : un petit formulaire (nombre, date du jour préremplie, « sait de qui vient ce sang »), avec l'aperçu du nouveau niveau ;
  - « Contact », qui note un contact du jour ;
  - l'étiquette « Connu de <lié> » ou « Ignoré de <lié> ».
- **Exercés :** les liens dont la fiche est le régnant, mêmes lignes, avec « + Gorgée » et « Contact ».
- **« + Nouveau lien » :** choisir l'autre fiche (parmi les fiches et les PNJ), le sens (subi ou exercé), puis le formulaire de gorgée.
- **À dater :** la ligne de la goule, décrite plus haut.
- **Vide :** « Aucun lien. ».
- **Lecture seule :** pour le narrateur, pour le conte sur sa propre fiche (vue du joueur), et sur une fiche en brouillon ou en validation qui n'est pas un PNJ.

### Conte : page « Liens de sang de la chronique » (C-Liens)

- **Route :** `/conteur/liens`.
- **En-tête :** « Fiches / Liens de sang », le titre « Liens de sang de la chronique » et la phrase « Chaque gorgée et chaque contact mettent à jour les deux fiches. Les échéances se calculent seules. ».
- **Compteurs :** liens actifs, liens complets, échéance sous 30 jours, ignorés du lié.
- **Filtres :** Tous, Complets, Échéance proche, Ignorés du lié, PJ liés ; recherche par nom (régnant ou lié).
- **Tableau :** donne son sang, lié, niveau, dernière gorgée, dernier contact, échéance (en or si proche), connu du lié. Tri : échéance la plus proche d'abord. Toucher une ligne la charge dans le panneau.
- **Panneau « Enregistrer une gorgée » :**
  - « Qui donne son sang » et « Qui boit » : listes des fiches et des PNJ, avec l'étiquette « PNJ Ventrue » ou « PJ Malkavien » ;
  - date (JJ/MM/AAAA) et gorgées (1 à 3) ;
  - « <lié> sait de qui vient ce sang » ;
  - l'aperçu : « Lien envers <régnant> ●●○ → ●●● », puis « Lien complet. Les liens moindres de <lié> envers d'autres vampires sont effacés : <noms ou aucun>. » quand le lien devient complet, et « Sans nouvelle gorgée, il redescendra à ●● le 27 décembre 2026. » ;
  - le refus, s'il y a lieu, à la place de l'aperçu ;
  - « La gorgée s'ajoute aussi aux événements de <lié>, visible par le joueur si le lien lui est connu. » ;
  - « Enregistrer la gorgée » et « Noter un simple contact » ;
  - « Règles appliquées » : les trois délais, en lecture.
- **Accès :** l'équipe ; le narrateur voit la page sans le panneau.
- **Mobile :** l'alerte de l'échéance la plus proche, les filtres, des cartes « <lié> envers <régnant> », puis « Contact » et « + Gorgée » en bas, qui ouvrent le panneau en pleine page avec « ← Retour ».
- **Accès depuis la navigation :** une entrée « Liens de sang » dans la page Fiches.

### Joueur : bloc « Liens de sang » (J-Moralite)

- **« Liens de sang que vous subissez » :** les liens connus du lié. Pour chacun : le régnant, les pastilles, « Une gorgée · dernière le 2 août » (ou « 2 gorgées », « Lien complet »), et la phrase du délai : « Disparaît après un an sans le voir ni lui parler. », « Disparaît après six mois sans le voir ni lui parler. » ou « Redescend après trois mois sans boire son sang. ».
- Puis le rappel des règles.
- **« Liens que vous exercez » :** les liens connus du régnant. Pour chacun : le lié, « votre goule » s'il s'agit de sa goule, les pastilles, « Dernière gorgée le 26 sept. · à renforcer avant le 26 déc. ».
- Puis « Le conte choisit ce que vous savez des liens envers vous. ».
- **Vide :** « Aucun lien. » dans chaque bloc.
- Aucune action.

### Mobile

Une seule colonne, dans l'ordre des maquettes mobiles.

## Erreurs et cas limites

- **Refus d'écriture :** « Enregistrement refusé : réessayez. ».
- **Fiche supprimée :** ses liens restent, sans lien vers la fiche ; les noms recopiés s'affichent.
- **Écritures concurrentes :** la dernière écriture l'emporte (pas de version).
- **Gorgée datée dans le passé :** le niveau effectif est calculé à cette date ; `lastDrink` et `lastContact` ne reculent jamais (on garde la plus récente).

## Tests

- **Calculs purs :**
  - niveau effectif juste avant et juste après chaque délai, et un 3 qui redescend puis s'efface ;
  - fin de mois du calendrier ;
  - échéance et ses phrases ;
  - gorgée plafonnée à 3 ;
  - effacement des liens moindres ;
  - refus quand un lien complet existe ailleurs ;
  - contact sur un lien effacé ;
  - gorgée datée dans le passé ;
  - contrôles.
- **Règles d'accès :**
  - l'équipe lit tout ;
  - le joueur lit selon `known` ou `regnantKnows`, et sa requête sans filtre est refusée ;
  - le narrateur ne peut pas écrire ;
  - le conte ne peut pas écrire un lien qui touche sa propre fiche ;
  - identifiant du document imposé ;
  - suppression refusée ;
  - type d'événement `bond` accepté.
- **Écrans :**
  - le conte enregistre une gorgée et un contact depuis la fiche et depuis la page ;
  - le lien complet efface les liens moindres ;
  - la goule à dater ;
  - le narrateur en lecture seule ;
  - le joueur ne voit que les liens connus ;
  - pas de débordement à 390 px.

## Hors périmètre

- Le réglage des délais dans les paramètres de la chronique.
- Les liens des serviteurs (dossiers séparés).
- Le coût en Volonté pour résister à un lien.
- Les liens de sang de PNJ envers des personnages non créés dans le portail.
- Les notifications d'échéance.
