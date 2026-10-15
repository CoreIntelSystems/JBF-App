/// The number WhatsApp wants for a stored phone number: country code first,
/// digits only. Returns null when there is no usable number.
String? whatsappNumber(String? stored) {
  var s = (stored ?? '').trim();
  if (s.isEmpty) return null;
  final international = s.startsWith('+');
  s = s.replaceAll(RegExp(r'\D'), '');
  if (s.isEmpty) return null;
  if (international) return s.length >= 8 ? s : null;
  if (s.startsWith('0') && s.length == 10) return '233${s.substring(1)}';
  if (s.startsWith('233') && s.length == 12) return s;
  return null;
}

/// The message the Founder sends so a member learns their ID.
String idInviteMessage({
  required String name,
  required String memberNo,
  required String orgName,
}) {
  final first = name.trim().split(RegExp(r'\s+')).first;
  return 'Hello $first, this is $orgName. Your member ID is $memberNo.\n\n'
      'To see your dues and details on the app, open it, choose "Member '
      'sign-in" and enter your member ID and the phone number you gave us.';
}

Uri whatsappLink(String number, String message) =>
    Uri.https('wa.me', '/$number', {'text': message});
