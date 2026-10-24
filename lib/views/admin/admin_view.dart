import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/booking.dart';
import '../../data/models/profile.dart';
import '../../data/models/tariff.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';

/// Super-admin tools: accounts, role permissions, approval workflow, audit log.
class AdminView extends ConsumerWidget {
  const AdminView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffold(
      title: 'Administration',
      subtitle: 'Accounts, permissions and approval configuration',
      child: DefaultTabController(
        length: 4,
        child: Column(children: [
          const TabBar(
            isScrollable: true,
            labelColor: AppColors.navy,
            indicatorColor: AppColors.gold,
            tabs: [
              Tab(text: 'Accounts'),
              Tab(text: 'Permissions'),
              Tab(text: 'Approval workflow'),
              Tab(text: 'Audit log'),
            ],
          ),
          const SizedBox(height: 12),
          const Expanded(
            child: TabBarView(children: [
              _AccountsTab(),
              _PermissionsTab(),
              _WorkflowTab(),
              _AuditTab(),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _AccountsTab extends ConsumerWidget {
  const _AccountsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final me = ref.session?.profile.id;
    final vm = ref.read(adminActionsProvider.notifier);

    return Column(children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          icon: const Icon(Icons.person_add),
          label: const Text('Add administrator'),
          onPressed: () async {
            final res = await showDialog<_NewAdmin>(
                context: context, builder: (_) => const _AddAdminDialog());
            if (res == null) return;
            final o = await vm.createAdmin(
                email: res.email, fullName: res.name, role: res.role, password: res.password);
            if (context.mounted) showOutcome(context, o);
          },
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: AsyncBody<List<Profile>>(
          value: profiles,
          onRetry: () => ref.invalidate(profilesProvider),
          isEmpty: (l) => l.isEmpty,
          data: (list) => ListView(children: [
            for (final p in list)
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.line)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 260,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(p.email, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                        ]),
                      ),
                      SizedBox(
                        width: 190,
                        child: DropdownButtonFormField<String>(
                          value: p.role.db,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: [
                            for (final r in AdminRole.values)
                              DropdownMenuItem(value: r.db, child: Text(r.label)),
                          ],
                          onChanged: p.id == me
                              ? null
                              : (v) async {
                                  if (v == null || v == p.role.db) return;
                                  final o = await vm.updateProfile(p.id, role: v);
                                  if (context.mounted) showOutcome(context, o);
                                },
                        ),
                      ),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Active'),
                        Switch(
                          value: p.isActive,
                          onChanged: p.id == me
                              ? null
                              : (v) async {
                                  final o = await vm.updateProfile(p.id, isActive: v);
                                  if (context.mounted) showOutcome(context, o);
                                },
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _NewAdmin {
  const _NewAdmin(this.name, this.email, this.role, this.password);
  final String name;
  final String email;
  final String role;
  final String password;
}

class _AddAdminDialog extends StatefulWidget {
  const _AddAdminDialog();
  @override
  State<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<_AddAdminDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  String _role = 'edc_admin';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add administrator'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Institute e-mail')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                for (final r in AdminRole.values)
                  DropdownMenuItem(value: r.db, child: Text(r.label)),
              ],
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pw,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Initial password (min 12 characters)'),
            ),
            const SizedBox(height: 8),
            const Text('Share the initial password through a secure channel.',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, _NewAdmin(_name.text, _email.text, _role, _pw.text)),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _PermissionsTab extends ConsumerWidget {
  const _PermissionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(rolePermissionsProvider);
    final vm = ref.read(adminActionsProvider.notifier);
    return AsyncBody<Map<String, Set<String>>>(
      value: perms,
      onRetry: () => ref.invalidate(rolePermissionsProvider),
      data: (m) => SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Permissions are enforced by the database (RLS and security-definer functions). '
            'Changes take effect at the next sign-in or refresh.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Permission')),
                for (final r in AdminRole.values) DataColumn(label: Text(r.label)),
              ],
              rows: [
                for (final e in Perm.all.entries)
                  DataRow(cells: [
                    DataCell(Text(e.value)),
                    for (final r in AdminRole.values)
                      DataCell(Checkbox(
                        value: m[r.db]?.contains(e.key) ?? false,
                        onChanged: (r == AdminRole.superAdmin && e.key == Perm.adminManage)
                            ? null
                            : (v) async {
                                final o = await vm.setPermission(r.db, e.key, v ?? false);
                                if (context.mounted && !o.ok) showOutcome(context, o);
                              },
                      )),
                  ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _WorkflowTab extends ConsumerWidget {
  const _WorkflowTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wf = ref.watch(workflowsProvider);
    final vm = ref.read(adminActionsProvider.notifier);

    Future<void> edit({ApprovalStage? stage, required String roomType, required int nextOrder}) async {
      final res = await showDialog<_StageEdit>(
          context: context,
          builder: (_) => _StageDialog(stage: stage, roomType: roomType, nextOrder: nextOrder));
      if (res == null) return;
      final o = await vm.saveStage(
          id: stage?.id,
          roomType: roomType,
          order: res.order,
          name: res.name,
          authority: res.authority,
          role: res.role,
          active: res.active);
      if (context.mounted) showOutcome(context, o);
    }

    return AsyncBody<List<ApprovalStage>>(
      value: wf,
      onRetry: () => ref.invalidate(workflowsProvider),
      data: (all) => ListView(children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Approval authority is configured separately for Suite and Standard Room requests. '
            'Each new request snapshots these stages; changes do not affect requests already submitted. '
            'The form lists Dean (Administration) for non-suite rooms and Director / Deputy Director for '
            'suites - confirm delegation with the institute.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
        for (final room in roomTypes.entries)
          SectionCard(
            title: '${room.value} approval stages',
            trailing: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add stage'),
              onPressed: () {
                final stages = all.where((s) => s.roomType == room.key);
                final next = stages.isEmpty
                    ? 1
                    : stages.map((s) => s.stageOrder).reduce((a, b) => a > b ? a : b) + 1;
                edit(roomType: room.key, nextOrder: next);
              },
            ),
            child: Column(children: [
              for (final s in all.where((s) => s.roomType == room.key))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: s.isActive ? AppColors.navy : AppColors.line,
                      child: Text('${s.stageOrder}',
                          style: const TextStyle(color: Colors.white, fontSize: 12))),
                  title: Text(s.stageName),
                  subtitle: Text(
                      '${s.authorityLabel}\nApprover role: ${roleLabels[s.approverRole]}${s.isActive ? '' : ' (inactive)'}'),
                  isThreeLine: true,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => edit(stage: s, roomType: room.key, nextOrder: s.stageOrder)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: 'Remove stage',
                            message: 'Remove "${s.stageName}" from the ${room.value} workflow?',
                            confirm: 'Remove');
                        if (!ok) return;
                        final o = await vm.deleteStage(s.id);
                        if (context.mounted) showOutcome(context, o);
                      },
                    ),
                  ]),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _StageEdit {
  const _StageEdit(this.order, this.name, this.authority, this.role, this.active);
  final int order;
  final String name;
  final String authority;
  final String role;
  final bool active;
}

class _StageDialog extends StatefulWidget {
  const _StageDialog({this.stage, required this.roomType, required this.nextOrder});
  final ApprovalStage? stage;
  final String roomType;
  final int nextOrder;
  @override
  State<_StageDialog> createState() => _StageDialogState();
}

class _StageDialogState extends State<_StageDialog> {
  late final _order = TextEditingController(text: '${widget.stage?.stageOrder ?? widget.nextOrder}');
  late final _name = TextEditingController(text: widget.stage?.stageName ?? '');
  late final _auth = TextEditingController(text: widget.stage?.authorityLabel ?? '');
  late String _role = widget.stage?.approverRole ?? 'dean_admin';
  late bool _active = widget.stage?.isActive ?? true;

  @override
  void dispose() {
    _order.dispose();
    _name.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.stage == null ? 'Add stage' : 'Edit stage'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Order')),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Stage name')),
            const SizedBox(height: 12),
            TextField(
                controller: _auth,
                decoration: const InputDecoration(labelText: 'Authority (as on the form)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Approver role'),
              items: [
                for (final r in AdminRole.values)
                  DropdownMenuItem(value: r.db, child: Text(r.label)),
              ],
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(
              context,
              _StageEdit(int.tryParse(_order.text.trim()) ?? 0, _name.text, _auth.text, _role, _active)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AuditTab extends ConsumerWidget {
  const _AuditTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(auditLogProvider);
    return AsyncBody<List<AuditEntry>>(
      value: log,
      onRetry: () => ref.invalidate(auditLogProvider),
      isEmpty: (l) => l.isEmpty,
      emptyMessage: 'No audit entries yet.',
      data: (list) => ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, i) {
          final a = list[i];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.history, size: 18, color: AppColors.muted),
            title: Text(a.description),
            subtitle: Text('${a.actorName ?? 'System'} - ${fmtDateTime(a.createdAt)}'),
          );
        },
      ),
    );
  }
}
