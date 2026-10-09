import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../auth/session_providers.dart';
import '../bonds/bonds_repository.dart';
import '../characters/character_repository.dart';
import '../characters/sheet_widgets.dart' show isDenied;
import '../core/empty_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../games/game.dart';
import '../games/game_rules.dart';
import '../games/games_repository.dart';
import '../items/items_repository.dart';
import '../places/places_repository.dart';
import '../rulebook/rulebook_provider.dart';
import '../xp/xp_repository.dart';
import '../xp/xp_request.dart';
import 'print_sheet.dart';
import 'sheet_pdf.dart';

/// « Imprimer la fiche » (J-Imprimer, simplifié) : choix de la version pendant un gel, aperçu du PDF.
class PrintScreen extends ConsumerStatefulWidget {
  const PrintScreen({super.key, required this.characterId, required this.basePath, this.preview});
  final String characterId;
  final String basePath;

  /// Aperçu ; remplacé dans les tests, car `PdfPreview` passe par des canaux de plateforme.
  final Widget Function(PrintSheet sheet)? preview;

  @override
  ConsumerState<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends ConsumerState<PrintScreen> {
  PrintVersion? _choice;
  int _attempt = 0;

  Widget _pdfPreview(PrintSheet sheet) => PdfPreview(
        key: ValueKey('${sheet.fileName}-$_attempt'),
        build: (_) async => sheetPdf(sheet, await loadPdfFonts()),
        pdfFileName: sheet.fileName,
        initialPageFormat: PdfPageFormat.a4,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        onError: (context, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Impossible de préparer le PDF : réessayez.'),
            const SizedBox(height: 8),
            TextButton(onPressed: () => setState(() => _attempt++), child: const Text('Réessayer')),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(characterProvider(widget.characterId));
    // Riverpod 3 relance un provider en erreur : on lit l'erreur même pendant la relance.
    if (value.error case final Object error when isDenied(error)) {
      return EmptyState(
        kind: EmptyKind.forbidden,
        title: 'Cette fiche n’est pas la vôtre',
        message: 'Vous ne voyez que vos personnages et les PNJ qui vous sont confiés.',
        actionLabel: 'Mes personnages',
        onAction: () => context.go('/joueur/personnages'),
      );
    }
    return asyncView(value, (live) {
      if (live == null) {
        return const EmptyState(kind: EmptyKind.notFound, title: 'Cette fiche n’existe pas', message: 'Elle a pu être retirée.');
      }
      final rb = ref.watch(rulebookProvider);
      if (rb == null) return const Center(child: CircularProgressIndicator());
      final now = DateTime.now();
      final game = frozenBy(ref.watch(gamesProvider).value ?? const <Game>[], live.id, now);
      final frozenAsync = game == null ? null : ref.watch(frozenSheetProvider(live.id, game.id));
      final frozen = frozenAsync?.value;
      final loadingFrozen = frozenAsync != null && frozenAsync.isLoading && !frozenAsync.hasValue;
      final version = frozen != null ? (_choice ?? PrintVersion.frozen) : PrintVersion.current;
      final staff = widget.basePath.startsWith('/conteur');
      final requests = staff ? ref.watch(characterRequestsProvider(live.id)).value : ref.watch(myRequestsProvider).value;
      final reserved = [
        for (final r in requests ?? const <XpRequest>[])
          if (r.characterId == live.id && r.status.open) r,
      ].fold<int>(0, (s, r) => s + r.total);
      final sheet = printSheet(
        version == PrintVersion.frozen ? frozen!.character : live,
        version: version,
        game: game,
        now: now,
        rb: rb,
        items: ref.watch(characterItemsProvider(live.id)).value ?? const [],
        places: ref.watch(characterPlacesProvider(live.id)).value ?? const [],
        bonds: ref.watch(characterBondsProvider(live.id)).value ?? const [],
        reserved: reserved,
        chronicle: ref.watch(chronicleProvider).value?.name ?? '',
      );
      final t = Theme.of(context).textTheme;
      return Padding(
        padding: isWide(context) ? const EdgeInsets.fromLTRB(56, 24, 56, 24) : const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            TextButton(onPressed: () => context.go(widget.basePath), child: Text(live.name)),
            Text('/ Imprimer', style: t.bodySmall),
          ]),
          Text('Imprimer la fiche', style: isWide(context) ? t.displaySmall : t.headlineMedium),
          const SizedBox(height: 12),
          if (game != null && frozen != null) ...[
            Wrap(spacing: 10, runSpacing: 10, children: [
              ChoiceChip(
                key: const Key('print-frozen'),
                label: Text('Version figée · partie du ${shortDay(game.date)}'),
                selected: version == PrintVersion.frozen,
                onSelected: (_) => setState(() => _choice = PrintVersion.frozen),
              ),
              ChoiceChip(
                key: const Key('print-current'),
                label: const Text('Version actuelle · non valable en jeu'),
                selected: version == PrintVersion.current,
                onSelected: (_) => setState(() => _choice = PrintVersion.current),
              ),
            ]),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: loadingFrozen
                ? Center(child: Text('Chargement de la version figée…', style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)))
                : (widget.preview ?? _pdfPreview)(sheet),
          ),
        ]),
      );
    }, onRetry: () => ref.invalidate(characterProvider(widget.characterId)));
  }
}
