import 'package:flutter_test/flutter_test.dart';

import 'package:di_cho_tien_loi/application/meal_service.dart';
import 'package:di_cho_tien_loi/application/validation/validators.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email('a@b.com'), isNull);
      expect(Validators.email('abc'), isNotNull);
    });

    test('mật khẩu 6-20 ký tự', () {
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });

    test('số lượng dương, chấp nhận dấu phẩy', () {
      expect(Validators.quantity('1,5'), isNull);
      expect(Validators.parseQuantity('1,5'), 1.5);
      expect(Validators.quantity('0'), isNotNull);
      expect(Validators.quantity('abc'), isNotNull);
    });

    test('username', () {
      expect(Validators.username('lan_01'), isNull);
      expect(Validators.username('ab'), isNotNull);
      expect(Validators.username('có dấu'), isNotNull);
    });
  });

  test('isoDate', () {
    expect(isoDate(DateTime(2026, 3, 5)), '2026-03-05');
    expect(parseIsoDate('2026-03-05'), DateTime(2026, 3, 5));
  });

  test('cách làm công thức <-> HTML', () {
    final html = MealService.instructionsToHtml('Rửa thịt\n\nHầm 2 <giờ>');
    expect(html, '<p>Rửa thịt</p><p>Hầm 2 &lt;giờ&gt;</p>');
    expect(MealService.htmlToText(html), 'Rửa thịt\nHầm 2 <giờ>');
  });
}
