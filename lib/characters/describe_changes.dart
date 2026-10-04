import 'package:collection/collection.dart';

import 'character.dart';

/// Points en pastilles ; 0 s'écrit « — ».
String dots(int n) => n <= 0 ? '—' : '●' * n;

String _v(String? s) => (s == null || s.isEmpty) ? '(vide)' : s;

String? _gen(Character c) =>
    c.genRank == null ? null : '${c.genRank!.label}${c.genNumber == null ? '' : ' (${c.genNumber}e)'}';

/// Résumé lisible des différences, une ligne par changement (historique, fenêtre d'enregistrement).
List<String> describeChanges(Character a, Character b) {
  final out = <String>[];
  void text(String label, String? x, String? y) {
    if ((x ?? '') != (y ?? '')) out.add('$label : ${_v(x)} → ${_v(y)}');
  }

  void number(String label, int x, int y) {
    if (x != y) out.add('$label $x → $y');
  }

  text('Nom', a.name, b.name);
  if (a.status != b.status) out.add('Statut : ${a.status.label} → ${b.status.label}');
  text('Joueur', a.playerName, b.playerName);
  text('Concept', a.concept, b.concept);
  text('Archétype', a.archetype, b.archetype);
  text('Clan', a.clan, b.clan);
  text('Lignée', a.lineage, b.lineage);
  text('Secte', a.sect, b.sect);
  text('Génération', _gen(a), _gen(b));
  text('Sire', a.sire, b.sire);
  text('Titre', a.title, b.title);
  for (final cat in AttrCategory.values) {
    final x = a.attributes[cat]!, y = b.attributes[cat]!;
    number(cat.label, x.value, y.value);
    text('Focus ${cat.label}', x.focus, y.focus);
  }
  _traits(out, a.skills, b.skills);
  _traits(out, a.backgrounds, b.backgrounds);
  _disciplines(out, a.disciplines, b.disciplines);
  _points(out, 'Atout', a.merits, b.merits);
  _points(out, 'Handicap', a.flaws, b.flaws);
  _names(out, 'Rituel', [for (final r in a.rituals) r.name], [for (final r in b.rituals) r.name]);
  _names(out, 'Technique', a.techniques, b.techniques);
  _names(out, 'Pouvoir d’ancien', [for (final e in a.elderPowers) e.name], [for (final e in b.elderPowers) e.name]);
  _servants(out, a.servants, b.servants);
  for (final cat in AttrCategory.values) {
    number('Points bonus ${cat.label}', a.attributeBonus[cat] ?? 0, b.attributeBonus[cat] ?? 0);
  }
  number('Sang', a.blood, b.blood);
  number('Sang par tour', a.bloodPerTurn, b.bloodPerTurn);
  number('Volonté', a.willpower, b.willpower);
  number('Humanité', a.humanity, b.humanity);
  text('Santé', a.health, b.health);
  number('XP initiale', a.xpInitial, b.xpInitial);
  number('Bonus du conte', a.xpBonus, b.xpBonus);
  number('XP gagnée', a.xpEarned, b.xpEarned);
  number('XP dépensée', a.xpSpent, b.xpSpent);
  if ((a.story ?? '') != (b.story ?? '')) out.add('Récit modifié');
  return out;
}

void _traits(List<String> out, List<Trait> a, List<Trait> b) {
  final before = {for (final t in a) t.name: t};
  final after = {for (final t in b) t.name: t};
  for (final t in b) {
    final old = before[t.name];
    if (old == null) {
      out.add('+ ${t.name} ${dots(t.level)}');
      continue;
    }
    if (old.level != t.level) out.add('${t.name} ${dots(old.level)} → ${dots(t.level)}');
    if ((old.note ?? '') != (t.note ?? '')) out.add('${t.name} : ${_v(old.note)} → ${_v(t.note)}');
  }
  for (final t in a) {
    if (!after.containsKey(t.name)) out.add('− ${t.name} ${dots(t.level)}');
  }
}

void _disciplines(List<String> out, List<Discipline> a, List<Discipline> b) {
  final before = {for (final d in a) d.name: d};
  final after = {for (final d in b) d.name: d};
  for (final d in b) {
    final old = before[d.name];
    if (old == null) {
      out.add('+ ${d.name} ${dots(d.level)}');
      continue;
    }
    if (old.level != d.level) out.add('${d.name} ${dots(old.level)} → ${dots(d.level)}');
    if (old.inClan != d.inClan) out.add('${d.name} : ${d.inClan ? 'hors clan → en clan' : 'en clan → hors clan'}');
    if (old.powers.join('|') != d.powers.join('|')) out.add('${d.name} : pouvoirs modifiés');
  }
  for (final d in a) {
    if (!after.containsKey(d.name)) out.add('− ${d.name} ${dots(d.level)}');
  }
}

void _points(List<String> out, String label, List<Trait> a, List<Trait> b) {
  final before = {for (final t in a) t.name: t.level};
  final after = {for (final t in b) t.name: t.level};
  for (final t in b) {
    final old = before[t.name];
    if (old == null) {
      out.add('+ $label ${t.name} (${t.level})');
    } else if (old != t.level) {
      out.add('$label ${t.name} : $old → ${t.level}');
    }
  }
  for (final t in a) {
    if (!after.containsKey(t.name)) out.add('− $label ${t.name} (${t.level})');
  }
}

void _names(List<String> out, String label, List<String> a, List<String> b) {
  for (final n in b) {
    if (!a.contains(n)) out.add('+ $label $n');
  }
  for (final n in a) {
    if (!b.contains(n)) out.add('− $label $n');
  }
}

void _servants(List<String> out, List<Servant> a, List<Servant> b) {
  final before = {for (final s in a) s.id: s};
  final after = {for (final s in b) s.id: s};
  for (final s in b) {
    final old = before[s.id];
    if (old == null) {
      out.add('+ Serviteur ${s.name} ${dots(s.rank)}');
      continue;
    }
    if (old.name != s.name) out.add('Serviteur : ${old.name} → ${s.name}');
    if (old.kind != s.kind) out.add('Serviteur ${s.name} : ${old.kind.label} → ${s.kind.label}');
    if (old.rank != s.rank) out.add('Serviteur ${s.name} ${dots(old.rank)} → ${dots(s.rank)}');
  }
  for (final s in a) {
    if (!after.containsKey(s.id)) out.add('− Serviteur ${s.name} ${dots(s.rank)}');
  }
}

/// Ligne d'historique de la conversion de l'ancien historique « Serviteurs », à sa première écriture.
List<String> withConversion(Character c, List<String> summary) =>
    c.legacyServants ? [...summary, 'Historique « Serviteurs » converti en serviteur'] : summary;

Map<String, int> xpDelta(Character a, Character b) => {
      'initial': b.xpInitial - a.xpInitial,
      'earned': b.xpEarned - a.xpEarned,
      'spent': b.xpSpent - a.xpSpent,
    };

/// Réapplique sur [incoming] les champs que [draft] a changés par rapport à [base].
/// Granularité : le champ de premier niveau (une liste modifiée des deux côtés garde la version locale).
Character rebase(Character base, Character draft, Character incoming) {
  const eq = DeepCollectionEquality();
  final b = base.toMap(), d = draft.toMap(), n = incoming.toMap();
  final merged = {for (final k in {...n.keys, ...d.keys}) k: eq.equals(b[k], d[k]) ? n[k] : d[k]}
    ..['version'] = n['version']
    ..['lastHistoryId'] = n['lastHistoryId'];
  return Character.fromMap(incoming.id, merged)
    ..createdAt = incoming.createdAt
    ..updatedAt = incoming.updatedAt;
}
