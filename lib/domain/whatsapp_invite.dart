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

/// Where members open the installable member app.
const memberAppUrl = 'https://jbf-members.onrender.com';

/// Where executives open the full app (records, payments, reports).
const fullAppUrl = 'https://jbf-app.onrender.com';

/// The message the Founder sends so a member learns their ID and how to
/// install and sign in to the member app.
String idInviteMessage({
  required String name,
  required String memberNo,
  required String orgName,
  String appUrl = memberAppUrl,
  bool executive = false,
}) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final unnamed =
      parts.first == 'Member' &&
      parts.length > 1 &&
      RegExp(r'^[+\d]').hasMatch(parts[1]);
  final hello = unnamed ? 'Hello' : 'Hello ${parts.first}';
  return '$hello, this is $orgName.\n'
      'Your member ID is *$memberNo*.\n\n'
      'To get the $orgName app on your phone:\n'
      '1. Open this link: ${executive && appUrl == memberAppUrl ? fullAppUrl : appUrl}\n'
      '   (iPhone: use Safari. Android: use Chrome.)\n'
      '2. iPhone: tap the Share button, then "Add to Home Screen", then "Add".\n'
      '   Android: tap the 3 dots, then "Install app" or "Add to Home screen".\n'
      '3. Open the app from your home screen and tap "First time? Activate '
      'your account".\n'
      '4. Enter your member ID, this phone number, and choose a password.\n'
      '5. Choose your zone. You can only choose it once.\n\n'
      'Next time, just sign in with your member ID and password. '
      '${executive ? 'Your executive tools are inside the app.' : 'You can also see your dues and vote in elections there.'}';
}

Uri whatsappLink(String number, String message) =>
    Uri.https('wa.me', '/$number', {'text': message});
