import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/common.dart';
import '../../data/models/booking.dart';
import '../../viewmodels/request_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import 'request_tile.dart';

/// Incoming requests: Pending + Awaiting Approval.
class RequestsView extends ConsumerWidget {
  const RequestsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(incomingRequestsProvider);
    final notifier = ref.read(incomingFilterProvider.notifier);
    final filter = ref.watch(incomingFilterProvider);

    return PageScaffold(
      title: 'Incoming requests',
      subtitle: 'Requisitions pending or awaiting approval',
      actions: [
        if (ref.can(Perm.requestCreate))
          FilledButton.icon(
            onPressed: () => context.go('/requests/new'),
            icon: const Icon(Icons.add),
            label: const Text('New requisition'),
          ),
      ],
      child: Column(children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
            width: 280,
            child: TextField(
              decoration: const InputDecoration(
                  hintText: 'Search name, reference, organisation',
                  prefixIcon: Icon(Icons.search)),
              onChanged: notifier.setQuery,
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String?>(
              value: filter.roomType,
              decoration: const InputDecoration(labelText: 'Room type'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                for (final e in roomTypes.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: notifier.setRoomType,
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              value: filter.statuses.length != 1
                  ? 'all'
                  : (filter.statuses.first == RequestStatus.pending ? 'pending' : 'awaiting'),
              decoration: const InputDecoration(labelText: 'Stage'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All open')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'awaiting', child: Text('Awaiting Approval')),
              ],
              onChanged: (v) => notifier.setStatuses(switch (v) {
                'pending' => const [RequestStatus.pending],
                'awaiting' => const [RequestStatus.awaiting],
                _ => const [RequestStatus.pending, RequestStatus.awaiting],
              }),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(child: _RequestList(value: list, onRetry: () => ref.invalidate(incomingRequestsProvider))),
      ]),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.value, required this.onRetry});
  final AsyncValue<List<BookingRequest>> value;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AsyncBody<List<BookingRequest>>(
      value: value,
      onRetry: onRetry,
      isEmpty: (l) => l.isEmpty,
      emptyMessage: 'No requests to review.',
      emptyIcon: Icons.fact_check_outlined,
      data: (l) => ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: l.length,
        itemBuilder: (_, i) => RequestTile(request: l[i]),
      ),
    );
  }
}
