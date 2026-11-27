import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/reminders.dart';

Reminder _r(String id, DateTime due, {String repeat = 'none', bool done = false}) =>
    Reminder(id: id, title: 'Bill $id', dueAt: due, createdAt: DateTime(2026, 1, 1), repeat: repeat, done: done);

void main() {
  test('a monthly reminder moves to the same day next month, and 31 January goes to the end of February', () {
    expect(addMonths(DateTime(2026, 11, 5, 9, 30), 1), DateTime(2026, 12, 5, 9, 30));
    expect(addMonths(DateTime(2026, 1, 31, 8), 1), DateTime(2026, 2, 28, 8));
    expect(addMonths(DateTime(2028, 1, 31, 8), 1), DateTime(2028, 2, 29, 8), reason: '2028 is a leap year');
    expect(addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
  });

  test('marking a monthly reminder done moves it to next month and keeps it open', () {
    final next = _r('m', DateTime(2026, 11, 10, 9), repeat: 'monthly').advanced();
    expect(next.dueAt, DateTime(2026, 12, 10, 9));
    expect(next.done, isFalse);
  });

  test('a yearly reminder moves a year on, including from 29 February', () {
    expect(_r('y', DateTime(2028, 2, 29), repeat: 'yearly').advanced().dueAt, DateTime(2029, 2, 28));
  });

  test('overdue and due-today are recognised, and done reminders are never overdue', () {
    final now = DateTime(2026, 11, 27, 14);
    expect(_r('a', DateTime(2026, 11, 27, 9)).isOverdue(now), isTrue);
    expect(_r('b', DateTime(2026, 11, 27, 20)).isOverdue(now), isFalse);
    expect(_r('b', DateTime(2026, 11, 27, 20)).isDueToday(now), isTrue);
    expect(_r('c', DateTime(2026, 11, 20), done: true).isOverdue(now), isFalse);
  });

  test('the attention list keeps open reminders due within three days, soonest first, and drops done ones', () {
    final now = DateTime(2026, 11, 27, 10);
    final list = remindersNeedingAttention([
      _r('far', DateTime(2026, 12, 20)),
      _r('soon', DateTime(2026, 11, 29)),
      _r('overdue', DateTime(2026, 11, 25)),
      _r('done', DateTime(2026, 11, 28), done: true),
    ], now);
    expect(list.map((r) => r.id), ['overdue', 'soon']);
  });

  test('a reminder survives a save and reload, and a damaged repeat value falls back to once', () {
    final r = Reminder(id: 'j', title: 'Rent', dueAt: DateTime(2026, 12, 1, 10, 15), createdAt: DateTime(2026, 11, 1), repeat: 'monthly', route: '/property', notes: 'Hostel rent');
    final back = Reminder.fromJson(r.toJson());
    expect(back.dueAt, DateTime(2026, 12, 1, 10, 15));
    expect(back.repeat, 'monthly');
    expect(back.route, '/property');
    expect(Reminder.fromJson({...r.toJson(), 'repeat': 'weekly?'}).repeat, 'none');
  });
}
