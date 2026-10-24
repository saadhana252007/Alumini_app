import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/session_viewmodel.dart';
import '../../views/admin/admin_view.dart';
import '../../views/auth/login_view.dart';
import '../../views/dashboard/dashboard_view.dart';
import '../../views/notices/notice_editor_view.dart';
import '../../views/notices/notices_view.dart';
import '../../views/reports/reports_view.dart';
import '../../views/requests/history_view.dart';
import '../../views/requests/request_detail_view.dart';
import '../../views/requests/request_form_view.dart';
import '../../views/requests/requests_view.dart';
import '../../views/shell/admin_shell.dart';
import '../../views/tariffs/tariffs_view.dart';
import '../constants.dart';

/// Route -> permission required to open it (also enforced by the database).
const _routePermissions = <String, List<String>>{
  '/notices': [Perm.noticeView],
  '/notices/new': [Perm.noticeManage],
  '/requests': [Perm.requestView],
  '/requests/new': [Perm.requestCreate],
  '/history': [Perm.requestView],
  '/reports': [Perm.reportView],
  '/tariffs': [Perm.requestView],
  '/admin': [Perm.adminManage, Perm.configManage],
};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      final loc = state.uri.path;
      if (s.isLoading && !s.hasValue) return loc == '/splash' ? null : '/splash';
      final session = s.valueOrNull;
      if (session == null) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash' || loc == '/') return '/dashboard';

      final required = _routePermissions[loc] ??
          (loc.startsWith('/notices/') && loc.endsWith('/edit')
              ? const [Perm.noticeManage]
              : null);
      if (required != null && !required.any(session.can)) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _Splash()),
      GoRoute(path: '/login', builder: (_, __) => const LoginView()),
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardView()),
          GoRoute(path: '/notices', builder: (_, __) => const NoticesView()),
          GoRoute(path: '/notices/new', builder: (_, __) => const NoticeEditorView()),
          GoRoute(
            path: '/notices/:id/edit',
            builder: (_, s) => NoticeEditorView(noticeId: s.pathParameters['id']),
          ),
          GoRoute(path: '/requests', builder: (_, __) => const RequestsView()),
          GoRoute(path: '/requests/new', builder: (_, __) => const RequestFormView()),
          GoRoute(
            path: '/requests/:id',
            builder: (_, s) => RequestDetailView(id: s.pathParameters['id']!),
          ),
          GoRoute(path: '/history', builder: (_, __) => const HistoryView()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsView()),
          GoRoute(path: '/tariffs', builder: (_, __) => const TariffsView()),
          GoRoute(path: '/admin', builder: (_, __) => const AdminView()),
        ],
      ),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
