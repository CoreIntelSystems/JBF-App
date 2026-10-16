import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/org_config.dart';
import '../../core/xlsx.dart';
import '../../data/database.dart';
import '../../data/repositories/finance_repository.dart';

String reportRange(FinanceReport r) {
  final last = r.to.subtract(const Duration(days: 1));
  return r.from == last
      ? formatDate(r.from)
      : '${formatDate(r.from)} to ${formatDate(last)}';
}

String reportFileStem(FinanceReport r) =>
    'finance-${ymd(r.from)}-to-${ymd(r.to.subtract(const Duration(days: 1)))}';

String ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

double _cedis(int pesewas) => pesewas / 100;

List<List<Object?>> _summaryRows(FinanceReport r, OrgSetting org) => [
  [org.name],
  ['${r.title} financial report', reportRange(r)],
  [],
  ['Opening balance', _cedis(r.opening)],
  ['Total income', _cedis(r.totalIncome)],
  ['Total spending', _cedis(r.totalExpense)],
  ['Net for the period', _cedis(r.net)],
  ['Closing balance', _cedis(r.closing)],
  [],
  ['Income by contribution type', 'Amount (${org.currency})', 'Count'],
  for (final l in r.incomeByType) [l.label, _cedis(l.amount), l.count],
  [],
  ['Income by category', 'Amount (${org.currency})', 'Count'],
  for (final l in r.incomeByCategory) [l.label, _cedis(l.amount), l.count],
  [],
  ['Income by payment method', 'Amount (${org.currency})', 'Count'],
  for (final l in r.incomeByMethod) [l.label, _cedis(l.amount), l.count],
  [],
  ['Income by zone', 'Amount (${org.currency})', 'Count'],
  for (final l in r.incomeByZone) [l.label, _cedis(l.amount), l.count],
  [],
  ['Spending by category', 'Amount (${org.currency})', 'Count'],
  for (final l in r.expenseByCategory) [l.label, _cedis(l.amount), l.count],
];

List<List<Object?>> _txnRows(FinanceReport r, OrgSetting org) => [
  [
    'Date',
    'Reference',
    'Description',
    'Member / paid to',
    'Method',
    'Income (${org.currency})',
    'Spending (${org.currency})',
  ],
  for (final t in r.transactions)
    [
      ymd(t.date),
      t.ref,
      t.description,
      t.party,
      t.method,
      t.income == 0 ? null : _cedis(t.income),
      t.expense == 0 ? null : _cedis(t.expense),
    ],
];

Uint8List reportXlsx(FinanceReport r, OrgSetting org) => buildXlsx([
  XlsxSheet('Summary', _summaryRows(r, org)),
  XlsxSheet('Transactions', _txnRows(r, org)),
]);

Uint8List reportCsv(FinanceReport r, OrgSetting org) => Uint8List.fromList(
  // BOM so Excel opens accented names correctly.
  [0xEF, 0xBB, 0xBF, ...utf8.encode(buildCsv(_txnRows(r, org)))],
);

Future<Uint8List> reportPdf(FinanceReport r, OrgSetting org) async {
  final logo = pw.MemoryImage(
    (await rootBundle.load(OrgDefaults.logoAsset)).buffer.asUint8List(),
  );
  String m(int v) => formatMoney(v, currency: org.currency);
  final doc = pw.Document(title: '${r.title} financial report');

  pw.Widget table(String title, List<ReportLine> lines) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 10),
      pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      if (lines.isEmpty)
        pw.Text('None')
      else
        pw.TableHelper.fromTextArray(
          headers: ['', 'Count', 'Amount'],
          data: [
            for (final l in lines) [l.label, '${l.count}', m(l.amount)],
          ],
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
          },
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
    ],
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (c) => c.pageNumber == 1
          ? pw.Row(
              children: [
                pw.Image(logo, width: 44, height: 44),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        org.name,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('${r.title} financial report, ${reportRange(r)}'),
                    ],
                  ),
                ),
              ],
            )
          : pw.SizedBox(),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated ${formatDateTime(DateTime.now())}'
            '${org.poweredBy == null ? '' : ' - ${org.poweredBy}'}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            'Page ${c.pageNumber} of ${c.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
      build: (c) => [
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          data: [
            ['Opening balance', m(r.opening)],
            ['Total income', m(r.totalIncome)],
            ['Total spending', m(r.totalExpense)],
            ['Net for the period', m(r.net)],
            ['Closing balance', m(r.closing)],
          ],
          cellAlignments: {1: pw.Alignment.centerRight},
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
        table('Income by contribution type', r.incomeByType),
        table('Income by payment method', r.incomeByMethod),
        table('Income by zone', r.incomeByZone),
        table('Spending by category', r.expenseByCategory),
        pw.SizedBox(height: 14),
        pw.Text(
          'Transactions',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        if (r.transactions.isEmpty)
          pw.Text('No transactions in this period.')
        else
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Ref', 'Description', 'Party', 'In', 'Out'],
            data: [
              for (final t in r.transactions)
                [
                  formatDate(t.date),
                  t.ref,
                  t.description,
                  t.party,
                  t.income == 0 ? '' : m(t.income),
                  t.expense == 0 ? '' : m(t.expense),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignments: {
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
          ),
      ],
    ),
  );
  return doc.save();
}
