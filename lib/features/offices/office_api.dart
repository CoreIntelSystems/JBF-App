import '../../data/sync/sync_api.dart';

/// The committee office functions of the cloud, called with the caller's
/// token. Who sits in which office, and who may do what there, is decided
/// in the cloud (supabase/migrations/..._committee_offices.sql).
class OfficeApi {
  OfficeApi(this._api, this.token);

  final SyncApi _api;

  /// The cloud connection, for screens the office links to.
  SyncApi get sync => _api;
  final String token;

  static Map<String, dynamic> _map(Object? o) =>
      Map<String, dynamic>.from(o! as Map);

  static List<Map<String, dynamic>> _list(Object? o) => [
    for (final x in o! as List) Map<String, dynamic>.from(x as Map),
  ];

  /// The offices the caller sits in (empty when none).
  Future<List<Map<String, dynamic>>> list() async =>
      _list(await _api.rpc('office_list', {'token': token}));

  /// Everything on one office's desk: members, tasks, notes, notices, log,
  /// and for the Electoral Commission its elections and the voter roll.
  Future<Map<String, dynamic>> home(String committee) async => _map(
    await _api.rpc('office_home', {'token': token, 'committee': committee}),
  );

  Future<void> saveTask(
    String committee, {
    String? id,
    required String title,
    String? details,
    String? assignee,
    DateTime? dueOn,
    String? electionId,
  }) => _api.rpc('office_task_save', {
    'token': token,
    'committee': committee,
    'id': id,
    'title': title,
    'details': details,
    'assignee': assignee,
    'due_on': dueOn == null ? null : _day(dueOn),
    'election': electionId,
  });

  Future<void> setTaskDone(String committee, String id, bool done) => _api.rpc(
    'office_task_done',
    {'token': token, 'committee': committee, 'id': id, 'done': done},
  );

  Future<void> removeTask(String committee, String id) => _api.rpc(
    'office_task_remove',
    {'token': token, 'committee': committee, 'id': id},
  );

  /// Adds the committee's standard steps to an election.
  Future<void> addChecklist(String committee, String electionId) => _api.rpc(
    'office_add_checklist',
    {'token': token, 'committee': committee, 'election': electionId},
  );

  /// Adds the Disciplinary Committee's standard hearing steps to a
  /// complaint.
  Future<void> addCaseSteps(String committee, String caseId) => _api.rpc(
    'office_add_case_steps',
    {'token': token, 'committee': committee, 'case_id': caseId},
  );

  /// Adds the Organizing Committee's standard planning steps to an event.
  Future<void> addEventSteps(String committee, String eventId) => _api.rpc(
    'office_add_event_steps',
    {'token': token, 'committee': committee, 'event': eventId},
  );

  /// Adds the Welfare Committee's standard steps to a welfare case.
  Future<void> addWelfareSteps(String committee, String caseId) => _api.rpc(
    'office_add_welfare_steps',
    {'token': token, 'committee': committee, 'welfare_case': caseId},
  );

  /// Adds the Secretariat's standard steps to a meeting.
  Future<void> addMeetingSteps(String committee, String meetingId) => _api.rpc(
    'office_add_meeting_steps',
    {'token': token, 'committee': committee, 'meeting': meetingId},
  );

  /// Adds the Treasury's standard month-end steps to [period] (`YYYY-MM`).
  Future<void> addMonthSteps(String committee, String period) => _api.rpc(
    'office_add_month_steps',
    {'token': token, 'committee': committee, 'period': period},
  );

  /// [kind] is `meeting`, `decision` or `note`.
  Future<void> saveNote(
    String committee, {
    String? id,
    required String kind,
    required String title,
    required String body,
    DateTime? metOn,
  }) => _api.rpc('office_note_save', {
    'token': token,
    'committee': committee,
    'id': id,
    'kind': kind,
    'title': title,
    'body': body,
    'met_on': metOn == null ? null : _day(metOn),
  });

  Future<void> removeNote(String committee, String id) => _api.rpc(
    'office_note_remove',
    {'token': token, 'committee': committee, 'id': id},
  );

  Future<void> postNotice(String committee, String title, String body) =>
      _api.rpc('office_notice_post', {
        'token': token,
        'committee': committee,
        'title': title,
        'body': body,
      });

  Future<void> withdrawNotice(String committee, String id) => _api.rpc(
    'office_notice_withdraw',
    {'token': token, 'committee': committee, 'id': id},
  );

  /// Notices committees have posted to every member, newest first.
  Future<List<Map<String, dynamic>>> notices({String? committee}) async =>
      _list(
        await _api.rpc('office_notices', {
          'token': token,
          'committee': committee,
        }),
      );

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// A message for the screen from a failed call.
String officeError(Object e) => e is SyncException
    ? (e.offline
          ? 'The office needs internet. Connect and pull down to try again.'
          : e.message)
    : 'Something went wrong. Please try again.';
