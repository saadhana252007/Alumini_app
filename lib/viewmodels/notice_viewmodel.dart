import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/utils/formatters.dart';
import '../data/models/notice.dart';
import 'busy.dart';
import 'dashboard_viewmodel.dart';

typedef NoticeFilter = ({String? status, String? category, String query});

class NoticeFilterNotifier extends Notifier<NoticeFilter> {
  @override
  NoticeFilter build() => (status: null, category: null, query: '');

  void setStatus(String? v) =>
      state = (status: v, category: state.category, query: state.query);
  void setCategory(String? v) =>
      state = (status: state.status, category: v, query: state.query);
  void setQuery(String v) =>
      state = (status: state.status, category: state.category, query: v);
  void clear() => state = (status: null, category: null, query: '');
}

final noticeFilterProvider =
    NotifierProvider<NoticeFilterNotifier, NoticeFilter>(NoticeFilterNotifier.new);

final noticesProvider = FutureProvider.autoDispose<List<Notice>>((ref) {
  final f = ref.watch(noticeFilterProvider);
  return ref
      .watch(noticeRepositoryProvider)
      .list(status: f.status, category: f.category, query: f.query);
});

final noticeByIdProvider = FutureProvider.autoDispose.family<Notice, String>(
    (ref, id) => ref.watch(noticeRepositoryProvider).get(id));

class NoticeActionsViewModel extends BusyNotifier {
  void _refresh() {
    ref.invalidate(noticesProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<Outcome> save({
    Notice? existing,
    required String title,
    required String description,
    required String category,
    required DateTime publishDate,
    DateTime? expiryDate,
    required String status,
    Uint8List? imageBytes,
    String? imageExt,
    bool removeImage = false,
  }) =>
      run(() async {
        if (title.trim().length < 3) {
          throw Exception('Title must be at least 3 characters.');
        }
        if (expiryDate != null && expiryDate.isBefore(publishDate)) {
          throw Exception('Expiry date cannot be before the publication date.');
        }
        final repo = ref.read(noticeRepositoryProvider);
        String? imagePath = existing?.imagePath;
        if (imageBytes != null) {
          imagePath = await repo.uploadImage(imageBytes, imageExt ?? 'jpg');
        } else if (removeImage) {
          imagePath = null;
        }
        final values = {
          'title': title.trim(),
          'description': description.trim(),
          'category': category,
          'publish_date': ymd(publishDate),
          'expiry_date': expiryDate == null ? null : ymd(expiryDate),
          'status': status,
          'image_path': imagePath,
        };
        if (existing == null) {
          await repo.create(values);
        } else {
          await repo.update(existing.id, values);
          final old = existing.imagePath;
          if (old != null && old != imagePath) await repo.removeImage(old);
        }
        _refresh();
        ref.invalidate(noticeByIdProvider);
        return existing == null ? 'Notice created.' : 'Notice updated.';
      });

  Future<Outcome> setStatus(Notice n, String status) => run(() async {
        await ref.read(noticeRepositoryProvider).setStatus(n.id, status);
        _refresh();
        return switch (status) {
          'published' => 'Notice published.',
          'archived' => 'Notice archived.',
          _ => 'Notice unpublished (draft).',
        };
      });
}

final noticeActionsProvider =
    NotifierProvider<NoticeActionsViewModel, BusyState>(NoticeActionsViewModel.new);
