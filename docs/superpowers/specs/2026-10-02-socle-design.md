# Portail Personnages MET — Sous-projet 1 : Socle

Date : 2026-10-02
Statut : en relecture

## Contexte

Application de gestion de fiches de personnage pour un GN *Vampire : La Mascarade* (règles Mind's Eye Theatre). Cible : Android et Web, backend Firebase.

Source des maquettes : canvas Claude Design « Portail Personnages MET » (https://claude.ai/artifact/RMXAnPkQ4qP48GBCDKDSGp), ~95 écrans en version Web (1440 px) et Mobile (390 px).

Le projet complet est découpé en 10 sous-projets, chacun avec sa spec, son plan et son implémentation :

1. **Socle** (ce document)
2. Fiche de personnage : modèle, cycle de vie, consultation, historique
3. Création guidée (10 étapes) et validation conteur
4. XP : dépense, attribution, paramètres, corrections
5. Référentiels de règles (conteur)
6. PNJ confiés, goules, alliés, lieux, équipement
7. Moralité, liens de sang, titres, événements
8. Partie : gel des fiches, hors ligne, impression A4
9. Wiki
10. Notifications, journal, import de fiches

## Objectif du socle

Une application déployable où l'on peut :

- demander un accès, se connecter, récupérer son mot de passe ;
- être redirigé vers l'espace correspondant à son rôle ;
- côté conteur, démarrer la chronique, valider les comptes et gérer l'équipe ;
- gérer son compte (nom, e-mail, mot de passe).

Tous les sous-projets suivants s'appuient sur ce socle : thème, coquilles de navigation, session, rôles et règles de sécurité.

### Critères de réussite

- L'app tourne sur Android et sur le Web (Firebase Hosting) à partir d'une seule base de code.
- Les écrans du socle reproduisent fidèlement les maquettes : couleurs, typographies, mise en page Web et Mobile.
- Aucun utilisateur ne peut s'attribuer ou attribuer un rôle hors de ses droits. Les tests des règles Firestore le prouvent.

## Contraintes

- Forfait Firebase **Spark** (gratuit) : pas de Cloud Functions. Les rôles sont stockés dans Firestore et protégés par les règles de sécurité.
- Nouveau projet Firebase, créé par l'utilisateur.
- Emplacement : `C:\Users\vince\Documents\Projets\portail_met`.
- Développement et tests contre la Firebase Emulator Suite.

## Stack

- Flutter 3.47 (stable), Dart.
- `firebase_core`, `firebase_auth`, `cloud_firestore`.
- `go_router` : routage avec URL Web et redirections par rôle.
- `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` et `build_runner` : gestion d'état.
- `google_fonts` : Cormorant Garamond (titres), Source Sans 3 (texte).
- Firebase Hosting pour le Web.

## Identité visuelle (relevée dans les maquettes)

| Jeton | Valeur | Usage |
|---|---|---|
| fond | `#120E10` | fond de page |
| surface | `#1A1315` | en-tête, panneau latéral |
| carte | `#1C1618` | cartes, champs |
| survol nav | `#2A2023` | onglet actif |
| bordure | `#3A2E31` | bordures de cartes, séparateurs |
| bordure champ | `#4A3B3F` | champs, boutons secondaires |
| texte | `#EEE6D8` | texte principal |
| texte doux | `#D9D0C2` | paragraphes |
| texte secondaire | `#B5A99A` | sous-titres, nav inactive |
| texte discret | `#8F8377` | légendes, placeholders |
| accent | `#B3262F` | bouton principal, filets |
| accent icône | `#E0575F` | logo goutte, pastille notif |
| lien | `#E0707A` / survol `#F0A0A6` | liens, actions destructives |
| or | `#C8A96A` / `#E3C98E` | progression, rôle conteur |
| succès | `#8FD3B8` | « Fait », « Oui » |
| narrateur | `#C3B5F0` | rôle narrateur |

- Rayons : 6 px pour les champs et boutons, 10 px pour les cartes.
- Champs : 44 à 48 px de haut. Cibles tactiles : au moins 44 px.
- Titres de section : 13 px, majuscules, interlettrage 0,16 em, `#B5A99A`, gras.
- Logo : une goutte, en SVG trait `#E0575F`.

## Architecture

```
lib/
  main.dart            init Firebase, ProviderScope, MaterialApp.router
  router.dart          routes go_router + fonction de redirection pure
  core/
    theme.dart         ThemeData à partir des jetons ci-dessus
    widgets/           PrimaryButton, SecondaryButton, LabeledField, Panel, SectionTitle, EmptyState
  auth/                écrans connexion, mot de passe oublié, demande d'accès, attente ; providers de session
  account/             Mon compte
  chronicle/           config de chronique, démarrage (C32), comptes (C7), équipe (C33)
  shell/               PlayerShell et StorytellerShell, version Web (en-tête) et Mobile (barre en bas)
firestore.rules
firebase.json
test/                  tests Dart
rules_test/            tests Node des règles (émulateur)
```

Chaque sous-projet suivant ajoutera son propre dossier sous `lib/`.

### Session

- Le provider `authStateProvider` diffuse `FirebaseAuth.authStateChanges()`.
- Le provider `currentUserProvider` diffuse le document `users/{uid}` de l'utilisateur connecté (null si déconnecté).
- Le routeur se rafraîchit à chaque changement de ces flux, via un `Listenable` alimenté par ces providers.

### Redirection par rôle

`redirect(location, session)` est une fonction pure, testable sans Firebase.

| État | Destination |
|---|---|
| non connecté | `/connexion` (sauf `/mot-de-passe`, `/demande-acces`) |
| connecté, document `users` absent ou `pending` | `/attente` |
| `disabled` | déconnexion, puis `/connexion` avec le message « Compte désactivé » |
| `joueur` | `/joueur/...` ; toute route `/conteur/...` renvoie vers `/joueur` |
| `narrateur`, `conteur`, `principal` | `/conteur/...` |
| `principal` et chronique sans nom (`chronicle/config.name` vide) | `/conteur/demarrage` |
| session en cours de chargement | `/chargement?de=<destination>`, puis retour à la destination (rafraîchissement d'une page Web) |

`/compte` est accessible à tous les rôles validés.

## Données Firestore

### `chronicle/config`

```
name: string            // nom de la chronique
associationName: string
defaultSect: string     // "Camarilla" par défaut
ownerUid: string        // premier conteur principal
createdAt: timestamp
```

Le nom de la chronique remplace les `[Nom de la chronique]` des maquettes. Tant que le document n'existe pas, l'app affiche « Portail MET ».

### `users/{uid}`

```
displayName: string
email: string
role: "pending" | "joueur" | "narrateur" | "conteur" | "principal" | "disabled"
accessMessage: string?  // message joint à la demande d'accès
createdAt: timestamp
lastLoginAt: timestamp
```

### `invitations/{emailEnMinuscules}`

```
role: "joueur" | "narrateur" | "conteur"
invitedBy: uid
createdAt: timestamp
```

## Flux

### Premier lancement

1. Le premier utilisateur passe par « Demander un accès ».
2. Si `chronicle/config` n'existe pas, un seul batch crée à la fois `users/{uid}` avec le rôle `principal` et `chronicle/config` avec `ownerUid = uid`.
3. Une règle n'autorise ce rôle que si `chronicle/config` n'existe pas encore et qu'il est créé dans le même batch, avec `ownerUid` égal à l'uid de l'auteur.
4. Le nouveau principal est redirigé vers `/conteur/demarrage` (C32).

### Demande d'accès

1. Formulaire : nom affiché, e-mail, mot de passe (au moins 12 caractères, saisi deux fois), message pour le conte.
2. L'app crée le compte avec `createUserWithEmailAndPassword`, puis envoie un e-mail de vérification.
3. Le document `users` est créé avec le rôle `pending`.
4. Sur l'écran `/attente`, le rôle `pending` voit « Un conteur va valider votre compte ». Un bouton « J'ai confirmé mon e-mail » recharge l'utilisateur et applique l'invitation si elle existe et que l'e-mail est vérifié.
5. Si la création du document `users` a échoué (réseau, deux premiers comptes simultanés), l'écran `/attente` propose « Finaliser ma demande », qui relance la création.

### Connexion

- Connexion par e-mail et mot de passe.
- « Rester connecté » s'applique au Web uniquement : persistance `LOCAL` si la case est cochée, `SESSION` sinon. Sur Android, la session est toujours conservée.
- À chaque connexion, `lastLoginAt` est mis à jour.
- Une seule réponse d'échec pour un e-mail inconnu ou un mot de passe faux : « E-mail ou mot de passe incorrect ».

### Mot de passe oublié

- `sendPasswordResetEmail`, avec toujours le même message de confirmation, que le compte existe ou non.
- La saisie du nouveau mot de passe passe par la page d'action par défaut de Firebase. Une page personnalisée viendra plus tard.

### Lien de connexion par e-mail (dernière tâche, peut être retirée)

- Sur le Web : `sendSignInLinkToEmail` puis `signInWithEmailLink` au retour sur l'app.
- Sur Android : App Links sur le domaine Firebase Hosting (`/.well-known/assetlinks.json`).
- Si la configuration Android bloque, le bouton est masqué sur Android et reste disponible sur le Web.

## Écrans

| Route | Écran | Maquette |
|---|---|---|
| `/connexion` | Connexion | `Main`, `Connexion-mobile` |
| `/mot-de-passe` | Mot de passe oublié | `MotDePasse`, `MotDePasse-mobile` |
| `/demande-acces` | Demander un accès | aucune ; même style que la connexion |
| `/attente` | En attente de validation | aucune ; panneau du style de `MotDePasse` |
| `/joueur` | Accueil joueur (bienvenue) | `J-Bienvenue`, `J-Bienvenue-mobile` |
| `/conteur` | Tableau de bord ; affiche la liste de démarrage tant qu'elle n'est pas finie | `C-Demarrage` |
| `/conteur/demarrage` | Démarrer la chronique ; l'étape 1, « Nommer la chronique », est fonctionnelle | `C-Demarrage`, `C-Demarrage-mobile` |
| `/conteur/comptes` | Comptes : demandes d'accès, liste, filtres, désactivation | `C-Comptes`, `C-Comptes-mobile` |
| `/conteur/equipe` | Équipe de conteurs, rôles, invitations (principal seulement) | `C-Roles`, `C-Roles-mobile` |
| `/compte` | Mon compte : profil, e-mail, mot de passe | `Compte`, `Compte-mobile` |

- Les onglets des autres sous-projets (Mes personnages, PNJ confiés, Demandes, XP, Wiki, Référentiel, Paramètres, Notifications) existent dans les coquilles et affichent l'état vide « À venir ».
- Les étapes 2 à 6 de C32 renvoient vers ces mêmes onglets.

### Coquilles

- **À partir de 900 px de large** : en-tête de 72 px façon maquette Web, avec logo, nom de la chronique, onglets, cloche et avatar.
  - Côté conteur, l'en-tête ajoute les icônes Référentiel et Paramètres, et le rôle s'affiche sous le nom.
- **En dessous de 900 px** : barre d'onglets en bas.
  - Joueur : 5 onglets (Accueil, Personnages, PNJ confiés, Demandes, Wiki).
  - Conteur : 4 onglets (Tableau de bord, Fiches, Demandes, Comptes) plus un onglet « Plus » qui ouvre les autres destinations.
- Badge sur l'onglet Comptes : nombre de demandes d'accès en attente (conteurs et principal). Le narrateur ne voit pas l'onglet Comptes.

### Composant d'états (`EmptyState`, maquette `Etats`)

Six variantes : liste vide, recherche sans résultat, page introuvable, accès refusé, hors connexion, erreur. Chacune affiche une icône, un titre, une explication et un bouton de sortie.

### Reporté

- **Mon compte** : appareils connectés (sous-projet 8), préférences de notifications (sous-projet 10), export de mes données et suppression du compte avec anonymisation (plus tard, pour ne pas risquer de perdre des fiches).
- **Envoi des invitations** : l'app n'envoie pas l'e-mail, faute de Cloud Functions. Le conteur partage lui-même le lien de l'app.

## Droits du socle

Le tableau suit C33. La matrice générale est plus floue, on retient l'interprétation la plus stricte.

| Action | Joueur | Narrateur | Conteur | Principal |
|---|---|---|---|---|
| Lire la liste des comptes | non | non | oui | oui |
| Accepter / refuser une demande d'accès (vers `joueur`) | non | non | oui | oui |
| Désactiver / réactiver un joueur | non | non | oui | oui |
| Nommer narrateur / conteur / principal, inviter | non | non | non | oui |
| Modifier `chronicle/config` | non | non | non | oui |
| Retirer le dernier principal | non | non | non | non |

## Règles de sécurité Firestore

Fonctions utilitaires : `role()` lit `users/{request.auth.uid}.role` ; `isStaff()` vaut vrai pour conteur ou principal (le narrateur n'accède pas aux comptes, selon C33) ; `isPrincipal()`.

- `chronicle/config`
  - Lecture : publique, sans connexion. L'écran de connexion affiche le nom de la chronique, et le document ne contient rien de sensible.
  - Création : seulement si le document n'existe pas, avec `ownerUid == request.auth.uid` et la création simultanée de `users/{uid}` en `principal` (vérifiée par `getAfter`).
  - Modification : `isPrincipal()` ; `ownerUid` ne change pas.
- `users/{uid}`
  - Lecture : soi-même, ou `isStaff()`.
  - Création par soi-même, champs `email` et `displayName` cohérents avec le jeton, avec l'un de ces rôles :
    - `pending` ;
    - `principal`, dans le cas du premier lancement ci-dessus.
    - Une invitation ne s'applique jamais à la création, car l'e-mail n'est pas encore vérifié à ce moment-là. Elle s'applique ensuite, par la modification de `pending` vers le rôle invité décrite ci-dessous.
  - Modification par soi-même : uniquement `displayName` et `lastLoginAt`. Exception : passer de `pending` au rôle d'une invitation existante, si l'e-mail est vérifié.
  - Modification par un conteur : `role` de `pending` vers `joueur` ou `disabled`, de `joueur` vers `disabled`, de `disabled` vers `joueur`.
  - Modification par le principal : tout changement de `role`, sauf faire tomber à zéro le nombre de principaux.
    - Sans requête d'agrégat dans les règles, un principal ne peut pas modifier son propre rôle. Il faut d'abord nommer un autre principal, qui le rétrograde ensuite.
  - Suppression : refusée.
- `invitations/{email}` : lecture, écriture et suppression par `isPrincipal()` ; lecture aussi par l'utilisateur dont `token.email` correspond.
- Par défaut : tout est refusé.

## Gestion des erreurs

- Les codes `FirebaseAuthException` sont traduits en français :
  - mauvais identifiants, identifiants invalides, utilisateur introuvable → « E-mail ou mot de passe incorrect » ;
  - trop de tentatives ;
  - pas de réseau ;
  - e-mail déjà utilisé : à la demande d'accès seulement, avec « Un compte existe déjà, connectez-vous ou réinitialisez votre mot de passe » ;
  - mot de passe trop faible.
- Les écrans qui lisent Firestore affichent le chargement, puis `EmptyState(erreur)` avec un bouton « Réessayer ». Les formulaires conservent leur saisie en cas d'erreur.
- Validation côté client : e-mail bien formé, mot de passe d'au moins 12 caractères, confirmation identique, nom affiché non vide et d'au plus 60 caractères.

## Tests

1. **Règles Firestore**, dans `rules_test/` en Node avec `@firebase/rules-unit-testing`, contre l'émulateur. Les cas :
   - élévation de son propre rôle refusée ;
   - création en `pending` autorisée, en `joueur` sans invitation refusée ;
   - invitation appliquée seulement si l'e-mail est vérifié ;
   - premier principal accepté, deuxième « premier principal » refusé ;
   - transitions autorisées et interdites d'un conteur ;
   - un principal ne peut pas se rétrograder lui-même ;
   - un joueur ne lit pas les autres comptes.
2. **Redirection** : test unitaire Dart de `redirect()`, une ligne par cas du tableau.
3. **Widget de connexion** : validation des champs et affichage d'un message d'erreur Auth simulé.

Pas de test de bout en bout dans le socle.

## Livraison

- Projet Flutter créé avec `flutter create --platforms=android,web --org fr.portailmet portail_met`.
- Étapes réalisées par l'utilisateur, car elles demandent son compte Google :
  - `firebase login` ;
  - création du projet Firebase ;
  - activation d'Authentication (fournisseurs e-mail/mot de passe et lien e-mail) ;
  - création de la base Firestore (région `europe-west`).
- Ensuite, avec l'accord de l'utilisateur à chaque déploiement :
  - `flutterfire configure` ;
  - `firebase deploy --only firestore:rules` ;
  - `flutter build web` puis `firebase deploy --only hosting`.
- Android : APK de debug installable. La signature de publication et le Play Store sont hors périmètre.

## Hors périmètre du socle

Fiches de personnage, création guidée, XP, référentiels, PNJ, wiki, notifications, mode hors ligne, impression : sous-projets 2 à 10.
