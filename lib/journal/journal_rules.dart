import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/session.dart';
import '../characters/character_repository.dart' show Actor;
import '../core/dates.dart';
import '../games/game.dart';
import '../rulebook/rule_entry.dart';
import '../rulebook/schema.dart';

/// Catégories du journal ; le nom est la valeur stockée (`journal.cat`) pour `rules` et `accounts`.
enum JournalCat {
  sheets('Fiches'),
  xp('XP'),
  wiki('Wiki'),
  rules('Référentiel'),
  accounts('Comptes et rôles');

  const JournalCat(this.label);
  final String label;
}

enum JournalPeriod {
  days30('30 derniers jours'),
  sinceGame('Depuis la dernière partie'),
  all('Tout');

  const JournalPeriod(this.label);
  final String label;
}

String _who(String? name) => (name ?? '').trim().isEmpty ? 'Inconnu' : name!.trim();

/// Une ligne du journal : calculée (historiques, wiki, parties) ou lue dans `journal/{id}`.
class JournalLine {
  const JournalLine({required this.cat, required this.at, required this.who, required this.action, required this.target, required this.detail, this.link});

  /// L'heure est celle du serveur : absente de l'écho local de l'écriture, on prend celle de l'appareil.
  factory JournalLine.fromMap(Map<String, dynamic> m) => JournalLine(
        cat: JournalCat.values.asNameMap()[m['cat']] ?? JournalCat.accounts,
        at: (m['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        who: _who(m['byName'] as String?),
        action: m['action'] as String? ?? '',
        target: m['target'] as String? ?? '',
        detail: m['detail'] as String? ?? '',
        link: m['link'] as String?,
      );

  final JournalCat cat;
  final DateTime at;
  final String who;
  final String action;
  final String target;
  final String detail;

  /// Chemin de l'application ; null si l'élément n'est plus connu.
  final String? link;
}

/// Entrée d'historique lue par groupe de collections : `{col}/{parentId}/history/{h}`.
class RawHistory {
  const RawHistory({required this.col, required this.parentId, required this.at, required this.byName, required this.kind, required this.summary, required this.reason});
  final String col;
  final String parentId;
  final DateTime at;
  final String byName;
  final String kind;
  final List<String> summary;
  final String reason;
}

/// Version publiée d'une page du wiki : `wiki/{pageId}/versions/{n}`.
class RawVersion {
  const RawVersion({required this.pageId, required this.n, required this.title, required this.note, required this.byName, required this.at});
  final String pageId;
  final int n;
  final String title;
  final String note;
  final String byName;
  final DateTime at;
}

// ---- Lignes calculées ----

/// Écrites par le joueur : le journal trace les actes du conte.
const _playerKinds = {'submission', 'withdrawal'};
const _xpKinds = {'gain', 'award', 'xp', 'correction', 'bonus'};
const _kindLabels = {
  'edit': 'Modification',
  'status': 'Changement de statut',
  'validation': 'Validation',
  'corrections': 'Corrections demandées',
  'rejection': 'Fiche refusée',
  'embrace': 'Étreinte',
  'award': 'XP attribuée',
  'xp': 'Dépense d’XP',
  'correction': 'Correction d’XP',
  'bonus': 'Bonus du conte',
};

/// Collections qui ont un historique : (nom par défaut, liste du conte ; null pour une fiche).
const Map<String, (String, String?)> _owners = {
  'characters': ('Fiche', null),
  'places': ('Lieu', '/conteur/lieux'),
  'items': ('Objet', '/conteur/objets'),
  'allies': ('Allié', '/conteur/allies'),
  'servants': ('Goule ou serviteur', '/conteur/goules'),
};

String _detail(List<String> summary, String reason) => [...summary, if (reason.trim().isNotEmpty) 'Motif : ${reason.trim()}'].join(' ; ');

/// [names] : nom de chaque élément, par clé `'{col}/{id}'`.
/// Le gain mensuel écrit un lot par fiche : ses entrées sont regroupées par motif (le mois) et par auteur.
List<JournalLine> historyLines(List<RawHistory> rows, Map<String, String> names) {
  final out = <JournalLine>[];
  final gains = <(String, String), List<RawHistory>>{};
  for (final r in rows) {
    final owner = _owners[r.col];
    if (owner == null) continue;
    final sheet = r.col == 'characters';
    if (sheet && _playerKinds.contains(r.kind)) continue;
    if (sheet && r.kind == 'gain') {
      (gains[(r.reason, r.byName)] ??= []).add(r);
      continue;
    }
    final name = names['${r.col}/${r.parentId}'];
    out.add(JournalLine(
      cat: sheet && _xpKinds.contains(r.kind) ? JournalCat.xp : JournalCat.sheets,
      at: r.at,
      who: _who(r.byName),
      action: sheet ? _kindLabels[r.kind] ?? 'Modification' : owner.$1,
      target: name ?? owner.$1,
      detail: _detail(r.summary, r.reason),
      link: name == null ? null : (sheet ? '/conteur/fiches/${r.parentId}/historique' : owner.$2),
    ));
  }
  for (final g in gains.values) {
    out.add(JournalLine(
      cat: JournalCat.xp,
      at: g.map((r) => r.at).reduce((a, b) => a.isAfter(b) ? a : b),
      who: _who(g.first.byName),
      action: 'Gain mensuel',
      target: g.length == 1 ? '1 fiche' : '${g.length} fiches',
      detail: 'XP ajoutée selon le palier de chaque fiche',
    ));
  }
  return out;
}

/// [pageIds] : pages encore publiées (les autres n'ont pas de lien).
List<JournalLine> versionLines(List<RawVersion> versions, Set<String> pageIds) => [
      for (final v in versions)
        JournalLine(
          cat: JournalCat.wiki,
          at: v.at,
          who: _who(v.byName),
          action: 'Wiki',
          target: 'Page « ${v.title} »',
          detail: v.note.trim().isEmpty ? 'Version ${v.n} publiée' : 'Version ${v.n} publiée : ${v.note.trim()}',
          link: pageIds.contains(v.pageId) ? '/conteur/wiki/edition/${v.pageId}/historique' : null,
        ),
    ];

String _two(int n) => n.toString().padLeft(2, '0');
String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// [userNames] : nom affiché par uid.
List<JournalLine> gameLines(List<Game> games, Map<String, String> userNames) => [
      for (final g in games) ...[
        JournalLine(
          cat: JournalCat.sheets,
          at: g.frozenAt,
          who: _who(userNames[g.byUid]),
          action: 'Gel des fiches',
          target: 'Partie du ${formatDay(g.date)}',
          detail: 'Fiches figées jusqu’au ${formatDay(g.until)} à ${_hm(g.until)}',
          link: '/conteur/gel',
        ),
        if (g.liftedAt case final at?)
          JournalLine(
            cat: JournalCat.sheets,
            at: at,
            who: _who(userNames[g.liftedByUid]),
            action: 'Gel levé',
            target: 'Partie du ${formatDay(g.date)}',
            detail: 'Fiches rendues aux joueurs',
            link: '/conteur/gel',
          ),
      ],
    ];

// ---- Fil ----

/// Lignes depuis [since] (toutes si null), de la plus récente à la plus ancienne.
List<JournalLine> mergeLines(Iterable<List<JournalLine>> sources, DateTime? since) => [
      for (final s in sources)
        for (final l in s)
          if (since == null || !l.at.isBefore(since)) l,
    ]..sort((a, b) => b.at.compareTo(a.at));

List<JournalLine> filterLines(List<JournalLine> lines, {JournalCat? cat, String? author}) => [
      for (final l in lines)
        if ((cat == null || l.cat == cat) && (author == null || l.who == author)) l,
    ];

List<String> authorsOf(List<JournalLine> lines) => {for (final l in lines) l.who}.toList()..sort();

/// Jour de la dernière partie déjà jouée (ou du jour même) ; null s'il n'y en a pas.
DateTime? lastGameDay(List<Game> games, DateTime now) {
  final past = [for (final g in games) if (!g.date.isAfter(now)) g.date];
  return past.isEmpty ? null : past.reduce((a, b) => a.isAfter(b) ? a : b);
}

/// Début de la période ; null : tout. Au jour près, pour que la clé du provider reste stable.
DateTime? periodStart(JournalPeriod p, DateTime now, List<Game> games) {
  final days30 = DateTime(now.year, now.month, now.day - 30);
  return switch (p) {
    JournalPeriod.days30 => days30,
    JournalPeriod.sinceGame => lastGameDay(games, now) ?? days30,
    JournalPeriod.all => null,
  };
}

/// « 29 sept. · 20:00 ».
String journalStamp(DateTime d) => '${formatDay(d)} · ${_hm(d)}';

String _cell(String s) => s.contains(RegExp('[;"\n\r]')) ? '"${s.replaceAll('"', '""')}"' : s;

/// CSV « ; » des lignes, avec la date complète.
String toCsv(List<JournalLine> lines) => [
      'Quand;Qui;Action;Sur;Détail',
      for (final l in lines)
        ['${l.at.year}-${_two(l.at.month)}-${_two(l.at.day)} ${_hm(l.at)}', l.who, l.action, l.target, l.detail].map(_cell).join(';'),
    ].join('\n');

// ---- Écritures (`journal/{id}`) ----

/// Ce qu'une action écrit dans le journal ; l'auteur et l'heure s'ajoutent à l'écriture.
typedef JournalNote = ({JournalCat cat, String action, String target, String detail, String? link});

String _catLabel(String cat) => categoryById(cat)?.label ?? cat;
String _ruleTarget(String cat, RuleEntry e) => '« ${e.name} » · ${_catLabel(cat)}';

/// [before] : la version précédente ; null pour une création.
JournalNote ruleSaveNote(String cat, RuleEntry? before, RuleEntry after) => (
      cat: JournalCat.rules,
      action: 'Référentiel',
      target: _ruleTarget(cat, after),
      detail: before == null
          ? 'Créée'
          : before.state != after.state
              ? '${before.state.label} → ${after.state.label}'
              : 'Modifiée',
      link: '/conteur/referentiel/$cat',
    );

JournalNote ruleDeleteNote(String cat, RuleEntry e) =>
    (cat: JournalCat.rules, action: 'Référentiel', target: _ruleTarget(cat, e), detail: 'Supprimée', link: null);

JournalNote ruleImportNote(String cat, int n) => (
      cat: JournalCat.rules,
      action: 'Référentiel',
      target: _catLabel(cat),
      detail: n == 1 ? 'Import : 1 entrée' : 'Import : $n entrées',
      link: '/conteur/referentiel/$cat',
    );

JournalNote roleNote(AppUser u, Role to) =>
    (cat: JournalCat.accounts, action: 'Rôle', target: u.displayName, detail: '${u.role.label} → ${to.label}', link: '/conteur/comptes');

/// Sans lien : l'écran Équipe est réservé au principal, le conteur lit aussi le journal.
JournalNote inviteNote(String email, Role role) =>
    (cat: JournalCat.accounts, action: 'Invitation', target: email.trim().toLowerCase(), detail: role.label, link: null);

JournalNote inviteCancelNote(String email) => (cat: JournalCat.accounts, action: 'Invitation', target: email, detail: 'Annulée', link: null);

String _clip(String s, int max) => s.length <= max ? s : '${s.substring(0, max - 1)}…';

/// Document `journal/{id}` : clés exactes, tailles et auteur contrôlés par les règles, heure du serveur.
Map<String, dynamic> journalData(JournalNote n, Actor by) => {
      'cat': n.cat.name,
      'action': _clip(n.action, 80),
      'target': _clip(n.target, 120),
      'detail': _clip(n.detail, 300),
      if (n.link != null) 'link': n.link,
      'byUid': by.uid,
      'byName': _clip(by.name, 60),
      'at': FieldValue.serverTimestamp(),
    };
