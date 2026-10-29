import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/booking.dart';
import '../../viewmodels/busy.dart';
import '../theme/app_colors.dart';
import '../utils/errors.dart';

/// Neutral monogram until the authorised institute logo is supplied in
/// assets/branding/logo.png.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.onDark = true});
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(size * 0.05),
      child: Image.asset(
        'assets/branding/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            'ISM',
            style: TextStyle(
              color: onDark ? AppColors.navy : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.32,
            ),
          ),
        ),
      ),
    );
  }
}

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.backTo,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  /// When set, shows a back button that returns here.
  final String? backTo;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Padding(
          padding:
              EdgeInsets.fromLTRB(narrow ? 12 : 24, 16, narrow ? 12 : 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (backTo != null)
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(backTo!),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: AppColors.navy)),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: const TextStyle(color: AppColors.muted)),
                      ],
                    ),
                  ),
                  if (actions.isNotEmpty)
                    Flexible(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: actions,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.accent = false,
  });
  final String title;
  final Widget child;
  final Widget? trailing;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent ? AppColors.gold : AppColors.line,
          width: accent ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060B2545),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (accent)
                Container(
                  width: 4,
                  height: 18,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.navy, fontWeight: FontWeight.w700)),
              ),
              if (trailing != null) trailing!,
            ]),
            const Divider(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

/// Label/value pairs laid out in a wrapping grid.
class KvGrid extends StatelessWidget {
  const KvGrid(this.items, {super.key, this.width = 250});
  final List<(String, String)> items;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 12,
      children: [
        for (final (k, v) in items)
          SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        letterSpacing: 0.2)),
                const SizedBox(height: 2),
                SelectableText(v.isEmpty ? '-' : v,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String status;
  final String? label;

  static Color colorFor(String s) {
    switch (s) {
      case 'approved':
      case 'published':
      case 'simulated_success':
        return AppColors.success;
      case 'rejected':
      case 'simulated_failed':
        return AppColors.danger;
      case 'awaiting_approval':
        return AppColors.info;
      case 'pending':
      case 'draft':
        return AppColors.warning;
      case 'completed':
        return AppColors.navyLight;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tint(c),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tint(c, 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          Text(
            label ?? RequestStatus.label(status),
            style:
                TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
}

class EmptyView extends StatelessWidget {
  const EmptyView(
      {super.key, required this.message, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: AppColors.line),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 44, color: AppColors.danger),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry')),
            ],
          ]),
        ),
      );
}

/// Renders loading / error / empty / data states for an AsyncValue.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.emptyMessage = 'Nothing to show yet.',
    this.emptyIcon = Icons.inbox_outlined,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: friendlyError(e), onRetry: onRetry),
      data: (d) => (isEmpty?.call(d) ?? false)
          ? EmptyView(message: emptyMessage, icon: emptyIcon)
          : data(d),
    );
  }
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        backgroundColor: AppColors.success,
        content: Text(message, style: const TextStyle(color: Colors.white))));
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 6),
        content: Text(message, style: const TextStyle(color: Colors.white))));
}

void showOutcome(BuildContext context, Outcome o, {String? fallback}) {
  if (o.ok) {
    final m = o.message ?? fallback;
    if (m != null) showSuccess(context, m);
  } else {
    showError(context, o.error!);
  }
}

Future<DateTime?> pickDate(BuildContext context, DateTime? initial,
    {DateTime? first, DateTime? last}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: first ?? DateTime(now.year - 3),
    lastDate: last ?? DateTime(now.year + 3),
  );
}

Future<DateTime?> pickDateTime(BuildContext context, DateTime? initial) async {
  final now = DateTime.now();
  final d = await showDatePicker(
    context: context,
    initialDate: initial ?? now.add(const Duration(days: 2)),
    firstDate: now,
    lastDate: DateTime(now.year + 3),
  );
  if (d == null || !context.mounted) return null;
  final t = await showTimeOfDay(context, initial);
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

Future<TimeOfDay?> showTimeOfDay(BuildContext context, DateTime? initial) =>
    showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );

Future<bool> confirmDialog(BuildContext context,
    {required String title,
    required String message,
    String confirm = 'Confirm'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(confirm)),
      ],
    ),
  );
  return r ?? false;
}
