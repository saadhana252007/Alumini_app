import 'package:flutter_test/flutter_test.dart';
import 'package:alumini_app/data/models/tariff.dart';

TariffRule rule(String cat, String room, double? rate, String unit, {String sub = ''}) =>
    TariffRule(
      id: '$cat$sub$room',
      category: cat,
      subCategory: sub,
      roomType: room,
      rate: rate,
      billingUnit: unit,
      isActive: true,
    );

void main() {
  final rules = [
    rule('A', 'standard', 0, 'free'),
    rule('B', 'standard', 600, 'per_day'),
    rule('D', 'standard', 1200, 'per_day'),
    rule('D', 'suite', 2000, 'per_day'),
    rule('E', 'suite', 3000, 'per_day', sub: 'a'),
    rule('E', 'standard', null, 'unspecified', sub: 'a'),
    rule('E', 'standard', 4000, 'per_month', sub: 'b'),
    rule('E', 'standard', null, 'as_applicable', sub: 'c'),
  ];
  final arrival = DateTime(2026, 11, 1, 14);

  ChargeBreakdown calc(String cat, String room, int rooms, Duration stay,
          {String sub = '', double gst = 0}) =>
      TariffCalculator.calculate(
        rules: rules,
        category: cat,
        subCategory: sub,
        roomType: room,
        rooms: rooms,
        arrival: arrival,
        departure: arrival.add(stay),
        gstPercent: gst,
      );

  test('billable days round up and are at least one', () {
    expect(TariffCalculator.billableDays(arrival, arrival.add(const Duration(hours: 5))), 1);
    expect(TariffCalculator.billableDays(arrival, arrival.add(const Duration(hours: 24))), 1);
    expect(TariffCalculator.billableDays(arrival, arrival.add(const Duration(hours: 25))), 2);
  });

  test('Category A is free', () {
    final c = calc('A', 'standard', 1, const Duration(days: 3));
    expect(c.isFree, isTrue);
    expect(c.total, 0);
  });

  test('Category D standard: rate x days x rooms', () {
    final c = calc('D', 'standard', 2, const Duration(days: 3));
    expect(c.subtotal, 1200 * 3 * 2);
    expect(c.total, 7200);
  });

  test('GST is added on top of the subtotal', () {
    final c = calc('B', 'standard', 1, const Duration(days: 2), gst: 12);
    expect(c.subtotal, 1200);
    expect(c.gst, 144);
    expect(c.total, 1344);
  });

  test('Category E(a) suite uses the foreign-guest rate', () {
    expect(calc('E', 'suite', 1, const Duration(days: 1), sub: 'a').total, 3000);
  });

  test('missing policy is never invented', () {
    final std = calc('E', 'standard', 1, const Duration(days: 2), sub: 'a');
    expect(std.total, isNull);
    expect(std.isDetermined, isFalse);
    final lic = calc('E', 'standard', 1, const Duration(days: 2), sub: 'c');
    expect(lic.total, isNull);
  });

  test('monthly tariff is charged per started 30-day month', () {
    expect(calc('E', 'standard', 1, const Duration(days: 31), sub: 'b').total, 8000);
    expect(calc('E', 'standard', 1, const Duration(days: 10), sub: 'b').total, 4000);
  });
}
