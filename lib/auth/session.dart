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
