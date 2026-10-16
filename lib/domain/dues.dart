/// Arrears rules for monthly dues.
///
/// A member owes each month from the later of their join date and the dues
/// start date, up to the current month. Accrual stops at the end date, and
/// at the status date for members who are no longer active (inactive,
/// suspended or deceased). Payments count against the total owed; a
/// payment's period only decides which month it is shown against.
abstract final class Dues {
  static String periodOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

  /// Months from [from] to [until], inclusive, as `YYYY-MM`.
  static List<String> months(DateTime from, DateTime until) {
    final out = <String>[];
    var m = monthStart(from);
    final end = monthStart(until);
    while (!m.isAfter(end)) {
      out.add(periodOf(m));
      m = DateTime(m.year, m.month + 1);
    }
    return out;
  }

  /// The months a member is liable for.
  static List<String> liableMonths({
    required DateTime joined,
    required DateTime now,
    DateTime? duesStart,
    DateTime? duesEnd,
    DateTime? stoppedOn,
  }) {
    var from = joined;
    if (duesStart != null && duesStart.isAfter(from)) from = duesStart;
    var until = now;
    if (duesEnd != null && duesEnd.isBefore(until)) until = duesEnd;
    if (stoppedOn != null && stoppedOn.isBefore(until)) until = stoppedOn;
    if (monthStart(until).isBefore(monthStart(from))) return const [];
    return months(from, until);
  }

  /// Summary for one member and one monthly contribution type.
  static DuesSummary summarise({
    required int monthlyAmount,
    required List<String> liableMonths,
    required Map<String?, int> paidByPeriod,
  }) {
    final expected = monthlyAmount * liableMonths.length;
    final paid = paidByPeriod.values.fold(0, (a, b) => a + b);
    // Fill months oldest first with whatever has been paid, so the next
    // month to collect is the oldest not fully covered.
    var pool = paid;
    String? nextUnpaid;
    var monthsBehind = 0;
    for (final m in liableMonths) {
      if (pool >= monthlyAmount) {
        pool -= monthlyAmount;
      } else {
        nextUnpaid ??= m;
        pool = 0;
        monthsBehind++;
      }
    }
    return DuesSummary(
      expected: expected,
      paid: paid,
      outstanding: expected > paid ? expected - paid : 0,
      monthsBehind: monthsBehind,
      nextUnpaidPeriod: nextUnpaid,
    );
  }
}

class DuesSummary {
  const DuesSummary({
    required this.expected,
    required this.paid,
    required this.outstanding,
    required this.monthsBehind,
    this.nextUnpaidPeriod,
  });

  final int expected;
  final int paid;
  final int outstanding;
  final int monthsBehind;
  final String? nextUnpaidPeriod;

  bool get isDefaulter => outstanding > 0;
}
