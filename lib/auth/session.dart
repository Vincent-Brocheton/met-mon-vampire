import 'package:cloud_firestore/cloud_firestore.dart';

enum Role {
  pending,
  joueur,
  narrateur,
  conteur,
  principal,
  disabled;

  static Role? parse(Object? value) => Role.values.asNameMap()[value];

  /// Accède à l'espace conteur.
  bool get isStaff => this == narrateur || this == conteur || this == principal;

  /// Valide les comptes (C7). Le narrateur n'y a pas accès (C33).
  bool get managesAccounts => this == conteur || this == principal;

  String get label => switch (this) {
        pending => 'En attente',
        joueur => 'Joueur',
        narrateur => 'Narrateur',
        conteur => 'Conteur',
        principal => 'Conteur principal',
        disabled => 'Désactivé',
      };
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    this.accessMessage,
    this.createdAt,
    this.lastLoginAt,
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return AppUser(
      uid: doc.id,
      displayName: m['displayName'] as String? ?? '',
      email: m['email'] as String? ?? '',
      role: Role.parse(m['role']) ?? Role.pending,
      accessMessage: m['accessMessage'] as String?,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (m['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  final String uid;
  final String displayName;
  final String email;
  final Role role;
  final String? accessMessage;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
}

class ChronicleConfig {
  const ChronicleConfig({
    required this.name,
    required this.associationName,
    required this.defaultSect,
    required this.ownerUid,
  });

  factory ChronicleConfig.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return ChronicleConfig(
      name: m['name'] as String? ?? '',
      associationName: m['associationName'] as String? ?? '',
      defaultSect: m['defaultSect'] as String? ?? 'Camarilla',
      ownerUid: m['ownerUid'] as String? ?? '',
    );
  }

  final String name;
  final String associationName;
  final String defaultSect;
  final String ownerUid;

  String get displayName => name.isEmpty ? 'Portail MET' : name;
}

/// Ce que le routeur sait de l'utilisateur.
class Session {
  const Session({this.loading = false, this.uid, this.role, this.chronicleNamed = false});

  static const loadingState = Session(loading: true);

  final bool loading;
  final String? uid;

  /// `null` si connecté sans document `users` (demande interrompue).
  final Role? role;
  final bool chronicleNamed;
}
