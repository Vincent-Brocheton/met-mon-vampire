# PNJ confiés (sous-projet 6e) : conception

## Objectif

Le conte confie un PNJ à un joueur pour une période : le joueur voit la fiche en lecture, reçoit des consignes d'interprétation et tient ses notes, partagées avec le conte. Les notes privées du conte ne sont jamais montrées.

Maquettes : C-PNJ, J-PNJ (et leurs versions mobiles). « Nouveau PNJ » (saisie rapide, barème d'XP des PNJ) est hors périmètre.

## Décisions

- **Copie dans le prêt :** le conte enregistre une copie de la fiche, complète ou résumée, dans le document du prêt. Le joueur ne lit que ce document : le mode résumé est réel, et la fiche du PNJ reste fermée aux joueurs.
- **Mise à jour de la copie :** bouton « Mettre à jour la copie ». Quand le PNJ a changé depuis la copie, le conte voit « Copie du … : mettre à jour ».

## Données : `npcLoans/{id}`

| Champ | Contenu |
|---|---|
| `characterId`, `characterName` | PNJ |
| `playerUid`, `playerName` | joueur |
| `from`, `until` | début, fin incluse (fin de journée) |
| `mode` | `full` ou `summary` |
| `allowNotes` | notes du joueur autorisées |
| `personality`, `goals`, `limits` | consignes |
| `sheet` | copie de la fiche, selon le mode |
| `sheetAt` | date de la copie |
| `revokedAt` | révocation, ou absent |
| `playerNotes`, `notesAt` | notes du joueur |
| `version`, `createdAt`, `updatedAt`, `updatedByName` | suivi |

**Copie selon le mode :**
- **Complète :** la fiche entière (`Character.toMap()`), sans rien de `private/`.
- **Résumée :**
  - identité : nom, clan, secte, génération, titre ;
  - attributs avec leur focus ;
  - les 7 meilleures compétences ;
  - les disciplines ;
  - Sang et Volonté.

## Règles Firestore

- **Lecture :** l'équipe ; ou le joueur du prêt, pendant la période (`from <= request.time <= until`), si le prêt n'est pas révoqué.
- **Création, modification et suppression :** le conte (`managesAccounts`), avec la version incrémentée de 1 à chaque modification.
- **Joueur :** il ne modifie que `playerNotes` et `notesAt`, si `allowNotes`, pendant la période et sans révocation. `notesAt` vaut `request.time`.

## Écrans

### Conte : `/conteur/pnj` (C-PNJ)

- **Formulaire :**
  - PNJ actif (fiches de PNJ) et joueur ;
  - dates de début et de fin ;
  - mode, notes autorisées ;
  - consignes : personnalité, objectifs, limites.
  - Le bouton s'intitule « Confier à X ».
- **Liste à droite :** « PNJ confiés · N en cours ». Pour chaque prêt :
  - le PNJ, le joueur et la période ;
  - « Prolonger » (nouvelle date de fin), « Révoquer », « Mettre à jour la copie » ;
  - « Terminé » une fois la fin passée ou le prêt révoqué.
- **Ouvrir un prêt :** cela montre ses consignes et les notes du joueur.

### Joueur : `/joueur/pnj` (J-PNJ)

- **Liste :** ses prêts en cours. Un seul prêt s'ouvre directement.
- **Page d'un prêt :**
  - bandeau : « PNJ confié par X — lecture seule, accès jusqu'au … 23h59. Les notes privées du conte ne sont pas visibles. Encore N jours » ;
  - en-tête : nom, identité ;
  - consignes du conte ;
  - fiche selon le mode : attributs, Sang et Volonté, compétences, disciplines, titre, et pour la fiche complète la fiche en lecture ;
  - « Mes notes d'interprétation » si elles sont autorisées : enregistrement automatique, avec « enregistré à … ».
- **Aucun prêt en cours :** état vide.

### Fiche d'un PNJ (C3)

Une section « Prêts » liste les prêts du PNJ (joueur, période, état) et les notes des joueurs, en lecture.

## Contrôles et cas limites

- **Date de fin avant la date de début :** refusé (« La fin précède le début »).
- **Prêts qui se chevauchent :** deux prêts actifs du même PNJ sont permis, avec l'avertissement « déjà confié à X jusqu'au … ».
- **Prêt expiré ou révoqué :** il n'est plus lisible par le joueur ; il reste dans la liste du conte (« Terminé »).
- **Copie ancienne :** si le PNJ a été modifié après `sheetAt`, le conte voit « Copie du … : mettre à jour ».
- **Fiche de PNJ retirée ou morte :** le prêt reste possible, avec un avertissement.
- **Conflit de version :** « Modifié entre-temps : rechargez la page. » ; les autres refus affichent « Enregistrement refusé : réessayez. ».

## Tests

- **Calculs purs :**
  - copie complète ou résumée ;
  - état du prêt (à venir, en cours, terminé, révoqué) ;
  - jours restants ;
  - avertissements (chevauchement, copie ancienne, fiche retirée).
- **Règles d'accès :**
  - lecture du joueur pendant la période seulement ;
  - pas de lecture après révocation, ni pour un autre joueur ;
  - notes modifiables seulement si autorisées ;
  - le joueur ne touche à rien d'autre ;
  - écriture réservée au conte.
- **Écrans :**
  - confier ;
  - prolonger ;
  - révoquer ;
  - mettre à jour la copie ;
  - page du joueur en mode complet et résumé ;
  - notes du joueur ;
  - section « Prêts » de C3.

## Hors périmètre

- Saisie rapide d'un PNJ (« Nouveau PNJ ») et barème d'XP des PNJ selon la date d'Étreinte.
- Export PDF de la fiche prêtée (impression : sous-projet 8).
