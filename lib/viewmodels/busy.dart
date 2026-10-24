import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/errors.dart';

class BusyState {
  const BusyState({this.busy = false, this.error});
  final bool busy;
  final String? error;
}

/// Result of a ViewModel action: either a success message or an error.
class Outcome {
  const Outcome.ok([this.message]) : error = null;
  const Outcome.fail(this.error) : message = null;
  final String? message;
  final String? error;
  bool get ok => error == null;
}

/// Base class for ViewModels that run one async action at a time.
abstract class BusyNotifier extends Notifier<BusyState> {
  @override
  BusyState build() => const BusyState();

  /// Runs [action]; its returned string becomes the success message.
  Future<Outcome> run(Future<String?> Function() action) async {
    state = const BusyState(busy: true);
    try {
      final msg = await action();
      state = const BusyState();
      return Outcome.ok(msg);
    } catch (e) {
      final m = friendlyError(e);
      state = BusyState(error: m);
      return Outcome.fail(m);
    }
  }
}
