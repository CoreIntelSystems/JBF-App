import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/org_config.dart';
import '../../data/database.dart';
import '../../data/repositories/payment_repository.dart';

/// Builds a receipt sized for 80 mm thermal paper; it also prints fine on
/// A4 and shares well on WhatsApp.
Future<Uint8List> buildReceiptPdf(PaymentView v, OrgSetting org) async {
  final logo = pw.MemoryImage(
    (await rootBundle.load(OrgDefaults.logoAsset)).buffer.asUint8List(),
  );
  final p = v.payment;
  final voided = p.status == PaymentStatus.voided;
  final doc = pw.Document(title: 'Receipt ${p.receiptNo}');

  pw.Widget row(String label, String value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 70, child: pw.Text(label)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
          ),
        ),
      ],
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80.copyWith(
        marginLeft: 8,
        marginRight: 8,
        marginTop: 10,
        marginBottom: 10,
      ),
      build: (context) => pw.DefaultTextStyle(
        style: const pw.TextStyle(fontSize: 9),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(child: pw.Image(logo, width: 56, height: 56)),
            pw.SizedBox(height: 4),
            pw.Text(
              org.name.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('OFFICIAL RECEIPT', textAlign: pw.TextAlign.center),
            if (voided)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(
                  'VOID: ${p.voidReason ?? ''}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red,
                  ),
                ),
              ),
            pw.Divider(),
            row('Receipt no.', p.receiptNo, bold: true),
            row('Date', formatDate(p.paidOn)),
            row('Received from', v.payerName),
            if (v.member != null) row('Member ID', v.member!.memberNo),
            row('Purpose', v.type.name),
            if (p.period != null) row('For', formatPeriod(p.period)),
            row('Method', p.method.label),
            if (p.reference != null) row('Reference', p.reference!),
            pw.Divider(),
            pw.Text(
              formatMoney(p.amount, currency: org.currency),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            row('Collected by', p.collectorName),
            if (p.remarks != null) row('Remarks', p.remarks!),
            pw.SizedBox(height: 8),
            pw.Text('Thank you.', textAlign: pw.TextAlign.center),
            if (org.poweredBy != null)
              pw.Text(
                'Powered by ${org.poweredBy}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}
