import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/sip.dart';

void main() {
  final sip = SipPlan(id: 'a', name: 'Index fund SIP', monthlyCents: 500000, dayOfMonth: 5, startDate: DateTime(2026, 9, 1));

  test('months due are those whose day has come, from the start month', () {
    expect(monthsDue(sip, DateTime(2026, 11, 27)), ['2026-09', '2026-10', '2026-11']);
    // Before the 5th of November, November is not due yet.
    expect(monthsDue(sip, DateTime(2026, 11, 3)), ['2026-09', '2026-10']);
  });

  test('pending amount counts only unpaid due months', () {
    final paid = sip.copyWith(paidMonths: ['2026-09', '2026-10']);
    expect(pendingCents(sip, DateTime(2026, 11, 27)), 3 * 500000);
    expect(pendingCents(paid, DateTime(2026, 11, 27)), 500000);
    expect(paid.investedCents, 1000000);
  });

  test('this month shows paid, pending on the due day, or not yet due', () {
    expect(sipStateFor(sip.copyWith(paidMonths: ['2026-11']), DateTime(2026, 11, 27)), SipState.paid);
    expect(sipStateFor(sip, DateTime(2026, 11, 27)), SipState.pending);
    expect(sipStateFor(sip, DateTime(2026, 11, 2)), SipState.notYet);
  });

  test('missed earlier months are listed, and the current month is not counted as missed', () {
    final p = sip.copyWith(paidMonths: ['2026-09']);
    expect(missedMonths(p, DateTime(2026, 11, 27)), ['2026-10']);
  });

  test('a day of the month past the end of a short month is due on its last day', () {
    final late = SipPlan(id: 'b', name: 'x', monthlyCents: 100, dayOfMonth: 28, startDate: DateTime(2026, 2, 1));
    expect(dueDateFor(late, 2026, 2), DateTime(2026, 2, 28));
    final thirty = SipPlan(id: 'c', name: 'y', monthlyCents: 100, dayOfMonth: 28, startDate: DateTime(2026, 4, 1));
    expect(dueDateFor(thirty, 2026, 4), DateTime(2026, 4, 28));
  });

  test('each paid month becomes one spending entry, and removing a payment removes only its entry', () {
    final p = sip.copyWith(paidMonths: ['2026-09', '2026-10']);
    final entries = mergeSipEntries([], [p]);
    expect(entries.map((e) => e.id), ['sip-a-2026-09', 'sip-a-2026-10']);
    expect(entries.every((e) => !e.income && e.category == 'Savings & SIP'), isTrue);

    final after = mergeSipEntries(entries, [p.copyWith(paidMonths: ['2026-09'])]);
    expect(after.map((e) => e.id), ['sip-a-2026-09']);
  });

  test('the monthly reminder repeats on the due day', () {
    final r = sipReminder(sip, now: DateTime(2026, 11, 27));
    expect(r.repeats, isTrue);
    expect(r.dueAt, DateTime(2026, 11, 5, 9));
    expect(r.id, 'sip-rem-a');
  });

  test('a plan survives a save and reload', () {
    final back = SipPlan.fromJson(sip.copyWith(paidMonths: ['2026-09'], currentValueCents: 1200000).toJson());
    expect(back.paidMonths, ['2026-09']);
    expect(back.currentValueCents, 1200000);
    expect(back.dayOfMonth, 5);
  });
}
