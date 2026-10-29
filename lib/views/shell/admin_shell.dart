import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/profile.dart';
import '../../viewmodels/session_viewmodel.dart';

class _NavItem {
  const _NavItem(
      this.label, this.path, this.icon, this.selectedIcon, this.visible);
  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final bool Function(AdminSession) visible;
}

final _items = <_NavItem>[
  _NavItem('Dashboard', '/dashboard', Icons.dashboard_outlined, Icons.dashboard,
      (_) => true),
  _NavItem('Notices', '/notices', Icons.campaign_outlined, Icons.campaign,
      (s) => s.can(Perm.noticeView)),
  _NavItem('Requests', '/requests', Icons.inbox_outlined, Icons.inbox,
      (s) => s.can(Perm.requestView)),
  _NavItem('Alumni', '/alumni', Icons.verified_user_outlined,
      Icons.verified_user, (_) => true),
  _NavItem('History', '/history', Icons.history, Icons.history,
      (s) => s.can(Perm.requestView)),
  _NavItem('Reports', '/reports', Icons.assessment_outlined, Icons.assessment,
      (s) => s.can(Perm.reportView)),
  _NavItem('Tariffs', '/tariffs', Icons.receipt_long_outlined,
      Icons.receipt_long, (s) => s.can(Perm.requestView)),
  _NavItem(
      'Administration',
      '/admin',
      Icons.admin_panel_settings_outlined,
      Icons.admin_panel_settings,
      (s) => s.can(Perm.adminManage) || s.can(Perm.configManage)),
];

/// Adaptive navigation: bottom bar (mobile), collapsible rail (tablet),
/// persistent sidebar + top app bar (desktop/web).
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  bool _railExtended = false;

  int _indexOf(List<_NavItem> items) {
    for (var i = 0; i < items.length; i++) {
      final p = items[i].path;
      if (widget.location == p || widget.location.startsWith('$p/')) return i;
    }
    return 0;
  }

  Future<void> _signOut() => ref.read(sessionProvider.notifier).signOut();

  void _showMore(List<_NavItem> secondary) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final i in secondary)
            ListTile(
              leading: Icon(i.icon),
              title: Text(i.label),
              onTap: () {
                Navigator.pop(ctx);
                context.go(i.path);
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () {
              Navigator.pop(ctx);
              _signOut();
            },
          ),
        ]),
      ),
    );
  }

  PreferredSizeWidget _appBar(AdminSession session, String title,
      {bool showBrand = false}) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(children: [
        if (showBrand) ...[
          const BrandMark(size: 32, onDark: false),
          const SizedBox(width: 10)
        ],
        Flexible(
          child: Text(title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Account',
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.navy,
            child: Text(
              session.profile.fullName.isEmpty
                  ? '?'
                  : session.profile.fullName[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          onSelected: (v) {
            if (v == 'out') _signOut();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.profile.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(session.profile.role.label,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ]),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'out', child: Text('Sign out')),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).valueOrNull;
    if (session == null) return const SizedBox.shrink();
    final items = _items.where((i) => i.visible(session)).toList();
    final index = _indexOf(items);
    final title = items[index].label;
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 1100) {
      return Scaffold(
        body: Row(children: [
          _Sidebar(
            items: items,
            selected: index,
            session: session,
            onSelect: (i) => context.go(items[i].path),
            onSignOut: _signOut,
          ),
          Expanded(
            child: Scaffold(
              appBar: _appBar(session, title),
              body: widget.child,
            ),
          ),
        ]),
      );
    }

    if (width >= 700) {
      return Scaffold(
        appBar: _appBar(session, title, showBrand: true),
        body: Row(children: [
          NavigationRail(
            extended: _railExtended,
            selectedIndex: index,
            labelType: _railExtended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: IconButton(
              tooltip: _railExtended ? 'Collapse' : 'Expand',
              icon: Icon(_railExtended ? Icons.menu_open : Icons.menu),
              onPressed: () => setState(() => _railExtended = !_railExtended),
            ),
            onDestinationSelected: (i) => context.go(items[i].path),
            destinations: [
              for (final i in items)
                NavigationRailDestination(
                    icon: Icon(i.icon),
                    selectedIcon: Icon(i.selectedIcon),
                    label: Text(i.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ]),
      );
    }

    // Mobile: first four on the bottom bar, rest under "More".
    final primary = items.take(4).toList();
    final secondary = items.skip(4).toList();
    final onMore = index >= primary.length;
    return Scaffold(
      appBar: _appBar(session, title, showBrand: true),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: onMore ? primary.length : index,
        onDestinationSelected: (i) {
          if (i == primary.length) {
            _showMore(secondary);
          } else {
            context.go(primary[i].path);
          }
        },
        destinations: [
          for (final i in primary)
            NavigationDestination(
                icon: Icon(i.icon),
                selectedIcon: Icon(i.selectedIcon),
                label: i.label),
          const NavigationDestination(
              icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selected,
    required this.session,
    required this.onSelect,
    required this.onSignOut,
  });

  final List<_NavItem> items;
  final int selected;
  final AdminSession session;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppColors.navy,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Row(children: [
              const BrandMark(size: 44),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'IIT (ISM) Dhanbad\nInstitutional Admin',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.25),
                ),
              ),
            ]),
          ),
          Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              color: AppColors.gold),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: ListTile(
                dense: true,
                selected: i == selected,
                selectedTileColor: AppColors.navyLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: i == selected
                      ? BorderSide(
                          color: AppColors.gold.withAlpha(90), width: 1)
                      : BorderSide.none,
                ),
                leading: Icon(
                    i == selected ? items[i].selectedIcon : items[i].icon,
                    color: i == selected ? AppColors.gold : Colors.white70),
                title: Text(items[i].label,
                    style: TextStyle(
                        color: i == selected ? Colors.white : Colors.white70,
                        fontWeight:
                            i == selected ? FontWeight.w700 : FontWeight.w500)),
                onTap: () => onSelect(i),
              ),
            ),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navyDark.withAlpha(140),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.gold,
                  child: Text(
                    session.profile.fullName.isEmpty
                        ? '?'
                        : session.profile.fullName[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.navyDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.profile.fullName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        session.profile.role.label,
                        style: const TextStyle(
                            color: AppColors.gold, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  icon:
                      const Icon(Icons.logout, size: 18, color: Colors.white70),
                  onPressed: onSignOut,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
