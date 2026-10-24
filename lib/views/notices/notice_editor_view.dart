import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/notice.dart';
import '../../viewmodels/notice_viewmodel.dart';

class NoticeEditorView extends ConsumerWidget {
  const NoticeEditorView({super.key, this.noticeId});
  final String? noticeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (noticeId == null) {
      return const PageScaffold(
          title: 'New notice', backTo: '/notices', child: _NoticeForm());
    }
    final n = ref.watch(noticeByIdProvider(noticeId!));
    return PageScaffold(
      title: 'Edit notice',
      backTo: '/notices',
      child: AsyncBody<Notice>(
        value: n,
        onRetry: () => ref.invalidate(noticeByIdProvider(noticeId!)),
        data: (notice) => _NoticeForm(existing: notice),
      ),
    );
  }
}

class _NoticeForm extends ConsumerStatefulWidget {
  const _NoticeForm({this.existing});
  final Notice? existing;
  @override
  ConsumerState<_NoticeForm> createState() => _NoticeFormState();
}

class _NoticeFormState extends ConsumerState<_NoticeForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late String _category;
  late DateTime _publish;
  DateTime? _expiry;
  late String _status;
  Uint8List? _imageBytes;
  String? _imageExt;
  bool _removeImage = false;

  @override
  void initState() {
    super.initState();
    final n = widget.existing;
    _title = TextEditingController(text: n?.title ?? '');
    _desc = TextEditingController(text: n?.description ?? '');
    _category = n?.category ?? noticeCategories.first;
    _publish = n?.publishDate ?? DateTime.now();
    _expiry = n?.expiryDate;
    _status = n?.status ?? 'draft';
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) showError(context, 'Image must be smaller than 5 MB.');
      return;
    }
    final dot = x.name.lastIndexOf('.');
    setState(() {
      _imageBytes = bytes;
      _imageExt = dot < 0 ? 'jpg' : x.name.substring(dot + 1);
      _removeImage = false;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final o = await ref.read(noticeActionsProvider.notifier).save(
          existing: widget.existing,
          title: _title.text,
          description: _desc.text,
          category: _category,
          publishDate: _publish,
          expiryDate: _expiry,
          status: _status,
          imageBytes: _imageBytes,
          imageExt: _imageExt,
          removeImage: _removeImage,
        );
    if (!mounted) return;
    showOutcome(context, o);
    if (o.ok) context.go('/notices');
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(noticeActionsProvider).busy;
    final existingUrl = widget.existing?.imageUrl;

    Widget preview;
    if (_imageBytes != null) {
      preview = Image.memory(_imageBytes!, fit: BoxFit.cover);
    } else if (existingUrl != null && !_removeImage) {
      preview = Image.network(existingUrl, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));
    } else {
      preview = const Center(child: Icon(Icons.image_outlined, size: 40, color: AppColors.gold));
    }

    return Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        SectionCard(
          title: 'Notice details',
          child: Column(children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'Enter at least 3 characters' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _desc,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 14, runSpacing: 14, children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in noticeCategories) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
              ),
              _DateButton(
                label: 'Publication date',
                value: _publish,
                onPick: () async {
                  final d = await pickDate(context, _publish);
                  if (d != null) setState(() => _publish = d);
                },
              ),
              _DateButton(
                label: 'Expiry date (optional)',
                value: _expiry,
                onPick: () async {
                  final d = await pickDate(context, _expiry ?? _publish);
                  if (d != null) setState(() => _expiry = d);
                },
                onClear: _expiry == null ? null : () => setState(() => _expiry = null),
              ),
            ]),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String>(
                segments: [
                  for (final e in noticeStatuses.entries)
                    ButtonSegment(value: e.key, label: Text(e.value)),
                ],
                selected: {_status},
                onSelectionChanged: (s) => setState(() => _status = s.first),
              ),
            ),
          ]),
        ),
        SectionCard(
          title: 'Poster / image',
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                  width: 160, height: 160, color: AppColors.goldSoft, child: preview),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('JPG, PNG or WebP up to 5 MB. Stored privately in Supabase Storage.',
                    style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload),
                      label: const Text('Choose image')),
                  if (_imageBytes != null || (existingUrl != null && !_removeImage))
                    TextButton(
                      onPressed: () => setState(() {
                        _imageBytes = null;
                        _removeImage = true;
                      }),
                      child: const Text('Remove'),
                    ),
                ]),
              ]),
            ),
          ]),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: busy
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(widget.existing == null ? 'Create notice' : 'Save changes'),
          ),
        ),
      ]),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.value, required this.onPick, this.onClear});
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: InkWell(
        onTap: onPick,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: onClear == null
                ? const Icon(Icons.calendar_today, size: 18)
                : IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: onClear),
          ),
          child: Text(value == null ? 'Not set' : fmtDate(value)),
        ),
      ),
    );
  }
}
