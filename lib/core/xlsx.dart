import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A sheet of rows; cells may be [String], [num] or null.
class XlsxSheet {
  const XlsxSheet(this.name, this.rows);
  final String name;
  final List<List<Object?>> rows;
}

/// Writes a minimal Excel workbook (.xlsx) with inline strings and numbers.
/// Enough for exports that open in Excel, Google Sheets and WPS Office.
Uint8List buildXlsx(List<XlsxSheet> sheets) {
  final archive = Archive();
  void add(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  final n = sheets.length;
  add(
    '[Content_Types].xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
${[for (var i = 1; i <= n; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join('\n')}
</Types>''',
  );
  add('_rels/.rels', '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''');
  add(
    'xl/workbook.xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>
${[for (var i = 1; i <= n; i++) '<sheet name="${_esc(_sheetName(sheets[i - 1].name))}" sheetId="$i" r:id="rId$i"/>'].join('\n')}
</sheets>
</workbook>''',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${[for (var i = 1; i <= n; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join('\n')}
</Relationships>''',
  );
  for (var i = 0; i < n; i++) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
      );
    final rows = sheets[i].rows;
    for (var r = 0; r < rows.length; r++) {
      b.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final v = rows[r][c];
        final ref = '${_col(c)}${r + 1}';
        if (v == null) continue;
        if (v is num) {
          b.write('<c r="$ref"><v>$v</v></c>');
        } else {
          b.write(
            '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_esc('$v')}</t></is></c>',
          );
        }
      }
      b.write('</row>');
    }
    b.write('</sheetData></worksheet>');
    add('xl/worksheets/sheet${i + 1}.xml', b.toString());
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _col(int i) {
  var n = i + 1;
  var s = '';
  while (n > 0) {
    final m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

String _sheetName(String n) {
  final clean = n.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ');
  return clean.length > 31 ? clean.substring(0, 31) : clean;
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// RFC 4180 CSV.
String buildCsv(List<List<Object?>> rows) => rows
    .map(
      (r) => r
          .map((v) {
            final s = v == null ? '' : '$v';
            return s.contains(RegExp(r'[",\n]'))
                ? '"${s.replaceAll('"', '""')}"'
                : s;
          })
          .join(','),
    )
    .join('\r\n');
