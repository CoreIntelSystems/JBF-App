/// Who is performing a change, for audit and `created_by` columns.
class Actor {
  const Actor({this.userId, this.username, this.deviceId});

  /// Used for system actions such as first-run setup.
  const Actor.system({this.deviceId}) : userId = null, username = 'system';

  final String? userId;
  final String? username;
  final String? deviceId;
}
