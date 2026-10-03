# Portail Personnages MET — Sous-projet 5 : Référentiel des règles

Date : 2026-10-03
Statut : validé en conversation, en attente de relecture
Dépend de :
- sous-projet 2, Fiche et création (`2026-10-02-fiche-design.md`) ;
- sous-projet 4, Expérience (`2026-10-03-xp-design.md`).

Maquettes :
- `C-Atouts`, `C-Handicaps`, `C-Clans`, `C-Disciplines`, `C-Rituels`, `C-Techniques` ;
- `C-Competences`, `C-Generations`, `C-Historiques`, `C-Allies`, `C-Archetypes`, `C-Sectes` ;
- `C-Voies`, `C-Derangements`, `C-Titres`, `C-Equipement`, `C-QualitesLieux`, `C-QualitesAnimales`, `C-Sang` ;
- `C-Referentiel-mobile`.

Livres de règles : MET : VTM, livre de base, extension V2 et Volume 2 n° 1.

## Objectif

Les conteurs gèrent eux-mêmes, depuis l'application, toutes les données de règles de la chronique, en 18 catégories, sans toucher au code. La création et la dépense d'XP les utilisent. On peut en plus acheter des rituels, des techniques et des pouvoirs d'anciens, avec leurs contrôles.

## Décisions

1. **Les 18 catégories des maquettes.**
   - Les catégories sans mécanique (voies, dérangements, titres, équipement, qualités de lieu et animales, sang et chasse, alliés) sont éditables dès maintenant.
   - Les sous-projets 6 et 7 les utiliseront.
2. **Remplissage :**
   - les valeurs de base actuelles du code, chargées en un clic ;
   - puis un import CSV ;
   - et la saisie manuelle.
   - Aucun texte des livres n'est recopié : la « règle affichée aux joueurs » est rédigée par le conte. Les noms, les noms VO, les coûts et les numéros de page peuvent être saisis.
3. **Architecture :**
   - une collection par catégorie et un document par élément ;
   - des écrans génériques construits à partir d'un schéma de champs par catégorie ;
   - quelques vues dédiées, là où la maquette est plus riche.
4. **Les moteurs de création et d'XP lisent un `Rulebook`.**
   - Une catégorie vide retombe sur les valeurs de base du code : un référentiel partiellement rempli ne casse rien.
5. **Achats de rituels, de techniques et de pouvoirs d'anciens** à la création et en XP, avec leurs contrôles.
6. **Pas de migration des fiches :**
   - les nouveaux champs d'une fiche sont tolérés par les règles à liste de clés fermée, s'ils passent d'absents à vides ;
   - les fiches gardent le **nom** des éléments, comme aujourd'hui.

## Hors périmètre

| Élément | Où |
|---|---|
| Attribuer un titre, un territoire, un lieu ou une goule depuis une fiche | sous-projets 6 et 7 |
| Voies d'illumination sur la fiche (moralité autre que l'Humanité), péchés | sous-projet 7 |
| Rangs Master et Luminary Elder | non retenu (8e génération au plus pour un PJ) |
| Atout « Suprématie rituelle » (rituels à × 1), talismans, transformations des techniques | correction d'XP par le conte ; information seulement |
| File « Domaines à valider » de C-Competences | les demandes d'XP couvrent déjà ce besoin |
| Wiki côté joueur | sous-projet 9 |

## Modèle de données

### `rules/{catégorie}` (réglages) et `rules/{catégorie}/entries/{id}` (éléments)

Chaque élément a les champs communs suivants :

```
name: string            nom français (1 à 80 caractères)
vo: string | null       nom anglais, pour retrouver la règle
state: 'available' | 'approval' | 'draft' | 'forbidden'
                        Disponible · Accord du conte · Brouillon · Interdit
source: string | null   « Livre de base, p. 249 »
description: string     règle affichée aux joueurs, rédigée par le conte
data: map               champs propres à la catégorie (ci-dessous)
updatedAt, updatedByUid, updatedByName
```

La note réservée au conte vit à part, dans `rules/{catégorie}/entries/{id}/private/note`, avec le champ `{ text }`.

L'identifiant de chaque catégorie (`{catégorie}`) est son nom anglais en camelCase. Champs propres à chaque catégorie (`data`) et réglages (`rules/{catégorie}`) :

| Catégorie (id) | `data` | Réglages |
|---|---|---|
| Atouts (`merits`) | `cost`, `type` (general, clan, sect, morality, rarity, chronicle), `restrictedTo` (nom de clan, de lignée ou de secte), `atCreation`, `withXp`, `countsInLimit` | — |
| Handicaps (`flaws`) | mêmes champs (`countsInLimit` : rapporte des points dans la limite de 7) | — |
| Clans & lignées (`clans`) | `disciplines` (3 noms), `rarity` {secte: common, uncommon, rare, forbidden}, `weakness`, `bloodlines` [{name, merit}] | — |
| Disciplines (`disciplines`) | `common` (bool), `school` (thaumaturgy, necromancy, abyss, ou null), `parent` (discipline mère d'une voie), `powers` [{level, name, vo, elder, activation, test, effect}] | — |
| Rituels (`rituals`) | `school`, `level` (1 à 5), `talisman`, `atCreation`, `withXp` | `costPerLevel` (2) |
| Techniques (`techniques`) | `prerequisites` [[{discipline, level}]] (alternatives de conjonctions), `transformation` (none, minor, major) | — |
| Pouvoirs d'anciens (`elderPowers`) | `discipline`, `costInClan` (18), `costOutOfClan` (24) | — |
| Compétences (`skills`) | `domainMode` (perDot, multiple, optional, none), `domains` (suggestions), `cap` (5) | — |
| Générations (`generations`) | un élément par rang (neonate, ancilla, pretender) : `numbers` [13, 12, 11], `blood`, `bloodPerTurn`, `attributeBonus`, `skillCap`, `traitFactor` (1 ou 2), `outOfClanFactor` (4), `techniqueCost`, `eldersAllowed`, `eldersLimit` | — |
| Historiques (`backgrounds`) | `ask` (monthly, people, specialties, text), `cap`, `approvalRequired`, `scale` [montant par niveau] | — |
| Alliés (`allies`) | spécialisations : `effect`, `condition` | `maxLevel`, `returnAfter`, `types`, `domains` |
| Archétypes (`archetypes`) | — | `freeAllowed` |
| Sectes (`sects`) | `playable` (all, pjOnApproval, npcOnly), `isDefault` | — |
| Voies & moralité (`paths`) | `meritCost` (3), `maxMorality`, `sins` [5 textes], `sectStatus` {secte: accepted, heretic, none}, `changeNeedsApproval` | — |
| Dérangements (`derangements`) | `type` (belief, incapacity, compulsion, phobia, destruction, obsession), `gameEffect`, `asFlaw`, `byPower` | — |
| Titres (`titles`) | `sect`, `count` (unlimited, unique, perClan, ou un nombre), `under`, `public`, `onSheet`, `npcOnly` | — |
| Équipement (`equipment`) | qualités : `categories` (melee, ranged, armor, gear), `incompatible`, `outsideLimit`, `resale` | par catégorie : `damage`, `hands`, `qualitiesNormal`, `qualitiesCheap` |
| Qualités de lieu (`placeQualities`) | `family` (standard, iconic, supernatural, negative, elysium), `repeatable` (1 à 3), `placeTypes` | — |
| Qualités animales (`animalQualities`) | `cost`, `requires` | — |
| Sang & chasse (`blood`) | `block` (resonance, hunting, territory), `effect`, `linkedTo` | `enabled` {bloc: bool} |

### Valeurs de création (`chronicle/xp`, nouvelle clé `creation`)

```
creation: {
  attributeSlots: [7, 5, 3],
  skillSlots: [4, 3, 3, 2, 2, 2, 1, 1, 1, 1],
  backgroundSlots: [3, 2, 1],
  disciplineSlots: [2, 1, 1],
  startingXp: 30, maxFlawXp: 7, maxSetAside: 5,
  defaultBonus: 0
}
```

### Fiche (`characters/{id}`) : nouveaux champs, écrits par `toMap`

```
rituals: [{ name, school, level }]
techniques: [string]
elderPowers: [{ name, discipline }]
attributeBonus: { physical: int, social: int, mental: int }   // points bonus de Génération placés
```

- **Plafond d'une catégorie d'attributs :** 10 + `attributeBonus[cat]`.
- **Somme des points placés :** elle ne dépasse pas `attributeBonus` du rang (tableau des générations).

## Écrans

### « Référentiel » (`/conteur/referentiel`)

- **Accès :** conteurs et principal. Le narrateur le voit en lecture seule.
- **Web :**
  - à gauche, les 18 catégories avec leur nombre d'éléments ;
  - au centre, la liste ;
  - à droite, le panneau d'édition.
- **Mobile :** le menu des catégories, puis la liste, puis l'édition en page entière.
- **Liste générique :**
  - titre et phrase d'aide de la catégorie ;
  - filtres par état et par un ou deux champs clés : type d'atout, école, famille, secte, catégorie d'équipement ;
  - recherche sur le nom et le nom VO ;
  - colonnes : nom (et VO), champs clés, « Fiches » (nombre de fiches qui portent ce nom), état.
- **Boutons :**
  - « Nouvel élément » ;
  - « Importer / exporter » ;
  - « Charger les valeurs de base » quand la catégorie est vide.
- **Panneau d'édition générique :**
  - il est construit depuis le schéma de la catégorie : texte, nombre, choix, cases, liste de valeurs, liste de lignes ;
  - il porte aussi les champs communs (état, source, règle affichée aux joueurs) et la note du conte ;
  - boutons « Enregistrer » et « Supprimer ».
- **Messages d'avertissement :**
  - renommer un élément utilisé : « N fiches portent l'ancien nom ; elles ne sont pas modifiées » ;
  - changer le coût : « Les fiches existantes ne changent pas » ;
  - supprimer un élément utilisé : confirmation, avec la proposition « Marquer Interdit » ;
  - l'élément a été modifié par un autre conteur depuis l'ouverture : « Modifié par X à l'instant », avec le choix « Recharger » ou « Écraser ».
- **Vues dédiées :**
  - **Clans :** 3 disciplines, rareté pour chaque secte, faiblesse, lignées ;
  - **Disciplines :** arborescence (communes, propres, écoles et voies), avec les pouvoirs en sous-liste ;
  - **Générations :** tableau des 3 rangs, éditable ;
  - **Alliés :** règles générales, types, domaines et spécialisations sur une page ;
  - **Équipement :** bandeau des règles de base de la catégorie choisie ;
  - **Sang & chasse :** activation des blocs.

### Valeurs de création

Dans « Paramètres d'expérience », le bloc « XP de création » devient éditable : répartitions, XP de départ, maximums, bonus de départ par défaut.

### Côté joueur

- **Dans la création et dans « Dépenser de l'XP » :**
  - la « règle affichée aux joueurs » s'affiche sous l'élément choisi ;
  - un badge « Accord du conte » s'affiche pour un élément en accord du conte ;
  - les éléments brouillons ou interdits ne sont pas proposés.
- **Fiche (J2, C3) :** sections Rituels, Techniques et Pouvoirs d'anciens.

### Import / export CSV

- **Export :** un fichier par catégorie, en UTF-8 avec séparateur « ; ».
  - Une colonne par champ commun et par champ propre.
  - Les listes sont séparées par « | ».
  - Les objets imbriqués (pouvoirs, lignées, prérequis) sont écrits en JSON dans la cellule.
- **Import :**
  - **Aperçu :** « N nouveaux, M modifiés, K lignes en erreur », avec la ligne et le motif.
  - **Doublons :** ils se repèrent par le nom (sans tenir compte de la casse ni des espaces).
  - **Écriture :** par lots de 400, seulement après la confirmation « Importer N éléments ».
  - **Colonne inconnue :** elle est ignorée, avec un avertissement.
  - **Nom ou état manquant :** la ligne est en erreur.

## Moteurs : `Rulebook`

- **`Rulebook`** (pur) contient :
  - les listes des 18 catégories, avec des recherches par nom ;
  - les valeurs de création ;
  - le tableau des générations.
- **Provider `rulebookProvider` :** il combine les flux des catégories et de `chronicle/xp`.
- **Valeurs de base :** `Rulebook.base()` reprend les listes actuelles de `met_lists.dart` et les constantes de création. Chaque catégorie vide prend sa version de base.
- **Ce qui reste fixe dans le code :** les catégories d'attributs et les focus, les rangs, la Santé.
- **Fonctions qui reçoivent `rb`** (création et XP) : `creationChecks`, `budgetOf`, `purchaseCost`, `addPurchase`, `applyDerived`, `costOf`, `elementOptions`, `itemError`, `requestChecks`, `sendProblems`, `applyRequest`.
- **États :**
  - **Accord du conte :** contrôle d'avertissement « X : accord du conte nécessaire ».
  - **Interdit ou brouillon** présent sur une fiche : contrôle d'erreur « X est interdit dans la chronique ».
  - **Nom absent du référentiel** (et de la base) : avertissement « hors liste ».
- **Clans :**
  - la rareté est lue pour la secte de la fiche ;
  - `forbidden` : le clan n'est pas proposé, et c'est une erreur s'il est déjà sur la fiche ;
  - lignée choisie : son atout entre dans le total des atouts.
- **Sectes :** à la création d'un PJ, seules les sectes `all` ou `pjOnApproval` sont proposées ; `pjOnApproval` donne un avertissement.
- **Disciplines :** `common` détermine les disciplines achetables hors clan à la création.
- **Compétences :**
  - `perDot` et `multiple` : précision obligatoire ;
  - `optional` : précision facultative ;
  - `none` : pas de précision ;
  - plafond : `cap` de la compétence, borné par `skillCap` du rang.
- **Historiques :**
  - plafond `cap` ;
  - précision obligatoire selon `ask` ;
  - montant hors barème : avertissement « Montant hors barème : à valider par le conte ».
- **Générations :** coûts et plafonds lus dans la ligne du rang de la fiche.
- **Points bonus d'attribut :**
  - acheter un attribut au-delà de 10 demande d'y placer un point bonus ;
  - l'achat porte le placement (`XpItem.note = 'bonus'`), appliqué à la validation ;
  - erreur si plus aucun point n'est disponible.

## Rituels, techniques, pouvoirs d'anciens

Trois nouveaux types d'achat : `XpKind.ritual`, `technique` et `elderPower`, à l'étape 9 de la création (`Buy`) et dans « Dépenser de l'XP ».

| Achat | Coût | Contrôles (erreur sauf mention) |
|---|---|---|
| Rituel | `level × costPerLevel` | une discipline ou une voie de l'école sur la fiche ; nombre de rituels de l'école ≤ somme des points de ses disciplines et voies ; au moins un rituel de chaque niveau inférieur ; pas de doublon ; à la création : avertissement « à confirmer par le conte » |
| Technique | `techniqueCost` du rang | technique non interdite au rang (`techniqueCost` > 0) ; au moins une alternative de prérequis remplie ; pas de doublon |
| Pouvoir d'ancien | `costInClan` ou `costOutOfClan` | `eldersAllowed` au rang ; 5 points dans la discipline ; nombre total < `eldersLimit` ; hors clan : avertissement « Professeur nécessaire » |

- **Messages d'exemple :**
  - « Voie du Sang ●●● : 3 rituels au plus, vous en avez 3 » ;
  - « Il manque un rituel de niveau 2 » ;
  - « Prérequis manquant : Présence ●● » ;
  - « Pouvoir d'ancien : 5 points d'Auspex requis ».
- **`requestChecks` et `creationChecks`** refont ces contrôles sur la fiche actuelle, comme pour les autres achats : niveau changé, prérequis perdus.
- **`applyRequest`** ajoute l'élément à la liste de la fiche.
- **Annulation d'un achat** (corrections) : elle retire l'élément.
- **C3 :** édition directe des trois listes par le conteur, avec motif et historique, comme le reste de la fiche.

## Sécurité (`firestore.rules`)

- **`rules/{cat}` et `rules/{cat}/entries/{id}` :**
  - lecture si connecté ;
  - écriture si `managesAccounts()` ;
  - entrée valide : `name` est une chaîne de 1 à 80 caractères, `state` vaut une des 4 valeurs, `data` est une map, `updatedByUid == auth.uid`.
- **`rules/{cat}/entries/{id}/private/note` :** lecture si `isStaff()`, écriture si `managesAccounts()`.
- **`chronicle/xp` :** règle existante (écriture par `managesAccounts()`).
- **Fiche : tolérance des nouvelles clés** (`rituals`, `techniques`, `elderPowers`, `attributeBonus`) :
  - les règles `playerSubmission`, `staffBonus` et `staffDecision` appliquent leur `hasOnly` aux clés modifiées **moins** ces quatre clés ;
  - à condition que chacune soit inchangée, ou passe d'absente à sa valeur vide (`[]` ou `{}`).
  - `playerDraftSave` les laisse modifier (brouillon) ; `staffEdit` aussi.
- **Joueur sur une fiche active :** il n'écrit jamais ces clés, car il n'a aucune règle d'écriture sur une fiche active.

## Architecture du code

```
lib/rulebook/schema.dart          18 catégories : id, libellés, aide, champs (type, clé, libellé, options), colonnes, filtres
lib/rulebook/rule_entry.dart      RuleEntry (communs + data), RuleState
lib/rulebook/rulebook.dart        Rulebook (recherches, valeurs de création, générations), Rulebook.base()
lib/rulebook/rules_repository.dart  CRUD, note privée, chargement de base, import par lots ; providers
lib/rulebook/csv.dart             export, analyse et aperçu d'import (pur)
lib/rulebook/referential_screen.dart   menu, liste, panneau générique (Web, mobile)
lib/rulebook/views/*.dart         clans, disciplines, générations, alliés, équipement, sang
lib/rules/creation_rules.dart, lib/xp/xp_rules.dart   paramètre Rulebook ; nouveaux achats
lib/characters/character.dart     nouveaux champs ; sheet_widgets et edit pour l'affichage et C3
```

## Plans

- **A — Référentiel éditable :** schémas, modèle, règles, dépôt, écrans génériques et vues dédiées, valeurs de base, CSV. Les moteurs ne changent pas.
- **B — Moteurs branchés :** `Rulebook`, repli, états et badges, rareté par secte, sectes jouables, domaines, historiques, générations, valeurs de création éditables, points bonus d'attribut.
- **C — Rituels, techniques, pouvoirs d'anciens :** champs de fiche et tolérance des règles, achats et contrôles, affichage et édition C3.

## Tests

- **Unitaires :**
  - `Rulebook.base()` et le repli catégorie par catégorie ;
  - les quatre états dans la création et l'XP ;
  - la rareté par secte et le clan interdit ;
  - les sectes jouables, les modes de domaines, le barème des historiques ;
  - les coûts selon le rang ;
  - les points bonus d'attribut ;
  - pour chaque contrôle de rituel, de technique et de pouvoir d'ancien, un cas qui passe et un cas qui échoue ;
  - CSV : aller-retour, listes et JSON, colonnes inconnues, doublons, erreurs.
- **Règles (émulateur) :**
  - lecture par un joueur ✓, écriture par un joueur ✗ ;
  - note privée lue par un joueur ✗ ;
  - entrée invalide ✗ ;
  - fiche sans les nouvelles clés : soumission, bonus et décision ✓ ;
  - nouvelles clés modifiées dans une soumission ✗.
- **Widgets :**
  - liste, filtres et recherche ;
  - édition générique et enregistrement ;
  - « Charger les valeurs de base » ;
  - import avec aperçu ;
  - vues des clans et des générations ;
  - élément « accord du conte » dans la création ;
  - achat d'un rituel refusé puis accepté.

## Cas à vérifier à la revue

1. Un import CSV qui écrase un élément déjà utilisé par des fiches. L'aperçu le signale (« modifié, utilisé par N fiches »).
2. Un clan rendu « interdit » alors que des fiches actives l'ont : erreur à la validation suivante seulement, les fiches ne sont pas modifiées.
3. Un rituel acheté, puis une voie qui baisse : la limite est dépassée après coup, et l'erreur s'affiche au contrôle suivant.
4. Deux conteurs qui modifient le même élément en même temps : avertissement « Modifié par X », pas d'écrasement silencieux.
5. Un référentiel à moitié rempli (atouts saisis, clans vides) : la création fonctionne avec les clans de base.
