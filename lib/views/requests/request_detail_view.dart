import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/booking.dart';
import '../../data/models/tariff.dart';
import '../../viewmodels/request_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';

class RequestDetailView extends ConsumerWidget {
  const RequestDetailView({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(requestDetailProvider(id));
    return PageScaffold(
      title: 'Request details',
      backTo: '/requests',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(requestDetailProvider(id)),
        ),
      ],
      child: AsyncBody<RequestDetail>(
        value: detail,
        onRetry: () => ref.invalidate(requestDetailProvider(id)),
        data: (d) => _Body(detail: d),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});
  final RequestDetail detail;

  BookingRequest get r => detail.request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(requestActionsProvider).busy;
    final step = detail.currentStep;
    final open = RequestStatus.isOpen(r.status);
    final canDecide =
        (ref.can(Perm.requestDecide) || ref.can(Perm.requestManage)) && open;
    final canManage = ref.can(Perm.requestManage);
    final receipt = detail.receipt;
    final canPay = ref.can(Perm.paymentSimulate) &&
        receipt != null &&
        (receipt.total ?? 0) > 0 &&
        !detail.hasSuccessfulPayment &&
        (r.status == RequestStatus.approved ||
            r.status == RequestStatus.completed);
    final vm = ref.read(requestActionsProvider.notifier);

    Future<void> approve() async {
      final stage = step?.stageName ?? 'Room Allotment & Confirmation';
      final res = await showDialog<({String? availability, String roomNo})>(
        context: context,
        builder: (_) => _ApproveDialog(request: r, stageName: stage),
      );
      if (res == null) return;
      final o = await vm.decide(
          id: r.id,
          approve: true,
          roomNo: res.roomNo,
          availability: res.availability);
      if (context.mounted) showOutcome(context, o);
    }

    Future<void> reject() async {
      final reason = await showDialog<String>(
        context: context,
        builder: (_) => const _ReasonDialog(
            title: 'Reject request',
            label: 'Rejection reason *',
            confirm: 'Reject'),
      );
      if (reason == null) return;
      final o = await vm.decide(id: r.id, approve: false, reason: reason);
      if (context.mounted) showOutcome(context, o);
    }

    Future<void> cancel() async {
      final reason = await showDialog<String>(
        context: context,
        builder: (_) => const _ReasonDialog(
            title: 'Cancel booking',
            label: 'Reason for cancellation *',
            confirm: 'Cancel booking'),
      );
      if (reason == null) return;
      final o =
          await vm.setStatus(r.id, RequestStatus.cancelled, reason: reason);
      if (context.mounted) showOutcome(context, o);
    }

    Future<void> complete() async {
      final ok = await confirmDialog(context,
          title: 'Mark as completed',
          message: 'Confirm that the guest has completed the stay.');
      if (!ok) return;
      final o = await vm.setStatus(r.id, RequestStatus.completed);
      if (context.mounted) showOutcome(context, o);
    }

    Future<void> pay() async {
      final res = await showDialog<({String method, bool success})>(
          context: context,
          builder: (_) => _PayDialog(amount: receipt!.total!));
      if (res == null) return;
      final o =
          await vm.simulatePayment(r.id, res.method, success: res.success);
      if (context.mounted) showOutcome(context, o);
    }

    Future<void> download() async {
      final o = await vm.downloadReceipt(detail);
      if (context.mounted) showOutcome(context, o);
    }

    final guestTxt = r.guestDetails
        .map((g) =>
            '${g['relationship'] ?? ''} (age ${g['age'] ?? '-'}, ${g['gender'] ?? '-'})')
        .join('; ');

    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      SectionCard(
        title: r.reference,
        trailing: StatusChip(r.status),
        accent: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              '${r.visitorName} - Category ${r.categoryLabel} - ${roomTypes[r.roomType]}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (r.status == RequestStatus.rejected && r.rejectionReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Rejected: ${r.rejectionReason}',
                  style: const TextStyle(color: AppColors.danger)),
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (canDecide) ...[
              FilledButton.icon(
                  onPressed: busy ? null : approve,
                  icon: const Icon(Icons.check),
                  label: Text(
                      'Approve${step != null ? " (${step.stageName})" : ""}')),
              OutlinedButton.icon(
                  onPressed: busy ? null : reject,
                  icon: const Icon(Icons.close),
                  label: const Text('Reject')),
            ],
            if (canManage && r.status == RequestStatus.approved)
              OutlinedButton.icon(
                  onPressed: busy ? null : complete,
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Mark completed')),
            if (canManage && (open || r.status == RequestStatus.approved))
              OutlinedButton.icon(
                  onPressed: busy ? null : cancel,
                  icon: const Icon(Icons.block),
                  label: const Text('Cancel booking')),
            if (ref.can(Perm.receiptView) && receipt != null)
              OutlinedButton.icon(
                  onPressed: busy ? null : download,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Download receipt (PDF)')),
            if (canPay)
              FilledButton.icon(
                  onPressed: busy ? null : pay,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Simulate payment')),
          ]),
          if (open && step != null && !canDecide)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                  'Waiting for: ${step.authorityLabel.isEmpty ? step.stageName : step.authorityLabel} '
                  '(${roleLabels[step.approverRole] ?? step.approverRole}).',
                  style: const TextStyle(color: AppColors.muted)),
            ),
        ]),
      ),
      SectionCard(
        title: 'Visitor & booking details (entered by visitor/office)',
        child: KvGrid([
          ('Name', r.visitorName),
          ('Organisation', r.organization ?? ''),
          ('Address', r.address),
          ('Nationality', humanize(r.nationality)),
          ('Mobile', r.mobile),
          ('E-mail', r.email ?? ''),
          ('Purpose of visit', humanize(r.purpose)),
          (
            'Persons (lodging / food)',
            '${r.personsLodging} / ${r.personsFood}'
          ),
          ('Children below 12', '${r.childrenUnder12}'),
          ('Rooms', '${r.numRooms}'),
          ('Visitor category', r.categoryLabel),
          ('Room type', roomTypes[r.roomType] ?? r.roomType),
          ('Arrival', fmtDateTime(r.arrivalAt)),
          ('Departure', fmtDateTime(r.departureAt)),
          (
            'Lodging billed to',
            billingParties[r.lodgingBilledTo] ?? r.lodgingBilledTo
          ),
          ('Food billed to', billingParties[r.foodBilledTo] ?? r.foodBilledTo),
          if (r.isStudentGuest) ('Student guest(s)', guestTxt),
          if (r.isStudentGuest)
            ('Forwarded by DSW', r.forwardedByDsw ? 'Yes' : 'No'),
          if (r.extendedStayApproved) ('Extended stay', 'Approved beforehand'),
        ]),
      ),
      SectionCard(
        title: "Indenter's details",
        child: KvGrid([
          ('Name', r.indenterName),
          ('Designation', r.indenterDesignation ?? ''),
          ('Emp. code', r.indenterEmpCode ?? ''),
          ('Department', r.indenterDepartment ?? ''),
          ('Phone / mobile', r.indenterPhone ?? ''),
          ('E-mail', r.indenterEmail ?? ''),
          (
            'Forwarded by',
            forwardingAuthorities[r.forwardingAuthority ?? ''] ?? ''
          ),
        ]),
      ),
      SectionCard(
        title: 'For office use only',
        child: KvGrid([
          ('Status of booking', RequestStatus.label(r.status)),
          (
            'Availability',
            r.availability == null
                ? 'Not yet recorded'
                : humanize(r.availability!)
          ),
          ('Suite / room no.', r.allottedRoomNo ?? 'Not yet allotted'),
        ]),
      ),
      SectionCard(
        title: 'Approval',
        child: Column(children: [
          for (final s in detail.steps)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                s.status == 'approved'
                    ? Icons.check_circle
                    : s.status == 'rejected'
                        ? Icons.cancel
                        : s.status == 'pending'
                            ? Icons.hourglass_top
                            : Icons.remove_circle_outline,
                color: StatusChip.colorFor(s.status),
              ),
              title: Text('Stage ${s.stageOrder}: ${s.stageName}'),
              subtitle: Text([
                if (s.authorityLabel.isNotEmpty) s.authorityLabel,
                '${humanize(s.status)}${s.decidedByName == null ? '' : ' by ${s.decidedByName}'}'
                    '${s.decidedAt == null ? '' : ' on ${fmtDateTime(s.decidedAt)}'}',
                if ((s.reason ?? '').isNotEmpty) 'Reason: ${s.reason}',
              ].join('\n')),
              isThreeLine: true,
            ),
        ]),
      ),
      SectionCard(
        title: receipt == null
            ? 'Estimated charges'
            : 'Receipt ${receipt.receiptNo}',
        child: receipt == null
            ? KvGrid([
                (
                  'Estimated total (at submission)',
                  fmtMoney(r.estimatedAmount)
                ),
                const (
                  'Note',
                  'Final charges are fixed when the booking is approved.'
                ),
              ])
            : _ReceiptBlock(receipt: receipt),
      ),
      if (ref.can(Perm.receiptView))
        SectionCard(
          title: 'Payment (prototype simulation)',
          child: detail.payments.isEmpty
              ? const Text('No payment has been simulated.',
                  style: TextStyle(color: AppColors.muted))
              : Column(children: [
                  for (final p in detail.payments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.science_outlined,
                          color: AppColors.gold),
                      title:
                          Text('${fmtMoney(p.amount)} - ${humanize(p.method)}'),
                      subtitle: Text(
                          'SIMULATED - ref ${p.reference} - ${fmtDateTime(p.createdAt)}'),
                      trailing: StatusChip(p.status,
                          label: p.isSuccess
                              ? 'Simulated: success'
                              : 'Simulated: failed'),
                    ),
                ]),
        ),
      SectionCard(
        title: 'E-mail notifications',
        child: detail.notifications.isEmpty
            ? const Text('None recorded.',
                style: TextStyle(color: AppColors.muted))
            : Column(children: [
                for (final n in detail.notifications)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                        n.mode == 'sent'
                            ? Icons.mark_email_read
                            : Icons.mail_outline,
                        color: n.mode == 'failed'
                            ? AppColors.danger
                            : AppColors.muted),
                    title: Text(n.subject),
                    subtitle:
                        Text('${n.recipient} - ${fmtDateTime(n.createdAt)}'),
                    trailing: Text(
                        n.mode == 'simulated' ? 'SIMULATED' : humanize(n.mode),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: n.mode == 'sent'
                                ? AppColors.success
                                : AppColors.warning)),
                  ),
              ]),
      ),
      if (detail.audit.isNotEmpty)
        SectionCard(
          title: 'Audit trail',
          child: Column(children: [
            for (final a in detail.audit)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading:
                    const Icon(Icons.history, size: 18, color: AppColors.muted),
                title: Text(a.description),
                subtitle: Text(
                    '${a.actorName ?? 'System'} - ${fmtDateTime(a.createdAt)}'),
              ),
          ]),
        ),
    ]);
  }
}

class _ReceiptBlock extends StatelessWidget {
  const _ReceiptBlock({required this.receipt});
  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final ChargeBreakdown b = receipt.breakdown;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      KvGrid([
        ('Issued', fmtDateTime(receipt.issuedAt)),
        ('Billable days', '${b.days}'),
        ('Tariff basis', humanize(b.unit)),
        ('Rate', b.unitRate == null ? '-' : fmtMoney(b.unitRate)),
        ('Subtotal', fmtMoney(b.subtotal)),
        (
          'GST @ ${b.gstPercent.toStringAsFixed(2)}%',
          fmtMoney(b.gst, whenNull: '-')
        ),
        ('Total', b.isFree ? 'Free (Category A)' : fmtMoney(receipt.total)),
      ], width: 200),
      if (b.note != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(b.note!,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ),
    ]);
  }
}

class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog({required this.request, required this.stageName});
  final BookingRequest request;
  final String stageName;
  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  late String _availability = widget.request.availability ?? 'available';
  late final TextEditingController _room =
      TextEditingController(text: widget.request.allottedRoomNo ?? '');

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Approve - ${widget.stageName}'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'Office use: confirm availability and room allotment. '
              'Final approval requires "Available" and a room number.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _availability,
            decoration: const InputDecoration(labelText: 'Availability'),
            items: const [
              DropdownMenuItem(value: 'available', child: Text('Available')),
              DropdownMenuItem(
                  value: 'not_available', child: Text('Not available')),
            ],
            onChanged: (v) =>
                setState(() => _availability = v ?? _availability),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _room,
            decoration: const InputDecoration(labelText: 'Suite / room no.'),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, (availability: _availability, roomNo: _room.text)),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog(
      {required this.title, required this.label, required this.confirm});
  final String title;
  final String label;
  final String confirm;
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _c,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.label),
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Back')),
        FilledButton(
          onPressed: _c.text.trim().length < 3
              ? null
              : () => Navigator.pop(context, _c.text.trim()),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

class _PayDialog extends StatefulWidget {
  const _PayDialog({required this.amount});
  final double amount;
  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  String _method = 'upi';
  bool _success = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Simulate payment'),
      content: SizedBox(
        width: 400,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  'PROTOTYPE SIMULATION ONLY. No real money is transferred; the '
                  'result is stored in the database and labelled as simulated.',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 14),
              Text('Amount: ${fmtMoney(widget.amount)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _method,
                decoration:
                    const InputDecoration(labelText: 'Method (simulated)'),
                items: const [
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(value: 'card', child: Text('Card / POS')),
                  DropdownMenuItem(
                      value: 'net_banking', child: Text('Net banking')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash at EDC')),
                ],
                onChanged: (v) => setState(() => _method = v ?? _method),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Succeed')),
                  ButtonSegment(value: false, label: Text('Fail')),
                ],
                selected: {_success},
                onSelectionChanged: (s) => setState(() => _success = s.first),
              ),
            ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (method: _method, success: _success)),
          child: const Text('Run simulation'),
        ),
      ],
    );
  }
}
