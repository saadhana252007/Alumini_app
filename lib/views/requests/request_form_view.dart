import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/booking.dart';
import '../../data/models/tariff.dart';
import '../../viewmodels/request_viewmodel.dart';
import '../../viewmodels/tariff_viewmodel.dart';

String? _required(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

/// Office entry of an EDC requisition (Section 1-3 of the paper form).
/// Office-use and approval fields are deliberately NOT editable here.
class RequestFormView extends ConsumerStatefulWidget {
  const RequestFormView({super.key});
  @override
  ConsumerState<RequestFormView> createState() => _RequestFormViewState();
}

class _RequestFormViewState extends ConsumerState<RequestFormView> {
  final _form = GlobalKey<FormState>();
  final d = RequestDraft();

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final o = await ref.read(requestActionsProvider.notifier).create(d);
    if (!mounted) return;
    showOutcome(context, o);
    if (o.ok) context.go('/requests');
  }

  Widget _text(String label, void Function(String) set,
          {String? initial,
          String? Function(String?)? validator,
          TextInputType? type,
          int maxLines = 1,
          double width = 260}) =>
      SizedBox(
        width: width,
        child: TextFormField(
          initialValue: initial,
          keyboardType: type,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label),
          validator: validator,
          onChanged: set,
        ),
      );

  Widget _dt(String label, DateTime? v, void Function(DateTime) set) =>
      SizedBox(
        width: 260,
        child: InkWell(
          onTap: () async {
            final x = await pickDateTime(context, v);
            if (x != null) setState(() => set(x));
          },
          child: InputDecorator(
            decoration: InputDecoration(
                labelText: label,
                suffixIcon: const Icon(Icons.event, size: 18)),
            child: Text(v == null ? 'Select' : fmtDateTime(v)),
          ),
        ),
      );

  Widget _seg(Map<String, String> options, String value,
          void Function(String) set) =>
      SegmentedButton<String>(
        segments: [
          for (final e in options.entries)
            ButtonSegment(value: e.key, label: Text(e.value)),
        ],
        selected: {value},
        onSelectionChanged: (s) => setState(() => set(s.first)),
      );

  Widget _stepper(String label, int value, int min, void Function(int) set) =>
      SizedBox(
        width: 260,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Row(children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline),
              onPressed:
                  value > min ? () => setState(() => set(value - 1)) : null,
            ),
            Expanded(
                child: Center(
                    child: Text('$value',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)))),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => setState(() => set(value + 1)),
            ),
          ]),
        ),
      );

  Widget _billing(String label, String value, void Function(String) set) =>
      SizedBox(
        width: 260,
        child: DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final e in billingParties.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => set(v ?? value)),
        ),
      );

  Widget _estimateCard() {
    final a = d.arrivalAt, b = d.departureAt;
    if (a == null || b == null || !b.isAfter(a)) {
      return const Text('Select arrival and departure to see an estimate.',
          style: TextStyle(color: AppColors.muted));
    }
    final rules = ref.watch(tariffRulesProvider);
    final gst = ref.watch(gstPercentProvider);
    return rules.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => const Text('Tariff could not be loaded.'),
      data: (r) {
        final c = TariffCalculator.calculate(
          rules: r,
          category: d.category,
          subCategory: d.category == 'E' ? d.subCategory : '',
          roomType: d.roomType,
          rooms: d.numRooms,
          arrival: a,
          departure: b,
          gstPercent: gst.valueOrNull ?? 0,
        );
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KvGrid([
            ('Billable days', '${c.days}'),
            ('Rooms', '${c.rooms}'),
            (
              'Rate',
              c.unitRate == null
                  ? '-'
                  : '${fmtMoney(c.unitRate)} (${humanize(c.unit)})'
            ),
            ('Subtotal', fmtMoney(c.subtotal)),
            (
              'GST @ ${c.gstPercent.toStringAsFixed(2)}%',
              fmtMoney(c.gst, whenNull: '-')
            ),
            (
              'Estimated total',
              c.isFree ? 'Free (Category A)' : fmtMoney(c.total)
            ),
          ], width: 200),
          if (c.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(c.note!,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(requestActionsProvider).busy;

    return PageScaffold(
      title: 'New requisition',
      subtitle: 'EDC requisition form - visitor-entered details',
      backTo: '/requests',
      child: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          SectionCard(
            title: '1. Visitor & booking details',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 14, runSpacing: 14, children: [
                _text('Name *', (v) => d.visitorName = v, validator: _required),
                _text('Organisation', (v) => d.organization = v),
                _text('Address *', (v) => d.address = v,
                    validator: _required, width: 540),
                _text('Mobile no. *', (v) => d.mobile = v,
                    type: TextInputType.phone,
                    validator: (v) =>
                        RegExp(r'^[0-9+\-\s]{7,20}$').hasMatch(v ?? '')
                            ? null
                            : 'Enter a valid number'),
                _text('E-mail', (v) => d.email = v,
                    type: TextInputType.emailAddress,
                    validator: (v) => (v == null ||
                            v.trim().isEmpty ||
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(v.trim()))
                        ? null
                        : 'Invalid e-mail'),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 24, runSpacing: 12, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Nationality',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  _seg(const {'indian': 'Indian', 'foreigner': 'Foreigner'},
                      d.nationality, (v) => d.nationality = v),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Purpose of visit',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  _seg(const {'official': 'Official', 'personal': 'Personal'},
                      d.purpose, (v) => d.purpose = v),
                ]),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 14, runSpacing: 14, children: [
                _stepper('No. of persons - lodging', d.personsLodging, 1,
                    (v) => d.personsLodging = v),
                _stepper('No. of persons - food', d.personsFood, 0,
                    (v) => d.personsFood = v),
                _stepper('Children below 12', d.childrenUnder12, 0,
                    (v) => d.childrenUnder12 = v),
                _stepper('No. of rooms (max 2 persons/room)', d.numRooms, 1,
                    (v) => d.numRooms = v),
              ]),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                    'Guest of a student (parent / guardian / spouse)'),
                subtitle: const Text('Requisition must be forwarded by DSW.'),
                value: d.isStudentGuest,
                onChanged: (v) => setState(() {
                  d.isStudentGuest = v;
                  if (v && d.guestDetails.isEmpty) {
                    d.guestDetails
                        .add({'age': '', 'relationship': '', 'gender': 'M'});
                  }
                }),
              ),
              if (d.isStudentGuest) ...[
                for (final g in d.guestDetails)
                  Padding(
                    key: ObjectKey(g),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _text('Age', (v) => g['age'] = v,
                              initial: g['age'],
                              type: TextInputType.number,
                              width: 100),
                          _text('Relationship', (v) => g['relationship'] = v,
                              initial: g['relationship'], width: 200),
                          SizedBox(
                            width: 110,
                            child: DropdownButtonFormField<String>(
                              value: g['gender'],
                              decoration:
                                  const InputDecoration(labelText: 'Gender'),
                              items: const [
                                DropdownMenuItem(value: 'M', child: Text('M')),
                                DropdownMenuItem(value: 'F', child: Text('F')),
                              ],
                              onChanged: (v) =>
                                  setState(() => g['gender'] = v ?? 'M'),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                setState(() => d.guestDetails.remove(g)),
                          ),
                        ]),
                  ),
                TextButton.icon(
                  onPressed: () => setState(() => d.guestDetails
                      .add({'age': '', 'relationship': '', 'gender': 'M'})),
                  icon: const Icon(Icons.add),
                  label: const Text('Add guest'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Forwarded by DSW'),
                  value: d.forwardedByDsw,
                  onChanged: (v) => setState(() => d.forwardedByDsw = v),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 14, children: [
                SizedBox(
                  width: 540,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: d.category,
                    decoration:
                        const InputDecoration(labelText: 'Visitor category *'),
                    items: [
                      for (final e in visitorCategories.entries)
                        DropdownMenuItem(
                            value: e.key,
                            child:
                                Text(e.value, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() {
                      d.category = v ?? d.category;
                      if (d.category != 'E') d.subCategory = '';
                    }),
                  ),
                ),
                if (d.category == 'E')
                  SizedBox(
                    width: 540,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: d.subCategory.isEmpty ? null : d.subCategory,
                      decoration:
                          const InputDecoration(labelText: 'Category E type *'),
                      items: [
                        for (final e in eSubCategories.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      validator: (v) => v == null ? 'Select a type' : null,
                      onChanged: (v) => setState(() => d.subCategory = v ?? ''),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              const Text('Type of room',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 4),
              _seg(roomTypes, d.roomType, (v) => d.roomType = v),
              const SizedBox(height: 14),
              Wrap(spacing: 14, runSpacing: 14, children: [
                _dt('Arrival (date & time) *', d.arrivalAt,
                    (v) => d.arrivalAt = v),
                _dt('Departure (date & time) *', d.departureAt,
                    (v) => d.departureAt = v),
              ]),
              if (d.purpose == 'personal')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                      'Extended stay (beyond 3 days) approved beforehand'),
                  value: d.extendedStayApproved,
                  onChanged: (v) => setState(() => d.extendedStayApproved = v),
                ),
            ]),
          ),
          SectionCard(
            title: '2. Bill(s) to be settled by',
            child: Wrap(spacing: 14, runSpacing: 14, children: [
              _billing(
                  'Lodging', d.lodgingBilledTo, (v) => d.lodgingBilledTo = v),
              _billing('Food', d.foodBilledTo, (v) => d.foodBilledTo = v),
            ]),
          ),
          SectionCard(
            title: "3. Indenter's details",
            child: Wrap(spacing: 14, runSpacing: 14, children: [
              _text('Name *', (v) => d.indenterName = v, validator: _required),
              _text('Designation', (v) => d.indenterDesignation = v),
              _text('Emp. code', (v) => d.indenterEmpCode = v),
              _text('Department', (v) => d.indenterDepartment = v),
              _text('Phone / mobile', (v) => d.indenterPhone = v,
                  type: TextInputType.phone),
              _text('E-mail', (v) => d.indenterEmail = v,
                  type: TextInputType.emailAddress,
                  validator: (v) => (v == null ||
                          v.trim().isEmpty ||
                          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(v.trim()))
                      ? null
                      : 'Invalid e-mail'),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  value: d.forwardingAuthority,
                  decoration: const InputDecoration(labelText: 'Forwarded by'),
                  items: [
                    for (final e in forwardingAuthorities.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) =>
                      setState(() => d.forwardingAuthority = v ?? ''),
                ),
              ),
            ]),
          ),
          SectionCard(
            title: 'Estimated charges',
            accent: true,
            child: _estimateCard(),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Office-use details (room availability / allotment) and approvals are recorded '
              'by authorised administrators after submission. Bookings are provisional and '
              'subject to availability; they must be made at least 24 hours before arrival.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: busy ? null : _submit,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: const Text('Submit requisition'),
            ),
          ),
        ]),
      ),
    );
  }
}
