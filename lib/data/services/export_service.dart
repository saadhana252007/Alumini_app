import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/file_saver.dart';
import 'report_table.dart';

enum ExportFormat {
  xlsx('xlsx', 'Excel (.xlsx)',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  ods('ods', 'OpenDocument (.ods)',
      'application/vnd.oasis.opendocument.spreadsheet'),
  pdf('pdf', 'PDF (.pdf)', 'application/pdf');

  const ExportFormat(this.ext, this.label, this.mime);
  final String ext;
  final String label;
  final String mime;
}

class ExportService {
  /// Builds the file and hands it to the platform saver. Returns where it went.
  Future<String> export(ReportTable table, ExportFormat format,
      {String baseName = 'edc-report'}) async {
    final bytes = switch (format) {
      ExportFormat.xlsx => buildXlsx(table),
      ExportFormat.ods => buildOds(table),
      ExportFormat.pdf => await buildPdf(table),
    };
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    return saveBytes(
      fileName: '$baseName-$stamp.${format.ext}',
      bytes: bytes,
      mimeType: format.mime,
    );
  }

  // ---------------------------------------------------------------- XLSX
  Uint8List buildXlsx(ReportTable t) {
    final book = Excel.createExcel();
    const sheetName = 'Report';
    book.rename('Sheet1', sheetName);
    final sheet = book[sheetName];

    sheet.appendRow([TextCellValue(t.title)]);
    for (final e in t.meta.entries) {
      sheet.appendRow([TextCellValue(e.key), TextCellValue(e.value)]);
    }
    sheet.appendRow([TextCellValue('')]);

    final headerRow = 2 + t.meta.length;
    sheet.appendRow(t.headers.map<CellValue?>((h) => TextCellValue(h)).toList());
    final style = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#0B2545'),
    );
    for (var c = 0; c < t.headers.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRow))
          .cellStyle = style;
    }
    for (final row in t.rows) {
      sheet.appendRow(row.map<CellValue?>((v) {
        if (v == null) return null;
        if (v is num) return DoubleCellValue(v.toDouble());
        return TextCellValue('$v');
      }).toList());
    }
    final out = book.encode();
    return Uint8List.fromList(out!);
  }

  // ----------------------------------------------------------------- ODS
  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _cell(Object? v, {bool header = false}) {
    final style = header ? ' table:style-name="hdr"' : '';
    if (v == null) return '<table:table-cell$style/>';
    if (v is num) {
      return '<table:table-cell$style office:value-type="float" office:value="$v"><text:p>$v</text:p></table:table-cell>';
    }
    return '<table:table-cell$style office:value-type="string"><text:p>${_esc('$v')}</text:p></table:table-cell>';
  }

  static String _row(List<Object?> cells, {bool header = false}) =>
      '<table:table-row>${cells.map((c) => _cell(c, header: header)).join()}</table:table-row>';

  Uint8List buildOds(ReportTable t) {
    final rows = StringBuffer()
      ..write(_row([t.title]))
      ..writeAll(t.meta.entries.map((e) => _row([e.key, e.value])))
      ..write(_row(const []))
      ..write(_row(t.headers, header: true))
      ..writeAll(t.rows.map(_row));

    final content = '<?xml version="1.0" encoding="UTF-8"?>'
        '<office:document-content '
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
        'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" '
        'xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" '
        'office:version="1.2">'
        '<office:automatic-styles>'
        '<style:style style:name="hdr" style:family="table-cell">'
        '<style:table-cell-properties fo:background-color="#0b2545"/>'
        '<style:text-properties fo:color="#ffffff" fo:font-weight="bold"/>'
        '</style:style></office:automatic-styles>'
        '<office:body><office:spreadsheet>'
        '<table:table table:name="Report">$rows</table:table>'
        '</office:spreadsheet></office:body></office:document-content>';

    const manifest = '<?xml version="1.0" encoding="UTF-8"?>'
        '<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">'
        '<manifest:file-entry manifest:full-path="/" manifest:version="1.2" manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/>'
        '<manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>'
        '</manifest:manifest>';

    final mimetype =
        Uint8List.fromList('application/vnd.oasis.opendocument.spreadsheet'.codeUnits);
    final contentBytes = Uint8List.fromList(_utf8(content));
    final manifestBytes = Uint8List.fromList(_utf8(manifest));

    final archive = Archive()
      ..addFile(ArchiveFile.noCompress('mimetype', mimetype.length, mimetype))
      ..addFile(ArchiveFile('META-INF/manifest.xml', manifestBytes.length, manifestBytes))
      ..addFile(ArchiveFile('content.xml', contentBytes.length, contentBytes));
    final out = ZipEncoder().encode(archive);
    return Uint8List.fromList(out as List<int>);
  }

  static List<int> _utf8(String s) => utf8.encode(s);

  // ----------------------------------------------------------------- PDF
  Future<Uint8List> buildPdf(ReportTable t) async {
    final navy = PdfColor.fromInt(0xFF0B2545);
    final gold = PdfColor.fromInt(0xFFB8963E);
    final doc = pw.Document(title: t.title, author: 'IIT (ISM) Dhanbad - EDC');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Indian Institute of Technology (Indian School of Mines), Dhanbad',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: navy)),
            pw.Text('Executive Development Centre', style: const pw.TextStyle(fontSize: 9)),
            pw.Divider(color: gold, thickness: 1.2),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Prototype report - payments shown are simulated.',
                style: const pw.TextStyle(fontSize: 7)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        build: (ctx) => [
          pw.Text(t.title,
              style: pw.TextStyle(
                  fontSize: 15, fontWeight: pw.FontWeight.bold, color: navy)),
          pw.SizedBox(height: 4),
          ...t.meta.entries.map((e) => pw.Text('${e.key}: ${e.value}',
              style: const pw.TextStyle(fontSize: 8))),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: t.headers,
            data: t.rows
                .map((r) => r.map((c) => c == null ? '' : '$c').toList())
                .toList(),
            headerStyle: pw.TextStyle(
                fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: navy),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.all(3),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
