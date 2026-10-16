import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Rows of a spreadsheet as text. Reads .xlsx (the sheet whose first row
/// has a "Name" heading, else the first sheet) and .csv. Throws
/// [FormatException] when the file is neither.
List<List<String>> readSheetRows(Uint8List bytes, String fileName) {
  if (fileName.toLowerCase().endsWith('.csv')) {
    return _readCsv(utf8.decode(bytes, allowMalformed: true));
  }
  return _readXlsx(bytes);
}

List<List<String>> _readCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  final s = text.startsWith('﻿') ? text.substring(1) : text;
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      endCell();
    } else if (ch == '\n') {
      endRow();
    } else if (ch != '\r') {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

List<List<String>> _readXlsx(Uint8List bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const FormatException('This is not an Excel (.xlsx) or CSV file.');
  }
  String? read(String path) {
    final f = zip.findFile(path);
    return f == null ? null : utf8.decode(f.content, allowMalformed: true);
  }

  final workbook = read('xl/workbook.xml');
  if (workbook == null) {
    throw const FormatException('This is not an Excel (.xlsx) or CSV file.');
  }
  final rels = <String, String>{
    for (final r in XmlDocument.parse(
      read('xl/_rels/workbook.xml.rels') ?? '<r/>',
    ).findAllElements('Relationship'))
      r.getAttribute('Id') ?? '': r.getAttribute('Target') ?? '',
  };
  final shared = <String>[
    for (final si in XmlDocument.parse(
      read('xl/sharedStrings.xml') ?? '<sst/>',
    ).findAllElements('si'))
      si
          .findAllElements('t')
          .where((t) => t.parentElement?.name.local != 'rPh')
          .map((t) => t.innerText)
          .join(),
  ];

  List<List<String>> sheet(String target) {
    final path = target.startsWith('/')
        ? target.substring(1)
        : 'xl/${target.replaceFirst('./', '')}';
    final xml = read(path);
    if (xml == null) return const [];
    final rows = <List<String>>[];
    for (final r in XmlDocument.parse(xml).findAllElements('row')) {
      final cells = <String>[];
      for (final c in r.findElements('c')) {
        final col = _column(c.getAttribute('r') ?? '');
        while (cells.length < col) {
          cells.add('');
        }
        final t = c.getAttribute('t');
        final v = c.getElement('v')?.innerText;
        String value;
        if (t == 's') {
          final i = int.tryParse(v ?? '');
          value = i == null || i >= shared.length ? '' : shared[i];
        } else if (t == 'inlineStr') {
          value = c.findAllElements('t').map((e) => e.innerText).join();
        } else {
          value = v ?? '';
        }
        if (col < cells.length) {
          cells[col] = value;
        } else {
          cells.add(value);
        }
      }
      rows.add(cells);
    }
    return rows;
  }

  List<List<String>>? first;
  for (final s in XmlDocument.parse(workbook).findAllElements('sheet')) {
    final id = s.attributes
        .where((a) => a.name.local == 'id')
        .map((a) => a.value)
        .firstOrNull;
    final target = rels[id];
    if (target == null) continue;
    final rows = sheet(target);
    first ??= rows;
    final head = rows.firstOrNull;
    if (head != null && head.any((h) => h.trim().toLowerCase() == 'name')) {
      return rows;
    }
  }
  return first ?? const [];
}

/// Zero-based column of a cell reference such as "C12".
int _column(String ref) {
  var n = 0;
  for (final u in ref.toUpperCase().codeUnits) {
    if (u < 65 || u > 90) break;
    n = n * 26 + (u - 64);
  }
  return n == 0 ? 0 : n - 1;
}
