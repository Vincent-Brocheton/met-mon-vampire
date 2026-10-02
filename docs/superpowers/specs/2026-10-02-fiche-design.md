# Portail Personnages MET — Sous-projet 2 : Fiche de personnage

Date : 2026-10-02
Statut : en relecture
Dépend de : sous-projet 1, Socle (`docs/superpowers/specs/2026-10-02-socle-design.md`)

## Objectif

Donner une existence aux fiches de personnage :

- le conteur crée une fiche, la remplit et la fait évoluer ;
- le joueur consulte ses fiches et leur historique ;
- toute modification est tracée, avec son auteur et son motif.

### Critères de réussite

- Un conteur crée une fiche PJ rattachée à un joueur. Le joueur la voit aussitôt dans « Mes personnages », sur le Web comme sur Android.
- Chaque enregistrement côté conteur produit exactement une entrée d'historique, avec un résumé lisible et un motif. Les règles Firestore rendent impossible une modification non tracée.
- Un joueur ne voit jamais la fiche d'un autre joueur, ni les notes privées du conte. Les tests des règles le prouvent.

## Décisions prises avec l'utilisateur

- **Création :** seul le conteur crée les fiches dans ce sous-projet. La création guidée par le joueur arrive au sous-projet 3.
- **Listes de règles :** elles sont écrites dans le code (`lib/rules/met_lists.dart`) et servent les menus déroulants. Au sous-projet 5, elles migreront dans Firestore et deviendront éditables par le conte.

## Périmètre

| Écran | Maquettes | Route |
|---|---|---|
| Mes personnages | `Joueur`, `Joueur-mobile` (J1) | `/joueur` (remplace J15 dès que le joueur a au moins une fiche) et `/joueur/personnages` |
| Ma fiche, en lecture | `J-Fiche`, `J-Fiche-mobile` (J2) | `/joueur/personnages/:id` |
| Historique de la fiche | `J-Historique`, `J-Historique-mobile` (J6) | `/joueur/personnages/:id/historique` |
| Toutes les fiches | `C-Fiches`, `C-Fiches-mobile` (C2) | `/conteur/fiches` |
| Nouvelle fiche | — (bouton « Nouvelle fiche » de C2) | dialogue sur `/conteur/fiches` |
| Fiche en édition | `C-Fiche`, `C-Fiche-mobile` (C3) | `/conteur/fiches/:id` |
| Historique complet, côté conteur | onglet de C3 | `/conteur/fiches/:id/historique` |

### Hors périmètre

| Élément | Où il arrive |
|---|---|
| Onglets Moralité et Récit | sous-projet 7, et Récit au sous-projet 3 |
| Demandes du joueur, dépense d'XP, coût calculé des achats, attribution d'XP en masse | sous-projet 4 |
| Création guidée, brouillon et soumission par le joueur | sous-projet 3 |
| Goules, alliés détaillés, lieux, équipement | sous-projet 6 |
| Gel, mode hors ligne, impression | sous-projet 8 |
| Import de fiches | sous-projet 10 |

- **Portrait :** le stockage de fichiers Firebase exige le forfait Blaze. L'emplacement de la maquette reste vide, avec les initiales du personnage.
- **Sélection multiple et actions groupées de C2** (attribuer de l'XP, imprimer) : elles arrivent avec les sous-projets 4 et 8.
- **Les statuts `draft` et `review`** existent dans le modèle, mais seuls les sous-projets 3 et suivants les produiront. Ici, une fiche est créée directement `active`.

## Données Firestore

### `characters/{id}`

```
name: string                      // 1 à 80 caractères
kind: "pj" | "pnj"
playerUid: string?                // PJ : le joueur ; PNJ : null
playerName: string?               // copie du nom affiché, pour la liste C2
status: "draft" | "review" | "active" | "retired" | "dead"
clan, sect, generation, archetype, sire, title: string?
attributes: { physical: {value, focus}, social: {value, focus}, mental: {value, focus} }
skills: [ {name, level, specialty?} ]               // specialty = domaine (« chant lyrique »)
backgrounds: [ {name, level, details?} ]            // details : texte libre (revenus, sire…)
disciplines: [ {name, level, inClan: bool, powers: [string]} ]
merits: [ {name, points} ]                          // atouts
flaws: [ {name, points} ]                           // handicaps
blood: int, bloodPerTurn: int, willpower: int, humanity: int, health: string
xpInitial: int, xpEarned: int, xpSpent: int
version: int                      // +1 à chaque enregistrement
lastHistoryId: string             // entrée d'historique créée avec cette version
createdAt, updatedAt: timestamp
```

### `characters/{id}/history/{historyId}`

```
at: timestamp                     // request.time
byUid: string, byName: string
kind: "creation" | "edit" | "xp" | "status"
summary: [string]                 // lignes lisibles : « Présence ●● → ●●● »
reason: string                    // motif, obligatoire sauf pour "creation" ; 1 à 500 caractères
xpDelta: { earned: int, spent: int, initial: int }
```

### `characters/{id}/private/notes`

```
text: string                      // notes du conte, ≤ 5000 caractères
updatedAt: timestamp, byUid: string
```

### Index

- Requête joueur : `playerUid == uid`, triée côté client.
- Requête conteur : collection entière, triée par `name` (index simple).
- Aucun index composite.

## Listes de règles (`lib/rules/met_lists.dart`)

Listes de base en français, figées dans le code.

| Liste | Contenu |
|---|---|
| Sectes | Camarilla, Anarchs, Sabbat, Indépendants |
| Clans | Brujah, Gangrel, Malkavien, Nosferatu, Toreador, Tremere, Ventrue, Assamite, Disciples de Set, Giovanni, Ravnos, Lasombra, Tzimisce, Caïtiff |
| Générations | Neonate, Ancilla, Elder, Pretender Elder |
| Attributs et focus | Physique (Force, Dextérité, Vigueur), Social (Charisme, Manipulation, Apparence), Mental (Perception, Intelligence, Astuce) |
| Compétences | Animaux, Armes à feu, Artisanat, Athlétisme, Bagarre, Commandement, Conduite, Empathie, Érudition, Esquive, Finances, Furtivité, Informatique, Intimidation, Investigation, Linguistique, Médecine, Mêlée, Occultisme, Représentation, Science, Sécurité, Subterfuge, Survie, Vigilance, Connaissances |
| Historiques | Alliés, Contacts, Domaine, Génération, Influence, Mentor, Renommée, Ressources, Serviteurs, Troupeau, Statut |
| Disciplines | Animalisme, Auspex, Célérité, Chimérie, Démence, Domination, Force d'âme, Nécromancie, Occultation, Obténébration, Présence, Protéisme, Puissance, Quietus, Serpentis, Taumaturgie, Vicissitude |
| Archétypes | Architecte, Autocrate, Bon vivant, Bravache, Conformiste, Déviant, Enfant, Fanatique, Gentilhomme, Juge, Loup solitaire, Martyr, Masochiste, Monstre, Pédagogue, Pénitent, Protecteur, Rebelle, Survivant, Visionnaire |

- Les menus déroulants proposent ces listes, plus une option « Autre… » en saisie libre. Une valeur inconnue de la liste reste donc affichée et modifiable.
- La liste sera relue par l'utilisateur à la revue de la spec, puis rendue éditable au sous-projet 5.

## Droits

| Action | Joueur | Narrateur | Conteur, principal |
|---|---|---|---|
| Lire une fiche et son historique | ses fiches (`playerUid == uid`) | toutes | toutes |
| Lire et écrire les notes privées | non | non | oui, sauf sur sa propre fiche |
| Créer une fiche | non | non | oui |
| Modifier une fiche, son statut, son joueur rattaché | non | non | oui, sauf sa propre fiche |
| Supprimer une fiche ou une entrée d'historique | non | non | non |

**Conteur qui joue aussi (C33) :** quand `playerUid == uid`, un conteur est traité comme le joueur de cette fiche.

## Règles de sécurité (ajouts à `firestore.rules`)

Fonctions : `isStaff()` (narrateur, conteur, principal), `managesAccounts()` existant, `ownsCharacter()` (`resource.data.playerUid == request.auth.uid`).

- `characters/{id}`
  - **Lecture :** `ownsCharacter()`, ou `isStaff()`.
  - **Création :** `managesAccounts()`, avec :
    - `version == 1` ;
    - `existsAfter(history/lastHistoryId)` ;
    - une entrée de type `creation` dont `byUid == auth.uid` ;
    - `playerUid != auth.uid` (on ne se crée pas sa propre fiche).
  - **Modification :** `managesAccounts()`, sur une fiche qui n'est pas la sienne (avant comme après, donc pas de rattachement à soi-même), avec :
    - `version == ancienne + 1` ;
    - `lastHistoryId` modifié ;
    - `getAfter(history/nouveau lastHistoryId)` qui existe, avec `byUid == auth.uid`, `at == request.time` et un `reason` non vide.
  - **Suppression :** refusée.
- `characters/{id}/history/{h}`
  - **Lecture :** comme la fiche parente (`get` sur la fiche).
  - **Création :** `managesAccounts()`, avec :
    - `byUid == auth.uid` et `at == request.time` ;
    - la fiche parente qui pointe vers cette entrée après l'écriture (`getAfter(...).lastHistoryId == h`) ;
    - `reason` non vide sauf pour `creation`.
  - **Modification, suppression :** refusées.
- `characters/{id}/private/notes`
  - **Lecture, écriture :** `managesAccounts()` et la fiche parente n'appartient pas à l'auteur de la requête.

## Logique pure (testée unitairement)

- **`Character.fromDoc` / `toMap`** : aller-retour sans perte. Les champs absents prennent des valeurs par défaut (listes vides, 0).
- **`describeChanges(Character before, Character after) → List<String>`** : un résumé lisible par changement.
  - Points : `Présence ●● → ●●●`. Ajout : `+ Empathie ●`. Retrait : `− Mêlée ●`.
  - Valeur chiffrée : `Humanité 5 → 4`.
  - Texte : `Sire : (vide) → Octave Marchetti`.
  - Statut : `Statut : Active → Mort ultime`.
  - Joueur rattaché : `Joueur : Camille R. → Paul V.`.
  - XP : `XP gagnée 30 → 33`.
  - Aucun changement : liste vide, et l'enregistrement est désactivé.
- **`xpAvailable(c) = xpInitial + xpEarned − xpSpent`.**
- **`filterCharacters(list, CharacterFilter)`** pour C2 : type, statuts, secte, clan, texte cherché dans le nom et le joueur, sans tenir compte des accents ni de la casse.

## Écrans

- **J1, Mes personnages :** une carte par fiche, avec nom, clan · secte · génération, statut, XP disponible, Sang, Volonté, Humanité et un bouton « Ouvrir la fiche ». Les fiches retirées ou mortes sont listées après les actives, atténuées. Les sections PNJ confiés et Demandes de la maquette restent hors périmètre.
- **J2, Ma fiche :**
  - en-tête avec le nom et les pastilles statut et PJ/PNJ ;
  - onglets Fiche et Historique (Moralité et Récit sont grisés, « À venir ») ;
  - le contenu de la maquette : identité, traits dérivés, expérience, attributs, compétences, historiques, disciplines, atouts et handicaps ;
  - les boutons « Demander une modification » et « Dépenser de l'XP » sont absents, ils arrivent au sous-projet 4.
- **J6, Historique :**
  - le tableau date, évolution (résumé et motif), par, XP ;
  - les filtres Tout, XP, Modifications, Statut ;
  - le panneau « Bilan d'expérience ».
- **C2, Toutes les fiches :** filtres latéraux (en Web ; en mobile, une feuille « Filtres »), le tableau ou les cartes, le compteur « N fiches · X PJ actifs · Y PNJ » et le bouton « Nouvelle fiche ».
- **Nouvelle fiche :** dialogue avec le nom, le type PJ/PNJ et le joueur (liste des joueurs, obligatoire pour un PJ). La fiche est créée vide et active, avec une entrée « Fiche créée », puis l'app ouvre C3.
- **C3, Fiche en édition :**
  - bandeau « Mode conteur — les modifications s'appliquent directement et sont tracées » ;
  - titre ; statut (Active, Retirée, Mort ultime) ; joueur rattaché (changer) ;
  - toutes les sections sont éditables : menus déroulants, boutons − et + pour les points, ajout et retrait d'éléments ;
  - panneau XP éditable ; aperçu de l'historique récent ; notes privées du conte, enregistrées à part ;
  - barre fixe « N modifications non enregistrées · Annuler · Enregistrer ».
  - « Enregistrer » ouvre une fenêtre avec le récapitulatif (`describeChanges`) et un champ « Motif (obligatoire, visible par le joueur) ». La transaction vérifie la version, met à jour la fiche et crée l'entrée d'historique.
  - **En cas de conflit de version :** le message « La fiche a été modifiée par quelqu'un d'autre entre-temps : rechargez pour voir ses changements », puis rechargement de la fiche en gardant le brouillon local.
  - **Quitter avec des modifications non enregistrées** demande confirmation.

## Gestion des erreurs

- **Lecture refusée** (un joueur sur la fiche d'un autre) : `EmptyState` « Cette fiche n'est pas la vôtre », avec un retour vers Mes personnages.
- **Fiche introuvable :** `EmptyState` page introuvable.
- **Écriture refusée ou réseau :** SnackBar « Enregistrement impossible. Réessayez. », et le brouillon local est conservé.

## Tests

1. **Règles** (`rules_test/characters.test.js`) :
   - un joueur lit sa fiche, pas celle d'un autre ;
   - un narrateur lit tout, n'écrit rien ;
   - un conteur crée avec une entrée de création, et la création sans historique est refusée ;
   - une modification sans nouvelle entrée est refusée ;
   - une modification avec une version non incrémentée est refusée ;
   - une entrée d'historique ne peut être ni modifiée ni supprimée ;
   - un motif vide est refusé ;
   - le conteur qui joue : lecture de sa fiche oui, modification non, notes non ;
   - un joueur ne lit pas les notes privées.
2. **Unitaires Dart :** `describeChanges` (un cas par type), l'aller-retour `Character`, `xpAvailable`, `filterCharacters`.
3. **Widgets :** J2 en Web et mobile, avec les sections affichées ; C3 avec un changement de point, le bandeau « 1 modification », Enregistrer, le motif vide refusé et le motif rempli qui appelle le dépôt.

Pas de test de bout en bout ; un parcours manuel sur les émulateurs à la fin.
