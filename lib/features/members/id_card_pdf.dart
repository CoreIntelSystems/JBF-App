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
/// [roles] holds each member's role labels by member id; members with none
/// are shown as plain members.
Future<Uint8List> buildIdCardsPdf(
  List<MemberWithZones> members,
  OrgSetting org, {
  Map<String, List<String>> roles = const {},
}) async {
  final logo = pw.MemoryImage(
    (await rootBundle.load(OrgDefaults.logoAsset)).buffer.asUint8List(),
  );
  final primary = PdfColor.fromInt(org.primaryColor);
  final accent = PdfColor.fromInt(org.accentColor);
  const w = 85.6 * PdfPageFormat.mm;
  const h = 54 * PdfPageFormat.mm;
  const ink = PdfColor.fromInt(0xFF1B1B1B);
  const muted = PdfColor.fromInt(0xFF5F6B66);
  const tint = PdfColor.fromInt(0xFFF3E9C6);

  pw.ImageProvider? photo(Member m) {
    final path = m.photoPath;
    if (path == null) return null;
    final f = File(path);
    return f.existsSync() ? pw.MemoryImage(f.readAsBytesSync()) : null;
  }

  pw.Widget chip(String text, {bool lead = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: pw.BoxDecoration(
      color: lead ? primary : tint,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Text(
      text,
      maxLines: 1,
      style: pw.TextStyle(
        fontSize: 6.2,
        fontWeight: pw.FontWeight.bold,
        color: lead ? PdfColors.white : primary,
      ),
    ),
  );

  pw.Widget detail(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 2),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label  ',
            style: const pw.TextStyle(fontSize: 6.2, color: muted),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(
              fontSize: 7,
              color: ink,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );

  pw.Widget card(MemberWithZones mz) {
    final m = mz.member;
    final pic = photo(m);
    final held = roles[m.id] ?? const <String>[];
    final shown = held.take(4).toList();
    final zones = mz.zones.map((z) => z.name).join(', ');
    return pw.Container(
      width: w,
      height: h,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 6,
        verticalRadius: 6,
        child: pw.Column(
          children: [
            pw.Container(
              color: primary,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(1),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Image(logo, width: 17, height: 17),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          org.name.toUpperCase(),
                          maxLines: 1,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                        pw.Text(
                          'MEMBERSHIP CARD',
                          style: pw.TextStyle(
                            color: accent,
                            fontSize: 5,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.Container(height: 1.6, color: accent),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 58,
                          height: 76,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            border: pw.Border.all(color: accent, width: 0.8),
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                          child: pic == null
                              ? pw.Center(
                                  child: pw.Text(
                                    m.fullName.isEmpty ? '' : m.fullName[0],
                                    style: pw.TextStyle(
                                      fontSize: 22,
                                      color: primary,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                )
                              : pw.ClipRRect(
                                  horizontalRadius: 2.5,
                                  verticalRadius: 2.5,
                                  child: pw.Image(pic, fit: pw.BoxFit.cover),
                                ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                m.fullName,
                                maxLines: 2,
                                style: pw.TextStyle(
                                  fontSize: 9.5,
                                  color: ink,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                m.memberNo,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: primary,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              if (zones.isNotEmpty) detail('Zone', zones),
                              detail('Joined', formatDate(m.dateJoined)),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.all(2),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                  color: PdfColors.grey300,
                                  width: 0.5,
                                ),
                                borderRadius: pw.BorderRadius.circular(3),
                              ),
                              child: pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: MemberQr.encode(m.memberNo),
                                width: 50,
                                height: 50,
                                drawText: false,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Scan to check in',
                              style: const pw.TextStyle(
                                fontSize: 4.6,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Wrap(
                      spacing: 3,
                      runSpacing: 2,
                      children: [
                        if (shown.isEmpty)
                          chip('MEMBER', lead: true)
                        else
                          for (var i = 0; i < shown.length; i++)
                            chip(shown[i], lead: i == 0),
                        if (held.length > shown.length)
                          chip('+${held.length - shown.length} more'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            pw.Container(
              width: double.infinity,
              color: PdfColors.grey100,
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(
                org.poweredBy == null
                    ? org.name
                    : 'Powered by ${org.poweredBy}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 5, color: muted),
              ),
            ),
          ],
        ),
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
