import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format.dart';
import '../../core/org_config.dart';
import '../../data/database.dart';
import '../../data/repositories/member_repository.dart';
import '../../domain/member_qr.dart';

/// ID cards at bank-card size (85.6 x 54 mm), ten to an A4 sheet, with a
/// QR code for attendance scanning. Cut along the light borders.
Future<Uint8List> buildIdCardsPdf(
  List<MemberWithZones> members,
  OrgSetting org,
) async {
  final logo = pw.MemoryImage(
    (await rootBundle.load(OrgDefaults.logoAsset)).buffer.asUint8List(),
  );
  final primary = PdfColor.fromInt(org.primaryColor);
  final accent = PdfColor.fromInt(org.accentColor);
  const w = 85.6 * PdfPageFormat.mm;
  const h = 54 * PdfPageFormat.mm;

  pw.ImageProvider? photo(Member m) {
    final path = m.photoPath;
    if (path == null) return null;
    final f = File(path);
    return f.existsSync() ? pw.MemoryImage(f.readAsBytesSync()) : null;
  }

  pw.Widget card(MemberWithZones mz) {
    final m = mz.member;
    final pic = photo(m);
    return pw.Container(
      width: w,
      height: h,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            color: primary,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: pw.Row(
              children: [
                pw.Image(logo, width: 20, height: 20),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(
                    org.name.toUpperCase(),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Text(
                  'MEMBER',
                  style: pw.TextStyle(color: accent, fontSize: 7),
                ),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 52,
                    height: 64,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pic == null
                        ? pw.Center(
                            child: pw.Text(
                              m.fullName.isEmpty ? '' : m.fullName[0],
                              style: const pw.TextStyle(fontSize: 22),
                            ),
                          )
                        : pw.Image(pic, fit: pw.BoxFit.cover),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          m.fullName,
                          maxLines: 2,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          m.memberNo,
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: primary,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          mz.zones.map((z) => z.name).join(', '),
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                        pw.Text(
                          'Joined ${formatDate(m.dateJoined)}',
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ],
                    ),
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: MemberQr.encode(m.memberNo),
                    width: 54,
                    height: 54,
                    drawText: false,
                  ),
                ],
              ),
            ),
          ),
          if (org.poweredBy != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                'Powered by ${org.poweredBy}',
                style: const pw.TextStyle(
                  fontSize: 5,
                  color: PdfColors.grey600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  final doc = pw.Document(title: 'Member ID cards');
  const perPage = 10;
  for (var i = 0; i < members.length; i += perPage) {
    final page = members.skip(i).take(perPage).toList();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        build: (_) => pw.Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [for (final m in page) card(m)],
        ),
      ),
    );
  }
  if (members.isEmpty) {
    doc.addPage(pw.Page(build: (_) => pw.Text('No members selected.')));
  }
  return doc.save();
}
