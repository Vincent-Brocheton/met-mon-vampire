import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'auth_card.dart';
import 'forms.dart';
import 'session_providers.dart';

/// Maquettes MotDePasse.dc.html. La saisie du nouveau mot de passe passe par
/// la page d’action standard de Firebase (spec, « Mot de passe oublié »).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);
    final back = Align(
      alignment: Alignment.centerLeft,
      child: TextButton(onPressed: () => context.go('/connexion'), child: const Text('Retour à la connexion')),
    );
    if (_sent) {
      return AuthCard(title: 'Mot de passe oublié', children: [
        Semantics(
          liveRegion: true,
          child: Text(
            'Si un compte existe pour ${_email.text.trim()}, un lien valable 1 heure vient d’y être envoyé.',
            style: muted,
          ),
        ),
        back,
      ]);
    }
    return AuthCard(title: 'Mot de passe oublié', children: [
      Text('Indiquez l’adresse de votre compte. Vous recevrez un lien valable 1 heure.', style: muted),
      Form(
        key: _form,
        child: LabeledField(
          label: 'Adresse e-mail',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          validator: validateEmail,
          onSubmitted: _submit,
        ),
      ),
      if (_error != null) FormError(_error!),
      FilledButton(onPressed: _busy ? null : _submit, child: const Text('Envoyer le lien')),
      back,
    ]);
  }
}
