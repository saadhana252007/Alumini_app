import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/services/export_service.dart';
import '../../viewmodels/report_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';

class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key});
  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  ReportKind _kind = ReportKind.register;
  DateTime? _from;
  DateTime? _to;
  String? _status;
  String? _category;

  Future<void> _generate() => ref.read(reportsProvider.notifier).generate(
        kind: _kind,
        from: _from,
        to: _to,
        status: _status,
        category: _category,
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final canExport = ref.can(Perm.reportExport);
    final t = state.table;

    return PageScaffold(
      title: 'Reports & registers',
      subtitle: 'Generated from live Supabase data; exports include only necessary columns',
      child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        SectionCard(
          title: 'Report options',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SegmentedButton<ReportKind>(
              segments: const [
                ButtonSegment(value: ReportKind.register, label: Text('Booking register')),
                ButtonSegment(value: ReportKind.approvals, label: Text('Approval history')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(_from == null
                    ? 'Date range (arrival / decision)'
                    : '${fmtDate(_from)} - ${fmtDate(_to ?? _from)}'),
                onPressed: () async {
                  final r = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(DateTime.now().year - 5),
                    lastDate: DateTime(DateTime.now().year + 3),
                  );
                  if (r != null) setState(() {
                    _from = r.start;
                    _to = r.end;
                  });
                },
              ),
              if (_from != null)
                TextButton(
                    onPressed: () => setState(() {
                          _from = null;
                          _to = null;
                        }),
                    child: const Text('Clear dates')),
              if (_kind == ReportKind.register) ...[
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String?>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      for (final e in requestStatuses.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _status = v),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String?>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      for (final c in visitorCategories.keys)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ),
              ],
              FilledButton.icon(
                onPressed: state.busy ? null : _generate,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Generate'),
              ),
            ]),
          ]),
        ),
        if (state.busy) const LoadingView(),
        if (state.error != null) ErrorView(message: state.error!, onRetry: _generate),
        if (t != null)
          SectionCard(
            title: '${t.title} - ${t.rows.length} record(s)',
            trailing: canExport
                ? Wrap(spacing: 8, children: [
                    for (final f in ExportFormat.values)
                      OutlinedButton(
                        onPressed: () async {
                          final o = await ref.read(reportsProvider.notifier).export(f);
                          if (context.mounted) showOutcome(context, o);
                        },
                        child: Text(f.ext.toUpperCase()),
                      ),
                  ])
                : const Text('Export not permitted', style: TextStyle(color: AppColors.muted)),
            child: t.rows.isEmpty
                ? const EmptyView(message: 'No records for these filters.', icon: Icons.table_chart_outlined)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 38,
                      dataRowMinHeight: 34,
                      dataRowMaxHeight: 40,
                      headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 12),
                      dataTextStyle: const TextStyle(fontSize: 12, color: AppColors.ink),
                      columns: [for (final h in t.headers) DataColumn(label: Text(h))],
                      rows: [
                        for (final row in t.rows.take(50))
                          DataRow(cells: [
                            for (final c in row) DataCell(Text(c == null ? '' : '$c')),
                          ]),
                      ],
                    ),
                  ),
          ),
        if (t != null && t.rows.length > 50)
          const Text('Preview shows the first 50 rows; exports contain all rows.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ]),
    );
  }
}
