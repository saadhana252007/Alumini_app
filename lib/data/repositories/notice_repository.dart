import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/formatters.dart';
import '../models/notice.dart';

class NoticeRepository {
  NoticeRepository(this._c);
  final SupabaseClient _c;

  static const _select = '*, creator:profiles!created_by(full_name)';
  static const _bucket = 'notices';

  Future<List<Notice>> list({
    String? status,
    String? category,
    String query = '',
    bool activeOnly = false,
    int limit = 200,
  }) async {
    var q = _c.from('notices').select(_select);
    if (status != null) q = q.eq('status', status);
    if (category != null) q = q.eq('category', category);
    final term = sanitizeSearch(query);
    if (term.isNotEmpty) q = q.ilike('title', '%$term%');
    if (activeOnly) {
      final today = ymd(DateTime.now());
      q = q
          .lte('publish_date', today)
          .or('expiry_date.is.null,expiry_date.gte.$today');
    }
    final rows = await q
        .order('publish_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    final notices = rows.map(Notice.fromMap).toList();
    return Future.wait(notices.map(_withUrl));
  }

  Future<Notice> get(String id) async {
    final row = await _c.from('notices').select(_select).eq('id', id).single();
    return _withUrl(Notice.fromMap(row));
  }

  Future<Notice> _withUrl(Notice n) async {
    final p = n.imagePath;
    if (p == null) return n;
    try {
      final url = await _c.storage.from(_bucket).createSignedUrl(p, 3600);
      return n.copyWith(imageUrl: url);
    } catch (_) {
      return n;
    }
  }

  Future<String> uploadImage(Uint8List bytes, String ext) async {
    final uid = _c.auth.currentUser!.id;
    final clean = ext.toLowerCase().replaceAll('jpeg', 'jpg');
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$clean';
    final mime = clean == 'png'
        ? 'image/png'
        : clean == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    await _c.storage
        .from(_bucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    return path;
  }

  Future<void> removeImage(String path) async {
    try {
      await _c.storage.from(_bucket).remove([path]);
    } catch (_) {
      // Orphaned files are harmless; DB row is the source of truth.
    }
  }

  Future<void> create(Map<String, dynamic> values) async {
    await _c.from('notices').insert({
      ...values,
      'created_by': _c.auth.currentUser!.id,
    });
  }

  Future<void> update(String id, Map<String, dynamic> values) async {
    await _c.from('notices').update(values).eq('id', id);
  }

  Future<void> setStatus(String id, String status) => update(id, {'status': status});
}
