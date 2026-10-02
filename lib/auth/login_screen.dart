import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import 'auth_card.dart';
import 'forms.dart';
import 'session_providers.dart';

/// Maquettes Main.dc.html (Web) et Connexion-mobile.dc.html.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.disabled = false});

  /// Arrivée après désactivation du compte (redirection `?desactive=1`).
  final bool disabled;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // La redirection suit le changement de session.
      await ref.read(authRepositoryProvider).signIn(_email.text, _password.text, remember: _remember);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chronicle = ref.watch(chronicleProvider).value;
    final name = chronicle?.displayName ?? 'Portail MET';
    final association = chronicle?.associationName;
    final form = _buildForm(context);
    return Scaffold(
      body: SafeArea(
        child: isWide(context)
            ? Row(children: [
                SizedBox(width: 760, child: _Intro(name: name, association: association)),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(48),
                      child: SizedBox(width: 420, child: form),
                    ),
                  ),
                ),
              ])
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _Brand(association: association, size: 22),
                  const SizedBox(height: 28),
                  Container(width: 48, height: 2, color: AppColors.accent),
                  const SizedBox(height: 14),
                  Text(name, style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 44)),
                  const SizedBox(height: 14),
                  Text('Votre fiche, les PNJ que le conte vous confie et vos demandes en cours.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 28),
                  form,
                ]),
              ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AutofillGroup(
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (isWide(context)) ...[
            Text('Connexion', style: t.headlineLarge),
            const SizedBox(height: 8),
            Text('Un seul accès pour tous. Votre rôle — joueur ou conteur — est défini par l’équipe du conte.',
                style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 28),
          ],
          if (widget.disabled) ...[
            const FormError('Ce compte est désactivé. Contactez l’équipe du conte.'),
            const SizedBox(height: 18),
          ],
          LabeledField(
            label: 'Adresse e-mail',
            controller: _email,
            hint: 'vous@exemple.fr',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: validateEmail,
          ),
          const SizedBox(height: 18),
          LabeledField(
            label: 'Mot de passe',
            controller: _password,
            hint: '••••••••',
            obscure: true,
            autofillHints: const [AutofillHints.password],
            validator: validateRequired,
            onSubmitted: _submit,
            trailing: TextButton(
              onPressed: () => context.go('/mot-de-passe'),
              child: const Text('Mot de passe oublié ?'),
            ),
          ),
          if (kIsWeb)
            CheckboxListTile(
              value: _remember,
              onChanged: (v) => setState(() => _remember = v ?? true),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text('Rester connecté sur cet appareil',
                  style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            ),
          const SizedBox(height: 18),
          if (_error != null) ...[FormError(_error!), const SizedBox(height: 12)],
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Entrer'),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Nouveau joueur ?', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
            TextButton(onPressed: () => context.go('/demande-acces'), child: const Text('Demander un accès')),
            Text('— un conteur validera votre compte.', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
          ]),
        ]),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.association, this.size = 28});
  final String? association;
  final double size;

  @override
  Widget build(BuildContext context) {
    final a = association;
    return Row(children: [
      DropLogo(size: size),
      const SizedBox(width: 12),
      if (a != null && a.isNotEmpty)
        Flexible(
          child: Text(a.toUpperCase(),
              style: const TextStyle(fontSize: 13, letterSpacing: 2.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
    ]);
  }
}

/// Panneau gauche de la maquette Web.
class _Intro extends StatelessWidget {
  const _Intro({required this.name, required this.association});
  final String name;
  final String? association;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget fact(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 1.7, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: t.bodyMedium),
        ]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 64),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _Brand(association: association),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 64, height: 2, color: AppColors.accent),
          const SizedBox(height: 28),
          Text(name, style: t.displayLarge),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Le registre des Damnés. Vos fiches de personnage, les PNJ que le conte vous confie et le suivi de vos demandes.',
              style: t.bodyLarge?.copyWith(fontSize: 19, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 36),
          Wrap(spacing: 32, runSpacing: 16, children: [
            fact('Système', 'Mind’s Eye Theatre'),
            fact('Univers', 'Vampire : La Mascarade'),
            fact('Accès', 'Joueurs · Conteurs'),
          ]),
        ]),
        Text('Gestion des fiches — règles Mind’s Eye Theatre.',
            style: t.headlineSmall?.copyWith(fontSize: 18, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
      ]),
    );
  }
}
