import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/domain/dues.dart';

void main() {
  test('liable months run from join date to now, inclusive', () {
    expect(
      Dues.liableMonths(
        joined: DateTime(2026, 8, 20),
        now: DateTime(2026, 10, 3),
      ),
      ['2026-08', '2026-09', '2026-10'],
    );
  });

  test('dues start date and member status date limit the months', () {
    expect(
      Dues.liableMonths(
        joined: DateTime(2025, 1, 1),
        now: DateTime(2026, 10, 3),
        duesStart: DateTime(2026, 9, 1),
      ),
      ['2026-09', '2026-10'],
    );
    expect(
      Dues.liableMonths(
        joined: DateTime(2026, 1, 1),
        now: DateTime(2026, 10, 3),
        stoppedOn: DateTime(2026, 2, 15),
      ),
      ['2026-01', '2026-02'],
    );
    expect(
      Dues.liableMonths(
        joined: DateTime(2026, 11, 1),
        now: DateTime(2026, 10, 3),
      ),
      isEmpty,
    );
  });

  test('summary fills oldest months first', () {
    final s = Dues.summarise(
      monthlyAmount: 2000,
      liableMonths: ['2026-08', '2026-09', '2026-10'],
      paidByPeriod: {'2026-10': 2000, '2026-08': 1000},
    );
    expect(s.expected, 6000);
    expect(s.paid, 3000);
    expect(s.outstanding, 3000);
    expect(s.nextUnpaidPeriod, '2026-09');
    expect(s.isDefaulter, isTrue);
  });

  test('overpayment means nothing outstanding', () {
    final s = Dues.summarise(
      monthlyAmount: 2000,
      liableMonths: ['2026-10'],
      paidByPeriod: {'2026-10': 5000},
    );
    expect(s.outstanding, 0);
    expect(s.nextUnpaidPeriod, isNull);
  });
}
