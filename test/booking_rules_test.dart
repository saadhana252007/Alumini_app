import 'package:flutter_test/flutter_test.dart';
import 'package:alumini_app/data/models/booking.dart';

RequestDraft valid(DateTime now) {
  return RequestDraft()
    ..visitorName = 'A Visitor'
    ..address = 'Dhanbad'
    ..mobile = '9999999999'
    ..indenterName = 'Indenter'
    ..arrivalAt = now.add(const Duration(days: 2))
    ..departureAt = now.add(const Duration(days: 4));
}

void main() {
  final now = DateTime(2026, 11, 1, 10);

  group('RequestDraft.validate', () {
    test('accepts a valid draft', () {
      expect(valid(now).validate(now), isNull);
    });

    test('requires 24 hours notice', () {
      final d = valid(now)..arrivalAt = now.add(const Duration(hours: 23));
      expect(d.validate(now), contains('24 hours'));
    });

    test('departure must follow arrival', () {
      final d = valid(now)..departureAt = d0(now);
      expect(d.validate(now), contains('Departure'));
    });

    test('max two persons per room, children under 12 excluded', () {
      final d = valid(now)
        ..numRooms = 1
        ..personsLodging = 3;
      expect(d.validate(now), contains('2 persons'));
      d.childrenUnder12 = 1;
      expect(d.validate(now), isNull);
    });

    test('personal stays over 3 days need prior approval', () {
      final d = valid(now)
        ..purpose = 'personal'
        ..departureAt = now.add(const Duration(days: 7));
      expect(d.validate(now), contains('3 days'));
      d.extendedStayApproved = true;
      expect(d.validate(now), isNull);
    });

    test('student guests must be forwarded by DSW', () {
      final d = valid(now)..isStudentGuest = true;
      expect(d.validate(now), contains('DSW'));
      d.forwardedByDsw = true;
      expect(d.validate(now), isNull);
    });

    test('category E needs a sub-type', () {
      final d = valid(now)..category = 'E';
      expect(d.validate(now), contains('Category E'));
      d.subCategory = 'a';
      expect(d.validate(now), isNull);
    });
  });

  group('RequestStatus.canTransition', () {
    test('allows the documented flow', () {
      expect(
          RequestStatus.canTransition('pending', 'awaiting_approval'), isTrue);
      expect(
          RequestStatus.canTransition('awaiting_approval', 'approved'), isTrue);
      expect(RequestStatus.canTransition('approved', 'completed'), isTrue);
      expect(RequestStatus.canTransition('approved', 'cancelled'), isTrue);
    });

    test('blocks invalid transitions', () {
      expect(RequestStatus.canTransition('rejected', 'approved'), isFalse);
      expect(RequestStatus.canTransition('approved', 'pending'), isFalse);
      expect(RequestStatus.canTransition('completed', 'cancelled'), isFalse);
      expect(RequestStatus.canTransition('pending', 'completed'), isFalse);
    });
  });
}

DateTime d0(DateTime now) => now.add(const Duration(days: 1));
