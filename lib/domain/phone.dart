/// Phone number helpers for Ghana numbers.
abstract final class PhoneNumbers {
  /// International digits for links such as wa.me, e.g. 0241234567 ->
  /// 233241234567. Returns null when the number does not look usable.
  static String? international(String? phone, {String countryCode = '233'}) {
    if (phone == null) return null;
    var d = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (d.startsWith('+')) d = d.substring(1);
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith('0')) d = '$countryCode${d.substring(1)}';
    if (d.length == 9 && !d.startsWith(countryCode)) d = '$countryCode$d';
    if (d.length < 10 || d.length > 15 || d.contains('+')) return null;
    return d;
  }

  static Uri? whatsApp(String? phone, String message) {
    final n = international(phone);
    if (n == null) return null;
    return Uri.https('wa.me', '/$n', {'text': message});
  }
}
