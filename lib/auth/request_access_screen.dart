import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'auth_card.dart';
import 'forms.dart';
import 'session_providers.dart';

/// « Demander un accès » (lien de Main.dc.html). Le premier compte devient conteur principal.
class RequestAccessScreen extends ConsumerStatefulWidget {
  const RequestAccessScreen({super.key});

  @override
  ConsumerState<RequestAccessScreen> createState() => _RequestAccessScreenState();
}

class _RequestAccessScreenState extends ConsumerState<RequestAccessScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Dès la création du compte, la redirection mène à /attente (ou au démarrage).
      await ref.read(authRepositoryProvider).requestAccess(
            displayName: _name.text,
            email: _email.text,
            password: _password.text,
            message: _message.text,
          );
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);
    return AuthCard(title: 'Demander un accès', children: [
      Text('Un conteur validera votre compte. Vous recevrez aussi un e-mail pour confirmer votre adresse.', style: muted),
      AutofillGroup(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LabeledField(label: 'Nom affiché', controller: _name, hint: 'Camille R.', autofillHints: const [AutofillHints.name], validator: validateDisplayName),
            const SizedBox(height: 16),
            LabeledField(label: 'Adresse e-mail', controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], validator: validateEmail),
            const SizedBox(height: 16),
            LabeledField(label: 'Mot de passe', controller: _password, hint: '12 caractères minimum', obscure: true, autofillHints: const [AutofillHints.newPassword], validator: validateNewPassword),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Confirmer le mot de passe',
              controller: _confirm,
              obscure: true,
              validator: (v) => v == _password.text ? null : 'Les deux mots de passe diffèrent.',
            ),
            const SizedBox(height: 16),
            LabeledField(label: 'Un mot pour le conte (facultatif)', controller: _message, maxLines: 3),
          ]),
        ),
      ),
      if (_error != null) FormError(_error!),
      FilledButton(onPressed: _busy ? null : _submit, child: const Text('Envoyer la demande')),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: () => context.go('/connexion'), child: const Text('J’ai déjà un compte')),
      ),
    ]);
  }
}
