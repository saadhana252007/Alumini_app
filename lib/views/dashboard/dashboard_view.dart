import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardProvider);
    final session = ref.session;
    final name = session?.profile.fullName ?? '';

    return PageScaffold(
      title: 'Welcome${name.isEmpty ? '' : ', ${name.split(' ').first}'}',
      subtitle: '${session?.profile.role.label ?? ''} - live institutional overview',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(dashboardProvider),
        ),
      ],
      child: AsyncBody(
        value: data,
        onRetry: () => ref.invalidate(dashboardProvider),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _QuickActions(ref: ref),
              const SizedBox(height: 14),
              _StatGrid(stats: d.stats, ref: ref),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth > 820;
                final left = Column(children: [
                  if (ref.can(Perm.noticeView))
                    SectionCard(
                      title: 'Published notices',
                      trailing: TextButton(
                          onPressed: () => context.go('/notices'), child: const Text('View all')),
                      child: d.notices.isEmpty
                          ? const EmptyView(message: 'No published notices.', icon: Icons.campaign_outlined)
                          : Column(children: [
                              for (final n in d.notices)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.campaign_outlined, color: AppColors.gold),
                                  title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text('${n.category} - ${fmtDate(n.publishDate)}'),
                                ),
                            ]),
                    ),
                  if (ref.can(Perm.requestView))
                    SectionCard(
                      title: 'Upcoming arrivals',
                      child: d.arrivals.isEmpty
                          ? const EmptyView(message: 'No approved arrivals scheduled.', icon: Icons.luggage_outlined)
                          : Column(children: [
                              for (final r in d.arrivals)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  onTap: () => context.go('/requests/${r.id}'),
                                  leading: const Icon(Icons.login, color: AppColors.success),
                                  title: Text(r.visitorName),
                                  subtitle: Text(
                                      '${r.reference} - ${roomTypes[r.roomType]} - ${fmtDateTime(r.arrivalAt)}'),
                                ),
                            ]),
                    ),
                ]);
                final right = ref.can(Perm.reportView)
                    ? SectionCard(
                        title: 'Recent activity',
                        child: d.activity.isEmpty
                            ? const EmptyView(message: 'No activity recorded yet.', icon: Icons.timeline)
                            : Column(children: [
                                for (final a in d.activity)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    leading: const Icon(Icons.circle, size: 10, color: AppColors.gold),
                                    title: Text(a.description),
                                    subtitle: Text('${a.actorName ?? 'System'} - ${fmtDateTime(a.createdAt)}'),
                                  ),
                              ]),
                      )
                    : const SizedBox.shrink();
                if (!wide) return Column(children: [left, right]);
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: left),
                  const SizedBox(width: 14),
                  Expanded(child: right),
                ]);
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (ref.can(Perm.requestCreate))
        FilledButton.icon(
            onPressed: () => context.go('/requests/new'),
            icon: const Icon(Icons.add),
            label: const Text('New requisition')),
      if (ref.can(Perm.requestView))
        OutlinedButton.icon(
            onPressed: () => context.go('/requests'),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Review requests')),
      if (ref.can(Perm.noticeManage))
        OutlinedButton.icon(
            onPressed: () => context.go('/notices/new'),
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload notice')),
      if (ref.can(Perm.reportView))
        OutlinedButton.icon(
            onPressed: () => context.go('/reports'),
            icon: const Icon(Icons.download),
            label: const Text('Reports & exports')),
    ];
    return Wrap(spacing: 10, runSpacing: 10, children: actions);
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats, required this.ref});
  final Map<String, int> stats;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cards = <_Stat>[
      if (ref.can(Perm.noticeView))
        _Stat('Published notices', stats['published_notices'] ?? 0, Icons.campaign, AppColors.navy, '/notices'),
      if (ref.can(Perm.requestView)) ...[
        _Stat('Pending requests', stats['pending'] ?? 0, Icons.hourglass_top, AppColors.warning, '/requests'),
        if (ref.can(Perm.requestDecide))
          _Stat('Awaiting my decision', stats['awaiting_my_decision'] ?? 0, Icons.gavel, AppColors.info, '/requests'),
        _Stat('Approved bookings', stats['approved'] ?? 0, Icons.check_circle, AppColors.success, '/history'),
        _Stat('Rejected', stats['rejected'] ?? 0, Icons.cancel, AppColors.danger, '/history'),
        _Stat('Arrivals (next 7 days)', stats['upcoming_arrivals'] ?? 0, Icons.flight_land, AppColors.navyLight, '/history'),
      ],
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in cards)
          SizedBox(
            width: 210,
            child: Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.line)),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.go(c.path),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppColors.tint(c.color), borderRadius: BorderRadius.circular(8)),
                      child: Icon(c.icon, color: c.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c.value}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.navy)),
                        Text(c.label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.icon, this.color, this.path);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String path;
}
