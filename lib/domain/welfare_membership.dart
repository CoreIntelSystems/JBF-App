/// Welfare is by choice. A member joins by saying so, or by paying a welfare
/// contribution or welfare dues. Missing three payments in a row for either
/// disqualifies them from welfare benefits until an officer reinstates them.
abstract final class WelfareRules {
  /// Consecutive missed payments that disqualify a member.
  static const missedLimit = 3;

  /// True once a member has [missedLimit] or more unpaid months of dues
  /// (or unpaid contribution requests) in a row.
  static bool tooManyMissed(int missed) => missed >= missedLimit;

  /// Whether the dues of a welfare member run: nothing is owed before
  /// joining, or after leaving or being disqualified.
  static DateTime? dutyEnds(DateTime? statusStop, DateTime? welfareEnded) {
    if (statusStop == null) return welfareEnded;
    if (welfareEnded == null) return statusStop;
    return statusStop.isBefore(welfareEnded) ? statusStop : welfareEnded;
  }
}
