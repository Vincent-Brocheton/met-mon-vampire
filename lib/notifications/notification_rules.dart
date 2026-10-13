import '../auth/session.dart';
import '../characters/character.dart';
import '../core/dates.dart';
import '../games/game.dart';
import '../games/game_rules.dart';
import '../npcs/npc_loan.dart';
import '../wiki/wiki_page.dart';
import '../xp/xp_request.dart';

enum NotifKind { access, requests, review, wiki, decided, xp, freeze, npc }

/// Notification calculée : rien n'est stocké, chaque ligne vient d'une donnée que l'application tient déjà.
class AppNotification {
  const AppNotification({required this.kind, required this.title, required this.detail, required this.at, required this.link});
  final NotifKind kind;
  final String title;
  final String detail;
  final DateTime at;
  final String link;
}

/// Durée du fil, en jours.
const feedDays = 60;

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// ---- Conte ----

List<AppNotification> accessRequests(List<AppUser> pending) => [
      for (final u in pending)
        if (u.createdAt case final at?)
          AppNotification(
            kind: NotifKind.access,
            title: 'Demande d’accès : ${u.displayName}',
            detail: (u.accessMessage ?? '').trim().isEmpty ? 'Nouveau compte en attente.' : '« ${u.accessMessage!.trim()} »',
            at: at,
            link: '/conteur/comptes',
          ),
    ];

/// Une seule ligne pour toutes les demandes en attente, datée de la plus récente.
List<AppNotification> pendingSummary(List<XpRequest> pending) {
  final dates = [for (final r in pending) ?r.date];
  if (dates.isEmpty) return const [];
  final n = pending.length;
  return [
    AppNotification(
      kind: NotifKind.requests,
      title: n == 1 ? '1 demande à traiter' : '$n demandes à traiter',
      detail: 'Dépenses d’XP et demandes en attente.',
      at: dates.reduce((a, b) => a.isAfter(b) ? a : b),
      link: '/conteur/demandes',
    ),
  ];
}

List<AppNotification> reviewQueue(List<Character> sheets) => [
      for (final c in sheets)
        if (c.submittedAt case final at?)
          AppNotification(
            kind: NotifKind.review,
            title: '${c.name} : fiche soumise à validation',
            detail: (c.playerName ?? '').isEmpty ? 'Fiche en attente de validation.' : 'Joueur : ${c.playerName}',
            at: at,
            link: '/conteur/demandes',
          ),
    ];

/// Pages publiées par un autre membre du conte que le lecteur [uid].
List<AppNotification> wikiByOthers(List<WikiPage> pages, String uid) => [
      for (final p in pages)
        if (p.updatedAt case final at? when p.updatedByUid != null && p.updatedByUid != uid)
          AppNotification(
            kind: NotifKind.wiki,
            title: '${p.updatedByName ?? 'Un conteur'} a publié une page du wiki',
            detail: '« ${p.title} », version ${p.version}.',
            at: at,
            link: '/conteur/wiki/edition/${p.id}/historique',
          ),
    ];

// ---- Joueur ----

List<AppNotification> decidedRequests(List<XpRequest> mine) => [
      for (final r in mine)
        if (r.decidedAt case final at? when r.status == RequestStatus.accepted || r.status == RequestStatus.rejected)
          r.status == RequestStatus.accepted
              ? AppNotification(
                  kind: NotifKind.decided, title: 'Une demande a été validée', detail: '${r.characterName} · la fiche est à jour.', at: at, link: '/joueur/demandes')
              : AppNotification(
                  kind: NotifKind.decided,
                  title: 'Une demande a été refusée',
                  detail: 'Le conte a laissé un motif. Votre XP réservée vous est rendue.',
                  at: at,
                  link: '/joueur/demandes',
                ),
    ];

/// Entrées d'historique de la fiche qui ajoutent de l'XP gagnée (gain mensuel, attribution).
List<AppNotification> xpReceived(Character c, List<HistoryEntry> history) => [
      for (final e in history)
        if (e.at case final at? when e.xpEarned > 0)
          AppNotification(kind: NotifKind.xp, title: 'XP reçue : +${e.xpEarned}', detail: c.name, at: at, link: '/joueur/personnages/${c.id}/historique'),
    ];

/// Parties dont le gel est en cours (ni levé, ni dépassé) et fige au moins une des fiches [mine].
List<AppNotification> freeze(List<Game> games, DateTime now, List<String> mine) => [
      for (final g in games)
        if (isRunning(g, now) && g.sheetIds.any(mine.contains))
          AppNotification(
            kind: NotifKind.freeze,
            title: 'Fiches figées pour la partie du ${formatDay(g.date)}',
            detail: 'Jusqu’au ${formatDay(g.until)} à ${_hm(g.until)}, vos demandes restent en attente.',
            at: g.frozenAt,
            link: '/joueur/personnages',
          ),
    ];

List<AppNotification> npcLoans(List<NpcLoan> loans) => [
      for (final l in loans)
        if (l.revokedAt == null)
          AppNotification(kind: NotifKind.npc, title: 'Un PNJ vous a été confié', detail: l.characterName, at: l.createdAt ?? l.from, link: '/joueur/pnj/${l.id}'),
    ];

/// Pages lisibles par le joueur (la requête du wiki les filtre déjà).
List<AppNotification> wikiForPlayer(List<WikiPage> pages) => [
      for (final p in pages)
        if (p.updatedAt case final at?)
          AppNotification(
            kind: NotifKind.wiki,
            title: p.version <= 1 ? 'Nouvelle page du wiki' : 'Page du wiki mise à jour',
            detail: '« ${p.title} »',
            at: at,
            link: '/joueur/wiki/page/${p.id}',
          ),
    ];

// ---- Fil ----

/// Les [feedDays] derniers jours, du plus récent au plus ancien.
List<AppNotification> feed(List<AppNotification> items, {required DateTime now}) {
  final cutoff = now.subtract(const Duration(days: feedDays));
  return [for (final i in items) if (i.at.isAfter(cutoff)) i]..sort((a, b) => b.at.compareTo(a.at));
}

/// Non lue : plus récente que la dernière visite (toutes, sans visite).
bool isUnread(AppNotification n, DateTime? seenAt) => seenAt == null || n.at.isAfter(seenAt);

int unreadCount(List<AppNotification> items, DateTime? seenAt) => items.where((n) => isUnread(n, seenAt)).length;
