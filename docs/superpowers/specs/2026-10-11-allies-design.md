# Alliés (sous-projet 6g) : conception

## Objectif

Un seul trait, l'allié, remplace les historiques Influence, Alliés et Contacts :
- le joueur demande un allié, ou un niveau de plus, par une demande d'XP ;
- le conte valide, suit l'usage de chaque allié (indisponible pendant quelques mois après usage) et convertit les anciens historiques.

Maquettes : C-Allies (référentiel, déjà en place), C-AlliesSuivi, J-Allies, avec leurs versions mobiles.

Le livre ne connaît que l'historique Alliés classique. Les règles ci-dessous sont celles de la chronique, montrées par les maquettes et confirmées par le conte.

## Décisions

- **Achat :** demande d'XP, comme pour les serviteurs. Chaque allié coûte comme un historique (nouveau niveau × facteur de la génération), compté séparément.
- **Influence :**
  - à 2, 4 ou 5, elle occupe 1, 2 ou 3 spécialisations ;
  - elle ne dépasse pas le niveau de l'allié ;
  - Expert, Remplaçable, Ressource et Sécurité exigent un allié influent ;
  - les autres spécialisations se prennent une fois chacune.
- **Conversion des anciens historiques :** par le conte, une fiche à la fois, sans coût ni remboursement d'XP.
- **Données :**
  - l'allié est sur la fiche du personnage (clé `allies`) ;
  - le suivi d'usage est dans une collection `allies/{id}`, comme pour les serviteurs.

## Règles du jeu retenues

- **Niveau :** de 1 au niveau maximum du référentiel (`allies` → `maxLevel`, 5 par défaut).
- **Spécialisations :**
  - un allié de niveau N a N spécialisations ;
  - l'Influence compte pour 1 (Influence 2), 2 (Influence 4) ou 3 (Influence 5) d'entre elles ;
  - les autres viennent du référentiel `allies`, chacune une fois. Les entrées dont le nom commence par « Influent » ne sont pas proposées, car l'Influence a son propre choix.
- **Condition :** une spécialisation dont le champ `condition` du référentiel contient « Influent » exige une Influence.
- **Types et domaines :** ceux des paramètres du référentiel (`types`, `domains`). Les valeurs de base sont Gotha et Pègre, et les dix domaines de la maquette.
- **Retour après usage :**
  - date d'usage + N mois (N = niveau) ;
  - date d'usage + 2 mois si l'allié est Remplaçable.

## Données

### Sur la fiche : clé tardive `allies`

`[{id, name, level, type, domain, influence, specialties}]` :
- `name` : nom et fonction, 80 caractères au plus ;
- `level` : 1 à 5 ;
- `influence` : 0, 2, 4 ou 5 ;
- `specialties` : liste de noms (sans l'Influence).

La clé suit la règle des clés tardives : elle n'est écrite que si elle n'est pas vide, ou si elle était déjà présente.

**Identifiant :** stable, `<characterId>-a<horodatage en base 36><compteur>`.

**Historique de la fiche :**
- « + Allié Me Castan ●●●● » ;
- « Allié Me Castan ●●● → ●●●● » ;
- « Allié Me Castan modifié » ;
- « − Allié Me Castan ●●●● ».

### Collection `allies/{id}` : suivi d'usage

L'identifiant est le même que celui de l'entrée sur la fiche.

| Champ | Contenu |
|---|---|
| `name`, `characterId`, `characterName` | recopiés de la fiche |
| `holderPlayers` | joueur du personnage, ou liste vide |
| `usedAt` | date de la dernière utilisation, ou absente |
| `returnAt` | date de retour, ou absente |
| `lastUse` | « Ce qu'il a fait » |
| `version`, `lastHistoryId`, `createdAt`, `updatedAt`, `updatedByName` | comme pour les serviteurs |

L'historique `allies/{id}/history/{h}` reprend le format partagé (`TraceEntry`) : « Utilisé : action d'influence », « Rendu disponible ».

Le suivi n'existe qu'une fois l'allié utilisé une première fois. Sans suivi, l'allié est disponible.

### Demande d'XP

Un achat d'allié est un `XpItem` de type `ally` :
- `name` : nom de l'allié ;
- `fromLevel`, `toLevel` : niveaux, `fromLevel` vaut 0 pour un nouvel allié ;
- `ally` : `{type, domain, influence, specialties}`, l'état demandé.

La validation par le conte applique `ally` à la fiche :
- nouvel allié : ajouté ;
- montée de niveau : niveau, Influence et spécialisations remplacés.

## Contrôles (calcul pur)

`allyChecks(ally, rulebook)` renvoie des erreurs :
- « Nom obligatoire » ;
- « Niveau de 1 à M » ;
- « N spécialisations attendues pour un allié de niveau L, M choisies » ;
- « Influence I au-delà du niveau de l'allié » ;
- « Influence : 2, 4 ou 5 » ;
- « X demande un allié influent » ;
- « X en double » ;
- « X : pas une spécialisation d'allié » (hors du référentiel, ou état interdit ou brouillon) ;
- « Type hors liste » ;
- « Domaine hors liste ».

Aide affichée (`allySummary`) : « Influence 4 prend 2 spécialisations sur 4 : il en reste 2. Retour après usage : 4 mois. »

## Règles Firestore

- **Fiche du personnage :**
  - `allies` rejoint les clés protégées du brouillon du joueur ;
  - les chemins du conte (C3, XP, corrections) acceptent la clé.
- **`allies/{id}` :**
  - lecture : `isStaff()`, ou `auth.uid in holderPlayers` ;
  - création et modification : `managesAccounts()`, version 1 puis + 1, entrée d'historique dans le même lot ;
  - suppression : `managesAccounts()` ;
  - nom de 1 à 80 caractères ;
  - `holderPlayers` est une liste.
- **`history/{h}` :** comme pour les serviteurs.

## Écrans

### Joueur : « Alliés », `/joueur/personnages/:id/allies` (J-Allies)

- **Cartes des alliés :**
  - nom, niveau en pastilles, type, domaine ;
  - Influence et spécialisations ;
  - état : « Disponible », « De retour le … », ou « En attente du conte » quand une demande d'XP ouverte le concerne.
- **Formulaire « Nouvel allié · demande au conte » :**
  - nom et fonction, type, domaine, niveau ;
  - Influence (Aucune, 2, 4, 5) ;
  - une liste par spécialisation restante ;
  - « Comment l'avez-vous rencontré ? », qui devient la justification de la demande ;
  - l'encart d'aide, le coût en XP, et les erreurs en direct ;
  - « Envoyer la demande ».
- **Envoi :**
  - il crée une demande d'XP à un seul achat, envoyée au conte (statut « En attente ») ;
  - il est bloqué si l'XP disponible, moins celle réservée par les autres demandes ouvertes du personnage, ne couvre pas le coût.
- **« Monter d'un niveau »** sur une carte ouvre le même formulaire, prérempli, avec un niveau de plus.
- **Accès :** la section « Alliés » de J2 mène à cette page, pour une fiche active.

### Conte : « Alliés en jeu », `/conteur/allies` (C-AlliesSuivi)

- **Accès :** un bouton sur la page des fiches.
- **Liste :**
  - colonnes : allié (et spécialisations), personnage, niveau, type et domaine, état, retour ;
  - filtres :
    - Tous ;
    - Indisponibles ;
    - Demandes (demandes d'XP ouvertes de type allié) ;
    - À convertir.
  - Le narrateur la voit en lecture seule.
- **Panneau « Suivi de l'allié » :**
  - en-tête : nom, personnage, niveau, type, domaine, Influence et spécialisations ;
  - « Utilisé le » (JJ/MM/AAAA) et « Ce qu'il a fait » ;
  - « Date de retour », calculée et modifiable ;
  - historique des usages ;
  - « Enregistrer » ;
  - « Rendre disponible », qui efface `usedAt` et `returnAt`.
- **« À convertir » :**
  - liste les fiches actives qui ont encore un historique Alliés, Influence ou Contacts, avec le niveau restant ;
  - une ligne ouvre le formulaire d'allié, prérempli avec ce niveau ;
  - l'enregistrement ajoute l'allié à la fiche et diminue l'historique d'autant. L'historique est retiré à 0. Écriture tracée, motif « Conversion des anciens historiques » ;
  - le niveau de l'allié ne dépasse pas le niveau restant de l'historique ;
  - aucun mouvement d'XP.

### Fiche C3

- **Section « Alliés » :** ajouter, modifier (nom, type, domaine, niveau, Influence, spécialisations) ou retirer un allié, dans le brouillon de C3, avec le motif habituel.
- **Contrôles :** ceux de `allyChecks` sont affichés en avertissement, sans bloquer.
- **Retrait :** le suivi `allies/{id}` reste ; la liste « Alliés en jeu » ne montre que les alliés présents sur une fiche.

### Fiche J2

Section « Alliés » en lecture : nom, niveau, état, et lien vers la page Alliés.

## Écran XP et création

- **Écran XP :** l'historique « Alliés » n'est plus proposé en achat ; la page Alliés le remplace. Un achat d'allié validé passe par la validation existante des demandes.
- **Création :** inchangée. L'historique Alliés reste possible ; la fiche validée apparaîtra dans « À convertir ».

## Erreurs et cas limites

- **Conflit de version :** « Modifié entre-temps : rechargez la page. » ; les autres refus affichent « Enregistrement refusé : réessayez. ».
- **Joueur du personnage changé :** l'accès au suivi suit, comme pour les objets.
- **Allié retiré de la fiche :** son suivi reste, invisible dans la liste.
- **Demande validée pour un allié disparu entre-temps :** la validation est refusée avec « Allié introuvable sur la fiche ».
- **Référentiel sans spécialisation :** le formulaire n'en propose aucune, et le contrôle du nombre bloque l'envoi.

## Tests

- **Calculs purs :**
  - contrôles ;
  - aide (spécialisations restantes, durée de retour) ;
  - date de retour (Remplaçable) ;
  - application d'un achat à la fiche ;
  - conversion (historique diminué, puis retiré) ;
  - changements tracés.
- **Règles d'accès :**
  - lecture du suivi par le joueur du personnage seulement ;
  - écriture par le conte avec version et historique ;
  - `allies` protégée dans le brouillon du joueur.
- **Écrans :**
  - demande d'un allié et montée de niveau ;
  - validation d'une demande d'allié ;
  - suivi (utilisé, rendu disponible) ;
  - conversion ;
  - sections J2 et C3.

## Hors périmètre

- Les actions d'influence elles-mêmes (attaques, ressources récupérées) : le conte les arbitre ; l'application ne note que l'usage.
- Les règles des alliés dans le wiki.
- Le décompte des parties.
