import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// New random UUID (v4) used as the primary key of every syncable row.
String newId() => _uuid.v4();

/// Formats a member number such as `JBF-000123`.
String formatMemberNo(String prefix, int number) =>
    '$prefix-${number.toString().padLeft(6, '0')}';
