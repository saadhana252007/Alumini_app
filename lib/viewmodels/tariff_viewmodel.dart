import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../data/models/tariff.dart';
import 'busy.dart';

final tariffRulesProvider = FutureProvider.autoDispose<List<TariffRule>>(
    (ref) => ref.watch(tariffRepositoryProvider).rules());

final gstPercentProvider = FutureProvider.autoDispose<double>(
    (ref) => ref.watch(tariffRepositoryProvider).gstPercent());

class TariffActionsViewModel extends BusyNotifier {
  Future<Outcome> updateRule(TariffRule r,
          {double? rate,
          required String unit,
          required bool active,
          String? note}) =>
      run(() async {
        if ((unit == 'per_day' || unit == 'per_month') &&
            (rate == null || rate < 0)) {
          throw Exception(
              'Enter a valid rate for per-day / per-month tariffs.');
        }
        await ref.read(tariffRepositoryProvider).updateRule(r.id,
            rate: unit == 'free' ? 0 : rate,
            unit: unit,
            active: active,
            note: note);
        ref.invalidate(tariffRulesProvider);
        return 'Tariff rule updated.';
      });

  Future<Outcome> setGst(double percent) => run(() async {
        if (percent < 0 || percent > 100)
          throw Exception('GST must be between 0 and 100.');
        await ref.read(tariffRepositoryProvider).setGst(percent);
        ref.invalidate(gstPercentProvider);
        return 'GST percentage updated.';
      });
}

final tariffActionsProvider =
    NotifierProvider<TariffActionsViewModel, BusyState>(
        TariffActionsViewModel.new);
