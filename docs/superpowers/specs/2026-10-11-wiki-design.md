# Wiki (sous-projet 9) : conception

## Objectif

Le conte rédige le wiki de la chronique : une page par entrée du référentiel (règles) et des pages libres (système de jeu, lore, la chronique). Les joueurs le lisent dans l’app, hors ligne compris, et ne voient que les pages qui leur sont ouvertes : tous les joueurs, un clan, une secte, ou le conte seul.

Le sous-projet 9 est découpé en lots, avec une spec commune et un plan par lot :
- **9a Socle du wiki :** données, règles Firestore, Markdown, écrans conte (liste, édition), lecture joueur (accueil, rubrique, page, recherche, hors ligne), visibilité clan / secte ;
- **9b Enrichissements :** historique des versions (comparaison, restauration), chronologie publique, personnalisation joueur.

Maquettes (canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp), avec leurs versions mobiles :
- conte : `C-Wiki`, `C-WikiEdit`, `C-WikiHistorique` ;
- joueur : `J-Wiki`, `J-WikiRubrique`, `J-WikiPage`, `J-WikiLore`, `J-WikiRecherche`.

## Décisions

- **Visibilité appliquée par les règles Firestore**, pas seulement par l’interface. Les règles lisent une liste d’accès `wikiAudiences` sur `users/{uid}`.
- **Liste d’accès synchronisée par le conte** : recalculée à partir des fiches quand un conteur ou un principal ouvre la liste des fiches ou le wiki ; seules les différences sont écrites. Un seul mécanisme, qui sert aussi de migration. `stageEdit` n’est pas modifié. Un changement de secte n’ouvre l’accès qu’au prochain passage du conte sur l’un de ces écrans.
- **Brouillon à part** : retravailler une page publiée ne la retire pas aux joueurs ; ils gardent la version publiée jusqu’à « Publier ».
- **Markdown léger maison** : champ texte, barre d’outils qui insère la syntaxe, aperçu. Aucune dépendance nouvelle.
- **Pages de règles virtuelles** : une entrée du référentiel sans document wiki s’affiche quand même (« à rédiger », données seules). Aucun document vide n’est créé.
- **Copie hors ligne = cache Firestore** : toute page visible est copiée. Pas de case « Inclure dans la copie hors ligne ».

## Données

### `wiki/{id}` : version publiée

| Champ | Contenu |
|---|---|
| `title` | titre, 1 à 80 caractères |
| `rubric` | identifiant de rubrique (voir « Rubriques ») |
| `audience` | `all`, `clan:<clé>`, `sect:<clé>` ou `staff` ; la clé est `nameKey` du nom du clan ou de la secte |
| `body` | texte Markdown, 50 000 caractères au plus |
| `source` | référence du livre, facultative (« MET : VTM, p. 12 ») |
| `cat`, `entryId` | page de règle seulement : catégorie et identifiant de l’entrée du référentiel |
| `version` | entier, 1 à la première publication |
| `updatedAt`, `updatedByUid`, `updatedByName` | dernière publication |

Identifiants : `r_{cat}_{clé}` pour une page de règle, identifiant automatique pour une page libre. La clé est l’identifiant de l’entrée ; une valeur de base du livre (pas encore enregistrée, donc sans identifiant) prend `base-` suivi de son nom simplifié (`base-presence`). Une page écrite sur une valeur de base devient orpheline si la catégorie est ensuite enregistrée dans le référentiel. Une page de règle a toujours la rubrique de sa catégorie et le titre de son entrée.

### `wikiDrafts/{id}` : brouillon en cours

Mêmes champs que `wiki/{id}` sauf `version`, plus `baseVersion` (version publiée sur laquelle part le brouillon, 0 si jamais publiée). Même identifiant que la page. Une page jamais publiée n’existe que dans `wikiDrafts`.

### `wiki/{id}/versions/{n}` : copie de chaque publication

`title`, `rubric`, `audience`, `body`, `source`, `note` (facultative, 80 caractères au plus), `byUid`, `byName`, `at`. Écrite dans le même lot que la publication dès 9a, pour que l’historique de 9b soit complet ; l’écran d’historique arrive en 9b.

### `users/{uid}.wikiAudiences`

Liste de chaînes (`clan:toreador`, `sect:camarilla`), 29 éléments au plus (avec `all`, la requête reste sous la limite de 30 valeurs de `whereIn`). Absente = aucun accès réservé.

### `events` : nouveau champ facultatif `charName` (9b)

Nom du personnage, écrit par le dépôt des événements à chaque enregistrement. Sert à la chronologie publique. Les anciens événements n’en ont pas.

## Rubriques

Liste fixe dans `lib/wiki/wiki_rules.dart`, dans cet ordre :

| Rubrique | Catégories du référentiel |
|---|---|
| Clans & sectes | `clans`, `sects` |
| Disciplines | `disciplines` |
| Rituels | `rituals` |
| Techniques & pouvoirs d’anciens | `techniques`, `elderPowers` |
| Atouts & handicaps | `merits`, `flaws` |
| Historiques | `backgrounds` |
| Alliés | `allies` |
| Équipement | `equipment` |
| Lieux & goules animales | `placeQualities`, `animalQualities` |
| Compétences | `skills` |
| Moralité | `paths`, `derangements` |
| Système de jeu | `generations`, `blood`, `archetypes` + pages libres |
| La chronique | `titles` + pages libres + chronologie publique (9b) |

Une page libre peut aller dans n’importe quelle rubrique. Côté conte, la puce « Règles » regroupe toutes les rubriques sauf « La chronique », et la puce « La chronique » la seule rubrique du même nom.

Seules les entrées **proposées** du référentiel (`state.offered`) ont une page côté joueur ; le conte voit aussi les autres.

## Calculs purs

`lib/wiki/wiki_rules.dart` :
- `wikiAudiences(List<Character> sheets)` : pour chaque fiche **active** du joueur, `clan:` + clé du clan de sang (`bloodClan`) et `sect:` + clé de la secte ; dédoublonné, trié, tronqué à 29.
- `audienceChanges(users, sheets)` : comptes dont la liste stockée diffère de la liste calculée (ce qu’il faut écrire).
- `canRead(page, audiences, {staff})` : même test que les règles.
- `wikiIndex(rulebook, pages, {staff})` : toutes les pages lisibles, virtuelles comprises, groupées par rubrique.
- `progress(items)` : par rubrique, pages de règles publiées non vides sur nombre d’entrées.
- `search(index, query)` : correspondance sans casse ni accents sur le titre, le nom VO, le corps et les données ; renvoie un extrait autour de la première occurrence ; titres d’abord, puis corps.
- `resolveLink(title, index)` : page visible de ce titre (`nameKey`), sinon null.

`lib/wiki/wiki_markdown.dart` : `parseWiki(String) → List<WikiBlock>`.
- Blocs : paragraphe, `## titre`, `- élément de liste`, `§ encadré règle` (ligne commençant par `§`), tableau (lignes `| a | b |`, la ligne `|---|` ignorée).
- En ligne : `**gras**`, `*italique*`, `[[Titre]]`. Une syntaxe non fermée reste du texte.
- Un lien `[[ ]]` qui ne se résout pas s’affiche en texte simple (ne trahit pas une page cachée).

`lib/wiki/word_diff.dart` (9b) : `wordDiff(String before, String after)` → segments (inchangé, ajouté, retiré), par paragraphe, sur les mots (plus longue sous-suite commune).

## Règles Firestore

```
match /wiki/{id} {
  allow read: if isStaff()
    || (signedIn() && (resource.data.audience == 'all'
        || resource.data.audience in get(userPath(request.auth.uid)).data.get('wikiAudiences', [])));
  allow create, update: if managesAccounts() && wikiPageValid()
    && request.resource.data.version == (resource == null ? 0 : resource.data.version) + 1
    && existsAfter(versionPath(id, request.resource.data.version));
  allow delete: if managesAccounts();
  match /versions/{n} {
    allow read: if isStaff();
    allow create: if managesAccounts() && versionValid()
      && getAfter(pagePath(id)).data.version == int(n);
  }
}
match /wikiDrafts/{id} {
  allow read: if isStaff();
  allow write: if managesAccounts() && draftValid();
}
match /{path=**}/events/{e} {
  allow read: if signedIn() && resource.data.visibility == 'public';
}
```

- `wikiPageValid` : `keys().hasOnly(...)`, types, `audience` égale à `all` ou `staff` ou commençant par `clan:` ou `sect:`, `updatedByUid == request.auth.uid`, `updatedAt == request.time`.
- `users/{uid}` : nouvelle branche de mise à jour `changedOnly(['wikiAudiences'])` par `managesAccounts()`, liste de 29 chaînes au plus. Le joueur ne peut pas l’écrire (`selfUpdate` ne l’autorise pas).
- `eventValid` accepte la clé facultative `charName` (chaîne, 80 caractères au plus).
- Requête joueur : `wiki.where('audience', whereIn: ['all', ...wikiAudiences])`, le filtre que testent les règles. Une requête sans filtre est refusée.
- Chronologie : `collectionGroup('events').where('visibility', isEqualTo: 'public')`.
- Supprimer une page libre (conte) supprime le document publié et le brouillon ; les versions restent, lues par l’équipe seulement.

## Écrans

Routes, à la place des deux `soon('Wiki')` de `lib/router.dart` :

| Route | Écran | Lot |
|---|---|---|
| `/joueur/wiki` | accueil | 9a |
| `/joueur/wiki/rubrique/:rub` | rubrique | 9a |
| `/joueur/wiki/page/:id` | page | 9a |
| `/joueur/wiki/recherche?q=` | recherche | 9a |
| `/conteur/wiki` | liste du conte | 9a |
| `/conteur/wiki/edition/:id` (`nouvelle` pour une page libre) | édition | 9a |
| `/conteur/wiki/edition/:id/historique` | historique | 9b |
| `/conteur/wiki/accueil`, `/conteur/wiki/page/:id`, `/conteur/wiki/rubrique/:rub`, `/conteur/wiki/recherche` | lecture, mêmes widgets que le joueur ; `?apercu=1` : aperçu joueur | 9a |

### Joueur : accueil (J-Wiki)

- Titre « Wiki de la chronique », sous-titre « Les règles et le lore, au même endroit que vos fiches. Disponible hors ligne. »
- « Copie hors ligne à jour » ; sans réseau (`offlineProvider`) : « Hors ligne · copie de l’appareil ».
- Champ de recherche (Entrée → page de recherche).
- Cartes de rubrique : nom, nombre de pages visibles, description courte. Rubrique sans page visible : masquée.
- « Mis à jour récemment » : les 5 pages publiées les plus récentes.
- 9b : blocs « Pour {nom} » (voir Personnalisation).

### Joueur : rubrique (J-WikiRubrique)

Fil d’Ariane, titre, puces de filtre propres à la rubrique (Disciplines : Toutes, Communes, Propres à un clan ; rubrique de plusieurs catégories : Toutes et une puce par catégorie ; ailleurs : aucune), cartes groupées par catégorie (« Pages du conte » pour les pages libres). Une page « à rédiger » reste listée : ses données suffisent souvent.

### Joueur : page (J-WikiPage, J-WikiLore)

- Fil d’Ariane, titre, nom VO.
- Page réservée : bandeau « Réservé au clan {clan}. » ou « Réservé à la secte {secte}. »
- Page de règle : données du référentiel en tête, affichées à partir des champs de la catégorie (`schema.dart`) ; disciplines : rendu dédié des pouvoirs niveau par niveau.
- Corps Markdown rendu ; page de règle sans texte : « Le conte n’a pas encore rédigé cette page. »
- Sommaire « Sur cette page » (titres `##`) sur grand écran.
- Pied : « Source : … · mis à jour le {date} par {nom} ».
- Page inexistante ou cachée : « Page introuvable », le même message dans les deux cas.

### Joueur : recherche (J-WikiRecherche)

Résultats : titre, rubrique, extrait. Puces Tout / Règles / Chronique avec compte. Mention « La recherche ne montre que les pages que vous pouvez voir. Elle fonctionne aussi hors ligne. »

### Conte : liste (C-Wiki)

- Tableau : page (et rubrique), origine (« Fiche du référentiel », « Page libre », « Entrée supprimée », et en 9b « Événements publics, automatique »), visible par, état (« Publié », « Brouillon », « À rédiger »), modifiée.
- Puces : Toutes · n, Règles, La chronique, Brouillons · n.
- Panneau « Avancement de la rédaction » (`progress`) et bouton « Voir les pages vides » (filtre « À rédiger »).
- Panneau « Règles de visibilité » (texte fixe).
- Boutons « Voir comme un joueur » (`/conteur/wiki/accueil?apercu=1` : lecture limitée aux pages `all` et aux entrées proposées, sans personnalisation) et « Nouvelle page » (conteur et principal ; le narrateur lit seulement).
- Lance la synchronisation des `wikiAudiences` (conteur et principal seulement) ; la liste des fiches du conte la lance aussi.

### Conte : édition (C-WikiEdit)

- Fil d’Ariane, titre (modifiable pour une page libre), lien « Historique des versions (n) » (9b).
- Barre d’outils : Gras, Italique, Titre, Liste, Lien vers une page, Encadré règle, Tableau ; elle entoure la sélection ou insère un modèle.
- Texte et aperçu côte à côte sur grand écran ; onglets Texte / Aperçu en dessous de 900 px.
- Panneau « Publication » : Visible par (une seule liste : Tous les joueurs, chaque clan du référentiel, chaque secte du référentiel, Le conte seul), Rubrique (page libre seulement), Source.
- Une page de règle réservée garde ses données visibles de tous (le référentiel est lisible par tout compte) ; seul son texte est réservé.
- Panneau « Données du référentiel » (page de règle) avec lien « Modifier » vers le référentiel.
- Boutons « Aperçu joueur », « Enregistrer le brouillon », « Publier » (boîte de dialogue : note facultative ; lot : page + version + suppression du brouillon).
- Un brouillon existant est rouvert, avec le bandeau « Brouillon en cours, non publié. » et l’action « Abandonner le brouillon ».
- Page libre : « Supprimer la page », avec confirmation.
- Narrateur : écran en lecture seule.

### Conte : historique (C-WikiHistorique, 9b)

- Liste des versions : numéro, note, auteur, date ; « En ligne » sur la version actuelle.
- Version choisie comparée à la précédente (`wordDiff`), légende ajouté / retiré.
- « Restaurer la version n » : republie son contenu comme version suivante, avec la note « Restauration de la version n ». Mention « Restaurer crée une version {m} identique à la {n}. Aucune version n’est effacée. » Si un brouillon existe, confirmation : il sera abandonné.

### Chronologie publique (9b)

Page virtuelle `chronologie`, rubrique « La chronique », visible par tous. Événements publics de toutes les fiches, triés par année, mois, jour et groupés par année : « {charName} · {titre} », puis la description. Sans `charName` : le titre seul.

### Personnalisation (9b)

À partir des fiches actives du joueur :
- **Accueil :** un bloc « Pour {nom} » par fiche : disciplines (« ●●● · vos 3 pouvoirs »), clan (« votre clan »), atouts et handicaps ; chaque ligne mène à sa page si elle est visible.
- **Page de discipline :** « Vous l’avez » sur les niveaux possédés ; coût de chaque niveau, en clan ou hors clan (`inClan`, `costOf`) ; encadré « {nom} · {Discipline} ●● » avec « Prochain niveau : {pouvoir}, {coût} XP » et « Préparer l’achat » vers l’écran XP de la fiche. Un encadré par fiche active.
- **Rubrique Disciplines :** puce « En clan pour {nom} » et mention « ●● · en clan » sur les cartes.
- « Voir comme un joueur » côté conte : sans personnalisation.

## Erreurs et cas limites

- Lecture refusée (accès retiré entre deux synchronisations) : la page sort de la liste ; un lien direct affiche « Page introuvable ».
- Publication refusée (version déjà incrémentée par un autre conteur) : « Cette page a été publiée entre-temps. Rechargez-la avant de publier. » ; le brouillon reste.
- Entrée du référentiel supprimée : sa page publiée devient orpheline ; le conte la voit avec l’origine « Entrée supprimée » et peut la supprimer ; le joueur ne la voit plus.
- Entrée renommée : la page suit l’entrée (identifiant) ; le titre affiché est celui de l’entrée.
- Synchronisation des audiences en échec : silencieuse pour le conte, retentée à la prochaine ouverture.

## Tests

- Unitaires : `parseWiki` (chaque bloc, syntaxe non fermée, tableau), `wordDiff`, `wikiAudiences` (fiche inactive ignorée, goule = clan du domitor, dédoublonnage), `audienceChanges`, `canRead`, `wikiIndex` (pages virtuelles, entrées non proposées), `progress`, `search` (accents, ordre, extrait), `resolveLink`.
- Widgets : chaque écran avec `ProviderScope` et faux dépôts, aussi à 390 px (`tester.takeException()` nul) ; brouillon rouvert ; narrateur en lecture seule ; « Page introuvable ».
- Règles (`rules_test/wiki.test.js`) : lecture par audience (requête `whereIn` acceptée, requête sans filtre refusée, page d’un autre clan refusée, page `staff` refusée au joueur) ; publication (version + 1 et copie obligatoires ; narrateur et joueur refusés) ; brouillons et versions réservés à l’équipe ; `wikiAudiences` écrit par conteur et principal seulement ; événements publics lus par `collectionGroup`, événements `player` et `staff` refusés ; `charName` accepté.

## Hors périmètre

| Élément | Raison ou suite |
|---|---|
| Une page par pouvoir (« Envoûtement » seule) | les pouvoirs sont des sections de la page de discipline ; la recherche les trouve |
| Page publique d’un personnage, liée depuis le lore | non retenu |
| Page wiki d’un lieu (spec 6a) | une page libre suffit |
| Notifications de mise à jour du wiki | sous-projet 10 |
| Rattrapage du nom du personnage sur les anciens événements | non retenu |
| Recalcul immédiat des audiences à chaque modification de fiche | synchronisation à l’ouverture des écrans du conte |
| Éditeur visuel (WYSIWYG), images | Markdown léger |
