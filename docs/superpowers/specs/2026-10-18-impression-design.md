# Impression de la fiche (sous-projet 8b) : conception

## Objectif

Le joueur imprime sa fiche en A4 pour la partie : la version figée pendant un gel, sinon la version actuelle. Le conte peut imprimer une fiche depuis C3. La fiche imprimée reprend les deux pages de la maquette, avec des cases à cocher en jeu.

Le sous-projet 8 est découpé en lots :
- 8a Parties et gel (fait) ;
- 8b Impression (ce document) ;
- 8c Hors ligne et appareils connectés.

Maquettes (canvas Claude Design https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp) :
- `Impression-1` et `Impression-2` (les deux pages A4) ;
- `J-Imprimer` (écran d’impression du joueur, simplifié ici).

## Décisions

- **Un PDF généré dans l’app.** Paquets `pdf` (mise en page) et `printing` (aperçu, impression, partage), sur le Web et sur Android. Flutter web dessine dans un canvas : l’impression du navigateur ne convient pas.
- **Polices embarquées.** Cormorant Garamond et Source Sans 3, en fichiers `.ttf` dans `assets/fonts/` (licence OFL), pour les accents, l’apostrophe ’ et les guillemets « ».
- **Une seule option : la version.**
  - Pendant un gel qui fige la fiche : « Version figée » (par défaut) ou « Version actuelle ».
  - Hors gel : la version actuelle, sans choix.
  - Contenu fixe, A4 portrait, noir et blanc.
- **Qui imprime :** le joueur sa propre fiche ; le conte et le narrateur n’importe quelle fiche, depuis C3.
- **Le titre suit la vue du joueur** (`playerView`) : un titre caché au joueur ne s’imprime pas, même pour le conte.
- **Jamais imprimés :** les notes du conte, les événements de l’histoire, les péchés.

## Données

| Source | Version figée | Version actuelle |
|---|---|---|
| Fiche | `characters/{id}/frozen/{gameId}` du gel en cours | `characters/{id}` |
| Équipement, lieux | état actuel | état actuel |
| Liens de sang | liens connus du joueur, état actuel | idem |
| Demandes d’XP en attente | état actuel (« dont N réservés ») | idem |

Équipement, lieux et liens ne touchent pas à l’XP : le gel ne les fige pas, on imprime leur état actuel.

Nouveau provider : `frozenSheetProvider(characterId, gameId)`, lecture d’une version figée (permise au joueur de la fiche et à l’équipe par les règles du lot 8a). Aucune règle Firestore ne change.

## Contenu

### Page 1 (Impression-1)

- **En-tête :**
  - le nom ;
  - « Toreador · Camarilla · Ancilla, 10e génération · Architecte » (les éléments absents sont omis) ;
  - « Joueur : <nom> · Titre : <titre ou aucun> · Sire : <sire ou inconnu> ».
- **Cartouche :**
  - version figée : « Version figée », « Partie du samedi 3 oct. 2026 », « Figée le 29 sept. à 20h » ;
  - version actuelle pendant un gel : « Version actuelle », « Non valable en jeu » ;
  - hors gel : « Version du 17 oct. 2026 ».
- **Attributs :** Physique, Social, Mental, avec la valeur et « Focus : <focus> ».
- **Compétences :** nom, précision entre parenthèses, pastilles.
- **À cocher en jeu :**
  - « Sang · 12 · 2 par tour » et 12 cases ;
  - « Volonté · 6 » et 6 cases ;
  - « Santé » et trois groupes de cases, Sain, Blessé, Incapacité, selon le champ `health` (« 3 · 3 · 3 ») ;
  - « <moralité> · 5 <nom du niveau> » et autant de ronds que le maximum de la moralité (6 pour l’Humanité, le maximum de la voie dans le référentiel sinon), pleins jusqu’à la valeur ;
  - « Traits de Bête ce soir · à 5, perte d’un point » et 5 cases ;
  - « Traits de dérangement » et 3 cases.
- **Disciplines :** nom, pastilles, pouvoirs séparés par « · », « en clan » ou « hors clan ».
- **Atouts · N** et **Handicaps · N** (N : total des points) : nom et valeur.

### Page 2 (Impression-2)

- **Rappel :** le nom, et « Version figée · partie du samedi 3 oct. 2026 » ou la mention de la version actuelle.
- **Historiques :** nom, pastilles, note ; puis les alliés de la fiche et les serviteurs (goules et mortels).
- **Moralité :** la moralité et son niveau, les dérangements (« Aucun » sinon), le titre (« Aucun » sinon).
- **Liens de sang connus :** ceux que le personnage subit et ceux qu’il exerce, connus du joueur, avec leur niveau.
- **Équipement et lieux :** nom et qualités.
- **Expérience :** Initiale, Gagnée, Dépensée, Disponible, et « dont N réservés » si des demandes sont en attente.
- **Concept et récit.**
- **Notes de partie :** neuf lignes vides.

### Mise en page

- Pied de page : « <personnage> · <joueur> · <nom de la chronique> » et « Page n / m ».
- Une fiche longue passe sur une page de plus ; un texte long passe à la ligne.
- Un bloc vide affiche « Aucun » ; les notes de partie restent toujours.
- **Fiche de goule :** l’en-tête affiche « Goule de <domitor> » au lieu de la génération ; « Vitae » et 5 cases remplacent le sang.

## Écran « Imprimer la fiche »

- **Routes :** `/joueur/personnages/:id/imprimer` et `/conteur/fiches/:id/imprimer`.
- **Accès :**
  - bouton « Imprimer » sur la fiche du joueur, à côté de « Dépenser de l’XP » ;
  - bouton « Imprimer » dans le bandeau du gel de la fiche du joueur ;
  - bouton « Imprimer » en C3.
- **Contenu :**
  - titre « Imprimer la fiche », fil « <nom> / Imprimer » ;
  - pendant un gel qui fige la fiche, le choix « Version figée · partie du samedi 3 oct. » / « Version actuelle · non valable en jeu » ;
  - l’aperçu `PdfPreview`, avec ses boutons d’impression et de partage.
- **Nom du fichier :** « <nom> – partie du 2026-10-03.pdf » pour la version figée, « <nom> – 2026-10-17.pdf » pour la version actuelle.
- **Droits :** un joueur sur la fiche d’un autre voit « Cette fiche n’est pas la vôtre », comme sur la fiche.

## Erreurs et cas limites

- **Version figée en cours de lecture :** « Chargement de la version figée… ».
- **Version figée absente** (fiche validée pendant le gel) : seule la version actuelle est proposée.
- **Gel levé pendant que l’écran est ouvert :** le choix disparaît au prochain rafraîchissement ; la version actuelle n’a plus la mention « non valable en jeu ».
- **Échec de la génération :** « Impossible de préparer le PDF : réessayez. » et un bouton « Réessayer ».
- **Mobile, 390 px :** le choix de version au-dessus de l’aperçu, qui prend toute la largeur.

## Tests

- **Calcul pur (`PrintSheet`) :**
  - chaque bloc des deux pages ;
  - le cartouche dans les trois cas ;
  - titre caché absent, liens inconnus du joueur absents ;
  - cases de santé selon `health`, ronds de moralité ;
  - blocs vides (« Aucun ») ;
  - fiche de goule ;
  - « dont N réservés ».
- **PDF :** les octets commencent par `%PDF` ; une fiche courte tient en deux pages ; une fiche longue en prend trois.
- **Écran :**
  - le choix de version n’existe que pendant un gel ;
  - version figée par défaut ;
  - refus sur la fiche d’un autre ;
  - 390 px ;
  - le générateur de PDF est remplaçable dans les tests (`PdfPreview` passe par des canaux de plateforme).

## Hors périmètre

- L’impression groupée des fiches figées par le conte, et la colonne « Imprimée » de l’écran du gel.
- L’export de la fiche résumée d’un PNJ prêté.
- Les options de contenu, de format (Lettre US) et de couleur.
- Le hors ligne (8c).
