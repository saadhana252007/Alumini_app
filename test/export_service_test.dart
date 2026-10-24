import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:alumini_app/data/services/export_service.dart';
import 'package:alumini_app/data/services/report_table.dart';

void main() {
  final table = ReportBuilder.bookingRegister(
    [
      {
        'reference': 'EDC-2026-000001',
        'visitor_name': 'Dr. A & B <Test>',
        'organization': 'IIT',
        'visitor_category': 'D',
        'visitor_sub_category': '',
        'room_type': 'standard',
        'num_rooms': 1,
        'persons_lodging': 1,
        'arrival_at': '2026-11-03T08:30:00Z',
        'departure_at': '2026-11-05T08:30:00Z',
        'status': 'approved',
        'allotted_room_no': '204',
        'amount': 2400,
        'payment_status': 'simulated_success',
      }
    ],
    filters: {'Period': 'any'},
    generatedBy: 'Tester',
  );

  test('register has clear headings and no personal contact columns', () {
    expect(table.headers, contains('Booking ref'));
    expect(table.headers.any((h) => h.toLowerCase().contains('mobile')), isFalse);
    expect(table.headers.any((h) => h.toLowerCase().contains('mail')), isFalse);
    expect(table.rows.single.first, 'EDC-2026-000001');
  });

  test('ODS is a zip starting with the uncompressed mimetype entry', () {
    final bytes = ExportService().buildOds(table);
    expect(bytes.sublist(0, 2), [0x50, 0x4B]); // "PK"
    expect(String.fromCharCodes(bytes.sublist(30, 38)), 'mimetype');
  });

  test('XLSX and PDF produce non-empty files', () async {
    final svc = ExportService();
    expect(svc.buildXlsx(table).length, greaterThan(1000));
    final Uint8List pdf = await svc.buildPdf(table);
    expect(String.fromCharCodes(pdf.sublist(0, 4)), '%PDF');
  });
}
