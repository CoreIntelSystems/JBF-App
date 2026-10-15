import 'phone.dart';

/// One member ready to be registered from an imported list.
class ImportMember {
  const ImportMember({
    required this.line,
    required this.name,
    required this.phone,
    this.whatsapp,
    this.otherNumbers = const [],
    this.gender,
    this.zones = const [],
  });

  /// Row number in the file, as the person sees it in Excel.
  final int line;
  final String name;
  final String phone;
  final String? whatsapp;

  /// Numbers beyond the second, kept in the address field.
  final List<String> otherNumbers;
  final String? gender;

  /// Zone numbers from the file; empty when the file gave none.
  final List<int> zones;
}

/// A row that could not be imported, and why.
class ImportSkip {
  const ImportSkip(this.line, this.name, this.phones, this.reason);
  final int line;
  final String name;
  final String phones;
  final String reason;
}

class ImportPlan {
  const ImportPlan(this.members, this.skipped, {required this.hasZones});
  final List<ImportMember> members;
  final List<ImportSkip> skipped;

  /// The file has a Zone column.
  final bool hasZones;

  int get withoutZone => members.where((m) => m.zones.isEmpty).length;
}

/// Last nine digits of a phone number: how numbers are compared, so
/// "+233 24 486 2488" and "0244862488" are the same.
String phoneKey(String? phone) {
  final d = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  return d.length <= 9 ? d : d.substring(d.length - 9);
}

/// The number as it is stored: Ghana numbers as 0XXXXXXXXX, others with
/// their country code. Null when it is not a usable number.
String? storedPhone(String? raw) {
  final intl = PhoneNumbers.international(raw);
  if (intl == null) return null;
  if (intl.startsWith('233') && intl.length == 12) {
    return '0${intl.substring(3)}';
  }
  return '+$intl';
}

final _label = RegExp(r'\s+(king|queen)\s+june\b.*$', caseSensitive: false);

/// Turns the rows of a member list (a heading row, then people) into a
/// plan. [existing] holds [phoneKey]s of members already registered, so
/// running the import twice adds nobody twice.
ImportPlan planMemberImport(
  List<List<String>> rows, {
  Set<String> existing = const {},
}) {
  final headIndex = rows.indexWhere(
    (r) => r.any((c) => c.trim().toLowerCase() == 'name'),
  );
  if (headIndex < 0) {
    throw const FormatException(
      'The first row needs headings such as Name and Phone 1.',
    );
  }
  final head = [for (final h in rows[headIndex]) h.trim().toLowerCase()];
  final nameCol = head.indexOf('name');
  final phoneCols = [
    for (var i = 0; i < head.length; i++)
      if (RegExp(r'^(phone|mobile|contact|tel|whatsapp)').hasMatch(head[i])) i,
  ];
  final zoneCols = [
    for (var i = 0; i < head.length; i++)
      if (RegExp(r'^zone').hasMatch(head[i])) i,
  ];
  final genderCol = head.indexOf('gender');

  String cell(List<String> r, int i) =>
      i >= 0 && i < r.length ? r[i].trim() : '';

  final members = <ImportMember>[];
  final skipped = <ImportSkip>[];
  final seen = <String, int>{};
  for (var n = headIndex + 1; n < rows.length; n++) {
    final r = rows[n];
    if (r.every((c) => c.trim().isEmpty)) continue;
    final line = n + 1;
    final rawName = cell(r, nameCol);
    final raws = [
      for (final c in phoneCols) cell(r, c),
    ].where((p) => p.isNotEmpty).toList();
    final phones = raws.join(', ');

    final labelled = _label.firstMatch(rawName);
    var name = rawName.replaceAll(_label, '').trim();
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    String? gender;
    if (labelled != null) {
      gender = labelled.group(1)!.toLowerCase() == 'king' ? 'Male' : 'Female';
    }
    final g = cell(r, genderCol).toLowerCase();
    if (g.startsWith('m')) gender = 'Male';
    if (g.startsWith('f')) gender = 'Female';

    if (name.isEmpty ||
        name.startsWith('@') ||
        !RegExp(r'\p{L}', unicode: true).hasMatch(name) ||
        name.toLowerCase() == '(not saved)') {
      skipped.add(
        ImportSkip(
          line,
          rawName,
          phones,
          rawName.startsWith('@')
              ? 'WhatsApp username only, no name'
              : 'No name saved with this number',
        ),
      );
      continue;
    }
    final numbers = <String>[];
    for (final p in raws) {
      final s = storedPhone(p);
      if (s != null && !numbers.any((x) => phoneKey(x) == phoneKey(s))) {
        numbers.add(s);
      }
    }
    if (numbers.isEmpty) {
      skipped.add(ImportSkip(line, rawName, phones, 'No usable phone number'));
      continue;
    }
    final clash = numbers
        .map((x) => phoneKey(x))
        .firstWhere(
          (k) => existing.contains(k) || seen.containsKey(k),
          orElse: () => '',
        );
    if (clash.isNotEmpty) {
      skipped.add(
        ImportSkip(
          line,
          rawName,
          phones,
          existing.contains(clash)
              ? 'Already registered with this number'
              : 'Same number as row ${seen[clash]}',
        ),
      );
      continue;
    }

    final zones = <int>[];
    String? badZone;
    for (final c in zoneCols) {
      final v = cell(r, c);
      if (v.isEmpty) continue;
      final z = int.tryParse(
        v.replaceAll(RegExp(r'zone|\.0$|\s', caseSensitive: false), ''),
      );
      if (z == null) {
        badZone = v;
      } else if (!zones.contains(z)) {
        zones.add(z);
      }
    }
    if (badZone != null) {
      skipped.add(
        ImportSkip(line, rawName, phones, 'Zone "$badZone" not understood'),
      );
      continue;
    }
    for (final x in numbers) {
      seen[phoneKey(x)] = line;
    }
    members.add(
      ImportMember(
        line: line,
        name: name,
        phone: numbers[0],
        whatsapp: numbers.length > 1 ? numbers[1] : null,
        otherNumbers: numbers.skip(2).toList(),
        gender: gender,
        zones: zones,
      ),
    );
  }
  return ImportPlan(members, skipped, hasZones: zoneCols.isNotEmpty);
}
