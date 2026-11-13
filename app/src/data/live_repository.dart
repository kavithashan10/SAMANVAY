import 'package:supabase_flutter/supabase_flutter.dart';

import '../../department_checklists.dart';
import '../core/geo.dart';
import '../core/models.dart';
import '../core/repository.dart';

/// Supabase-backed repository. Row-level security decides what each role can
/// see; the RPCs enforce what each role can change.
class LiveRepository implements SamanvayRepository {
  LiveRepository(this.user);

  @override
  final AppUser user;

  @override
  bool get isDemo => false;

  SupabaseClient get _db => Supabase.instance.client;
  List<Department>? _departments;

  static const _caseColumns =
      'id,request_number,title,status,case_category,work_activity,road_name,city,latitude,longitude,'
      'work_radius_m,planned_start_date,planned_end_date,requester_id,description';

  static Future<AppUser?> loadCurrentUser() async {
    final auth = Supabase.instance.client.auth.currentUser;
    if (auth == null) return null;
    final row = await Supabase.instance.client
        .from('profiles')
        .select('role,department_id,display_name')
        .eq('id', auth.id)
        .maybeSingle();
    String? deptName;
    final deptId = row?['department_id']?.toString();
    if (deptId != null) {
      final d = await Supabase.instance.client.from('departments').select('name').eq('id', deptId).maybeSingle();
      deptName = d?['name']?.toString();
    }
    final metaName = auth.userMetadata?['display_name']?.toString();
    return AppUser(
      id: auth.id,
      email: auth.email,
      name: (row?['display_name'] ?? metaName ?? auth.email ?? 'SAMANVAY user').toString(),
      role: roleFromDb(row?['role']?.toString()),
      departmentId: deptId,
      departmentName: deptName,
    );
  }

  CaseSummary _toCase(Map<String, dynamic> r) => CaseSummary(
        id: r['id'].toString(),
        number: (r['request_number'] ?? r['id']).toString(),
        title: (r['title'] ?? 'Infrastructure work').toString(),
        status: (r['status'] ?? 'submitted').toString(),
        category: r['case_category']?.toString(),
        activity: r['work_activity']?.toString(),
        road: r['road_name']?.toString(),
        city: r['city']?.toString(),
        location: GeoPoint.tryCreate(num.tryParse('${r['latitude']}'), num.tryParse('${r['longitude']}')),
        radiusM: num.tryParse('${r['work_radius_m']}')?.toDouble(),
        start: DateTime.tryParse('${r['planned_start_date']}'),
        end: DateTime.tryParse('${r['planned_end_date']}'),
        requesterId: r['requester_id']?.toString(),
        description: r['description']?.toString(),
      );

  @override
  Future<List<CaseSummary>> cases() async {
    final rows = await _db.from('excavation_requests').select(_caseColumns).order('created_at', ascending: false).limit(300);
    return [for (final r in rows) _toCase(Map<String, dynamic>.from(r))];
  }

  @override
  Future<CaseSummary> caseById(String id) async =>
      _toCase(Map<String, dynamic>.from(await _db.from('excavation_requests').select(_caseColumns).eq('id', id).single()));

  @override
  Future<List<Department>> departments() async {
    final cached = _departments;
    if (cached != null) return cached;
    final rows = await _db.from('departments').select('id,name').order('name');
    return _departments = [for (final r in rows) Department(r['id'].toString(), (r['name'] ?? '').toString())];
  }

  @override
  Future<List<DeptReview>> reviews(String caseId) async {
    final depts = {for (final d in await departments()) d.id: d.name};
    final rows = await _db
        .from('request_department_reviews')
        .select('id,department_id,review_status,remarks')
        .eq('request_id', caseId)
        .order('assigned_at');
    return [
      for (final r in rows)
        DeptReview(
          id: r['id'].toString(),
          departmentId: r['department_id'].toString(),
          departmentName: depts[r['department_id'].toString()] ?? 'Department',
          status: (r['review_status'] ?? 'pending').toString(),
          remarks: r['remarks']?.toString(),
        ),
    ];
  }

  @override
  Future<List<ReviewChecklistItem>> checklist(String reviewId) => loadReviewChecklist(reviewId);

  @override
  Future<void> setChecklistItem(String reviewId, String itemKey, bool checked) =>
      setReviewChecklistItem(reviewId, itemKey, checked);

  @override
  Future<void> submitReview(String reviewId, String status, String remarks) async {
    await _db.rpc('submit_department_review', params: {'p_review_id': reviewId, 'p_review_status': status, 'p_remarks': remarks});
  }

  static const _transitions = <String, List<String>>{
    'draft': ['submitted'],
    'submitted': ['under_review', 'rejected', 'conflict_detected'],
    'under_review': ['approved', 'rejected', 'conflict_detected'],
    'conflict_detected': ['under_review', 'approved', 'rejected'],
    'approved': ['completed', 'conflict_detected'],
  };

  @override
  List<String> nextStatuses(CaseSummary c) =>
      (user.role == AppRole.coordinator || user.role == AppRole.admin) ? (_transitions[c.status] ?? const []) : const [];

  @override
  Future<void> changeStatus(String caseId, String status, String remarks) async {
    await _db.rpc('change_request_status', params: {'p_request_id': caseId, 'p_new_status': status, 'p_remarks': remarks});
  }

  SpatialResult _spatial(Map<String, dynamic> m) => SpatialResult(
        status: (m['assessment_status'] ?? '').toString(),
        possibleOverlap: m['possible_overlap'] == true,
        advisory: (m['advisory'] ?? '').toString(),
        checkedAt: DateTime.tryParse('${m['checked_at']}'),
      );

  @override
  Future<SpatialResult?> latestSpatial(String caseId) async {
    final rows = await _db
        .from('case_coordination_checks')
        .select('assessment_status,possible_overlap,advisory,checked_at')
        .eq('request_id', caseId)
        .order('checked_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : _spatial(Map<String, dynamic>.from(rows.first));
  }

  @override
  Future<SpatialResult> runSpatial(String caseId) async =>
      _spatial(Map<String, dynamic>.from(await _db.rpc('run_request_coordination_check', params: {'p_request_id': caseId}) as Map));

  @override
  Future<DigOnceResult> digOnce(String caseId) async {
    final m = Map<String, dynamic>.from(await _db.rpc('get_request_dig_once_matches', params: {'p_request_id': caseId}) as Map);
    return DigOnceResult(
      status: (m['status'] ?? '').toString(),
      windowDays: (m['window_days'] as num?)?.toInt() ?? 90,
      distanceM: (m['distance_m'] as num?)?.toDouble() ?? 60,
      matches: [
        for (final x in (m['matches'] as List? ?? const []))
          DigOnceMatch(
            number: (x['request_number'] ?? '').toString(),
            title: x['title']?.toString(),
            category: x['case_category']?.toString(),
            start: DateTime.tryParse('${x['planned_start_date']}'),
            end: DateTime.tryParse('${x['planned_end_date']}'),
            distanceM: (x['distance_m'] as num?)?.toDouble() ?? 0,
            gapDays: (x['gap_days'] as num?)?.toInt() ?? 0,
          ),
      ],
    );
  }

  @override
  Future<String> createCase(NewCaseDraft d) async {
    final p = d.location?.rounded();
    String date(DateTime? t) => t!.toIso8601String().split('T').first;
    final row = await _db
        .from('excavation_requests')
        .insert({
          'requester_id': user.id,
          'title': d.title.trim(),
          'description': d.description.trim(),
          'road_name': d.road.trim(),
          'city': d.city.trim(),
          'case_category': d.category,
          'work_activity': d.activity,
          'work_radius_m': d.radiusM.round(),
          'latitude': p?.lat,
          'longitude': p?.lon,
          if (d.start != null) 'planned_start_date': date(d.start),
          if (d.end != null) 'planned_end_date': date(d.end),
        })
        .select('id')
        .single();
    return row['id'].toString();
  }

  @override
  Future<List<NoticeItem>> publicNotices() async {
    final rows = await _db
        .from('public_excavation_notices')
        .select('title,area_label,city,responsible_department_name,starts_on,ends_on,notice_status,progress_percent')
        .neq('notice_status', 'draft')
        .order('published_at', ascending: false)
        .limit(100);
    return [
      for (final r in rows)
        NoticeItem(
          title: (r['title'] ?? 'Public work').toString(),
          area: [r['area_label'], r['city']].where((x) => x != null).join(', '),
          department: r['responsible_department_name']?.toString(),
          start: DateTime.tryParse('${r['starts_on']}'),
          end: DateTime.tryParse('${r['ends_on']}'),
          status: r['notice_status']?.toString(),
          progress: (r['progress_percent'] as num?)?.toInt(),
        ),
    ];
  }

  @override
  Future<List<CitizenReport>> myReports() async {
    final rows = await _db
        .from('public_obstruction_reports')
        .select('id,report_type,area_label,city,details,report_status,created_at')
        .eq('reporter_id', user.id)
        .order('created_at', ascending: false)
        .limit(100);
    return [
      for (final r in rows)
        CitizenReport(
          id: r['id'].toString(),
          type: (r['report_type'] ?? 'other').toString(),
          area: (r['area_label'] ?? '').toString(),
          city: r['city']?.toString(),
          details: (r['details'] ?? '').toString(),
          status: (r['report_status'] ?? 'submitted').toString(),
          createdAt: DateTime.tryParse('${r['created_at']}') ?? DateTime.now(),
        ),
    ];
  }

  @override
  Future<void> submitReport({required String type, required String city, required String area, required String details}) async {
    await _db.from('public_obstruction_reports').insert({
      'reporter_id': user.id,
      'report_type': type,
      'city': city.trim(),
      'area_label': area.trim(),
      'details': details.trim(),
    });
  }

  @override
  Future<List<InboxItem>> inbox() async {
    final rows = await _db
        .from('user_notifications')
        .select('id,title,body,created_at,read_at,request_id,notification_type')
        .eq('recipient_id', user.id)
        .order('created_at', ascending: false)
        .limit(100);
    return [
      for (final r in rows)
        InboxItem(
          id: r['id'].toString(),
          title: (r['title'] ?? '').toString(),
          body: (r['body'] ?? '').toString(),
          createdAt: DateTime.tryParse('${r['created_at']}') ?? DateTime.now(),
          read: r['read_at'] != null,
          caseId: r['request_id']?.toString(),
          kind: (r['notification_type'] ?? 'system').toString(),
        ),
    ];
  }

  @override
  Future<void> markRead(String id) async {
    await _db
        .from('user_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('recipient_id', user.id);
  }
}
