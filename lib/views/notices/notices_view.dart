import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/notice.dart';
import '../../viewmodels/notice_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';

class NoticesView extends ConsumerWidget {
  const NoticesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(noticeFilterProvider);
    final notices = ref.watch(noticesProvider);
    final canManage = ref.can(Perm.noticeManage);
    final notifier = ref.read(noticeFilterProvider.notifier);

    return PageScaffold(
      title: 'Notices & posters',
      subtitle:
          'Institutional announcements visible to authorised administrators',
      actions: [
        if (canManage)
          FilledButton.icon(
            onPressed: () => context.go('/notices/new'),
            icon: const Icon(Icons.add),
            label: const Text('New notice'),
          ),
      ],
      child: Column(children: [
        Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(
                      hintText: 'Search title', prefixIcon: Icon(Icons.search)),
                  onChanged: notifier.setQuery,
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  value: filter.status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    for (final e in noticeStatuses.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: notifier.setStatus,
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String?>(
                  value: filter.category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    for (final c in noticeCategories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: notifier.setCategory,
                ),
              ),
            ]),
        const SizedBox(height: 12),
        Expanded(
          child: AsyncBody<List<Notice>>(
            value: notices,
            onRetry: () => ref.invalidate(noticesProvider),
            isEmpty: (l) => l.isEmpty,
            emptyMessage: 'No notices match these filters.',
            emptyIcon: Icons.campaign_outlined,
            data: (list) => RefreshIndicator(
              onRefresh: () async => ref.refresh(noticesProvider.future),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: list.length,
                itemBuilder: (_, i) =>
                    _NoticeCard(notice: list[i], canManage: canManage),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _NoticeCard extends ConsumerWidget {
  const _NoticeCard({required this.notice, required this.canManage});
  final Notice notice;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notice;
    final vm = ref.read(noticeActionsProvider.notifier);

    Future<void> change(String status) async {
      final o = await vm.setStatus(n, status);
      if (context.mounted) showOutcome(context, o);
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.line)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 96,
              height: 96,
              child: n.imageUrl == null
                  ? Container(
                      color: AppColors.goldSoft,
                      child: const Icon(Icons.image_outlined,
                          color: AppColors.gold))
                  : Image.network(n.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: AppColors.canvas,
                          child: const Icon(Icons.broken_image_outlined))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(n.status, label: noticeStatuses[n.status]),
                    Chip(
                      label: Text(n.category,
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    if (n.isExpired && n.status == 'published')
                      const Text('Expired',
                          style:
                              TextStyle(color: AppColors.danger, fontSize: 12)),
                  ]),
              const SizedBox(height: 6),
              Text(n.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.navy)),
              if (n.description.isNotEmpty)
                Text(n.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 6),
              Text(
                'Published ${fmtDate(n.publishDate)}'
                '${n.expiryDate == null ? '' : ' - expires ${fmtDate(n.expiryDate)}'}'
                ' - by ${n.createdByName ?? 'unknown'}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ]),
          ),
          if (canManage)
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    context.go('/notices/${n.id}/edit');
                  case 'publish':
                    change('published');
                  case 'unpublish':
                    change('draft');
                  case 'archive':
                    change('archived');
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (n.status != 'published')
                  const PopupMenuItem(value: 'publish', child: Text('Publish')),
                if (n.status == 'published')
                  const PopupMenuItem(
                      value: 'unpublish', child: Text('Unpublish')),
                if (n.status != 'archived')
                  const PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
            ),
        ]),
      ),
    );
  }
}
