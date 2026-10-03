# Portail Personnages MET — Sous-projet 2 : Fiche de personnage et création guidée

Date : 2026-10-02
Statut : en relecture
Dépend de : sous-projet 1, Socle (`docs/superpowers/specs/2026-10-02-socle-design.md`)
Remplace : les anciens sous-projets 2 (Fiche) et 3 (Création guidée), fusionnés à la demande de l'utilisateur.

## Objectif

- Le conteur crée l'amorce d'une fiche de PJ et la rattache à un joueur.
- Le joueur la complète lui-même par la création guidée en 10 étapes, puis la soumet au conte.
- Le conteur valide la fiche, demande des corrections ou la refuse. Une fois la fiche active, il peut la faire évoluer, avec une trace.
- Le conteur crée et remplit lui-même les PNJ, qu'il incarne.

### Critères de réussite

- Un joueur peut mener une création complète, de l'amorce à la soumission, sur le Web comme sur Android.
  - Les budgets, les coûts et les traits dérivés sont calculés automatiquement.
  - Les contrôles affichés correspondent aux maquettes.
- Le conteur voit les mêmes contrôles dans C4. Valider rend la fiche active et visible dans « Mes personnages ».
- Toute modification d'une fiche hors brouillon produit une entrée d'historique, avec son auteur et son motif. Les règles Firestore rendent impossible une modification non tracée, ou un passage en « Active » décidé par le joueur.
- Un joueur ne voit jamais la fiche d'un autre joueur, ni les notes privées du conte.

## Décisions de l'utilisateur

1. **Le conteur crée seulement l'amorce d'un PJ** (nom, joueur rattaché). Seul le joueur remplit sa fiche. Le conteur remplit entièrement les fiches de ceux qu'il incarne : les PNJ.
2. **Une fois un PJ actif**, le conteur peut le modifier directement, avec un motif et une trace (maquette C3).
3. **La création guidée fait partie de ce sous-projet.**
4. **Listes de règles en dur dans le code** (`lib/rules/`). Elles migreront dans Firestore au sous-projet 5.

## Cycle de vie

```
PJ :   conteur crée l'amorce ──► draft ──(joueur soumet)──► review
                                  ▲  │                        │
                                  │  └── retire la soumission ┤
                                  └──── corrections demandées ┤
                                                              ├──► active ──► retired / dead
                                                              └──► rejected (archivée, lecture seule)
PNJ :  conteur crée et remplit ──► active (pas de validation, XP libre)
```

| État | Joueur (sa fiche) | Conteur |
|---|---|---|
| `draft` | remplit librement (création guidée), sans historique | voit ; fixe le bonus d'XP du conte ; ne remplit pas un PJ |
| `review` | lecture seule ; peut retirer sa soumission | valide, demande des corrections (commentaire obligatoire) ou refuse (commentaire obligatoire) |
| `active` | lecture seule (ses demandes arrivent au sous-projet 4) | modification directe, avec motif |
| `retired`, `dead`, `rejected` | lecture seule | change le statut, avec motif |
| PNJ, tous états | — | tout, avec trace |

**Conteur qui joue aussi (C33) :** sur une fiche dont il est le joueur (`playerUid == uid`), un conteur est traité comme un joueur. Il ne peut ni la valider, ni la modifier, ni lire ses notes privées.

## Écrans

| Écran | Maquettes | Route |
|---|---|---|
| Mes personnages | `Joueur`, `Joueur-mobile` (J1) | `/joueur`, et `/joueur/personnages`. Une fiche en brouillon affiche « Reprendre la création », une fiche en validation « En validation » |
| Ma fiche, en lecture | `J-Fiche`, `J-Fiche-mobile` (J2) | `/joueur/personnages/:id` |
| Historique de la fiche | `J-Historique`, `J-Historique-mobile` (J6) | `/joueur/personnages/:id/historique` |
| Création guidée, étapes 1 à 10 | `J-Creation-1` à `J-Creation-10`, et mobiles | `/joueur/personnages/:id/creation/:etape` |
| Fiche soumise | `J-Creation-Soumise`, mobile | `/joueur/personnages/:id/soumise` |
| Toutes les fiches | `C-Fiches`, `C-Fiches-mobile` (C2) | `/conteur/fiches` |
| Nouvelle fiche (amorce de PJ, ou PNJ) | dialogue sur C2 | `/conteur/fiches` |
| Fiche en édition (PJ actif ou PNJ) | `C-Fiche`, `C-Fiche-mobile` (C3) | `/conteur/fiches/:id` |
| Validation des créations | `C-Validation`, `C-Validation-mobile` (C4) | `/conteur/demandes` (file filtrée sur « Création ») |

**Hors périmètre**

| Élément | Où il arrive |
|---|---|
| Onglets Moralité et Récit en lecture (le récit se saisit à l'étape 10) | sous-projet 7 |
| Demandes du joueur après création, dépense d'XP hors création, gain mensuel, paramètres d'XP | sous-projet 4 (`/conteur/demandes` ne liste ici que les créations) |
| Référentiel éditable : rareté des clans par chronique, catalogue complet des atouts, rituels | sous-projet 5 |
| Goules, alliés détaillés, lieux, équipement | sous-projet 6 |
| Gel, hors ligne, impression | sous-projet 8 |
| Portrait (le stockage de fichiers exige le forfait Blaze) | emplacement affiché avec les initiales |
| Sélection multiple de C2 | sous-projets 4 et 8 |

## Données Firestore

### `characters/{id}`

```
name: string (1–80)            kind: "pj" | "pnj"
playerUid: string?             playerName: string?           // PNJ : null
status: "draft" | "review" | "active" | "retired" | "dead" | "rejected"
concept, archetype, clan, lineage, sect, sire, title, story: string?
inspiration: { before, embrace, became }: string?            // 3 questions de l'étape 1
generation: { rank: "neonate"|"ancilla"|"pretender", number: int }?
attributeRanks: { primary, secondary, tertiary }: "physical"|"social"|"mental"?
attributes: { physical|social|mental: { value: int, focus: string? } }
skills:      [ { name, level, specialty? } ]
backgrounds: [ { name, level, details? } ]
disciplines: [ { name, level, inClan: bool, powers: [string] } ]
merits: [ { name, points } ]   flaws: [ { name, points } ]
blood, bloodPerTurn, willpower, humanity: int   health: string
xpInitial: int     // 30 + bonus du conte + handicaps (≤ 7), figé à la validation
xpBonus: int       // « Bonus du conte », fixé par un conteur
xpEarned: int      // XP mise de côté à la création (≤ 5), puis gains (sous-projet 4)
xpSpent: int
creation: { purchases: [ {kind, name, toLevel, cost} ], step: int,
            submittedAt?, decidedAt?, decidedByUid?, comment? }
version: int       lastHistoryId: string?    createdAt, updatedAt: timestamp
```

- Pendant le brouillon, `xpInitial`, `xpEarned` et `xpSpent` sont recalculés par le moteur.
- Les niveaux finaux sont dans les listes de la fiche. La part gratuite d'un trait vaut son niveau final moins les achats de l'étape 9 ; c'est ce qui permet de vérifier les budgets.

### `characters/{id}/history/{h}`

```
at: timestamp (request.time)   byUid, byName: string
kind: "creation" | "submission" | "withdrawal" | "validation" | "corrections" | "rejection" | "edit" | "status" | "bonus"
summary: [string]   reason: string   xpDelta: { initial, earned, spent }: int
```

### `characters/{id}/private/notes`

```
text: string (≤ 5000), updatedAt, byUid
```

**Requêtes :**
- joueur : `playerUid == uid` ;
- conteur : toute la collection, triée par `name` ;
- C4 : `status == "review"`, triée côté client par `creation.submittedAt`.

Aucun index composite.

## Moteur de règles (`lib/rules/`, Dart pur, testé)

### Listes (`met_lists.dart`)

- **Sectes :** Camarilla, Anarchs, Sabbat, Indépendants.
- **Clans** (disciplines en clan · rareté) :

  | Rareté | Clans |
  |---|---|
  | Communs | Brujah (Célérité, Puissance, Présence), Caïtiff (3 disciplines communes au choix), Gangrel (Animalisme, Force d'âme, Protéisme), Malkavien (Aliénation, Auspex, Occultation), Nosferatu (Animalisme, Occultation, Puissance), Toreador (Auspex, Célérité, Présence), Tremere (Auspex, Domination, Thaumaturgie), Ventrue (Domination, Force d'âme, Présence) |
  | Peu communs (atout « Clan peu commun », 2 points) | Assamites (Célérité, Occultation, Quietus), Giovanni (Domination, Nécromancie, Puissance), Disciples de Set (Occultation, Présence, Serpentis), Ravnos (Animalisme, Chimérie, Force d'âme) |
  | Rares (atout « Clan rare », 4 points, accord du conte) | Lasombra (Domination, Obténébration, Puissance), Tzimisce (Animalisme, Auspex, Vicissitude), Salubri (Auspex, Force d'âme, Obeah) |

- **Disciplines communes** (seules achetables hors clan à la création) : Animalisme, Auspex, Célérité, Domination, Force d'âme, Occultation, Présence, Puissance.
- **Attributs et focus :** Physique (Force, Dextérité, Vigueur) ; Social (Charisme, Manipulation, Apparence) ; Mental (Perception, Intelligence, Astuce).
- **Compétences** (26) : Animaux, Armes à feu, Artisanat*, Athlétisme, Bagarre, Commandement, Conduite, Connaissances, Empathie, Érudition, Esquive, Expérience de la rue, Furtivité, Informatique, Intimidation, Investigation, Linguistique, Médecine, Mêlée, Occultisme, Représentation*, Sciences*, Sécurité, Subterfuge, Survie, Vigilance. Une astérisque signale un domaine obligatoire.
- **Historiques :** Alliés, Célébrité, Génération, Identité d'emprunt, Refuge, Ressources, Serviteurs, Troupeau.
- **Générations :**

  | Points de Génération | Rang | Génération | Sang | Coût compétence et historique |
  |---|---|---|---|---|
  | 1 | Neonate | 13e à 11e | 10, 1 par tour | nouveau niveau × 1 |
  | 2 | Ancilla | 10e et 9e | 12, 2 par tour | nouveau niveau × 2 |
  | 3 | Pretender Elder | 8e | 15, 3 par tour | nouveau niveau × 2 |

- **Archétypes :** une liste de base (Je-sais-tout, Architecte, Autocrate, Bon vivant, Bravache, Conformiste, Déviant, Enfant, Fanatique, Gentilhomme, Juge, Loup solitaire, Martyr, Monstre, Pédagogue, Pénitent, Protecteur, Rebelle, Survivant, Visionnaire), plus « Autre ».
- **Atouts et handicaps de base :** ceux des maquettes, plus les atouts automatiques de rareté de clan.
  - Atouts : Cœur calme 1, Érudit des traditions 1, Sommeil léger 1, Chanceux 2, Apprenti efficace 2, Volonté de fer 3, Esprit labyrinthique 3, Visage angélique 1, Oreille qui traîne 1.
  - Handicaps : Amnésie 1, Sombre secret 1, Illettré 1, Addiction 2, Impatient 2, Sommeil profond 2, Curiosité 2, Intolérance 1, Traqué 4.
  - Plus « Autre… », avec un nom et des points libres.

Toute valeur peut aussi être « Autre… » en saisie libre, avec un avertissement dans les contrôles (« à confirmer par le conte »).

### Règles de création (`creation_rules.dart`)

- **Attributs :** les trois catégories sont classées primaire 7, secondaire 5, tertiaire 3. Un focus par catégorie. Un point d'attribut acheté coûte 3 XP ; plafond de 10 par catégorie.
- **Compétences gratuites :** exactement une à 4, deux à 3, trois à 2, quatre à 1. Un domaine est obligatoire pour Artisanat, Représentation et Sciences. Plafond de 5.
- **Historiques gratuits :** exactement un à 3, un à 2, un à 1, dont au moins 1 en Génération (sans Génération, le personnage est mortel : contrôle bloquant). Plafond de 5.
- **Disciplines en clan gratuites :** une à 2, deux à 1. Le Caïtiff choisit ses trois disciplines parmi les communes.
- **Atouts :** au plus 7 points au total, rareté de clan comprise. Ils se paient en XP (leur valeur).
- **Handicaps :** ils rapportent leur valeur en XP, 7 au plus. On peut en prendre au-delà, avec l'accord du conte, mais sans gain supplémentaire.
- **Achats de l'étape 9 :**
  - compétence ou historique : nouveau niveau × 1 (Neonate) ou × 2 (Ancilla, Pretender) ;
  - discipline en clan : nouveau niveau × 3 ;
  - discipline hors clan : nouveau niveau × 4, uniquement dans une discipline commune, 3 points hors clan au total à la création ;
  - attribut : 3 XP ;
  - Génération : nouveau niveau × 2 (création uniquement) ;
  - Humanité : 10 XP le point, 6 au plus (livre de base p. 107 et 300) ;
  - rituel : niveau × 2 (avertissement « à confirmer par le conte »).
- **Budget :** 30 + bonus du conte + handicaps (7 au plus) − atouts − achats.
  - Il doit rester ≥ 0 pour soumettre.
  - Le reste, 5 au plus, est mis de côté (`xpEarned`). Le surplus est perdu (avertissement).
- **Traits dérivés :** Sang et Sang par tour selon le rang ; Volonté 6 ; Humanité 5, plus les achats ; Santé « 3 · 3 · 3 ».
- **`creationChecks(c) → List<Check{text, level: ok|todo|warn|error}>`** : la liste des maquettes (étape 4, étape 10, C4). La soumission est impossible tant qu'un contrôle est en `error` ou en `todo`.
- **`stepComplete(c, step)`** : sert à la coche de chaque étape dans la navigation latérale.

### Autres fonctions pures

- **`describeChanges(before, after)`** : résumé lisible (`Présence ●● → ●●●`, `Humanité 5 → 4`, `Statut : Active → Mort ultime`, `Joueur : A → B`, `XP gagnée 30 → 33`).
- **`xpAvailable(c)`**, **`filterCharacters(list, filtre)`** (C2, sans tenir compte des accents ni de la casse).
- **`Character.fromDoc` / `toMap`** : aller-retour sans perte.

## Droits et règles de sécurité

Fonctions : `isStaff()` (narrateur, conteur, principal), `managesAccounts()` (conteur, principal), `own()` (`playerUid == auth.uid`), `historyAfter(id)` (`getAfter` sur l'entrée `lastHistoryId` de la nouvelle version).

**Champs protégés pour le joueur :** `playerUid`, `playerName`, `kind`, `xpBonus`, `status`, `version`, `lastHistoryId`, `createdAt`, `creation.decidedAt`, `creation.decidedByUid`, `creation.comment`.

| Opération | Qui | Conditions |
|---|---|---|
| Lire une fiche ou son historique | `own()` ou `isStaff()` | — |
| Créer | `managesAccounts()` | version 1 ; entrée `creation` créée dans le même lot, `byUid == auth.uid` ; PJ → `draft` et `playerUid` différent de soi ; PNJ → `active` et `playerUid` nul |
| Modifier son brouillon | `own()` | statut `draft` avant et après ; aucun champ protégé modifié ; version +1 |
| Soumettre ou retirer sa soumission | `own()` | `draft` → `review` ou `review` → `draft` ; seuls `status`, `creation.submittedAt`, `version` et `lastHistoryId` changent ; entrée `submission` ou `withdrawal` par soi |
| Fixer le bonus du conte | `managesAccounts()`, pas `own()` | statut `draft` ; seuls `xpBonus`, `version` et `lastHistoryId` changent ; entrée `bonus` |
| Décider d'une création | `managesAccounts()`, pas `own()` | `review` → `active`, `draft` ou `rejected` ; entrée `validation`, `corrections` ou `rejection` ; commentaire non vide pour `corrections` et `rejection` |
| Modifier une fiche active ou un PNJ | `managesAccounts()`, pas `own()` avant ni après | statut avant ∈ {`active`, `retired`, `dead`} ou PNJ ; version +1 ; entrée par soi, `at == request.time`, motif non vide |
| Écrire une entrée d'historique | l'auteur de l'opération ci-dessus | `byUid == auth.uid`, `at == request.time`, la fiche pointe vers elle après l'écriture |
| Modifier ou supprimer une entrée d'historique ; supprimer une fiche | personne | — |
| Notes privées | `managesAccounts()`, pas `own()` sur la fiche parente | — |

**Limite assumée :** les budgets de création ne sont pas vérifiés par les règles Firestore. Ces calculs sont trop complexes pour ce langage, et le forfait Spark ne permet pas de serveur. La garantie vient du moteur partagé (la soumission est bloquée dans l'app, les contrôles sont réaffichés dans C4) et de la validation humaine, seule à pouvoir rendre un PJ actif.

## Comportements

- **Enregistrement du brouillon :** le brouillon est enregistré à chaque changement d'étape, et 3 secondes après la dernière saisie. L'app affiche « Brouillon enregistré il y a … ». En cas d'échec, le brouillon reste en mémoire, un bandeau « Non enregistré, nouvel essai… » s'affiche, et l'app réessaie au prochain changement.
- **Navigation :** les étapes sont libres, on peut revenir en arrière. Chaque étape affiche sa coche selon `stepComplete`. « Quitter (brouillon conservé) » ramène à Mes personnages.
- **Soumission (étape 10) :** le bouton est actif seulement si tous les contrôles sont `ok` ou `warn`. La soumission fixe `xpInitial`, `xpEarned` (mis de côté) et `xpSpent`, enregistre `submittedAt` et une entrée `submission`, puis ouvre l'écran « Fiche soumise ».
- **C4 :** une file des fiches en `review`, la plus ancienne en premier. Le détail affiche la fiche complète et `creationChecks`, un commentaire au joueur, et trois boutons : « Valider et activer », « Demander des corrections » (commentaire obligatoire) et « Refuser » (commentaire obligatoire, confirmation demandée).
- **C3 :** une édition directe sur un PJ actif ou un PNJ, avec une barre « N modifications non enregistrées ». Enregistrer affiche le récapitulatif (`describeChanges`) et demande un motif obligatoire.
  - En cas de conflit de version : « La fiche a été modifiée par quelqu'un d'autre entre-temps », puis la fiche est rechargée et le brouillon local conservé.
  - Notes privées enregistrées à part.
- **Nouvelle fiche (C2) :** l'app demande le type.
  - PJ : nom et joueur obligatoire. La fiche est créée en `draft` et reste visible dans C2 avec le statut Brouillon.
  - PNJ : nom. La fiche est créée en `active`, puis l'app ouvre C3.

## Gestion des erreurs

- **Fiche d'un autre joueur :** l'écran « Cette fiche n'est pas la vôtre ».
- **Fiche introuvable :** l'écran « page introuvable ».
- **Écriture refusée ou réseau :** SnackBar « Enregistrement impossible. Réessayez. », et le brouillon local est conservé.
- **Étape de création ouverte sur une fiche qui n'est pas en `draft`** : redirection vers la fiche, en lecture.

## Tests

1. **Règles** (`rules_test/characters.test.js`) :
   - lecture cloisonnée entre joueurs, et le narrateur lit tout ;
   - création d'amorce et de PNJ, avec un historique obligatoire ;
   - un joueur modifie son brouillon, mais pas les champs protégés, ni hors `draft` ;
   - soumettre et retirer, mais pas passer soi-même en `active` ;
   - bonus du conte ;
   - décisions du conteur, avec commentaire obligatoire ;
   - modification d'une fiche active : sans historique refusée, version non incrémentée refusée ;
   - entrée d'historique non modifiable ;
   - le conteur qui joue ne valide pas sa fiche ;
   - notes privées.
2. **Moteur de règles :**
   - chaque contrôle : attributs, compétences, domaines, historiques, Génération, disciplines, Caïtiff, atouts, handicaps (plafond), budget, mise de côté ;
   - chaque coût, en Neonate et en Ancilla ;
   - les traits dérivés.
3. **Autres fonctions pures :** `describeChanges`, `Character`, `filterCharacters`.
4. **Widgets :**
   - étape 4 : choisir les catégories met à jour les contrôles ;
   - étape 10 : bouton Soumettre désactivé tant qu'un contrôle échoue ;
   - C4 : commentaire obligatoire pour les corrections ;
   - C3 : motif obligatoire ;
   - J2 en Web et mobile.

Pas de test de bout en bout ; un parcours manuel sur les émulateurs à la fin : amorce, création complète, soumission, corrections, nouvelle soumission, validation, puis modification par le conteur.
