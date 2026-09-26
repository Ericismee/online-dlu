import 'package:dlu_tkb/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('hhmm formats', () {
    expect(hhmm(7 * 60 + 5), '07:05');
    expect(hhmm(13 * 60), '13:00');
  });

  test('nextClass picks the next slot, wrapping to next week', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    // Wed 2026-09-30 at 08:00.
    final now = DateTime(2026, 9, 30, 8);
    expect(store.nextClass(now), isNull);

    store.slots.addAll([
      Slot(subject: 'Toán', day: 3, start: 7 * 60, end: 9 * 60), // already started
      Slot(subject: 'Lý', day: 3, start: 13 * 60, end: 15 * 60), // later today
      Slot(subject: 'Hoá', day: 1, start: 7 * 60, end: 9 * 60), // next Monday
    ]);
    store.save();

    var (slot, at) = store.nextClass(now)!;
    expect(slot.subject, 'Lý');
    expect(at, DateTime(2026, 9, 30, 13));

    // After Wednesday's classes, the next one is Monday's.
    (slot, at) = store.nextClass(DateTime(2026, 9, 30, 20))!;
    expect(slot.subject, 'Hoá');
    expect(at, DateTime(2026, 10, 5, 7));
  });

  test('data survives a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await Store.open();
    a.slots.add(Slot(subject: 'CSDL', day: 2, start: 420, end: 540, room: 'A21'));
    a.tasks.add(Task(title: 'Bài tập 1', due: DateTime(2026, 10, 1)));
    a.save();

    final b = await Store.open();
    expect(b.slots.single.room, 'A21');
    expect(b.tasks.single.due, DateTime(2026, 10, 1));
    expect(b.todo, hasLength(1));
  });
}
