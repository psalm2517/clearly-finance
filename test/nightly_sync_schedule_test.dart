import 'package:flutter_test/flutter_test.dart';
import 'package:clearly/screens/shell.dart';

void main() {
  test('the slot is the most recent 1:30 AM', () {
    expect(lastSyncSlot(DateTime(2026, 10, 21, 18, 14)),
        DateTime(2026, 10, 21, 1, 30));
    expect(lastSyncSlot(DateTime(2026, 10, 21, 0, 45)),
        DateTime(2026, 10, 20, 1, 30));
    expect(lastSyncSlot(DateTime(2026, 10, 21, 1, 30)),
        DateTime(2026, 10, 21, 1, 30));
    expect(lastSyncSlot(DateTime(2026, 3, 1, 0, 10)),
        DateTime(2026, 2, 28, 1, 30));
  });

  test('a sync is owed once the last one is older than the latest slot', () {
    final now = DateTime(2026, 10, 21, 18, 14);
    // The real case: last synced on the 17th, app not open since.
    expect(dailySyncDue(now, DateTime(2026, 10, 17, 14, 9)), isTrue);
    expect(dailySyncDue(now, null), isTrue);
    // Synced yesterday afternoon: still owed today, since 1:30 AM has passed.
    expect(dailySyncDue(now, DateTime(2026, 10, 20, 15, 0)), isTrue);
    // Synced today after 1:30 AM: done until tomorrow.
    expect(dailySyncDue(now, DateTime(2026, 10, 21, 9, 0)), isFalse);
    expect(dailySyncDue(now, DateTime(2026, 10, 21, 1, 30)), isFalse);
  });

  test('between midnight and 1:30 AM yesterday\'s sync still counts', () {
    final now = DateTime(2026, 10, 21, 0, 50);
    expect(dailySyncDue(now, DateTime(2026, 10, 20, 9, 0)), isFalse);
    expect(dailySyncDue(now, DateTime(2026, 10, 19, 9, 0)), isTrue);
  });

  test('once 1:30 AM passes, the day before is no longer enough', () {
    expect(dailySyncDue(DateTime(2026, 10, 21, 1, 31),
        DateTime(2026, 10, 20, 23, 0)), isTrue);
  });
}
