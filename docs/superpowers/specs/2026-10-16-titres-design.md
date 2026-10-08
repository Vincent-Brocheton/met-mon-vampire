# Titres (sous-projet 7d) : conception

## Objectif

Le conte attribue les titres de la chronique (Prince, Harpie, Primogène…) aux fiches, à partir du référentiel des titres. Le détenteur voit son titre. Les joueurs voient la Cour : la liste des titres publics et de leurs détenteurs.

Le sous-projet 7 est découpé en lots :
- 7a Événements (fait) ;
- 7b Moralité (fait) ;
- 7b2 Dérangements (fait) ;
- 7c Liens de sang (fait) ;
- 7d Titres (ce document).

Maquettes (canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp) :
- `C-Moralite` et `J-Moralite`, bloc « Titre » ;
- `C-Titres` (référentiel), avec leurs versions mobiles.

## Décisions

- **Un seul titre par fiche.** Attribuer un nouveau titre retire l'ancien.
- **La Cour :** une page joueur qui liste les titres publics et leurs détenteurs.
- **Données :**
  - le titre reste sur la fiche (`title`, plus la nouvelle clé `titleSince`) ;
  - une copie publique `court/{characterId}` alimente la Cour, sur le modèle de `publicPlaces`.
- **Traits de statut :** ils ne sont pas utilisés (la maquette le dit).

## Référentiel existant (`titles`)

| Champ | Contenu |
|---|---|
| `sect` | secte du titre, ou « Toutes » |
| `count` | « Illimité », « Unique », « Un par clan », ou un nombre |
| `under` | titre au-dessus (« placé sous ») |
| `public` | titre public, visible par tous les joueurs |
| `onSheet` | affiché sur la fiche du détenteur |
| `npcOnly` | réservé aux PNJ |

## Règles (calcul pur)

`titleChecks(title, sheet, sheets, rulebook)` renvoie des erreurs et des avertissements.

- **Erreurs :**
  - « Unique » : « <titre> est déjà tenu par <nom>. » si une autre fiche le tient ;
  - « Un par clan » : « <titre> est déjà tenu pour le clan <clan> par <nom>. » ;
  - nombre fixe N : « <titre> : N détenteurs au plus (<noms>). » ;
  - « Réservé aux PNJ » sur une fiche de PJ : « <titre> est réservé aux PNJ. » ;
  - titre absent du référentiel ou interdit : « <titre> : pas un titre de la chronique. » ;
  - date « depuis » invalide : « Date invalide ».
- **Avertissements :**
  - secte du titre différente de celle de la fiche (sauf « Toutes ») : « <titre> relève de <secte> ; la fiche est <secte de la fiche>. » ;
  - « Un par clan » sur une fiche sans clan : « Fiche sans clan : le contrôle par clan ne s'applique pas. ».

Seules les fiches actives et les PNJ comptent comme détenteurs. Les fiches mortes ou retirées ne bloquent pas un titre.

**Visibilité d'un titre :**
- `onSheet` faux : réservé à l'équipe, le joueur ne le voit pas ;
- `onSheet` vrai et `public` vrai : public, il figure dans la Cour ;
- sinon : visible du joueur seulement.

## Données

### Fiche `characters/{id}`

- `title` : nom du titre (déjà présent), ou vide.
- `titleSince` : date d'obtention, nouvelle clé tardive. Elle n'est écrite que si elle n'est pas vide ou si elle était déjà présente.
- **Écriture :** attribuer, changer ou retirer un titre est une écriture tracée de la fiche, avec motif et historique (type `edit`), dans un seul lot avec :
  - les événements « Titre perdu » (ancien titre) et « Titre obtenu » (nouveau) de la fiche ; leur visibilité est celle du titre (public → `public`, joueur → `player`, équipe → `staff`) ;
  - la copie publique de la Cour, écrite ou supprimée.
- **Valeurs existantes :** un `title` libre absent du référentiel reste en place. Le conte voit « hors liste » et le remplace.

### Collection `court/{characterId}` : copie publique

| Champ | Contenu |
|---|---|
| `name` | nom du personnage |
| `title` | nom du titre |
| `sect` | secte du titre |
| `under` | titre au-dessus, ou vide |
| `since` | date d'obtention |

- **Quand la copie existe :** elle est écrite si le titre est `public` et `onSheet`. Elle est supprimée sinon (retrait, titre devenu secret, fiche sans titre).
- **Renommage dans le référentiel :** les copies ne changent pas jusqu'à la prochaine attribution. Le panneau du référentiel affiche « Copie publique à mettre à jour » pour un détenteur dont la copie diffère, avec un bouton « Mettre à jour » qui réécrit la copie.

## Règles Firestore

- **`court/{id}` :**
  - lecture : tout utilisateur connecté ;
  - écriture et suppression : `managesAccounts()` ;
  - clés limitées à celles du tableau ;
  - `title` de 1 à 80 caractères, `name` de 1 à 80 caractères.
- **Fiche :**
  - `titleSince` rejoint les clés protégées du brouillon du joueur, comme `title` s'il ne l'est pas déjà ;
  - les écritures du conte passent par les chemins existants (`staffEdit`).
- **Événements :** les types `titleGained` et `titleLost` sont déjà permis.

## Écrans

### Onglet « Moralité & liens », bloc « Titre »

- **Conte (C-Moralite) :**
  - liste déroulante des titres du référentiel, plus « Aucun » ;
  - le titre actuel, avec « hors liste » s'il n'est pas dans le référentiel ;
  - champ « Depuis » (JJ/MM/AAAA), par défaut la date du jour ;
  - contrôles en direct, sous la liste ;
  - « Enregistrer », qui demande le motif comme C3 ;
  - lien « Gérer la liste des titres » vers le référentiel.
  - **Lecture seule :** pour le narrateur, et pour un conte sur sa propre fiche (vue du joueur).
- **Joueur (J-Moralite) :** « Harpie · depuis mars 2026 », ou « Aucun titre. ». Un titre `onSheet` faux ne s'affiche pas.

### Fiche C3

Le champ libre « Titre » devient une lecture, avec un lien « Changer le titre » vers l'onglet « Moralité & liens ».

### Référentiel, catégorie Titres (C-Titres)

- **Liste :** colonne « Détenu par » (noms, ou « Vacant » ; pour « Un par clan », « N / M clans »), et case « Seulement les titres vacants ».
- **Panneau du titre :**
  - section « Détenteurs » : nom, PJ ou PNJ, clan, « depuis » ;
  - bouton « Retirer » sur chaque détenteur, avec le motif ;
  - « + Attribuer à une fiche » : choix de la fiche, date, puis les mêmes contrôles et la même écriture que le bloc « Titre » ;
  - « Copie publique à mettre à jour » avec son bouton, le cas échéant.

### Joueur : « La Cour », `/joueur/cour`

- **Contenu :** titres publics groupés par secte. Chaque titre porte ses détenteurs (nom du personnage, « depuis »). La hiérarchie « placé sous » s'affiche en retrait.
- **Accès :** dans la navigation du joueur, et par un lien depuis le bloc « Titre ». L'équipe y accède aussi.
- **État vide :** « Aucun titre public pour l'instant. ».

## Erreurs et cas limites

- **Conflit de version de la fiche :** « Modifié entre-temps : rechargez la page. » ; les autres refus affichent « Enregistrement refusé : réessayez. ». Un refus ne vide pas le formulaire.
- **Titre supprimé du référentiel :** la fiche le garde, marqué « hors liste ».
- **Fiche morte ou retirée qui tient un titre :** le titre reste sur la fiche. Il ne compte plus dans le contrôle du nombre. Sa copie dans la Cour est supprimée à la prochaine écriture de son titre.
- **Mobile, 390 px :** les rangées de boutons passent en `Wrap`.

## Tests

- **Calculs purs :** contrôles (unique, par clan, nombre fixe, réservé aux PNJ, hors référentiel, secte), visibilité, fiches mortes ignorées, lignes d'historique.
- **Règles d'accès :**
  - Cour lisible par un joueur, écrite par le conte seul ;
  - clés et longueurs ;
  - `titleSince` protégée dans le brouillon.
- **Écrans :**
  - bloc du conte : attribution, refus, retrait ;
  - bloc du joueur : titre visible, titre caché ;
  - référentiel : détenteurs, vacants, attribution ;
  - la Cour, y compris à 390 px.

## Hors périmètre

- Traits de statut, prestations (boons).
- Le wiki (sous-projet 9).
- Les notifications (sous-projet 10).
