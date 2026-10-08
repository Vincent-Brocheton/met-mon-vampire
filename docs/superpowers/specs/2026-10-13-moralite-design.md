# Moralité (sous-projet 7b) : conception

## Objectif

L'onglet « Moralité & liens » de la fiche devient actif :
- le conte choisit la voie du personnage (Humanité ou une voie d'illumination) et règle sa valeur ;
- le conte note les péchés de chaque soirée, avec le test de remords ;
- le total de traits de Bête de la soirée s'affiche, et à 5 traits le conte applique la perte d'un point ;
- le joueur voit sa moralité, son échelle et le tableau de ses péchés, et peut acheter un point par l'XP.

Le sous-projet 7 est découpé en lots :
- 7a Événements (fait) ;
- 7b Moralité (ce document) ;
- 7b2 Dérangements ;
- 7c Liens de sang ;
- 7d Titres ;
- 7e Récit.

Maquettes : C-Moralite, J-Moralite, avec leurs versions mobiles (canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp). Les blocs Dérangements, Liens de sang et Titre de ces maquettes arrivent avec les lots 7b2, 7c et 7d.

## Décisions

- **Voie :** le conte la choisit dans l'écran Moralité.
  - La valeur est gardée, ramenée au maximum de la nouvelle voie si elle le dépasse.
  - L'atout de voie se règle à part (XP ou C3).
- **Péchés :** dans une sous-collection, sur le modèle des événements (7a).
- **Perte d'un point :** jamais automatique. Le conte la confirme avec « Appliquer la perte ».
- **Moralité à 0 :** signalée à l'écran. La fiche ne change pas d'elle-même : le wassail et le passage en PNJ relèvent de la clôture des fiches, hors périmètre.

## Données

### Sur la fiche

- **`path` (clé tardive) :** nom d'une entrée du référentiel `paths`, ou absente pour l'Humanité.
  - Elle n'est écrite que si elle est renseignée ou déjà présente.
  - Le brouillon du joueur ne l'écrit jamais.
- **`humanity` :** reste le champ de la valeur de moralité, quelle que soit la voie (pas de migration). Les écrans l'appellent « moralité » et affichent le nom de la voie.
- **Maximum :**
  - Humanité : 6 ;
  - une voie : `maxMorality` de son entrée, ou 6 si ce champ est vide.

### Échelle

Libellés des niveaux 1 à 6 : Horrible, Bestiale, Insensible, Distante, Normale, Sainte. Une voie au maximum de N utilise les N premiers. Le niveau 0 se lit « Wassail ».

### Hiérarchie des péchés

- Le champ `sins` de l'entrée de la voie, un niveau par ligne.
- Pour l'Humanité, ou si ce champ est vide, la hiérarchie par défaut :
  - 1 Blesser gravement autrui ;
  - 2 Séquelles durables ;
  - 3 Tuer ;
  - 4 Meurtres multiples ;
  - 5 Actes odieux, diablerie.

### Collection `characters/{id}/sins/{s}`

| Champ | Contenu |
|---|---|
| `date` | soirée (horodatage au jour, minuit heure locale) |
| `level` | 1 au nombre de niveaux de la hiérarchie (10 au plus) |
| `what` | « Ce qui s'est passé », 500 caractères au plus |
| `remorse` | `success`, `failed` ou `none` |
| `lossApplied` | vrai une fois la perte de la soirée appliquée |
| `byUid`, `byName` | auteur de la dernière écriture |
| `createdAt`, `updatedAt` | horodatages du serveur |

**Traits de Bête :**
- d'un péché : son niveau, moins 1 si le remords est réussi, 0 au minimum ;
- d'une soirée : la somme de ses péchés.

### Événements (7a)

Un nouveau type `morality` (« Moralité », pastille moralité) s'ajoute à la liste du modèle et des règles.

## Calculs purs (`lib/morality/morality_rules.dart`)

- `moralityMax(c, rb)` : le maximum selon la voie.
- `moralityName(c)` : « Humanité » ou le nom de la voie.
- `moralityLabel(n)` : le libellé de l'échelle, « Wassail » à 0.
- `sinLevels(c, rb)` : la hiérarchie de la voie, ou celle par défaut.
- `sinTraits(s)` et `eveningTraits(sins)`.
- `eveningsOf(sins)` : les soirées, de la plus récente à la plus ancienne.
- `lossDue(sins)` : la soirée atteint 5 traits ou plus, et sa perte n'est pas encore appliquée.
- `changePath(c, rb, path)` : la fiche après le changement de voie, valeur ramenée au maximum.
- `applyLoss(c)` : la fiche avec la moralité − 1, jamais sous 0.
- `sinChecks(sin, c, rb)` renvoie les erreurs :
  - « Niveau de 1 à N » ;
  - « Ce qui s'est passé : 500 caractères au plus » ;
  - « Date invalide ».

## XP

- L'achat existant `XpKind.humanity` reste, mais il est plafonné par `moralityMax(c, rb)` au lieu de 6.
- Son libellé devient le nom de la voie : « Humanité 5 » ou « Voie de la Nuit 4 ».
- Le coût ne change pas : 10 XP le point.
- La règle de création (Humanité 6 au plus) ne change pas.

## Règles Firestore

- **Fiche :**
  - `path` rejoint les clés protégées de `playerDraftSave` ;
  - les chemins du conte (C3, XP, corrections, décision) l'acceptent.
- **`characters/{id}/sins/{s}` :**
  - **lecture :** `isStaff()`, ou le joueur de la fiche ;
  - **création :**
    - `managesAccounts()`, et la fiche n'est pas celle de l'auteur (`getAfter`) ;
    - clés limitées à la liste ;
    - `level` entier de 1 à 10 ;
    - `remorse` parmi les trois valeurs ;
    - `what` chaîne de 500 caractères au plus ;
    - `date` horodatage ;
    - `lossApplied` booléen ;
    - `byUid == auth.uid` ;
  - **modification :** mêmes contrôles, et `resource.data.lossApplied == false` ;
  - **suppression :** `managesAccounts()`, fiche qui n'est pas celle de l'auteur, et `resource.data.lossApplied == false`.
- **`events` :** `morality` rejoint la liste des types.

## Écrans

### Onglet « Moralité & liens »

- **Routes :** `/conteur/fiches/:id/moralite` et `/joueur/personnages/:id/moralite`.
- L'onglet de l'en-tête devient actif pour l'équipe et le joueur.

### Conte (C-Moralite)

- **Bloc Moralité :**
  - le choix de la voie : Humanité et les voies du référentiel, chacune avec « (max. N) » ;
  - la valeur, avec « − », le nombre, « + » et le libellé (« Distante ») ;
  - chaque changement demande un motif (dialogue habituel), puis est enregistré comme une modification tracée ;
  - le changement de voie crée l'événement « Voie adoptée », titré « Adopte <voie> » ou « Revient à l'Humanité » ;
  - le rappel : « Une voie s'obtient avec l'atout de voie. À 0, le personnage sombre dans le wassail et devient un PNJ. ».
- **Bloc « Enregistrer un péché » :**
  - la date de la soirée (JJ/MM/AAAA, aujourd'hui par défaut) ;
  - le niveau, choisi parmi les cartes de la hiérarchie ;
  - « Ce qui s'est passé » ;
  - le test de remords : « Réussi (−1 trait) », « Échoué » ou « Non tenté » ;
  - le rappel de la difficulté : « Mental + Volonté contre 10 + niveau. Le conte peut baisser la difficulté de 5 au plus si c'était justifié. » ;
  - un bouton « Ajouter · N trait(s) ».
- **Bloc « Traits de Bête · soirée du … » :**
  - la soirée la plus récente, avec une liste pour en choisir une autre ;
  - le total « N / 5 » ;
  - les péchés de la soirée : modifier ou supprimer tant que la perte n'est pas appliquée ;
  - à 5 traits ou plus, sans perte appliquée : « N traits de Bête atteints : <nom> perd un point de <moralité> (4 → 3, Insensible). », puis le bouton « Appliquer la perte » ;
  - une soirée dont la perte est appliquée affiche « Perte appliquée ».
- **Appliquer la perte**, en un seul lot :
  - la fiche, moralité − 1, en modification tracée avec le motif « Traits de Bête : soirée du <date> » ;
  - `lossApplied` à vrai sur les péchés de la soirée ;
  - l'événement automatique de type « Moralité », titré « <moralité> 5 → 4, Distante », visible par le joueur et le conte, daté de la soirée.
- **Lecture seule :** pour le narrateur, et pour le conte sur sa propre fiche.

### Joueur (J-Moralite)

- **Carte Moralité :**
  - la voie, la valeur et le libellé (« Humanité 5 · Normale ») ;
  - l'échelle en cases (niveaux 1 au maximum), le niveau actuel mis en avant ;
  - le lien « Acheter un point · 10 XP » vers l'écran XP, si la valeur est sous le maximum et la fiche active ;
  - la phrase : « Chaque péché donne des traits de Bête égaux à son niveau. À 5 traits dans une même soirée, vous perdez un point. Les traits s'effacent après une journée de sommeil. ».
- **Tableau « Péchés et traits de Bête · Saisis par le conte » :**
  - colonnes : soirée, péché (« Niveau N · ce qui s'est passé »), remords, traits ;
  - vide : « Aucun péché. ».

### Mobile

Une seule colonne, dans l'ordre de la maquette mobile.

## Erreurs et cas limites

- **Conflit de version sur la fiche :** « Modifié entre-temps : rechargez la page. ».
- **Autres refus :** « Enregistrement refusé : réessayez. ».
- **Voie retirée du référentiel :** la fiche garde son nom, avec le maximum de 6 et la hiérarchie par défaut.
- **Péché d'une soirée déjà « perte appliquée » :** l'ajout reste possible ; le total grandit, mais aucune seconde perte n'est proposée pour cette soirée.
- **Moralité à 0 :** le bouton « − » est désactivé ; la carte affiche « Wassail ».

## Tests

- **Calculs purs :**
  - maximum selon la voie, voie inconnue ;
  - libellés et « Wassail » ;
  - hiérarchie par défaut ou celle de la voie ;
  - traits d'un péché et d'une soirée ;
  - soirées triées ;
  - seuil et soirée déjà appliquée ;
  - changement de voie qui ramène la valeur ;
  - perte jamais sous 0 ;
  - `sinChecks`.
- **XP :** achat plafonné par la voie, libellé de la voie.
- **Règles d'accès :**
  - le joueur lit ses péchés, un autre joueur non ;
  - le conte écrit, mais pas sur sa propre fiche ; le narrateur ne peut pas écrire ;
  - péché verrouillé après la perte ;
  - `path` refusé dans le brouillon du joueur, et brouillon sans `path` accepté ;
  - type d'événement `morality` accepté.
- **Écrans :**
  - le conte ajoute un péché, puis applique la perte (fiche, péchés et événement) ;
  - le conte change de voie et règle la valeur ;
  - le narrateur est en lecture seule ;
  - la carte et le tableau du joueur ;
  - le lien d'achat masqué au maximum.

## Hors périmètre

- Les dérangements (7b2), les liens de sang (7c), le titre (7d).
- Le wassail et le passage en PNJ.
- L'achat de l'atout de voie.
- Les parties (sous-projet 8) : la soirée est une simple date.
