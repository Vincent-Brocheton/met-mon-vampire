# Journal de la chronique (sous-projet 10b) : conception

## Objectif

Le conte retrouve sur une seule page tout ce que l’équipe et l’application ont modifié dans la chronique, toutes fiches confondues : quand, qui, quoi, sur quoi, avec quel détail. On peut filtrer par catégorie, par auteur et par période, et exporter en CSV.

Le sous-projet 10 est découpé en lots :
- 10a Notifications ;
- **10b Journal de la chronique** (ce document) ;
- 10c Import de fiches.

Maquettes (canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp) : `C-Journal`, `C-Journal-mobile`.

## Décisions

- **Mixte : calculé et stocké.**
  - La plupart des lignes sont calculées à partir des traces que l’application tient déjà : historiques, versions du wiki, parties. Le passé apparaît dès la mise en ligne.
  - Les deux sources qui ne laissent aucune trace sont stockées dans une nouvelle collection `journal`, en ajout seul : le référentiel et les comptes et rôles.
- **Le conte et l’application seulement.** Les entrées écrites par un joueur (soumission et retrait d’une fiche) sont exclues. Une dépense d’XP apparaît quand le conte la valide.
- **Réservé au conteur et au principal.** Le narrateur ne voit ni la page ni l’entrée des Paramètres, comme l’indique déjà le tableau des droits de C33.
- **Ni modifiable ni effaçable.** Les règles refusent toute modification ou suppression dans `journal`, même au principal.
- **Pas de Cloud Functions** (forfait Spark) : toute écriture vient de l’application, dans le même lot que l’action.

## Lignes calculées

Une ligne : catégorie, date, auteur, action, cible (« Sur »), détail, lien facultatif.

| Catégorie | Source | Action | Détail | Lien |
|---|---|---|---|---|
| Fiches | `characters/{id}/history`, sauf `kind` `submission` et `withdrawal` et sauf les types XP ci-dessous | selon `kind` : Modification, Validation, Étreinte… | le `summary`, joint par « ; » ; le motif s’il existe | historique de la fiche |
| XP | `characters/{id}/history` de `kind` `gain`, `award`, `xp`, `correction` | Gain mensuel, XP attribuée, Dépense validée, Correction d’XP | le `summary` ; le motif s’il existe | historique de la fiche |
| Fiches | `history` des lieux, objets, alliés et serviteurs | « Modification » | le `summary` | l’écran de l’élément |
| Wiki | `wiki/{id}/versions/{n}` | « Wiki » | « Version {n} publiée » et la note si elle existe | historique de la page |
| Fiches | les parties (`games`) | « Gel des fiches » | « Fiches figées jusqu’au {date} à {heure} » | écran du gel |

- La cible est le nom de la fiche, de l’élément ou « Page « {titre} » », ou « Partie du {date} ».
- **Regroupement des gains.** Les entrées `gain` qui ont le même `at` (un seul lot) donnent une seule ligne : action « Gain mensuel », cible « {n} fiches » (« 1 fiche »), détail « XP ajoutée selon le palier de chaque fiche », sans lien.
- Les libellés exacts des `kind` et les noms de champs sont relevés dans le code au moment du plan ; le tableau donne l’intention.

## Lignes stockées : `journal/{id}`

| Champ | Contenu |
|---|---|
| `cat` | `rules` ou `accounts` |
| `action` | 1 à 80 caractères |
| `target` | 0 à 120 caractères |
| `detail` | 0 à 300 caractères |
| `link` | chemin de l’application, 200 caractères au plus, ou absent |
| `byUid`, `byName` | auteur |
| `at` | heure du serveur |

**Règles :**
- création si `managesAccounts()`, clés exactes (`keys().hasOnly`), types et tailles valides, `byUid == request.auth.uid`, `at == request.time` ;
- lecture si `managesAccounts()` ;
- `update` et `delete` : jamais.

**Écritures, dans le même lot que l’action :**
- **Référentiel :**
  - enregistrer une entrée : action « Référentiel », cible « {catégorie} « {nom} » », détail « Créée », ou l’ancien état et le nouveau (« Disponible → Interdit ») s’il change, sinon « Modifiée » ;
  - supprimer une entrée : détail « Supprimée », sans lien ;
  - importer : une seule ligne, cible « {catégorie} », détail « Import : {n} entrées ». L’import découpé en plusieurs lots écrit sa ligne dans le premier.
- **Comptes et rôles :**
  - changement de rôle (`setRole`, ce qui couvre l’accès accordé et la désactivation) : action « Rôle », cible le nom du compte, détail « {ancien} → {nouveau} » avec les libellés français des rôles ;
  - invitation envoyée : action « Invitation », cible l’adresse, détail le rôle proposé ;
  - invitation annulée : détail « Annulée ».

## Lecture

- Chaque source est requêtée depuis le début de la période (`at`, `frozenAt`… selon la source), triée par date décroissante.
- Les requêtes sur un groupe de collections (`history`, `versions`) demandent un index sur leur champ de date, ajouté à `firestore.indexes.json`. La règle `{path=**}/versions/{n}` (lecture équipe) est ajoutée si elle manque.
- « Tout » est plafonné à 500 documents par source (commentaire `ponytail:` qui nomme la limite).
- `journalProvider(since)` assemble les sources. Une source en erreur est absente du fil, et la page l’indique.

## Calcul (pur)

`lib/journal/journal_rules.dart` :
- `JournalLine` : `cat`, `at`, `who`, `action`, `target`, `detail`, `link` ;
- une fonction par source, qui rend des `JournalLine` ;
- `groupGains`, `filterLines(lines, {cat, author})`, tri décroissant ;
- `rulesEntryLine` / `roleLine` / `invitationLine`, qui construisent les documents `journal` ;
- `toCsv(lines)` : en-tête Quand;Qui;Action;Sur;Détail, guillemets doublés, séparateur « ; ».

`lib/journal/journal_repository.dart` : requêtes, `append(batch, line)`, providers.
`lib/journal/journal_screen.dart` : l’écran.

## Écran

- **Route :** `/conteur/parametres/journal`. `redirect.dart` renvoie ailleurs tout rôle autre que conteur et principal.
- **Paramètres :** l’entrée « Journal de la chronique » devient active, avec le sous-titre « Toutes les modifications du conte. ». Elle est absente pour le narrateur.
- **En-tête :**
  - fil d’Ariane « Paramètres de la chronique / Journal » ;
  - titre « Journal de la chronique » ;
  - sous-titre « Tout ce que les conteurs et l’application ont modifié, toutes fiches confondues. » ;
  - bouton « Exporter en CSV ». Il copie le CSV des lignes filtrées dans le presse-papiers et affiche « CSV copié : {n} lignes. ».
- **Filtres :**
  - puces Tout, Fiches, XP, Wiki, Référentiel, Comptes et rôles ;
  - menu « Auteur » : « Tous les auteurs », puis les auteurs présents dans le fil ;
  - menu « Période » : « 30 derniers jours » (par défaut), « Depuis la dernière partie » (absent s’il n’y a pas de partie), « Tout ».
- **Liste :**
  - **large :** tableau Quand · Qui · Action · Sur · Détail. « Sur » est un lien quand la ligne en a un ;
  - **étroit :** une carte par ligne avec l’action et la date, « Sur · Détail », puis l’auteur ;
  - date courte « 29 sept. · 20:00 ».
- **Liste vide :** « Rien sur cette période. »
- **Pied de page :** « Le journal ne peut être ni modifié ni effacé. L’historique d’une seule fiche reste dans son onglet « Historique ». »
- **Mise en page :** écran à 390 px sans débordement.

## Erreurs et cas limites

- **Source en erreur ou index manquant :** les autres sources s’affichent quand même, et la page montre en tête « Une partie du journal n’a pas pu être chargée. ».
- **Écriture `journal` refusée :** l’action échoue avec elle (même lot) ; rien n’est modifié sans trace. Les messages d’erreur actuels des écrans ne changent pas.
- **Hors ligne :** le lot attend, avec son entrée de journal.
- **Auteur sans nom :** « Inconnu ».
- **Élément supprimé** (page du wiki, entrée du référentiel) : la ligne reste, sans lien.

## Tests

- **Unitaires :**
  - chaque source (action, cible, détail, lien) ;
  - exclusion de `submission` et `withdrawal` ;
  - regroupement des gains (singulier et pluriel) ;
  - filtres catégorie et auteur, tri ;
  - CSV (guillemets, « ; », retours à la ligne) ;
  - détail d’état du référentiel (créée, modifiée, changement d’état) ;
  - libellés des rôles ;
  - import en une seule ligne.
- **Dépôts :** l’entrée `journal` est dans le même lot que l’enregistrement, la suppression ou l’import du référentiel, et que le rôle et l’invitation. Les fakes enregistrent l’appel.
- **Widgets :**
  - tableau en large, cartes à 390 px ;
  - puces, menus, liste vide ;
  - message d’erreur partielle ;
  - export (presse-papiers et message) ;
  - entrée des Paramètres active pour le conteur et absente pour le narrateur.
- **Redirection :** le narrateur et le joueur sont renvoyés ailleurs depuis `/conteur/parametres/journal`.
- **Règles (`rules_test/journal.test.js`) :**
  - création acceptée pour un conteur ou le principal ;
  - création refusée pour le narrateur, pour un joueur, avec un autre `byUid`, une autre date ou une clé en trop ;
  - `update` et `delete` refusés à tous ;
  - lecture refusée au narrateur et au joueur ;
  - lecture des versions du wiki par groupe de collections pour l’équipe.

## Hors périmètre

| Élément | Raison ou suite |
|---|---|
| Chronologie publique pour les joueurs (évoquée dans le 7a) | déjà couverte par la chronologie publique du wiki (9b) |
| Traçage des réglages XP et de la configuration de la chronique | absents de la maquette |
| Export en fichier téléchargé | le presse-papiers suffit, comme pour le référentiel |
| Entrées écrites par les joueurs | le journal trace les actes de l’équipe |
