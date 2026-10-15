import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/domain/phone.dart';

void main() {
  test('Ghana numbers become international digits', () {
    expect(PhoneNumbers.international('024 123 4567'), '233241234567');
    expect(PhoneNumbers.international('+233 24 123 4567'), '233241234567');
    expect(PhoneNumbers.international('00233241234567'), '233241234567');
    expect(PhoneNumbers.international('241234567'), '233241234567');
    expect(PhoneNumbers.international('123'), isNull);
    expect(PhoneNumbers.international(null), isNull);
    final uri = PhoneNumbers.whatsApp('0241234567', 'Hi there')!;
    expect(uri.toString(), 'https://wa.me/233241234567?text=Hi+there');
  });
}
