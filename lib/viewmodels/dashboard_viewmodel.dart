import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/providers.dart';
import '../data/models/booking.dart';
import '../data/models/notice.dart';
import 'session_viewmodel.dart';

class DashboardData {
  const DashboardData({
    required this.stats,
    required this.notices,
    required this.arrivals,
    required this.activity,
  });
  final Map<String, int> stats;
  final List<Notice> notices;
  final List<BookingRequest> arrivals;
  final List<AuditEntry> activity;
}

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final session = ref.watch(sessionProvider).valueOrNull;
  if (session == null) throw Exception('Not signed in.');
  final repo = ref.watch(dashboardRepositoryProvider);

  final stats = await repo.stats();
  final notices = session.can(Perm.noticeView)
      ? await ref
          .watch(noticeRepositoryProvider)
          .list(status: 'published', activeOnly: true, limit: 4)
      : <Notice>[];
  final arrivals =
      session.can(Perm.requestView) ? await repo.upcomingArrivals() : <BookingRequest>[];
  final activity =
      session.can(Perm.reportView) ? await repo.recentActivity() : <AuditEntry>[];
  return DashboardData(
      stats: stats, notices: notices, arrivals: arrivals, activity: activity);
});
