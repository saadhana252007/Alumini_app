import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/constants.dart';
import '../../core/utils/file_saver.dart';
import '../../core/utils/formatters.dart';
import '../models/booking.dart';

class ReceiptPdfService {
  static final _navy = PdfColor.fromInt(0xFF0B2545);
  static final _gold = PdfColor.fromInt(0xFFB8963E);

  Future<String> download(RequestDetail d) async {
    final bytes = await build(d);
    return saveBytes(
      fileName: 'receipt-${d.request.reference}.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
    );
  }

  pw.Widget _kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(
              width: 120,
              child: pw.Text(k,
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
          pw.Expanded(child: pw.Text(v, style: const pw.TextStyle(fontSize: 9.5))),
        ]),
      );

  pw.Widget _section(String title) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12, bottom: 4),
        padding: const pw.EdgeInsets.only(bottom: 2),
        decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _gold, width: 0.8))),
        child: pw.Text(title,
            style: pw.TextStyle(
                fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _navy)),
      );

  Future<Uint8List> build(RequestDetail d) async {
    final r = d.request;
    final rc = d.receipt;
    final b = rc?.breakdown;
    final doc = pw.Document(
        title: 'Booking receipt ${r.reference}', author: 'IIT (ISM) Dhanbad - EDC');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Text(
          'Computer-generated prototype receipt. Any payment shown is SIMULATED - '
          'no real money has been transferred. Page ${ctx.pageNumber} of ${ctx.pagesCount}.',
          style: const pw.TextStyle(fontSize: 7.5),
        ),
        build: (ctx) => [
          pw.Center(
            child: pw.Column(children: [
              pw.Text('Indian Institute of Technology (Indian School of Mines), Dhanbad',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold, color: _navy)),
              pw.Text('Executive Development Centre',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 4),
              pw.Text('ACCOMMODATION BOOKING RECEIPT',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold, color: _gold)),
            ]),
          ),
          pw.Divider(color: _gold, thickness: 1.4),
          _kv('Receipt no.', rc?.receiptNo ?? '-'),
          _kv('Booking reference', r.reference),
          _kv('Issued on', fmtDateTime(rc?.issuedAt)),
          _kv('Booking status', RequestStatus.label(r.status)),

          _section('Visitor & booking'),
          _kv('Visitor', r.visitorName),
          _kv('Organisation', r.organization ?? '-'),
          _kv('Nationality', humanize(r.nationality)),
          _kv('Purpose', humanize(r.purpose)),
          _kv('Visitor category', visitorCategories[r.category]?.split(' - ').first ?? r.category),
          _kv('Room type', roomTypes[r.roomType] ?? r.roomType),
          _kv('Rooms / persons', '${r.numRooms} room(s), ${r.personsLodging} person(s) lodging'),
          _kv('Allotted room no.', r.allottedRoomNo ?? '-'),
          _kv('Arrival', fmtDateTime(r.arrivalAt)),
          _kv('Departure', fmtDateTime(r.departureAt)),
          _kv('Bills settled by',
              'Lodging: ${billingParties[r.lodgingBilledTo] ?? r.lodgingBilledTo}; Food: ${billingParties[r.foodBilledTo] ?? r.foodBilledTo}'),
          _kv('Indenter',
              '${r.indenterName}${r.indenterDepartment == null ? '' : ', ${r.indenterDepartment}'}'),

          _section('Charges'),
          if (b == null)
            pw.Text('No receipt has been issued yet.', style: const pw.TextStyle(fontSize: 9))
          else ...[
            _kv('Billable days', '${b.days}'),
            _kv('Tariff basis', humanize(b.unit)),
            _kv('Rate', b.unitRate == null ? '-' : fmtMoney(b.unitRate)),
            _kv('Subtotal', fmtMoney(b.subtotal, whenNull: 'To be determined')),
            _kv('GST @ ${b.gstPercent.toStringAsFixed(2)}%', fmtMoney(b.gst, whenNull: '-')),
            pw.SizedBox(height: 3),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              color: PdfColor.fromInt(0xFFF3EBD3),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      b.isFree ? 'Complimentary (Rs. 0.00)' : fmtMoney(b.total),
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            if (b.note != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(b.note!, style: const pw.TextStyle(fontSize: 8)),
              ),
          ],

          _section('Approval trail'),
          pw.TableHelper.fromTextArray(
            headers: const ['Stage', 'Authority', 'Decision', 'By', 'On'],
            data: d.steps
                .map((s) => [
                      '${s.stageOrder}. ${s.stageName}',
                      s.authorityLabel,
                      humanize(s.status),
                      s.decidedByName ?? '-',
                      fmtDateTime(s.decidedAt),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: _navy),
            cellStyle: const pw.TextStyle(fontSize: 8),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
          ),

          _section('Payment (prototype simulation)'),
          if (d.payments.isEmpty)
            pw.Text('No payment recorded.', style: const pw.TextStyle(fontSize: 9))
          else
            ...d.payments.map((p) => _kv(
                  fmtDateTime(p.createdAt),
                  '${p.isSuccess ? 'SIMULATED payment recorded' : 'SIMULATED payment failed'}: '
                  '${fmtMoney(p.amount)} via ${humanize(p.method)} (ref ${p.reference})',
                )),
          pw.SizedBox(height: 10),
          pw.Text(
            'Bookings are provisional and subject to availability. Check-in/check-out: 24 hrs. '
            'Consumption of narcotics/alcohol is strictly prohibited in EDC premises.',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
