import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/domain/whatsapp_invite.dart';

void main() {
  test('phone numbers become WhatsApp numbers', () {
    expect(whatsappNumber('0241234567'), '233241234567');
    expect(whatsappNumber('233241234567'), '233241234567');
    expect(whatsappNumber('+447911123456'), '447911123456');
    expect(whatsappNumber('024123'), isNull);
    expect(whatsappNumber(null), isNull);
  });

  test('message and link carry the ID', () {
    final text = idInviteMessage(
      name: 'Kofi Mensah',
      memberNo: 'JBF-000002',
      orgName: 'June Borns Family',
    );
    expect(text, contains('Hello Kofi'));
    expect(text, contains('JBF-000002'));
    expect(text, contains('https://jbf-members.onrender.com'));
    expect(text, contains('Add to Home Screen'));
    final link = whatsappLink('233241234567', text);
    expect(link.host, 'wa.me');
    expect(link.path, '/233241234567');
    expect(link.queryParameters['text'], text);
  });

  test('people with no saved name get a plain greeting', () {
    final text = idInviteMessage(
      name: 'Member 0265778617',
      memberNo: 'JBF-000009',
      orgName: 'June Borns Family',
    );
    expect(text, startsWith('Hello, this is'));
  });
}
