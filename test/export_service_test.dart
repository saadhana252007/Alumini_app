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
    expect(
        table.headers.any((h) => h.toLowerCase().contains('mobile')), isFalse);
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

  test('approvalReport builds valid headers, rows, and exports correctly',
      () async {
    final approvalTable = ReportBuilder.approvalReport(
      [
        {
          'reference': 'EDC-2026-000002',
          'visitor_name': 'Alumni Guest',
          'room_type': 'suite',
          'stage_order': 1,
          'stage_name': 'Final Approval',
          'authority_label': 'EDC Administration',
          'step_status': 'approved',
          'decided_by': 'Admin',
          'decided_at': '2026-11-04T10:00:00Z',
          'reason': 'Room 101 allotted',
        },
        {
          'reference': 'EDC-2026-000003',
          'visitor_name': 'Rejected Applicant',
          'room_type': 'standard',
          'stage_order': 1,
          'stage_name': 'Review Decision',
          'authority_label': 'EDC Administration',
          'step_status': 'rejected',
          'decided_by': 'Admin',
          'decided_at': '2026-11-04T11:00:00Z',
          'reason': 'No vacancy',
        },
      ],
      filters: {'Period': 'any'},
      generatedBy: 'Admin',
    );

    expect(approvalTable.headers, contains('Booking ref'));
    expect(approvalTable.headers, contains('Decision'));
    expect(approvalTable.rows.length, 2);
    expect(approvalTable.rows[0][0], 'EDC-2026-000002');
    expect(approvalTable.rows[0][6], 'Approved');
    expect(approvalTable.rows[1][6], 'Rejected');

    final svc = ExportService();
    expect(svc.buildXlsx(approvalTable).length, greaterThan(1000));
    final Uint8List pdf = await svc.buildPdf(approvalTable);
    expect(String.fromCharCodes(pdf.sublist(0, 4)), '%PDF');
    final odsBytes = svc.buildOds(approvalTable);
    expect(odsBytes.sublist(0, 2), [0x50, 0x4B]);
  });

  test(
      'alumniDirectory builds valid headers, rows, and exports XLSX, ODS, and PDF',
      () async {
    final alumniTable = ReportBuilder.alumniDirectory(
      [
        {
          'full_name': 'Aryan Jha',
          'admission_no': '20JE0001',
          'department_name': 'Computer Science & Engineering',
          'batch_year': 2024,
          'verification_status': 'verified',
          'email': 'aryanjha@gmail.com',
          'contact_no': '+919876543210',
          'organisation': 'Google',
          'current_position': 'Software Engineer',
          'city': 'Bengaluru',
          'created_at': '2026-10-25T10:00:00Z',
        },
        {
          'full_name': 'Pending Alumnus',
          'admission_no': '21JE0222',
          'department_name': 'Mining Engineering',
          'batch_year': 2025,
          'verification_status': 'pending',
          'email': 'pending@iitism.ac.in',
          'contact_no': '+919811122233',
          'organisation': 'IIT (ISM)',
          'current_position': 'Student',
          'city': 'Dhanbad',
          'created_at': '2026-10-26T12:00:00Z',
        },
      ],
      filters: {'Verification status': 'ALL'},
      generatedBy: 'Admin',
    );

    expect(alumniTable.headers, contains('Full Name'));
    expect(alumniTable.headers, contains('Verification'));
    expect(alumniTable.rows.length, 2);
    expect(alumniTable.rows[0][0], 'Aryan Jha');
    expect(alumniTable.rows[0][4], 'VERIFIED');
    expect(alumniTable.rows[1][4], 'PENDING');

    final svc = ExportService();
    expect(svc.buildXlsx(alumniTable).length, greaterThan(1000));
    final Uint8List pdf = await svc.buildPdf(alumniTable);
    expect(String.fromCharCodes(pdf.sublist(0, 4)), '%PDF');
    final odsBytes = svc.buildOds(alumniTable);
    expect(odsBytes.sublist(0, 2), [0x50, 0x4B]);
  });
}
