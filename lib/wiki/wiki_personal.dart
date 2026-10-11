import '../characters/character.dart';
import '../rulebook/rule_entry.dart';
import '../rulebook/rulebook.dart';
import '../xp/xp_request.dart';
import '../xp/xp_rules.dart';
import 'wiki_rules.dart';

/// Fiches qui personnalisent la lecture du wiki : les PJ actifs du joueur.
List<Character> activeSheets(Iterable<Character> sheets) =>
    [for (final c in sheets) if (c.kind == CharacterKind.pj && c.status == CharacterStatus.active) c];

String dots(int n) => '●' * n;

int disciplineLevel(Character c, String name) => c.disciplines.where((d) => nameKey(d.name) == nameKey(name)).firstOrNull?.level ?? 0;

/// Page de règle de cette catégorie et de ce nom, si elle est lisible.
WikiItem? itemFor(String cat, String? name, List<WikiItem> items) =>
    name == null ? null : items.where((i) => i.cat == cat && nameKey(i.title) == nameKey(name)).firstOrNull;

typedef MineLine = ({String title, String note, WikiItem? item});

/// Lignes du bloc « Pour {nom} » de l'accueil.
List<MineLine> mineLines(Character c, List<WikiItem> items) => [
      for (final d in c.disciplines)
        (title: d.name, note: '${dots(d.level)} · ${d.level == 1 ? 'votre pouvoir' : 'vos ${d.level} pouvoirs'}', item: itemFor('disciplines', d.name, items)),
      if (c.clan case final clan? when clan.trim().isNotEmpty) (title: clan, note: 'votre clan', item: itemFor('clans', clan, items)),
      for (final m in c.merits) (title: m.name, note: 'votre atout', item: itemFor('merits', m.name, items)),
      for (final f in c.flaws) (title: f.name, note: 'votre handicap', item: itemFor('flaws', f.name, items)),
    ];

String _clanWord(Character c, String discipline, Rulebook rb) => inClan(c, discipline, rb: rb) ? 'en clan' : 'hors clan';

int _levelCost(Character c, String discipline, int level, Rulebook rb) =>
    costOf(c, XpItem(XpKind.discipline, discipline, level - 1, level, 0), rb: rb);

typedef NextStep = ({String heading, String? next});

/// Encadré d'une fiche sur la page d'une discipline : niveau, prochain pouvoir et son coût (rien au-delà de 5).
NextStep nextStep(Character c, RuleEntry discipline, Rulebook rb) {
  final level = disciplineLevel(c, discipline.name);
  final heading = level == 0 ? '${c.name} · ${discipline.name} : pas encore apprise' : '${c.name} · ${discipline.name} ${dots(level)}';
  if (level >= 5) return (heading: heading, next: null);
  final power = disciplinePowers(discipline).where((p) => p.level == level + 1 && !p.elder).firstOrNull;
  final cost = _levelCost(c, discipline.name, level + 1, rb);
  return (heading: heading, next: 'Prochain niveau : ${power == null ? '' : '${power.name}, '}$cost XP ${_clanWord(c, discipline.name, rb)}.');
}

/// La fiche a ce pouvoir : niveau atteint (les pouvoirs d'anciens ne se déduisent pas du niveau).
bool owns(Character c, Power p, String discipline) => !p.elder && disciplineLevel(c, discipline) >= p.level;

/// « 9 XP en clan » : coût de ce niveau pour la fiche.
String powerCost(Character c, Power p, String discipline, Rulebook rb) =>
    '${_levelCost(c, discipline, p.level, rb)} XP ${_clanWord(c, discipline, rb)}';

/// Mention d'une carte de discipline : « ●● · en clan » si la fiche la possède.
String? cardMention(Character c, WikiItem i, Rulebook rb) {
  if (i.cat != 'disciplines') return null;
  final level = disciplineLevel(c, i.title);
  return level == 0 ? null : '${dots(level)} · ${_clanWord(c, i.title, rb)}';
}

/// Puce « En clan pour {nom} ».
bool inClanFor(Character c, WikiItem i, Rulebook rb) => i.cat == 'disciplines' && inClan(c, i.title, rb: rb);
