import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/booking.dart';
import '../../data/services/export_service.dart';
import '../../viewmodels/report_viewmodel.dart';
import '../../viewmodels/request_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import 'request_tile.dart';

/// Booking history: every status, with search, filters and date range.
class HistoryView extends ConsumerWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(historyRequestsProvider);
    final f = ref.watch(historyFilterProvider);
    final n = ref.read(historyFilterProvider.notifier);

    return PageScaffold(
      title: 'Booking history',
      subtitle: 'Search all requests, bookings and decisions',
      actions: [
        if (ref.can(Perm.reportExport))
          PopupMenuButton<ExportFormat>(
            tooltip: 'Export current filter',
            onSelected: (fmt) async {
              final o = await ref.read(reportsProvider.notifier).exportHistory(fmt);
              if (context.mounted) showOutcome(context, o);
            },
            itemBuilder: (_) => [
              for (final fmt in ExportFormat.values)
                PopupMenuItem(value: fmt, child: Text('Export ${fmt.label}')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.navy, borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.download, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text('Export', style: TextStyle(color: Colors.white)),
              ]),
            ),
          ),
      ],
      child: Column(children: [
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 280,
            child: TextField(
              decoration: const InputDecoration(
                  hintText: 'Search name, reference, organisation',
                  prefixIcon: Icon(Icons.search)),
              onChanged: n.setQuery,
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String?>(
              value: f.statuses.length == 1 ? f.statuses.first : null,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                for (final e in requestStatuses.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => n.setStatuses(v == null ? const [] : [v]),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String?>(
              value: f.category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                for (final c in visitorCategories.keys)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: n.setCategory,
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String?>(
              value: f.roomType,
              decoration: const InputDecoration(labelText: 'Room type'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                for (final e in roomTypes.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: n.setRoomType,
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(f.from == null
                ? 'Arrival date range'
                : '${fmtDate(f.from)} - ${fmtDate(f.to ?? f.from)}'),
            onPressed: () async {
              final r = await showDateRangePicker(
                context: context,
                firstDate: DateTime(DateTime.now().year - 5),
                lastDate: DateTime(DateTime.now().year + 3),
                initialDateRange: f.from == null
                    ? null
                    : DateTimeRange(start: f.from!, end: f.to ?? f.from!),
              );
              if (r != null) n.setRange(r.start, r.end);
            },
          ),
          if (f.from != null || f.query.isNotEmpty || f.statuses.isNotEmpty ||
              f.category != null || f.roomType != null)
            TextButton(onPressed: n.reset, child: const Text('Clear filters')),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: AsyncBody<List<BookingRequest>>(
            value: list,
            onRetry: () => ref.invalidate(historyRequestsProvider),
            isEmpty: (l) => l.isEmpty,
            emptyMessage: 'No bookings match these filters.',
            emptyIcon: Icons.history,
            data: (l) => RefreshIndicator(
              onRefresh: () async => ref.refresh(historyRequestsProvider.future),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: l.length,
                itemBuilder: (_, i) => RequestTile(request: l[i]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
