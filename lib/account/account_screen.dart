import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_card.dart';
import '../auth/forms.dart';
import '../auth/session_providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Mon compte : profil, e-mail, mot de passe. Même écran pour joueurs et conteurs.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _profileForm = GlobalKey<FormState>();
  final _emailForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _busy; // section en cours
  final _errors = <String, String>{};

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    _name.text = user?.displayName ?? '';
    _email.text = user?.email ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _current, _next]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(String section, GlobalKey<FormState> form, Future<void> Function() action, String success) async {
    if (_busy != null || !form.currentState!.validate()) return;
    setState(() {
      _busy = section;
      _errors.remove(section);
    });
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      final wrongCurrent = section == 'password' &&
          e is FirebaseAuthException &&
          (e.code == 'wrong-password' || e.code == 'invalid-credential');
      if (mounted) setState(() => _errors[section] = wrongCurrent ? 'Mot de passe actuel incorrect.' : authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(authRepositoryProvider);
    final muted = Theme.of(context).textTheme.bodySmall;

    Widget section(String title, GlobalKey<FormState> form, String key, List<Widget> fields, Widget button) => Panel(
          child: Form(
            key: form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle(title),
              const SizedBox(height: 14),
              for (final f in fields) ...[f, const SizedBox(height: 14)],
              if (_errors[key] != null) ...[FormError(_errors[key]!), const SizedBox(height: 12)],
              Align(alignment: Alignment.centerLeft, child: button),
            ]),
          ),
        );

    final profile = section('Profil', _profileForm, 'profile', [
      LabeledField(label: 'Nom affiché', controller: _name, validator: validateDisplayName),
    ], FilledButton(
      onPressed: _busy != null ? null : () => _run('profile', _profileForm, () => repo.updateDisplayName(_name.text), 'Nom enregistré.'),
      child: const Text('Enregistrer'),
    ));

    final email = section('Adresse e-mail', _emailForm, 'email', [
      LabeledField(label: 'Adresse e-mail', controller: _email, keyboardType: TextInputType.emailAddress, validator: validateEmail),
      Text('Un changement d’adresse est confirmé par un lien envoyé à la nouvelle adresse.', style: muted),
    ], OutlinedButton(
      onPressed: _busy != null
          ? null
          : () => _run('email', _emailForm, () => repo.changeEmail(_email.text),
              'Un lien de confirmation a été envoyé à ${_email.text.trim()}.'),
      child: const Text('Changer l’adresse'),
    ));

    final password = section('Mot de passe', _passwordForm, 'password', [
      LabeledField(label: 'Mot de passe actuel', controller: _current, obscure: true, validator: validateRequired),
      LabeledField(label: 'Nouveau mot de passe', controller: _next, hint: '12 caractères minimum', obscure: true, validator: validateNewPassword),
    ], OutlinedButton(
      onPressed: _busy != null
          ? null
          : () => _run('password', _passwordForm, () async {
                await repo.changePassword(_current.text, _next.text);
                _current.clear();
                _next.clear();
              }, 'Mot de passe modifié.'),
      child: const Text('Changer le mot de passe'),
    ));

    return PageBody(children: [
      PageTitle('Mon compte', action: TextButton(onPressed: repo.signOut, child: const Text('Se déconnecter'))),
      const SizedBox(height: 22),
      if (isWide(context))
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(children: [profile, const SizedBox(height: 20), email])),
          const SizedBox(width: 20),
          Expanded(child: password),
        ])
      else ...[
        profile,
        const SizedBox(height: 20),
        email,
        const SizedBox(height: 20),
        password,
      ],
      const SizedBox(height: 16),
      Text('Bientôt ici : notifications par e-mail, appareils connectés, export de vos données.',
          style: muted?.copyWith(color: AppColors.textMuted)),
    ]);
  }
}
