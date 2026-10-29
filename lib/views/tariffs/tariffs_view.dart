import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/tariff.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../../viewmodels/tariff_viewmodel.dart';

const _units = <String, String>{
  'per_day': 'Per day',
  'per_month': 'Per month',
  'free': 'Free',
  'as_applicable': 'As applicable (license fee)',
  'unspecified': 'Not specified',
};

class TariffsView extends ConsumerWidget {
  const TariffsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(tariffRulesProvider);
    final gst = ref.watch(gstPercentProvider);
    final canManage = ref.can(Perm.tariffManage);

    return PageScaffold(
      title: 'Tariffs',
      subtitle:
          'Initial rates from the EDC revised tariff (Section II of the requisition form)',
      child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        SectionCard(
          title: 'Applicable taxes',
          trailing: canManage
              ? TextButton(
                  onPressed: () async {
                    final v = await showDialog<double>(
                        context: context,
                        builder: (_) =>
                            _GstDialog(current: gst.valueOrNull ?? 0));
                    if (v == null) return;
                    final o = await ref
                        .read(tariffActionsProvider.notifier)
                        .setGst(v);
                    if (context.mounted) showOutcome(context, o);
                  },
                  child: const Text('Edit GST %'))
              : null,
          child: Text(
            'GST: ${(gst.valueOrNull ?? 0).toStringAsFixed(2)}%. The form says "plus admissible GST" '
            'without a rate, so it is configurable and starts at 0% until the institute confirms it.',
          ),
        ),
        AsyncBody<List<TariffRule>>(
          value: rules,
          onRetry: () => ref.invalidate(tariffRulesProvider),
          isEmpty: (l) => l.isEmpty,
          emptyMessage: 'No tariff rules configured.',
          data: (list) => Column(children: [
            for (final cat in visitorCategories.keys)
              SectionCard(
                title: 'Category ${visitorCategories[cat]}',
                child: Column(children: [
                  for (final r in list.where((x) => x.category == cat))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '${roomTypes[r.roomType]}${r.subCategory.isEmpty ? '' : ' - ${eSubCategories[r.subCategory] ?? r.subCategory}'}'),
                      subtitle: r.note == null ? null : Text(r.note!),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  r.billingUnit == 'free'
                                      ? 'Free'
                                      : r.rate == null
                                          ? (_units[r.billingUnit] ??
                                              r.billingUnit)
                                          : fmtMoney(r.rate),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy)),
                              if (r.rate != null && r.billingUnit != 'free')
                                Text(_units[r.billingUnit] ?? '',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.muted)),
                              if (!r.isActive)
                                const Text('inactive',
                                    style: TextStyle(
                                        fontSize: 11, color: AppColors.danger)),
                            ]),
                        if (canManage)
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final res = await showDialog<_RuleEdit>(
                                  context: context,
                                  builder: (_) => _RuleDialog(rule: r));
                              if (res == null) return;
                              final o = await ref
                                  .read(tariffActionsProvider.notifier)
                                  .updateRule(r,
                                      rate: res.rate,
                                      unit: res.unit,
                                      active: res.active,
                                      note: res.note);
                              if (context.mounted) showOutcome(context, o);
                            },
                          ),
                      ]),
                    ),
                ]),
              ),
          ]),
        ),
        const Text(
          'Rates are per room per day irrespective of single/double occupation; maximum 2 persons per '
          'room (children below 12 excluded). Monthly rates are charged per started 30-day month '
          '(prototype assumption).',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ]),
    );
  }
}

class _RuleEdit {
  const _RuleEdit(this.rate, this.unit, this.active, this.note);
  final double? rate;
  final String unit;
  final bool active;
  final String? note;
}

class _RuleDialog extends StatefulWidget {
  const _RuleDialog({required this.rule});
  final TariffRule rule;
  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  late String _unit = widget.rule.billingUnit;
  late bool _active = widget.rule.isActive;
  late final _rate =
      TextEditingController(text: widget.rule.rate?.toStringAsFixed(2) ?? '');
  late final _note = TextEditingController(text: widget.rule.note ?? '');

  @override
  void dispose() {
    _rate.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit tariff rule'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: _unit,
            decoration: const InputDecoration(labelText: 'Billing basis'),
            items: [
              for (final e in _units.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value))
            ],
            onChanged: (v) => setState(() => _unit = v ?? _unit),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rate,
            enabled: _unit == 'per_day' || _unit == 'per_month',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Rate (Rs.)'),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(
              context,
              _RuleEdit(double.tryParse(_rate.text.trim()), _unit, _active,
                  _note.text.trim().isEmpty ? null : _note.text.trim())),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _GstDialog extends StatefulWidget {
  const _GstDialog({required this.current});
  final double current;
  @override
  State<_GstDialog> createState() => _GstDialogState();
}

class _GstDialogState extends State<_GstDialog> {
  late final _c = TextEditingController(text: widget.current.toString());
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('GST percentage'),
      content: TextField(
        controller: _c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'GST %'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(_c.text.trim()) ?? 0),
            child: const Text('Save')),
      ],
    );
  }
}
