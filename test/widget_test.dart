import 'package:flutter_test/flutter_test.dart';
import 'package:kistbook/core/utils/date_helper.dart';

void main() {
  test('Friday due dates shift to Saturday', () {
    final friday = DateTime(2026, 4, 10);
    final shifted = DateHelper.shiftFridayToSaturday(friday);

    expect(shifted.weekday, DateTime.saturday);
    expect(shifted.day, 11);
  });

  test('Missed installments carry forward without changing the rest of schedule', () {
    final reconciled = DateHelper.reconcileMissedDueDate(
      currentDueDate: DateTime(2026, 4, 8),
      today: DateTime(2026, 4, 12),
    );

    expect(reconciled, DateTime(2026, 4, 12));
  });
}
