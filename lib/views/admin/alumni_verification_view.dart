import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/profile.dart';
import '../../data/services/export_service.dart';
import '../../data/services/report_table.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AlumniVerificationView extends ConsumerWidget {
  const AlumniVerificationView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(alumniFilterStatusProvider);
    final verificationsAsync = ref.watch(alumniVerificationsProvider);
    final claimsAsync = ref.watch(alumniClaimsProvider);
    final vm = ref.read(adminActionsProvider.notifier);
    final busy = ref.watch(adminActionsProvider).busy;

    Future<void> onVerify(AlumniVerificationItem item) async {
      final confirmed = await confirmDialog(
        context,
        title: 'Verify Alumnus',
        message:
            'Are you sure you want to approve and verify ${item.fullName} (${item.admissionNo ?? "No Roll No"}) as an official IIT (ISM) Alumnus?',
      );
      if (!confirmed) return;

      final o = await vm.verifyAlumnus(item.id, approve: true);
      if (context.mounted) showOutcome(context, o);
    }

    Future<void> onReject(AlumniVerificationItem item) async {
      final reason = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final c = TextEditingController();
          return AlertDialog(
            title: Text('Reject Verification - ${item.fullName}'),
            content: TextField(
              controller: c,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection (e.g. roll number mismatch)',
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                child: const Text('Reject'),
              ),
            ],
          );
        },
      );
      if (reason == null) return;

      final o = await vm.verifyAlumnus(item.id, approve: false, notes: reason);
      if (context.mounted) showOutcome(context, o);
    }

    Future<void> onResolveDuplicate(
      AlumniVerificationItem item, {
      required String action,
      String? masterId,
    }) async {
      if (action == 'clear') {
        final confirmed = await confirmDialog(
          context,
          title: 'Mark as Not a Duplicate',
          message:
              'Confirm that ${item.fullName} (${item.email}) is a distinct alumnus and not a duplicate account?',
        );
        if (!confirmed) return;
      } else if (action == 'merge') {
        final confirmed = await confirmDialog(
          context,
          title: 'Merge Profiles',
          message:
              'Merge all bookings, activity, and donations from this application into profile $masterId and deactivate this duplicate?',
        );
        if (!confirmed) return;
      }

      final o = await vm.resolveDuplicate(
        profileId: item.id,
        action: action,
        masterProfileId: masterId,
      );
      if (context.mounted) showOutcome(context, o);
    }

    Future<void> onDecideClaim(AlumniClaimItem claim, {required bool approve}) async {
      final reason = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final c = TextEditingController();
          return AlertDialog(
            title: Text('${approve ? "Approve" : "Reject"} Claim - ${claim.admissionNo}'),
            content: TextField(
              controller: c,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: approve ? 'Admin notes (optional)' : 'Reason for rejection',
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: approve ? AppColors.success : AppColors.danger),
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                child: Text(approve ? 'Approve' : 'Reject'),
              ),
            ],
          );
        },
      );
      if (reason == null && !approve) return;

      final o = await vm.decideClaim(
        claimId: claim.id,
        approve: approve,
        notes: reason,
      );
      if (context.mounted) showOutcome(context, o);
    }

    return PageScaffold(
      title: 'Alumni Verification & Identity',
      subtitle: 'Review applications, resolve duplicate flags, and manage admission claims',
      actions: [
        PopupMenuButton<ExportFormat>(
          tooltip: 'Export Alumni List (PDF/Excel)',
          icon: const Icon(Icons.download),
          onSelected: (format) async {
            final list = verificationsAsync.valueOrNull ?? [];
            if (list.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('No alumni records in the current view to export.')),
              );
              return;
            }
            final rows = list
                .map((item) => {
                      'full_name': item.fullName,
                      'admission_no': item.admissionNo,
                      'department_name': item.departmentName,
                      'batch_year': item.batchYear,
                      'verification_status': item.verificationStatus,
                      'email': item.email,
                      'contact_no': item.contactNo,
                      'organisation': item.organisation,
                      'current_position': item.currentPosition,
                      'city': item.city,
                      'created_at': item.createdAt.toIso8601String(),
                    })
                .toList();

            final table = ReportBuilder.alumniDirectory(
              rows,
              filters: {
                'Active view': statusFilter.toUpperCase(),
                'Total items': '${list.length}',
              },
              generatedBy: 'EDC Administration',
            );

            try {
              final where = await ref.read(exportServiceProvider).export(
                    table,
                    format,
                    baseName: 'iitism-alumni-${statusFilter.toLowerCase()}',
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.success,
                    content: Text('Export saved: $where'),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.danger,
                    content: Text('Export failed: $e'),
                  ),
                );
              }
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: ExportFormat.pdf,
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Export PDF (.pdf)'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: ExportFormat.xlsx,
              child: Row(
                children: [
                  Icon(Icons.table_chart, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text('Export Excel (.xlsx)'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: ExportFormat.ods,
              child: Row(
                children: [
                  Icon(Icons.grid_on, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Text('Export OpenDocument (.ods)'),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(alumniVerificationsProvider);
            ref.invalidate(alumniClaimsProvider);
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Pending Verification'),
                selected: statusFilter == 'pending',
                onSelected: (_) => ref
                    .read(alumniFilterStatusProvider.notifier)
                    .state = 'pending',
                selectedColor: AppColors.navy,
                labelStyle: TextStyle(
                  color:
                      statusFilter == 'pending' ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              ChoiceChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber, size: 14, color: AppColors.warning),
                    SizedBox(width: 4),
                    Text('Possible Duplicates'),
                  ],
                ),
                selected: statusFilter == 'duplicates',
                onSelected: (_) => ref
                    .read(alumniFilterStatusProvider.notifier)
                    .state = 'duplicates',
                selectedColor: AppColors.navy,
                labelStyle: TextStyle(
                  color: statusFilter == 'duplicates'
                      ? Colors.white
                      : AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              ChoiceChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment_ind_outlined, size: 14),
                    SizedBox(width: 4),
                    Text('Admission Claims'),
                  ],
                ),
                selected: statusFilter == 'claims',
                onSelected: (_) => ref
                    .read(alumniFilterStatusProvider.notifier)
                    .state = 'claims',
                selectedColor: AppColors.navy,
                labelStyle: TextStyle(
                  color: statusFilter == 'claims'
                      ? Colors.white
                      : AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              ChoiceChip(
                label: const Text('Verified Alumni'),
                selected: statusFilter == 'verified',
                onSelected: (_) => ref
                    .read(alumniFilterStatusProvider.notifier)
                    .state = 'verified',
                selectedColor: AppColors.navy,
                labelStyle: TextStyle(
                  color:
                      statusFilter == 'verified' ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              ChoiceChip(
                label: const Text('Rejected'),
                selected: statusFilter == 'rejected',
                onSelected: (_) => ref
                    .read(alumniFilterStatusProvider.notifier)
                    .state = 'rejected',
                selectedColor: AppColors.navy,
                labelStyle: TextStyle(
                  color:
                      statusFilter == 'rejected' ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              ChoiceChip(
                label: const Text('All Profiles'),
                selected: statusFilter == 'all',
                onSelected: (_) =>
                    ref.read(alumniFilterStatusProvider.notifier).state = 'all',
                selectedColor: AppColors.navy,
                labelStyle: TextStyle(
                  color: statusFilter == 'all' ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Content body
          Expanded(
            child: statusFilter == 'claims'
                ? AsyncBody<List<AlumniClaimItem>>(
                    value: claimsAsync,
                    onRetry: () => ref.invalidate(alumniClaimsProvider),
                    isEmpty: (l) => l.isEmpty,
                    emptyMessage: 'No admission claims pending review.',
                    emptyIcon: Icons.assignment_turned_in_outlined,
                    data: (claims) => ListView.builder(
                      padding: const EdgeInsets.only(bottom: 32),
                      itemCount: claims.length,
                      itemBuilder: (context, index) {
                        final claim = claims[index];
                        final claimant = claim.claimantDetails;
                        final isPending = claim.status == 'pending';
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.line),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Claim for Roll No: ${claim.admissionNo}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    _StatusBadge(status: claim.status),
                                  ],
                                ),
                                const Divider(height: 16),
                                KvGrid([
                                  ('Claimant Name', claimant['claimant_name'] ?? '-'),
                                  ('Contact Email', claimant['claimant_email'] ?? '-'),
                                  ('Contact Phone', claimant['claimant_contact'] ?? '-'),
                                  ('Claimant Notes', claimant['notes'] ?? 'None provided'),
                                  ('Claimed At', fmtDateTime(claim.createdAt)),
                                ]),
                                if (isPending) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.success,
                                        ),
                                        onPressed: busy
                                            ? null
                                            : () => onDecideClaim(claim,
                                                approve: true),
                                        icon: const Icon(
                                            Icons.check_circle_outline,
                                            size: 16),
                                        label: const Text('Approve Claim'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.danger,
                                          side: const BorderSide(
                                              color: AppColors.danger),
                                        ),
                                        onPressed: busy
                                            ? null
                                            : () => onDecideClaim(claim,
                                                approve: false),
                                        icon: const Icon(Icons.close, size: 16),
                                        label: const Text('Reject Claim'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : AsyncBody<List<AlumniVerificationItem>>(
                    value: verificationsAsync,
                    onRetry: () => ref.invalidate(alumniVerificationsProvider),
                    isEmpty: (l) => l.isEmpty,
                    emptyMessage: statusFilter == 'duplicates'
                        ? 'No duplicate flags detected.'
                        : (statusFilter == 'pending'
                            ? 'No pending alumni registrations to review.'
                            : 'No alumni profiles found matching this filter.'),
                    emptyIcon: statusFilter == 'duplicates'
                        ? Icons.check_circle_outline
                        : Icons.verified_user_outlined,
                    data: (list) {
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 32),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final item = list[index];
                          final isPending = item.verificationStatus == 'pending';
                          final isVerified = item.verificationStatus == 'verified';
                          final isDuplicateFlag = item.possibleDuplicateOf != null ||
                              item.duplicateReviewStatus == 'pending';

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDuplicateFlag
                                    ? AppColors.warning
                                    : (isPending
                                        ? AppColors.gold.withAlpha(160)
                                        : AppColors.line),
                                width: (isDuplicateFlag || isPending) ? 1.5 : 1.0,
                              ),
                            ),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: isDuplicateFlag
                                            ? AppColors.tint(AppColors.warning, 0.2)
                                            : (isVerified
                                                ? AppColors.tint(AppColors.success, 0.15)
                                                : (isPending
                                                    ? AppColors.tint(AppColors.gold, 0.2)
                                                    : AppColors.tint(AppColors.danger, 0.15))),
                                        child: Icon(
                                          isDuplicateFlag
                                              ? Icons.warning_amber
                                              : (isVerified
                                                  ? Icons.verified
                                                  : (isPending
                                                      ? Icons.hourglass_top
                                                      : Icons.cancel_outlined)),
                                          color: isDuplicateFlag
                                              ? AppColors.warning
                                              : (isVerified
                                                  ? AppColors.success
                                                  : (isPending
                                                      ? AppColors.navy
                                                      : AppColors.danger)),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  item.fullName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16,
                                                    color: AppColors.navy,
                                                  ),
                                                ),
                                                _StatusBadge(
                                                    status: isDuplicateFlag
                                                        ? 'DUPLICATE REVIEW'
                                                        : item.verificationStatus),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${item.departmentName ?? "IIT (ISM)"} • Batch of ${item.batchYear ?? "N/A"}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: AppColors.ink,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Admission / Roll No: ${item.admissionNo ?? "Not provided"}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),

                                  // Contact & Career Grid
                                  KvGrid(
                                    [
                                      ('Email', item.email),
                                      (
                                        'Phone / WhatsApp',
                                        '${item.contactNo ?? "-"} / ${item.whatsappNo ?? "-"}'
                                      ),
                                      (
                                        'Designation & Org',
                                        '${item.currentPosition ?? "-"} at ${item.organisation ?? "-"}'
                                      ),
                                      (
                                        'Location',
                                        '${item.city ?? "-"}, ${item.state ?? "-"}'
                                      ),
                                      ('Registered On', fmtDateTime(item.createdAt)),
                                      if (item.possibleDuplicateOf != null)
                                        ('Matched Profile ID', item.possibleDuplicateOf!),
                                    ],
                                    width: 180,
                                  ),
                                  const SizedBox(height: 14),

                                  // Action Buttons
                                  if (isDuplicateFlag) ...[
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.tint(AppColors.warning, 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.info_outline,
                                              size: 16, color: AppColors.warning),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Flagged: Matches existing alumnus with same Name, Department & Batch Year. Review identity carefully before merging or clearing.',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.ink),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.success,
                                            side: const BorderSide(
                                                color: AppColors.success),
                                          ),
                                          onPressed: busy
                                              ? null
                                              : () => onResolveDuplicate(item,
                                                  action: 'clear'),
                                          icon: const Icon(Icons.person_add,
                                              size: 16),
                                          label:
                                              const Text('Not a Duplicate'),
                                        ),
                                        const SizedBox(width: 8),
                                        if (item.possibleDuplicateOf != null) ...[
                                          FilledButton.tonalIcon(
                                            onPressed: busy
                                                ? null
                                                : () => onResolveDuplicate(item,
                                                    action: 'merge',
                                                    masterId:
                                                        item.possibleDuplicateOf),
                                            icon: const Icon(Icons.merge_type,
                                                size: 16),
                                            label: const Text('Merge Account'),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.danger,
                                            side: const BorderSide(
                                                color: AppColors.danger),
                                          ),
                                          onPressed: busy
                                              ? null
                                              : () => onResolveDuplicate(item,
                                                  action: 'reject'),
                                          icon: const Icon(Icons.block, size: 16),
                                          label: const Text('Reject Duplicate'),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (isPending || !isVerified)
                                          FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: AppColors.success,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed:
                                                busy ? null : () => onVerify(item),
                                            icon: const Icon(
                                                Icons.check_circle_outline,
                                                size: 16),
                                            label: const Text('Verify Alumnus'),
                                          ),
                                        const SizedBox(width: 8),
                                        if (isPending || isVerified)
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.danger,
                                              side: const BorderSide(
                                                  color: AppColors.danger),
                                            ),
                                            onPressed:
                                                busy ? null : () => onReject(item),
                                            icon: const Icon(Icons.close,
                                                size: 16),
                                            label: const Text('Reject'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'verified':
        bg = AppColors.tint(AppColors.success, 0.15);
        fg = AppColors.success;
        label = 'VERIFIED';
        break;
      case 'rejected':
        bg = AppColors.tint(AppColors.danger, 0.15);
        fg = AppColors.danger;
        label = 'REJECTED';
        break;
      case 'duplicate review':
        bg = AppColors.tint(AppColors.warning, 0.2);
        fg = const Color(0xFFB45309);
        label = 'DUPLICATE REVIEW';
        break;
      default:
        bg = AppColors.tint(AppColors.gold, 0.2);
        fg = const Color(0xFF8A641A);
        label = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withAlpha(120)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: fg,
            letterSpacing: 0.5),
      ),
    );
  }
}
