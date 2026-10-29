import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/utils/errors.dart';
import '../core/utils/formatters.dart';
import '../data/models/booking.dart';
import '../data/services/export_service.dart';
import '../data/services/report_table.dart';
import 'busy.dart';
import 'request_viewmodel.dart';
import 'session_viewmodel.dart';

enum ReportKind { register, approvals, alumni }

class ReportState {
  const ReportState({this.busy = false, this.table, this.error});
  final bool busy;
  final ReportTable? table;
  final String? error;
}

class ReportsViewModel extends Notifier<ReportState> {
  ReportKind kind = ReportKind.register;

  @override
  ReportState build() => const ReportState();

  String get _who =>
      ref.read(sessionProvider).valueOrNull?.profile.fullName ??
      'Administrator';

  Future<ReportTable> _load({
    required ReportKind kind,
    DateTime? from,
    DateTime? to,
    String? status,
    String? category,
  }) async {
    final repo = ref.read(reportRepositoryProvider);
    if (kind == ReportKind.alumni) {
      final rows = await repo.alumniReport(from: from, to: to, status: status);
      return ReportBuilder.alumniDirectory(rows,
          filters: {
            'Period':
                '${from == null ? 'any' : fmtDate(from)} to ${to == null ? 'any' : fmtDate(to)}',
            'Verification status': status == null ? 'All' : status.toUpperCase(),
          },
          generatedBy: _who);
    }

    final filters = <String, String>{
      'Period':
          '${from == null ? 'any' : fmtDate(from)} to ${to == null ? 'any' : fmtDate(to)}',
      if (kind == ReportKind.register)
        'Status filter': status == null ? 'All' : RequestStatus.label(status),
      if (kind == ReportKind.register) 'Category filter': category ?? 'All',
    };
    if (kind == ReportKind.register) {
      final rows = await repo.bookingRegister(
          from: from, to: to, status: status, category: category);
      return ReportBuilder.bookingRegister(rows,
          filters: filters, generatedBy: _who);
    }
    final rows = await repo.approvalReport(from: from, to: to);
    return ReportBuilder.approvalReport(rows,
        filters: filters, generatedBy: _who);
  }

  Future<void> generate({
    required ReportKind kind,
    DateTime? from,
    DateTime? to,
    String? status,
    String? category,
  }) async {
    this.kind = kind;
    state = const ReportState(busy: true);
    try {
      final t = await _load(
          kind: kind, from: from, to: to, status: status, category: category);
      state = ReportState(table: t);
    } catch (e) {
      state = ReportState(error: friendlyError(e));
    }
  }

  Future<Outcome> export(ExportFormat format) async {
    final t = state.table;
    if (t == null) return const Outcome.fail('Generate the report first.');
    final baseName = kind == ReportKind.alumni
        ? 'iitism-alumni-directory'
        : (kind == ReportKind.register ? 'edc-booking-register' : 'edc-approvals');
    try {
      final where = await ref.read(exportServiceProvider).export(t, format,
          baseName: baseName);
      return Outcome.ok('Saved: $where');
    } catch (e) {
      return Outcome.fail(friendlyError(e));
    }
  }

  /// Exports the register for the current History filters (one tap).
  Future<Outcome> exportHistory(ExportFormat format) async {
    try {
      final f = ref.read(historyFilterProvider);
      final t = await _load(
        kind: ReportKind.register,
        from: f.from,
        to: f.to,
        status: f.statuses.length == 1 ? f.statuses.first : null,
        category: f.category,
      );
      final where = await ref
          .read(exportServiceProvider)
          .export(t, format, baseName: 'edc-booking-register');
      return Outcome.ok('Saved: $where');
    } catch (e) {
      return Outcome.fail(friendlyError(e));
    }
  }
}

final reportsProvider =
    NotifierProvider<ReportsViewModel, ReportState>(ReportsViewModel.new);
