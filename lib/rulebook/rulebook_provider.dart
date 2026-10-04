import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../xp/xp_repository.dart';
import 'rulebook.dart';
import 'rules_repository.dart';

part 'rulebook_provider.g.dart';

/// Référentiel des moteurs : null tant que le référentiel ou les valeurs de création chargent.
/// Lecture en erreur : valeurs de base, la création reste possible.
@riverpod
Rulebook? rulebook(Ref ref) {
  final entries = ref.watch(allRuleEntriesProvider);
  final settings = ref.watch(xpSettingsProvider);
  final categories = ref.watch(allRuleSettingsProvider);
  bool waiting(AsyncValue<Object?> v) => !v.hasValue && !v.hasError;
  if (waiting(entries) || waiting(settings) || waiting(categories)) return null;
  return Rulebook(entries.value ?? const {}, settings.value?.creation ?? const CreationValues(), categories.value ?? const {});
}
