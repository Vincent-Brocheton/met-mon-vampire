import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../auth/session_providers.dart';
import '../chronicle/chronicle_repository.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class Destination {
  const Destination(this.label, this.path, this.icon, {this.shortLabel, this.iconOnly = false, this.mobileTab = false});

  final String label;
  final String path;
  final IconData icon;

  /// Libellé de la barre d'onglets mobile.
  final String? shortLabel;

  /// Icône seule dans l'en-tête (Web) ou la barre du haut (Mobile).
  final bool iconOnly;

  /// Onglet de la barre du bas (Mobile). Les autres vont dans « Plus ».
  final bool mobileTab;
}

List<Destination> destinationsFor(Role role) => role == Role.joueur
    ? const [
        Destination('Accueil', '/joueur', Icons.home_outlined, mobileTab: true),
        Destination('Mes personnages', '/joueur/personnages', Icons.person_outline, shortLabel: 'Personnages', mobileTab: true),
        Destination('PNJ confiés', '/joueur/pnj', Icons.theater_comedy_outlined, shortLabel: 'PNJ', mobileTab: true),
        Destination('La Cour', '/joueur/cour', Icons.account_balance_outlined),
        Destination('Mes demandes', '/joueur/demandes', Icons.inbox_outlined, shortLabel: 'Demandes', mobileTab: true),
        Destination('Wiki', '/joueur/wiki', Icons.menu_book_outlined, mobileTab: true),
        Destination('Notifications', '/joueur/notifications', Icons.notifications_none, iconOnly: true),
      ]
    : [
        const Destination('Tableau de bord', '/conteur', Icons.dashboard_outlined, shortLabel: 'Tableau', mobileTab: true),
        const Destination('Fiches', '/conteur/fiches', Icons.folder_open_outlined, mobileTab: true),
        const Destination('Demandes', '/conteur/demandes', Icons.inbox_outlined, mobileTab: true),
        Destination('PNJ confiés', '/conteur/pnj', Icons.theater_comedy_outlined,
            shortLabel: 'PNJ', mobileTab: !role.managesAccounts),
        const Destination('XP', '/conteur/xp', Icons.auto_awesome_outlined),
        const Destination('La Cour', '/conteur/cour', Icons.account_balance_outlined),
        if (role.managesAccounts) const Destination('Comptes', '/conteur/comptes', Icons.group_outlined, mobileTab: true),
        const Destination('Wiki', '/conteur/wiki', Icons.menu_book_outlined),
        const Destination('Référentiel des règles', '/conteur/referentiel', Icons.library_books_outlined, iconOnly: true),
        const Destination('Paramètres de la chronique', '/conteur/parametres', Icons.settings_outlined, iconOnly: true),
        const Destination('Notifications', '/conteur/notifications', Icons.notifications_none, iconOnly: true),
      ];

/// Destination active : la plus longue dont le chemin préfixe [location].
int? selectedIndex(List<Destination> items, String location) {
  int? best;
  for (var i = 0; i < items.length; i++) {
    final p = items[i].path;
    final hit = location == p || location.startsWith('$p/');
    if (hit && (best == null || p.length > items[best].path.length)) best = i;
  }
  return best;
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final role = user?.role ?? Role.joueur;
    final title = ref.watch(chronicleProvider).value?.displayName ?? 'Portail MET';
    final pending = role.managesAccounts ? ref.watch(pendingUsersProvider).value?.length ?? 0 : 0;
    final items = destinationsFor(role);
    final data = _ShellData(
      title: title,
      user: user,
      items: items,
      selected: selectedIndex(items, location),
      pending: pending,
    );
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= kWideBreakpoint ? _WideShell(data, child) : _NarrowShell(data, child),
    );
  }
}

class _ShellData {
  const _ShellData({required this.title, required this.user, required this.items, required this.selected, required this.pending});
  final String title;
  final AppUser? user;
  final List<Destination> items;
  final int? selected;
  final int pending;

  bool isSelected(Destination d) => selected != null && items[selected!] == d;
  int badgeFor(Destination d) => d.path == '/conteur/comptes' ? pending : 0;
}

class _WideShell extends StatelessWidget {
  const _WideShell(this.data, this.child);
  final _ShellData data;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final nav = data.items.where((d) => !d.iconOnly);
    final icons = data.items.where((d) => d.iconOnly);
    return Scaffold(
      body: Column(children: [
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            const DropLogo(),
            const SizedBox(width: 10),
            Text(data.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(width: 32),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final d in nav) _NavButton(d, selected: data.isSelected(d), badge: data.badgeFor(d)),
                ]),
              ),
            ),
            for (final d in icons)
              IconButton(
                tooltip: d.label,
                onPressed: () => context.go(d.path),
                icon: Icon(d.icon, color: data.isSelected(d) ? AppColors.text : AppColors.textSecondary),
              ),
            const SizedBox(width: 8),
            _AccountButton(data.user),
          ]),
        ),
        Expanded(child: child),
      ]),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton(this.d, {required this.selected, required this.badge});
  final Destination d;
  final bool selected;
  final int badge;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: TextButton(
          onPressed: () => context.go(d.path),
          style: TextButton.styleFrom(
            backgroundColor: selected ? AppColors.navActive : null,
            foregroundColor: selected ? AppColors.text : AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(d.label),
            if (badge > 0) ...[
              const SizedBox(width: 8),
              Badge(label: Text('$badge'), backgroundColor: AppColors.accent),
            ],
          ]),
        ),
      );
}

class _AccountButton extends StatelessWidget {
  const _AccountButton(this.user, {this.compact = false});
  final AppUser? user;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final staff = u?.role.isStaff ?? false;
    final avatar = CircleAvatar(
      radius: compact ? 16 : 20,
      backgroundColor: staff ? AppColors.staffAvatar : AppColors.border,
      child: Text(initialsOf(u?.displayName ?? ''),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
    );
    return Semantics(
      button: true,
      label: 'Mon compte',
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.go('/compte'),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: compact || u == null
              ? avatar
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  avatar,
                  const SizedBox(width: 12),
                  Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    if (staff) Text(u.role.label, style: TextStyle(fontSize: 13, color: roleColor(u.role))),
                  ]),
                ]),
        ),
      ),
    );
  }
}

class _NarrowShell extends StatelessWidget {
  const _NarrowShell(this.data, this.child);
  final _ShellData data;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tabs = data.items.where((d) => d.mobileTab).toList();
    final more = data.items.where((d) => !d.mobileTab && !d.iconOnly).toList();
    final icons = data.items.where((d) => d.iconOnly);
    final current = tabs.indexWhere(data.isSelected);
    final inMore = more.any(data.isSelected);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(children: [
          const DropLogo(size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(data.title, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall)),
        ]),
        actions: [
          for (final d in icons) IconButton(tooltip: d.label, onPressed: () => context.go(d.path), icon: Icon(d.icon)),
          _AccountButton(data.user, compact: true),
          const SizedBox(width: 12),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: current >= 0 ? current : (inMore ? tabs.length : 0),
        onDestinationSelected: (i) => i < tabs.length ? context.go(tabs[i].path) : _showMore(context, more),
        destinations: [
          for (final d in tabs)
            NavigationDestination(
              icon: Badge(
                isLabelVisible: data.badgeFor(d) > 0,
                label: Text('${data.badgeFor(d)}'),
                backgroundColor: AppColors.accent,
                child: Icon(d.icon),
              ),
              label: d.shortLabel ?? d.label,
            ),
          if (more.isNotEmpty) const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Plus'),
        ],
      ),
    );
  }

  void _showMore(BuildContext context, List<Destination> more) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.card,
        builder: (sheet) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final d in more)
              ListTile(
                leading: Icon(d.icon),
                title: Text(d.label),
                onTap: () {
                  Navigator.pop(sheet);
                  context.go(d.path);
                },
              ),
          ]),
        ),
      );
}
