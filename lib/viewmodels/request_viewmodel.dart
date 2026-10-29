import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../data/models/booking.dart';
import 'busy.dart';
import 'dashboard_viewmodel.dart';

class RequestFilterNotifier extends Notifier<RequestFilter> {
  RequestFilterNotifier(this.initial);
  final RequestFilter initial;

  @override
  RequestFilter build() => initial;

  void setStatuses(List<String> v) => state = (
        statuses: v,
        category: state.category,
        roomType: state.roomType,
        from: state.from,
        to: state.to,
        query: state.query
      );
  void setCategory(String? v) => state = (
        statuses: state.statuses,
        category: v,
        roomType: state.roomType,
        from: state.from,
        to: state.to,
        query: state.query
      );
  void setRoomType(String? v) => state = (
        statuses: state.statuses,
        category: state.category,
        roomType: v,
        from: state.from,
        to: state.to,
        query: state.query
      );
  void setRange(DateTime? from, DateTime? to) => state = (
        statuses: state.statuses,
        category: state.category,
        roomType: state.roomType,
        from: from,
        to: to,
        query: state.query
      );
  void setQuery(String v) => state = (
        statuses: state.statuses,
        category: state.category,
        roomType: state.roomType,
        from: state.from,
        to: state.to,
        query: v
      );
  void reset() => state = initial;
}

const _incomingStatuses = [RequestStatus.pending, RequestStatus.awaiting];

final incomingFilterProvider =
    NotifierProvider<RequestFilterNotifier, RequestFilter>(
        () => RequestFilterNotifier((
              statuses: _incomingStatuses,
              category: null,
              roomType: null,
              from: null,
              to: null,
              query: '',
            )));

final historyFilterProvider =
    NotifierProvider<RequestFilterNotifier, RequestFilter>(
        () => RequestFilterNotifier((
              statuses: const <String>[],
              category: null,
              roomType: null,
              from: null,
              to: null,
              query: '',
            )));

final incomingRequestsProvider =
    FutureProvider.autoDispose<List<BookingRequest>>((ref) => ref
        .watch(bookingRepositoryProvider)
        .list(ref.watch(incomingFilterProvider)));

final historyRequestsProvider =
    FutureProvider.autoDispose<List<BookingRequest>>((ref) => ref
        .watch(bookingRepositoryProvider)
        .list(ref.watch(historyFilterProvider)));

final requestDetailProvider = FutureProvider.autoDispose
    .family<RequestDetail, String>(
        (ref, id) => ref.watch(bookingRepositoryProvider).detail(id));

class RequestActionsViewModel extends BusyNotifier {
  void _refresh(String? id) {
    ref.invalidate(incomingRequestsProvider);
    ref.invalidate(historyRequestsProvider);
    ref.invalidate(dashboardProvider);
    if (id != null) ref.invalidate(requestDetailProvider(id));
  }

  Future<Outcome> create(RequestDraft draft) => run(() async {
        final err = draft.validate(DateTime.now());
        if (err != null) throw Exception(err);
        final created = await ref.read(bookingRepositoryProvider).create(draft);
        final mail = await ref
            .read(notificationServiceProvider)
            .notify(created.id, 'submitted');
        _refresh(null);
        return 'Request ${created.reference} submitted. $mail';
      });

  Future<Outcome> decide({
    required String id,
    required bool approve,
    String? reason,
    String? roomNo,
    String? availability,
  }) =>
      run(() async {
        if (!approve && (reason ?? '').trim().length < 3) {
          throw Exception('A rejection reason is required.');
        }
        final res = await ref.read(bookingRepositoryProvider).decide(
              requestId: id,
              approve: approve,
              reason: reason?.trim(),
              roomNo: roomNo?.trim().isEmpty == true ? null : roomNo?.trim(),
              availability: availability,
            );
        final status = res['status'] as String?;
        var mail = '';
        if (status == RequestStatus.approved ||
            status == RequestStatus.rejected) {
          mail = await ref
              .read(notificationServiceProvider)
              .notify(id, 'decision');
        }
        _refresh(id);
        if (!approve) return 'Request rejected. $mail';
        return status == RequestStatus.approved
            ? 'Final approval recorded and receipt issued. $mail'
            : 'Stage approved - forwarded to the next approval authority.';
      });

  Future<Outcome> setStatus(String id, String status, {String? reason}) =>
      run(() async {
        if (status == RequestStatus.cancelled &&
            (reason ?? '').trim().length < 3) {
          throw Exception('Please give a reason for cancelling.');
        }
        await ref
            .read(bookingRepositoryProvider)
            .setStatus(id, status, reason?.trim());
        _refresh(id);
        return status == RequestStatus.cancelled
            ? 'Booking cancelled.'
            : 'Booking marked completed.';
      });

  Future<Outcome> simulatePayment(String id, String method,
          {bool success = true}) =>
      run(() async {
        await ref
            .read(bookingRepositoryProvider)
            .simulatePayment(id, method, success);
        _refresh(id);
        return success
            ? 'SIMULATED payment recorded. No real money was transferred.'
            : 'SIMULATED failed payment recorded.';
      });

  Future<Outcome> downloadReceipt(RequestDetail d) => run(() async {
        final where = await ref.read(receiptPdfServiceProvider).download(d);
        return 'Receipt saved: $where';
      });
}

final requestActionsProvider =
    NotifierProvider<RequestActionsViewModel, BusyState>(
        RequestActionsViewModel.new);
