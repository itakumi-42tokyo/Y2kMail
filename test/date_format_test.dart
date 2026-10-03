import 'package:flutter_test/flutter_test.dart';
import 'package:kengai/util/date_format.dart';

void main() {
  test('一覧: 今日は HH:MM、それ以前は MM/DD', () {
    final now = DateTime(2026, 10, 3, 15, 30);
    final today = DateTime(2026, 10, 3, 9, 5);
    final past = DateTime(2026, 9, 1, 9, 5);
    expect(listDate(today, now: now), '09:05');
    expect(listDate(past, now: now), '09/01');
  });

  test('詳細: YYYY/MM/DD HH:MM', () {
    expect(detailDate(DateTime(2026, 1, 2, 3, 4)), '2026/01/02 03:04');
  });
}
