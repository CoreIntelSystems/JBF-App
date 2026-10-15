/// What the QR code on a member ID card contains, and how scans are read.
abstract final class MemberQr {
  static const _prefix = 'MEMBER:';

  static String encode(String memberNo) => '$_prefix$memberNo';

  /// The member number from a scanned code, or null for other QR codes.
  /// A bare member number (typed or from an older card) is accepted too.
  static String? decode(String raw) {
    final t = raw.trim();
    if (t.startsWith(_prefix)) {
      final n = t.substring(_prefix.length).trim();
      return n.isEmpty ? null : n;
    }
    return RegExp(r'^[A-Z]{2,6}-\d{3,}$').hasMatch(t) ? t : null;
  }
}
