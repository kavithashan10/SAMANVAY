import '../../department_checklists.dart' show ReviewChecklistItem;
import 'models.dart';

/// Everything the screens need, independent of where the data lives.
/// [LiveRepository] talks to Supabase; [DemoRepository] serves the offline
/// LPU demonstration. Both enforce the same role rules so the flow is identical.
abstract class SamanvayRepository {
  bool get isDemo;
  AppUser get user;

  Future<List<CaseSummary>> cases();
  Future<CaseSummary> caseById(String id);
  Future<List<DeptReview>> reviews(String caseId);
  Future<List<Department>> departments();

  Future<List<ReviewChecklistItem>> checklist(String reviewId);
  Future<void> setChecklistItem(String reviewId, String itemKey, bool checked);
  Future<void> submitReview(String reviewId, String status, String remarks);

  /// Status changes this user may make on [c] right now.
  List<String> nextStatuses(CaseSummary c);
  Future<void> changeStatus(String caseId, String status, String remarks);

  Future<SpatialResult?> latestSpatial(String caseId);
  Future<SpatialResult> runSpatial(String caseId);
  Future<DigOnceResult> digOnce(String caseId);

  Future<String> createCase(NewCaseDraft draft);

  Future<List<NoticeItem>> publicNotices();
  Future<List<CitizenReport>> myReports();
  Future<void> submitReport({required String type, required String city, required String area, required String details});

  Future<List<InboxItem>> inbox();
  Future<void> markRead(String id);
}

/// Friendly message for any repository failure.
String friendlyError(Object e) {
  final s = e.toString();
  if (s.contains('DEPARTMENT_CHECKLIST_INCOMPLETE')) return 'Tick every item in the department checklist before approving.';
  if (s.contains('not authorised') || s.contains('Not authorised') || s.contains('permission denied')) {
    return 'Your account is not allowed to do that.';
  }
  if (s.contains('Could not find the function') || s.contains('PGRST202')) {
    return 'This feature is not deployed on the server yet.';
  }
  if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('ClientException')) {
    return 'No connection. Check the internet and try again.';
  }
  return 'Something went wrong. Please try again.';
}
