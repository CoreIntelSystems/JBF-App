/// Business rules for assigning members to zones.
abstract final class ZoneRules {
  static const minZones = 1;
  static const maxZones = 2;

  static const tooManyMessage =
      'A member can belong to at most $maxZones zones.';
  static const tooFewMessage = 'Choose at least $minZones zone.';

  /// Returns an error message, or null when [zoneIds] is a valid assignment.
  /// [activeZoneIds] are zones currently open for assignment.
  static String? validate(
    Iterable<String> zoneIds, {
    required Set<String> activeZoneIds,
    Set<String> alreadyAssigned = const {},
  }) {
    final ids = zoneIds.toSet();
    if (ids.length < minZones) return tooFewMessage;
    if (ids.length > maxZones) return tooManyMessage;
    // A member already in a zone that was later switched off keeps it;
    // only new assignments must be to active zones.
    final inactive = ids.difference(activeZoneIds).difference(alreadyAssigned);
    if (inactive.isNotEmpty) return 'That zone is not open for members yet.';
    return null;
  }

  /// Whether one more zone can be added to [current].
  static bool canAddAnother(Iterable<String> current) =>
      current.toSet().length < maxZones;
}

class ZoneRuleException implements Exception {
  ZoneRuleException(this.message);
  final String message;
  @override
  String toString() => message;
}
